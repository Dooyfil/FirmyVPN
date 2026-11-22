/* ============================================================
   FirmyVPN — preview shim: имитирует Wails runtime + Go bindings,
   чтобы открыть интерфейс в обычном браузере для ревью дизайна.
   ============================================================ */

const listeners = {}
const emit = (name, data) => (listeners[name] || []).forEach((fn) => { try { fn(data) } catch (e) { console.error(e) } })

window.runtime = {
  EventsOnMultiple(name, cb) {
    ;(listeners[name] = listeners[name] || []).push(cb)
    return () => {
      listeners[name] = (listeners[name] || []).filter((x) => x !== cb)
    }
  },
  EventsOn(name, cb) { return window.runtime.EventsOnMultiple(name, cb) },
  EventsOff() {},
  EventsOffAll() {},
  EventsOnce(name, cb) { return window.runtime.EventsOnMultiple(name, cb) },
  EventsEmit: emit,
  LogPrint() {}, LogTrace() {}, LogDebug() {}, LogInfo() {},
  LogWarning() {}, LogError() {}, LogFatal() {},
  WindowHide() { console.log('[shim] WindowHide') },
  WindowShow() { console.log('[shim] WindowShow') },
  WindowMinimise() {}, WindowUnminimise() {},
  WindowToggleMaximise() {}, WindowMaximise() {}, WindowUnmaximise() {},
  WindowIsMaximised() { return Promise.resolve(false) },
  WindowCenter() {}, WindowSetSize() {}, WindowSetPosition() {},
  WindowSetAlwaysOnTop() {}, WindowSetDarkTheme() {}, WindowSetLightTheme() {},
  WindowSetTitle() {}, WindowReload() {}, WindowReloadApp() {},
  Quit() { console.log('[shim] Quit') },
  Environment: { Platform: 'windows', Arch: 'amd64', PlatformInfo: () => ({}) },
  Clipboard: { WriteText: () => Promise.resolve(), ReadText: () => Promise.resolve('') },
  BrowserOpenURL: () => {},
  Screen: { ScreenGetAll: () => Promise.resolve([]) },
}

/* ------------------------------ данные ------------------------------ */

const now = Date.now()
const servers = [
  { id: 's1', name: '🇩🇪 Франкфурт · Reality', protocol: 'vless', type: 'vless', host: 'de-01.firmy.net', port: 443, ping: 42, source: 'manual', addedAt: now - 86400000 * 12 },
  { id: 's2', name: '🇳🇱 Амстердам · VLESS-WS', protocol: 'vless', type: 'vless', host: 'nl-02.firmy.net', port: 8443, ping: 61, source: 'manual', addedAt: now - 86400000 * 9 },
  { id: 's3', name: '🇫🇮 Хельсинки · Trojan', protocol: 'trojan', type: 'trojan', host: 'fi-01.firmy.net', port: 443, ping: 88, source: 'manual', addedAt: now - 86400000 * 7 },
  { id: 's4', name: '🇸🇪 Стокгольм · Hysteria2', protocol: 'hysteria2', type: 'hysteria2', host: 'se-03.firmy.net', port: 8443, ping: 74, source: 'subscription', subName: 'Firmy Premium', addedAt: now - 86400000 * 5 },
  { id: 's5', name: '🇺🇸 Нью-Йорк · VMess', protocol: 'vmess', type: 'vmess', host: 'us-ny-01.firmy.net', port: 443, ping: 138, source: 'subscription', subName: 'Firmy Premium', addedAt: now - 86400000 * 5 },
  { id: 's6', name: '🇸🇬 Сингапур · TUIC', protocol: 'tuic', type: 'tuic', host: 'sg-02.firmy.net', port: 443, ping: 176, source: 'manual', addedAt: now - 86400000 * 3 },
  { id: 's7', name: '🇯🇵 Токио · Shadowsocks', protocol: 'shadowsocks', type: 'shadowsocks', host: 'jp-05.firmy.net', port: 8388, ping: 112, source: 'manual', addedAt: now - 86400000 * 2 },
  { id: 's8', name: '🇬🇧 Лондон · AnyTLS', protocol: 'anytls', type: 'anytls', host: 'uk-01.firmy.net', port: 443, ping: -1, source: 'manual', addedAt: now - 3600000 },
]

const subs = [
  { url: 'https://t.me/firmy_bot/sub/aaa111', name: 'Firmy Premium', count: 2, lastSync: now - 7200000 },
  { url: 'https://sub.example.org/base64', name: '', count: 0, lastSync: 0 },
]

const settings = {
  mode: 'tun', killSwitch: false, blockLan: false, blockBt: false, setSystemProxy: false,
  dns: 'auto', autostart: false, startMinimized: false, closeToTray: true,
  hotkeyEnabled: true, logLevel: 'info', proxyPort: 10808, strictRoute: true,
  selectedServer: 's1', lastMode: '',
}

