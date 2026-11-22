# FirmyVPN для iOS

Готовый `.ipa`, который нужно только **подписать своим сертификатом** и
поставить на iPhone. Mac не нужен: собирается на макинах GitHub.

## Как получить IPA (3 шага)

1. **Загрузите проект на GitHub** (новый публичный репозиторий, ветка `main`):

   ```powershell
   cd C:\Users\d3sp1res\Desktop\FirmyVPN
   git init -b main
   git add .
   git commit -m "FirmyVPN"
   # далее создайте пустой репозиторий на github.com и:
   git remote add origin https://github.com/<ваш-логин>/<репозиторий>.git
   git push -u origin main
   ```

2. **Запустите сборку**: GitHub → вкладка **Actions** → **iOS** →
   **Run workflow**. Первый прогон ~15–25 минут (ядро sing-box кэшируется,
   дальше быстрее). Закончится артефактом **FirmyVPN-unsigned** со ссылкой
   на `FirmyVPN-unsigned.ipa` (и тем же файлом в релизах, если отметить
   «Опубликовать IPA»).

3. **Подпишите и установите** на iPhone одним из:

   - **ESign** / **Feather** / **Scarlet** — импортируйте IPA, свой p12 +
     профиль, подпишите и установите;
   - **zsign** (Windows/CLI): `zsign -k cert.p12 -m cert.mobileprovision -o signed.ipa FirmyVPN-unsigned.ipa`.

   Подписанная сборка просит доверия в Настройках → Основные → VPN и управление.

> Нужен **оплаченный** аккаунт Apple Developer (или самоподписка на
 jailbroken/через TrollStore): entitlement `packet-tunnel-provider`
> (Network Extension) в обычном free-профиле недоступен.

## Что внутри

| Слой | Где | Что делает |
|---|---|---|
| Ядро Go | `core/` | парсер всех форматов (vless/vmess/trojan/ss/hysteria2/tuic/anytls, base64-подписки, JSON, Clash YAML), сборка конфига sing-box, TCP-пинг |
| libbox | `Frameworks/Libbox.xcframework` | sing-box 1.14.4, собирается `scripts/build-libbox.sh` через gomobile |
| Расширение | `PacketTunnel/` | NEPacketTunnelProvider, мост PlatformInterface (openTun → NEPacketTunnelNetworkSettings → fd utun), статистика clash API |
| Приложение | `App/`, `Shared/` | SwiftUI: главный экран с кнопкой питания, серверы с пингом, импорт (подписка/файл), тест скорости, настройки, журнал |

## Особенности

- **Kill switch** = `NETunnelProviderProtocol.includeAllNetworks`.
- **Бесшовная смена сервера** = перезапись `servers.json`/`settings.json` в
  App Group + сообщение расширению `reload` (без разрыва туннеля).
- **App Group** `group.com.firmyvpn.app`: если переподписанная сборка его не
  получает, настройки едут в `providerConfiguration` профиля VPN (фолбэк).
- **Импорт** — ровно две вкладки: **Подписка** и **Файл** (как в PC-версии).
- Режим «прокси» на iOS не нужен: всегда TUN.

## Локальная сборка (только если есть Mac)

```bash
bash scripts/build-libbox.sh     # Libbox.xcframework
xcodegen generate                # FirmyVPN.xcodeproj
open FirmyVPN.xcodeproj          # подпись в Config/Signing.xcconfig
```
