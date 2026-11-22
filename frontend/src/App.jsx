import React, { useCallback, useEffect, useRef, useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import TitleBar from './components/TitleBar'
import Sidebar from './components/Sidebar'
import ConnectView from './components/ConnectView'
import ImportView from './components/ImportView'
import SpeedTestView from './components/SpeedTestView'
import LogsView from './components/LogsView'
import SettingsView from './components/SettingsView'
import { ToastHost } from './components/ui'
import { EventsOn } from '../wailsjs/runtime/runtime'
import { toast } from './lib/toast'
import {
  ClearLogs,
  Connect,
  DeleteSubscription,
  Disconnect,
  GetInitialState,
  GetServers,
  GetSubscriptions,
  ImportSubscription,
  ImportText,
  OpenFolder,
  PingAll,
  RefreshSubscription,
  SaveSettings,
  UnblockKillSwitch,
} from '../wailsjs/go/main/App'

const EMPTY_STATUS = {
  connected: false, connecting: false, mode: 'tun', serverId: '', serverName: '',
  protocol: '', startedAt: 0, upload: 0, download: 0, uploadTot: 0, downloadTot: 0,
  assignedIp: '', proxyAddr: '', error: '',
}
const EMPTY_SETTINGS = {
  mode: 'tun', killSwitch: false, blockLan: false, blockBt: false, setSystemProxy: true,
  dns: 'auto', autostart: false, startMinimized: false, closeToTray: true,
  hotkeyEnabled: true, logLevel: 'info', proxyPort: 10808, strictRoute: true,
  selectedServer: '', lastMode: '',
  autoConnect: false, fastestServer: false, customDNS: '', bypassDomains: '',
  blockAds: false, disableIPv6: false, mtu: 9000, udpBlock: false,
}

const VIEWS = {
  connect: ConnectView,
  import: ImportView,
  speed: SpeedTestView,
  logs: LogsView,
  settings: SettingsView,
}

export default function App() {
  const [view, setView] = useState('connect')
  const [settings, setSettings] = useState(EMPTY_SETTINGS)
  const [servers, setServers] = useState([])
  const [subs, setSubs] = useState([])
  const [status, setStatus] = useState(EMPTY_STATUS)
  const [logs, setLogs] = useState([])
  const [killActive, setKillActive] = useState(false)
  const [samples, setSamples] = useState([])
  const [pinging, setPinging] = useState(false)
  const [version, setVersion] = useState('')
  const [admin, setAdmin] = useState(true)
  const [ready, setReady] = useState(false)
  const [now, setNow] = useState(Date.now())

  const statusRef = useRef(status)
  statusRef.current = status

  /* ---------- начальная загрузка ---------- */
  useEffect(() => {
    let alive = true
    ;(async () => {
      try {
        const s = await GetInitialState()
        if (!alive) return
        if (s.settings) setSettings({ ...EMPTY_SETTINGS, ...s.settings })
        if (Array.isArray(s.servers)) setServers(s.servers)
        if (Array.isArray(s.subscriptions)) setSubs(s.subscriptions)
        if (s.status) setStatus({ ...EMPTY_STATUS, ...s.status })
        if (Array.isArray(s.logs)) setLogs(s.logs)
        setKillActive(!!s.killSwitch)
        setVersion(s.version || '')
        setAdmin(!!s.admin)
      } catch (e) {
        toast('Не удалось загрузить состояние: ' + e, 'error')
      } finally {
        if (alive) setReady(true)
      }
    })()
    return () => { alive = false }
  }, [])

  /* ---------- события от бэкенда ---------- */
  useEffect(() => {
    const offLog = EventsOn('vpn:log', (entry) => {
      setLogs((prev) => [...prev.slice(-799), entry])
    })
    const offState = EventsOn('vpn:state', (st) => {
      setStatus({ ...EMPTY_STATUS, ...st })
    })
    const offKill = EventsOn('vpn:killswitch', (active) => {
      setKillActive(!!active)
      if (active) toast('Kill switch: интернет заблокирован', 'warn')
    })
    return () => { offLog(); offState(); offKill() }
  }, [])

  /* ---------- часы для таймера сессии ---------- */
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 1000)
    return () => clearInterval(t)
  }, [])

  /* ---------- семплы графика скорости (60 точек по 1с) ---------- */
  const samplesRef = useRef([])
  useEffect(() => {
    const t = setInterval(() => {
      const st = statusRef.current
      samplesRef.current = [
        ...samplesRef.current.slice(-59),
        { up: st.upload || 0, down: st.download || 0 },
      ]
      setSamples(samplesRef.current)
    }, 1000)
    return () => clearInterval(t)
  }, [])

  /* ---------- операции ---------- */
  const patchSettings = useCallback(async (next) => {
    const prev = settings
    setSettings(next)
    try {
      await SaveSettings(next)
    } catch (e) {
      setSettings(prev)
      toast('Ошибка сохранения настроек: ' + e, 'error')
    }
  }, [settings])

  const doImportText = useCallback(async (text) => {
    const r = await ImportText(text)
    setServers(await GetServers())
    return r
  }, [])

  const doImportSub = useCallback(async (url, name) => {
    const r = await ImportSubscription(url, name)
    setServers(await GetServers())
    setSubs(await GetSubscriptions())
    return r
  }, [])

  const doRefreshSub = useCallback(async (url) => {
    const r = await RefreshSubscription(url)
    setServers(await GetServers())
    setSubs(await GetSubscriptions())
    return r
  }, [])

  const doDeleteSub = useCallback(async (url) => {
    await DeleteSubscription(url)
    setServers(await GetServers())
    setSubs(await GetSubscriptions())
    toast('Подписка удалена', 'success')
  }, [])

  // выбор сервера: если подключены — бесшовная смена (бэкенд сам перезапустит
  // ядро, статус «подключено» не сбрасывается), иначе просто запоминаем выбор
  const selectServer = useCallback(async (id) => {
    if (statusRef.current.connected) {
      try {
        await Connect(id)
        patchSettings({ ...settings, selectedServer: id })
      } catch (e) {
        toast(String(e || 'Не удалось сменить сервер'), 'error')
      }
    } else {
      patchSettings({ ...settings, selectedServer: id })
    }
  }, [settings, patchSettings])

  const doPingAll = useCallback(async () => {
    setPinging(true)
    try {
      await PingAll()
      setServers(await GetServers())
      toast('Пинг завершён', 'success')
    } catch (e) {
      toast(String(e || 'Ошибка пинга'), 'error')
    } finally {
      setPinging(false)
    }
  }, [])

  const toggleConnect = useCallback(async () => {
    try {
      if (statusRef.current.connected) await Disconnect()
      else {
        const id = settings.selectedServer || servers[0]?.id
        if (!id) { setView('import'); toast('Сначала импортируйте сервер', 'warn'); return }
        await Connect(id)
      }
    } catch (e) {
      toast(String(e || 'Ошибка подключения'), 'error')
    }
  }, [settings.selectedServer, servers])

  const unblock = useCallback(async () => {
    try {
      await UnblockKillSwitch()
      setKillActive(false)
    } catch (e) {
      toast(String(e || 'Не удалось снять блокировку'), 'error')
    }
  }, [])

  const selectedId = settings.selectedServer || servers[0]?.id || ''
  const selected = servers.find((s) => s.id === selectedId) || null

  const View = VIEWS[view] || ConnectView
  const viewProps = {
    connect: {
      status, settings, servers, selected, now, samples, pinging, killActive,
      onToggle: toggleConnect,
      onNeedImport: () => setView('import'),
      onPatchSettings: patchSettings,
      onSelect: selectServer,
      onPingAll: doPingAll,
    },
    import: {
      subs,
      onImportText: doImportText,
      onImportSub: doImportSub,
      onRefreshSub: doRefreshSub,
      onDeleteSub: doDeleteSub,
      onDone: () => setView('connect'),
    },
    speed: {
      connected: status.connected,
      onNeedConnect: () => setView('connect'),
    },
    logs: {
      logs,
      onClear: async () => {
        await ClearLogs()
        setLogs([])
      },
    },
    settings: {
      settings, onSave: patchSettings, status, admin, version, killActive,
      onOpenFolder: OpenFolder,
      onUnblock: unblock,
    },
  }

  return (
    <div className="h-full flex flex-col relative overflow-hidden">
      {/* аврора-фон */}
      <div className="aurora" aria-hidden>
        <span
          className="aurora-blob animate-float"
          style={{ width: 520, height: 520, left: -120, top: -160, background: 'radial-gradient(circle, rgba(34,211,238,0.34), transparent 68%)' }}
        />
        <span
          className="aurora-blob animate-float-slow"
          style={{ width: 620, height: 620, right: -180, top: -120, background: 'radial-gradient(circle, rgba(139,92,246,0.32), transparent 68%)' }}
        />
        <span
          className="aurora-blob animate-float"
          style={{ width: 560, height: 560, left: '30%', bottom: -260, background: 'radial-gradient(circle, rgba(232,121,249,0.22), transparent 68%)' }}
        />
        <span
          className="aurora-blob animate-float-slow"
          style={{ width: 480, height: 480, right: 60, bottom: -200, background: 'radial-gradient(circle, rgba(52,211,153,0.16), transparent 70%)' }}
        />
        {/* сетка-текстура */}
        <span
          className="absolute inset-0 opacity-[0.035]"
          style={{
            backgroundImage:
              'linear-gradient(rgba(255,255,255,0.6) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.6) 1px, transparent 1px)',
            backgroundSize: '52px 52px',
          }}
        />
      </div>

      <TitleBar status={status} settings={settings} />

      <div className="relative z-10 flex flex-1 min-h-0">
        <Sidebar
          view={view}
          setView={setView}
          status={status}
          serverCount={servers.length}
          killActive={killActive}
        />

        <main className="flex-1 min-w-0 p-4.5 px-5 py-4 overflow-hidden">
          <AnimatePresence mode="wait">
            <motion.div
              key={view}
              initial={{ opacity: 0, y: 14, filter: 'blur(4px)' }}
              animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
              exit={{ opacity: 0, y: -10, filter: 'blur(3px)' }}
              transition={{ duration: 0.2, ease: [0.22, 1, 0.36, 1] }}
              className="h-full"
            >
              {ready ? <View {...viewProps[view]} /> : (
                <div className="h-full flex items-center justify-center">
                  <motion.div
                    animate={{ rotate: 360 }}
                    transition={{ repeat: Infinity, duration: 1.1, ease: 'linear' }}
                    className="w-9 h-9 rounded-full border-2 border-cyan-400/25 border-t-cyan-400"
                  />
                </div>
              )}
            </motion.div>
          </AnimatePresence>
        </main>
      </div>

      {/* ресайз-полоски */}
      <div className="resize-n absolute top-0 left-16 right-16 h-1.5 z-40" />
      <div className="resize-s absolute bottom-0 left-16 right-16 h-1.5 z-40" />
      <div className="resize-w absolute left-0 top-11 bottom-16 w-1.5 z-40" />
      <div className="resize-e absolute right-0 top-11 bottom-16 w-1.5 z-40" />
      <div className="resize-nw absolute left-0 top-0 w-3 h-3 z-40" />
      <div className="resize-ne absolute right-0 top-0 w-3 h-3 z-40" />
      <div className="resize-sw absolute left-0 bottom-0 w-3 h-3 z-40" />
      <div className="resize-se absolute right-0 bottom-0 w-3 h-3 z-40" />

      <ToastHost />
    </div>
  )
}
