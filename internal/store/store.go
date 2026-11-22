// Package store — хранение серверов, подписок и настроек FirmyVPN на диске.
package store

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"

	"FirmyVPN/internal/model"
)

var (
	mu       sync.Mutex
	dataDir  string
	servers  []*model.Server
	subs     []*model.Subscription
	settings model.Settings
)

func dir() string {
	if dataDir != "" {
		return dataDir
	}
	base, err := os.UserConfigDir()
	if err != nil {
		base = "."
	}
	dataDir = filepath.Join(base, "FirmyVPN")
	_ = os.MkdirAll(dataDir, 0o755)
	return dataDir
}

// SetDataDir переопределяет каталог данных (для тестов).
func SetDataDir(d string) { dataDir = d }

func loadJSON(name string, v any) {
	b, err := os.ReadFile(filepath.Join(dir(), name))
	if err != nil {
		return
	}
	_ = json.Unmarshal(b, v)
}

func saveJSON(name string, v any) error {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	tmp := filepath.Join(dir(), name+".tmp")
	if err := os.WriteFile(tmp, b, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, filepath.Join(dir(), name))
}

// Load читает все данные с диска.
func Load() {
	mu.Lock()
	defer mu.Unlock()
	loadJSON("servers.json", &servers)
	loadJSON("subscriptions.json", &subs)
	settings = model.DefaultSettings()
	loadJSON("settings.json", &settings)
	if settings.ProxyPort == 0 {
		settings.ProxyPort = 10808
	}
	if settings.DNS == "" {
		settings.DNS = "auto"
	}
	if settings.Mode == "" {
		settings.Mode = "tun"
	}
	if settings.LogLevel == "" {
		settings.LogLevel = "info"
	}
}

// Servers — список серверов.
func Servers() []*model.Server {
	mu.Lock()
	defer mu.Unlock()
	out := make([]*model.Server, len(servers))
	copy(out, servers)
	return out
}

// SaveServers сохраняет список серверов.
func SaveServers(list []*model.Server) error {
	mu.Lock()
	defer mu.Unlock()
	servers = list
	return saveJSON("servers.json", servers)
}

// AddServers добавляет новые (дедуплицируя по URI).
func AddServers(list []*model.Server) (added int) {
	mu.Lock()
	defer mu.Unlock()
	existing := map[string]bool{}
	for _, s := range servers {
		existing[s.URI] = true
	}
	for _, s := range list {
		if s == nil || s.URI == "" || existing[s.URI] {
			continue
		}
		existing[s.URI] = true
		servers = append(servers, s)
		added++
	}
	_ = saveJSON("servers.json", servers)
	return added
}

// DeleteServer удаляет сервер по id.
func DeleteServer(id string) bool {
	mu.Lock()
	defer mu.Unlock()
	for i, s := range servers {
		if s.ID == id {
			servers = append(servers[:i], servers[i+1:]...)
			_ = saveJSON("servers.json", servers)
			return true
		}
	}
	return false
}

// RenameServer переименовывает сервер.
func RenameServer(id, name string) bool {
	mu.Lock()
	defer mu.Unlock()
	for _, s := range servers {
		if s.ID == id {
			s.Name = name
			_ = saveJSON("servers.json", servers)
			return true
		}
	}
	return false
}

// SetPing сохраняет результат пинга.
func SetPing(id string, ping int) {
	mu.Lock()
	defer mu.Unlock()
	for _, s := range servers {
		if s.ID == id {
			s.Ping = ping
			_ = saveJSON("servers.json", servers)
			return
		}
	}
}

// Subscriptions — список подписок.
func Subscriptions() []*model.Subscription {
	mu.Lock()
	defer mu.Unlock()
	out := make([]*model.Subscription, len(subs))
	copy(out, subs)
	return out
}

// SaveSubscription добавляет/обновляет подписку.
func SaveSubscription(s *model.Subscription) {
	mu.Lock()
	defer mu.Unlock()
	for i, x := range subs {
		if x.URL == s.URL {
			subs[i] = s
			_ = saveJSON("subscriptions.json", subs)
			return
		}
	}
	subs = append(subs, s)
	_ = saveJSON("subscriptions.json", subs)
}

// DeleteSubscription удаляет подписку и её серверы.
func DeleteSubscription(url string) {
	mu.Lock()
	defer mu.Unlock()
	for i, x := range subs {
		if x.URL == url {
			subs = append(subs[:i], subs[i+1:]...)
			break
		}
	}
	_ = saveJSON("subscriptions.json", subs)
	// удаляем серверы этой подписки
	filtered := servers[:0]
	for _, s := range servers {
		if s.SubURL != url {
			filtered = append(filtered, s)
		}
	}
	servers = filtered
	_ = saveJSON("servers.json", servers)
}

// Settings текущие настройки.
func Settings() model.Settings {
	mu.Lock()
	defer mu.Unlock()
	return settings
}

// SaveSettings сохраняет настройки.
func SaveSettings(s model.Settings) error {
	mu.Lock()
	defer mu.Unlock()
	settings = s
	return saveJSON("settings.json", settings)
}
