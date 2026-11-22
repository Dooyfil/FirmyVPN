// Package firmycore — Go-ядро FirmyVPN для iOS: импорт ключей/подписок
// (все форматы из Telegram-ботов) и сборка конфига sing-box.
// Результат обменивается со Swift-оболочкой строками JSON: gomobile превращает
// эти функции в статические методы Firmycore* в Libbox.xcframework.
package firmycore

import (
	"encoding/json"

	"firmyvpn/ios/core/model"
	"firmyvpn/ios/core/parse"
)

// importResult — результат разбора ввода для Swift.
type importResult struct {
	Servers []*model.Server `json:"servers"`
	Errors  []string        `json:"errors"`
}

// ParseInputJSON разбирает произвольный текст: ссылки по строкам (vless://,
// vmess://, trojan://, ss://, hysteria2://, tuic://, anytls://), base64-подписку,
// sing-box JSON или Clash YAML.
//
//	source: "manual" | "subscription" | "file"
//	subURL/subName: имя и адрес подписки (для source=subscription), иначе "".
//
// Возвращает JSON вида {"servers":[...],"errors":[...]}.
func ParseInputJSON(text, source, subURL, subName string) (string, error) {
	servers, errs := parse.ParseInput(text, source, subURL, subName)
	b, err := json.Marshal(importResult{Servers: servers, Errors: errs})
	return string(b), err
}

// BuildConfigJSON собирает JSON-конфиг sing-box.
//
//	serverJSON — один model.Server (с полем outbound);
//	settingsJSON — model.Settings;
//	basePath   — папка расширения (кэш clash API, cache.db).
//
// Возвращает сам конфиг sing-box.
func BuildConfigJSON(serverJSON, settingsJSON, basePath string) (string, error) {
	var srv model.Server
	if err := json.Unmarshal([]byte(serverJSON), &srv); err != nil {
		return "", err
	}
	var st model.Settings
	if err := json.Unmarshal([]byte(settingsJSON), &st); err != nil {
		return "", err
	}
	cfg, err := buildConfig(&srv, &st, basePath)
	if err != nil {
		return "", err
	}
	return string(cfg), nil
}

// PingTCP замеряет задержку до сервера: TCP-соединение к host:port.
// Возвращает миллисекунды или -1, если не удалось. timeoutMs — таймаут попытки.
func PingTCP(host string, port int, timeoutMs int) int32 {
	return pingTCP(host, port, timeoutMs)
}