const levels = ['info', 'info', 'debug', 'info', 'warn', 'info', 'error', 'info']
const messages = [
  'sing-box: initialized, outbound=uuid@de-01.firmy.net:443',
  'tun: interface FirmyVPN up, addr=172.19.0.1/30, mtu=9000',
  'dns: hijack enabled, resolver=DoH https://dns.google/dns-query',
  'router: auto_route enabled, strict_route=true',
  'inbound/mixed: listening on 127.0.0.1:10808',
  'outbound/vless: connection to de-01.firmy.net:443 established (uTLS chrome)',
  'connection: [TCP] 127.0.0.1:52144 --> www.youtube.com:443 match(dst) using direct',
  'clash api: external controller listening at 127.0.0.1:9097',
  'healthcheck: connection lost, retry 1/3',
  'WARN router: excluded route 192.168.0.0/16 (LAN)',
  'ERROR outbound/hysteria2: dial: i/o timeout (se-03.firmy.net:8443)',
  'kill switch: rules removed, internet restored',
  'dns: cache flushed, 128 entries',
  'connection: [UDP] 172.19.0.1:5353 --> 1.1.1.1:53 match(dst) using proxy',
]
const logs = Array.from({ length: 46 }, (_, i) => ({
  time: new Date(now - (46 - i) * 4300).toLocaleTimeString('ru-RU', { hour12: false }),
  level: levels[i % levels.length],
  message: messages[i % messages.length],
}))

let status = {
  connected: false, connecting: false, mode: 'tun', serverId: '', serverName: '',
  protocol: '', startedAt: 0, upload: 0, download: 0, uploadTot: 0, downloadTot: 0,
  assignedIp: '', proxyAddr: '', error: '',
}

const pushState = () => emit('vpn:state', status)
const pushLog = (level, message) => {
  emit('vpn:log', { time: new Date().toLocaleTimeString('ru-RU', { hour12: false }), level, message })
}

/* симуляция живого трафика */
setInterval(() => {
  if (!status.connected) return
  const t = (Date.now() - status.startedAt) / 1000
  const wobble = 0.65 + 0.35 * Math.abs(Math.sin(t / 3.1)) + Math.random() * 0.18
  status = {
    ...status,
    download: Math.round(9_500_000 * wobble),
    upload: Math.round(2_100_000 * (0.5 + 0.5 * Math.abs(Math.cos(t / 4.3)))),
    downloadTot: status.downloadTot + Math.round(9_500_000 * wobble),
    uploadTot: status.uploadTot + Math.round(2_100_000 * 0.6),
  }
  pushState()
}, 1000)

/* ------------------------------ bindings ------------------------------ */

const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

window.go = {
  main: {
    App: {
      async GetInitialState() {
        await sleep(120)
        return {
          settings, servers, subscriptions: subs, status,
          killSwitch: false, logs, version: '1.0.0', admin: true,
        }
      },
      async GetServers() { return servers },
      async GetSubscriptions() { return subs },
      async GetStatus() { return status },
      async GetLogs() { return logs },
      async ClearLogs() { logs.length = 0 },
      async SaveSettings(s) { Object.assign(settings, s); console.log('[shim] SaveSettings', s) },
      async ImportText(text) {
        await sleep(500)
        const n = String(text).split('\n').filter((l) => l.trim()).length
        return { added: Math.max(1, n), skipped: 1, errors: n ? [] : ['пустой ввод'] }
      },
      async ImportSubscription(url, name) {
        await sleep(900)
        return { added: 14, skipped: 2, errors: [] }
      },
      async RefreshSubscription() {
        await sleep(800)
        return { added: 3, skipped: 11, errors: [] }
      },
      async DeleteSubscription() {},
      async DeleteServer() { return true },
      async RenameServer() { return true },
      async PingServer() { return Math.round(30 + Math.random() * 160) },
      async PingAll() {
        await sleep(1200)
        const m = {}
        servers.forEach((s) => { s.ping = Math.round(30 + Math.random() * 170); m[s.id] = s.ping })
        return m
      },
      async Connect(id) {
        const s = servers.find((x) => x.id === id) || servers[0]
        status = { ...status, connecting: true, error: '' }
        pushState()
        pushLog('info', `подключение к ${s.host}:${s.port}…`)
        await sleep(700)
        if (s.ping < 0) {
          status = { ...status, connecting: false, error: 'dial tcp: i/o timeout' }
          pushState()
          pushLog('error', `ERROR outbound/${s.type}: dial: i/o timeout`)
          throw new Error('dial tcp: i/o timeout')
        }
        pushLog('info', 'tun: interface FirmyVPN up, addr=172.19.0.1/30')
        status = {
          ...status, connecting: true, serverId: s.id, serverName: s.name, protocol: s.protocol, mode: settings.mode,
        }
        pushState()
        await sleep(900)
        status = {
          ...status, connected: true, connecting: false, startedAt: Date.now(),
          assignedIp: '172.19.0.2', proxyAddr: `127.0.0.1:${settings.proxyPort}`,
          download: 8_200_000, upload: 1_900_000, downloadTot: 0, uploadTot: 0, error: '',
        }
        pushState()
        pushLog('info', 'подключено: весь трафик системы идёт через VPN')
      },
      async Disconnect() {
        pushLog('info', 'остановка ядра…')
        status = { ...status, connecting: true }
        pushState()
        await sleep(500)
        status = {
          ...status, connected: false, connecting: false, download: 0, upload: 0,
          startedAt: 0, serverName: '', assignedIp: '', proxyAddr: '',
        }
        pushState()
        pushLog('info', 'отключено')
      },
      async ToggleConnect() {},
      async SpeedTest() {
        await sleep(4500)
        return { downloadMbps: 187.4, uploadMbps: 54.2, latencyMs: 41, url: 'speed.cloudflare.com' }
      },
      async UnblockKillSwitch() { emit('vpn:killswitch', false) },
      async ShowHide() {}, async Quit() {}, async OpenFolder() {},
    },
  },
}
