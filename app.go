package main

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"FirmyVPN/internal/engine"
	"FirmyVPN/internal/model"
	"FirmyVPN/internal/parse"
	"FirmyVPN/internal/store"
	"FirmyVPN/internal/winutil"

	"github.com/wailsapp/wails/v2/pkg/runtime"
)

// App — корневая структура приложения, методы которой доступны из фронтенда.
type App struct {
	ctx          context.Context
	engine       *engine.Engine
	watchdogQuit func()
	watchdogOnce sync.Once

	logMu  sync.Mutex
	logs   []model.LogEntry
	maxLog int

	hotkeyOn     bool
	shutdownOnce sync.Once
}

// NewApp создаёт экземпляр App.
func NewApp() *App {
	return &App{
		engine: engine.New(),
		maxLog: 800,
	}
}

// ---------- lifecycle ----------

func (a *App) startup(ctx context.Context) {
	a.ctx = ctx

	store.Load()

	a.engine.SetLogSink(func(level, msg string) {
		entry := model.LogEntry{
			Time:    time.Now().Format("15:04:05"),
			Level:   level,
			Message: msg,
		}
		a.pushLog(entry)
		runtime.EventsEmit(ctx, "vpn:log", entry)
	})
	a.engine.SetStateSink(func(st model.Status) {
		runtime.EventsEmit(ctx, "vpn:state", st)
		updateTrayState(st.Connected, st.ServerName)
	})

	// системный трей
	startTray(a)

	// kill switch мог остаться с прошлого раза
	if active, _ := winutil.KillSwitchActive(); active {
		runtime.EventsEmit(ctx, "vpn:killswitch", true)
	}

	// watchdog (защита от падения при включённом kill switch)
	st := store.Settings()
	a.spawnWatchdog(st.KillSwitch)

	// горячая клавиша
	if st.HotkeyEnabled {
		a.enableHotkey()
	}

	// автоподключение при запуске
	if st.AutoConnect {
		go func() {
			time.Sleep(700 * time.Millisecond)
			if err := a.Connect(""); err != nil {
				a.pushLog(model.LogEntry{Time: time.Now().Format("15:04:05"), Level: "warn",
					Message: "автоподключение не удалось: " + err.Error()})
			}
		}()
	}
}

func (a *App) spawnWatchdog(blockOnDeath bool) {
	if a.watchdogQuit != nil {
		a.watchdogQuit()
		a.watchdogQuit = nil
	}
	quit, err := winutil.SpawnWatchdog(blockOnDeath)
	if err == nil {
		a.watchdogQuit = quit
	}
}

func (a *App) enableHotkey() {
	if a.hotkeyOn {
		return
	}
	err := winutil.StartHotkey(func() {
		go a.ToggleConnect()
	})
	if err == nil {
		a.hotkeyOn = true
	} else {
		a.pushLog(model.LogEntry{Time: time.Now().Format("15:04:05"), Level: "warn",
			Message: "горячая клавиша Ctrl+Alt+V недоступна: " + err.Error()})
	}
}

func (a *App) shutdown(ctx context.Context) {
	a.shutdownOnce.Do(func() {
		st := store.Settings()
		connected := a.engine.Connected()
		active, _ := winutil.KillSwitchActive()

		// При включённом kill switch и активном подключении НЕ говорим
		// watchdog'у "quit" — после смерти процесса он заблокирует интернет
		// (туннель умрёт вместе с процессом — утечки быть не должно).
		if a.watchdogQuit != nil && !(st.KillSwitch && (connected || active)) {
			a.watchdogQuit()
		}

		if a.hotkeyOn {
			winutil.StopHotkey()
		}
		_ = a.engine.Stop()
		stopTray()
	})
}

// ---------- импорт ----------

// ImportText импортирует текст: ссылки-ключи, base64-подписку, JSON или Clash YAML.
func (a *App) ImportText(text string) model.ImportResult {
	servers, errs := parse.ParseInput(text, "manual", "", "")
	added := store.AddServers(servers)
	return model.ImportResult{Added: added, Skipped: len(servers) - added, Errors: errs}
}

// ImportSubscription скачивает подписку и импортирует её серверов.
func (a *App) ImportSubscription(subURL, name string) model.ImportResult {
	body, err := fetchURL(subURL)
	if err != nil {
		return model.ImportResult{Errors: []string{"загрузка подписки: " + err.Error()}}
	}
	if name == "" {
		name = shortURL(subURL)
	}
	servers, errs := parse.ParseInput(body, "subscription", subURL, name)
	added := store.AddServers(servers)
	if added > 0 || len(servers) > 0 {
		store.SaveSubscription(&model.Subscription{
			URL: subURL, Name: name, Count: len(servers), LastSync: time.Now().UnixMilli(),
		})
	}
	return model.ImportResult{Added: added, Skipped: len(servers) - added, Errors: errs}
}

