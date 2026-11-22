# FirmyVPN

VPN-клиент: **Windows** (Go + sing-box + Wails + React) и **iOS** (Go + sing-box +
SwiftUI, собирается в готовый `.ipa` на GitHub — Mac не нужен).

## Версии (последние релизы)

- **[📱 Айфон-версия (iOS)](https://github.com/Dooyfil/FirmyVPN/releases/download/ios-unsigned/FirmyVPN-iPhone-version.ipa)** —
  версия для iPhone, подписывайте своим Apple-сертификатом.
- **[💻 ПК-версия (Windows)](https://github.com/Dooyfil/FirmyVPN/releases/download/pc-version/FirmyVPN-Setup.exe)** —
  установщик ПК-версии VPN.

## Windows

Готовые файлы:

- `build/bin/FirmyVPN.exe` — приложение;
- `installer/FirmyVPN-Setup.exe` — установщик.

Сборка заново:

```powershell
wails build -skipbindings -tags "with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_acme,with_clash_api,with_tailscale,with_ccm,with_ocm,with_cloudflared,with_naive_outbound,with_purego,with_usbip,with_openvpn,with_openconnect,badlinkname,tfogo_checklinkname0" -ldflags "-checklinkname=0"
# установщик:
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\FirmyVPN.iss
```

Возможности: импорт всех форматов ключей из Telegram-ботов (vless, vmess,
trojan, ss, hysteria2, tuic, anytls, подписки в текте/base64, sing-box JSON,
Clash YAML), TUN и режим прокси, kill switch, выбор DNS, правила маршрутизации,
пинг, график скорости, статистика сессии, тест скорости, журнал, трей,
автозапуск, горячая клавиша Ctrl+Alt+V.

## iOS

Смотрите [`ios/README.md`](ios/README.md): проект загружается на GitHub,
Actions собирает **неподписанный** `FirmyVPN-iPhone-version.ipa`, вы подписываете его
своим сертификатом (ESign / Feather / Scarlet / zsign) и ставите на iPhone.

- ядро Go — `ios/core/` (тот же парсер и сборка конфига, что на PC);
- расширение VPN — `ios/PacketTunnel/` (sing-box внутри Network Extension);
- приложение — `ios/App/` (SwiftUI, тёмный аврора-дизайн).

## Структура

```
app.go            — Wails-связка (все методы для UI)
internal/engine   — сборка конфига, туннель, статистика, пинг, speed test
internal/parse    — парсер ключей/подписок
internal/store    — хранение серверов и настроек
frontend/         — React-интерфейс
installer/        — Inno Setup
ios/              — iOS-приложение и ядро для gomobile
.github/workflows — сборка iOS-IPA на макинах GitHub
```