// RefreshSubscription обновляет серверы подписки (заменяет старые).
func (a *App) RefreshSubscription(subURL string) model.ImportResult {
	body, err := fetchURL(subURL)
	if err != nil {
		return model.ImportResult{Errors: []string{"загрузка подписки: " + err.Error()}}
	}
	var subName string
	for _, s := range store.Subscriptions() {
		if s.URL == subURL {
			subName = s.Name
		}
	}
	servers, errs := parse.ParseInput(body, "subscription", subURL, subName)
	// заменяем серверы этой подписки
	all := store.Servers()
	filtered := make([]*model.Server, 0, len(all))
	for _, s := range all {
		if s.SubURL != subURL {
			filtered = append(filtered, s)
		}
	}
	_ = store.SaveServers(filtered)
	added := store.AddServers(servers)
	store.SaveSubscription(&model.Subscription{
		URL: subURL, Name: subName, Count: len(servers), LastSync: time.Now().UnixMilli(),
	})
	return model.ImportResult{Added: added, Skipped: 0, Errors: errs}
}

// DeleteSubscription удаляет подписку и её серверы.
func (a *App) DeleteSubscription(subURL string) {
	store.DeleteSubscription(subURL)
}

// GetSubscriptions список подписок.
func (a *App) GetSubscriptions() []*model.Subscription {
	return store.Subscriptions()
}

// ---------- серверы ----------

// GetServers список серверов.
func (a *App) GetServers() []*model.Server {
	return store.Servers()
}

// DeleteServer удаляет сервер.
func (a *App) DeleteServer(id string) bool {
	return store.DeleteServer(id)
}

// RenameServer переименовывает сервер.
func (a *App) RenameServer(id, name string) bool {
	return store.RenameServer(id, strings.TrimSpace(name))
}

// PingServer пингует сервер (TCP handshake, мс; -1 — недоступен).
func (a *App) PingServer(id string) int {
	for _, s := range store.Servers() {
		if s.ID == id {
			p := engine.Ping(s.Host, s.Port)
			store.SetPing(id, p)
			return p
		}
	}
	return -1
}

// PingAll пингует все серверы параллельно, возвращает map[id]ping.
func (a *App) PingAll() map[string]int {
	servers := store.Servers()
	result := make(map[string]int, len(servers))
	var mu sync.Mutex
	var wg sync.WaitGroup
	sem := make(chan struct{}, 16)
	for _, s := range servers {
		wg.Add(1)
		go func(s *model.Server) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()
			p := engine.Ping(s.Host, s.Port)
			store.SetPing(s.ID, p)
			mu.Lock()
			result[s.ID] = p
			mu.Unlock()
		}(s)
	}
	wg.Wait()
	return result
}

// ---------- подключение ----------

// Connect подключается к серверу по id.
func (a *App) Connect(serverID string) error {
	st := store.Settings()
	servers := store.Servers()
	if len(servers) == 0 {
		return fmt.Errorf("нет серверов — сначала импортируйте ключ или подписку")
	}

	// пустой id = «подключиться к лучшему/последнему серверу»
	var target *model.Server
	if serverID == "" {
		if st.FastestServer {
			target = fastestServer(servers)
		} else if st.SelectedServer != "" {
			target = findServer(servers, st.SelectedServer)
		}
	} else {
		target = findServer(servers, serverID)
	}
	if target == nil {
		if st.FastestServer {
			target = fastestServer(servers)
		}
		if target == nil {
			target = servers[0]
		}
	}

	st.SelectedServer = target.ID
	_ = store.SaveSettings(st)
	// уже подключены — просто переезжаем на другой узел без отключения
	if a.engine.Connected() {
		return a.engine.Switch(target, st)
	}
	return a.engine.Start(target, st)
}

func findServer(list []*model.Server, id string) *model.Server {
	for _, s := range list {
		if s.ID == id {
			return s
		}
	}
	return nil
}

// fastestServer возвращает сервер с минимальным пингом (учтённые только успешные).
func fastestServer(list []*model.Server) *model.Server {
	var best *model.Server
	for _, s := range list {
		if s.Ping < 0 {
			continue
		}
		if best == nil || s.Ping < best.Ping {
			best = s
		}
	}
	return best
}

// SwitchServer бесшовно меняет регион/сервер, не отключая VPN.
func (a *App) SwitchServer(serverID string) error {
	return a.Connect(serverID)
}

// Disconnect останавливает подключение.
func (a *App) Disconnect() error {
	return a.engine.Stop()
}

// ToggleConnect — переключатель для горячей клавиши и трея.
func (a *App) ToggleConnect() {
	if a.engine.Connected() {
		_ = a.engine.Stop()
		return
	}
	st := store.Settings()
	id := st.SelectedServer
	if id == "" {
		servers := store.Servers()
		if len(servers) == 0 {
			runtime.MessageDialog(a.ctx, runtime.MessageDialogOptions{
				Type:    runtime.ErrorDialog,
				Title:   "FirmyVPN",
				Message: "Нет импортированных серверов. Добавьте ключ или подписку.",
			})
			return
		}
		id = servers[0].ID
	}
	if err := a.Connect(id); err != nil {
		runtime.MessageDialog(a.ctx, runtime.MessageDialogOptions{
			Type:    runtime.ErrorDialog,
			Title:   "FirmyVPN — ошибка подключения",
			Message: err.Error(),
		})
	}
}

// GetStatus статус подключения.
func (a *App) GetStatus() model.Status {
	return a.engine.Status()
}

// SpeedTest тест скорости (все этапы разом).
func (a *App) SpeedTest() (model.SpeedResult, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 300*time.Second)
	defer cancel()
	return a.engine.SpeedTest(ctx)
}

// SpeedLatency этап 1: задержка и джиттер.
func (a *App) SpeedLatency() (model.LatencyResult, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	return a.engine.SpeedLatency(ctx)
}

// SpeedDown этап 2: скачивание (живой прогресс в SpeedProgress).
func (a *App) SpeedDown() (float64, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 240*time.Second)
	defer cancel()
	return a.engine.SpeedDown(ctx)
}

// SpeedUp этап 3: загрузка.
func (a *App) SpeedUp() (float64, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 240*time.Second)
	defer cancel()
	return a.engine.SpeedUp(ctx)
}

// SpeedProgress живой прогресс текущего этапа теста.
func (a *App) SpeedProgress() map[string]any {
	return a.engine.SpeedProgress()
}

// ---------- логи ----------

func (a *App) pushLog(e model.LogEntry) {
	a.logMu.Lock()
	a.logs = append(a.logs, e)
	if len(a.logs) > a.maxLog {
		a.logs = a.logs[len(a.logs)-a.maxLog:]
	}
	a.logMu.Unlock()
}

// GetLogs последние n строк лога.
func (a *App) GetLogs(n int) []model.LogEntry {
	a.logMu.Lock()
	defer a.logMu.Unlock()
	if n <= 0 || n > len(a.logs) {
		n = len(a.logs)
	}
	out := make([]model.LogEntry, n)
	copy(out, a.logs[len(a.logs)-n:])
	return out
}

// ClearLogs очищает буфер логов.
func (a *App) ClearLogs() {
	a.logMu.Lock()
	a.logs = nil
	a.logMu.Unlock()
}

// ---------- настройки ----------

// GetInitialState всё состояние одним вызовом при старте UI.
func (a *App) GetInitialState() map[string]any {
	ks, _ := winutil.KillSwitchActive()
	return map[string]any{
		"settings":      store.Settings(),
		"servers":       store.Servers(),
		"subscriptions": store.Subscriptions(),
		"status":        a.engine.Status(),
		"killSwitch":    ks,
		"logs":          a.GetLogs(200),
		"version":       Version,
		"admin":         winutil.IsAdmin(),
	}
}

// SaveSettings сохраняет настройки и применяет их.
func (a *App) SaveSettings(s model.Settings) error {
	prev := store.Settings()
	if err := store.SaveSettings(s); err != nil {
		return err
	}
	// автозагрузка
	if prev.Autostart != s.Autostart {
		if err := winutil.SetAutostart(s.Autostart); err != nil {
			return fmt.Errorf("автозагрузка: %w", err)
		}
	}
	// горячая клавиша
	if s.HotkeyEnabled && !a.hotkeyOn {
		a.enableHotkey()
	} else if !s.HotkeyEnabled && a.hotkeyOn {
		winutil.StopHotkey()
		a.hotkeyOn = false
	}
	// watchdog перезапускаем при смене kill switch
	if prev.KillSwitch != s.KillSwitch {
		a.spawnWatchdog(s.KillSwitch)
		if !s.KillSwitch {
			_ = winutil.RemoveKillSwitchRules()
			runtime.EventsEmit(a.ctx, "vpn:killswitch", false)
		}
	}
	return nil
}

// UnblockKillSwitch снимает блокировку интернета.
func (a *App) UnblockKillSwitch() error {
	if err := winutil.RemoveKillSwitchRules(); err != nil {
		return err
	}
	runtime.EventsEmit(a.ctx, "vpn:killswitch", false)
	a.pushLog(model.LogEntry{Time: time.Now().Format("15:04:05"), Level: "info",
		Message: "kill switch отключён, доступ в интернет восстановлен"})
	return nil
}

// ---------- misc ----------

// ShowHide переключает видимость окна (для трея).
func (a *App) ShowHide() {
	runtime.WindowShow(a.ctx)
	runtime.WindowUnminimise(a.ctx)
}

// Quit корректный выход из приложения.
func (a *App) Quit() {
	runtime.Quit(a.ctx)
}

// OpenFolder открывает папку данных приложения.
func (a *App) OpenFolder() {
	// shell: explorer с папкой данных
	go func() {
		_ = execExplorer()
	}()
}

func fetchURL(rawURL string) (string, error) {
	client := &http.Client{Timeout: 30 * time.Second}
	req, err := http.NewRequest(http.MethodGet, rawURL, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", "FirmyVPN/1.0 (Windows)")
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		return "", fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 16<<20))
	if err != nil {
		return "", err
	}
	return string(body), nil
}

func shortURL(u string) string {
	u = strings.TrimPrefix(u, "https://")
	u = strings.TrimPrefix(u, "http://")
	if len(u) > 40 {
		u = u[:40] + "…"
	}
	return u
}
