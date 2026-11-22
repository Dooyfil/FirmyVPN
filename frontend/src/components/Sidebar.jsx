import React from 'react'
import { motion } from 'framer-motion'
import {
  Activity,
  Gauge,
  Import,
  ScrollText,
  Settings,
  Zap,
} from 'lucide-react'

const NAV = [
  { id: 'connect', label: 'Подключение', icon: Zap, hint: 'VPN и регионы' },
  { id: 'import', label: 'Импорт', icon: Import, hint: 'ключи и подписки' },
  { id: 'speed', label: 'Тест скорости', icon: Gauge, hint: 'пинг и трафик' },
  { id: 'logs', label: 'Логи', icon: ScrollText, hint: 'события ядра' },
  { id: 'settings', label: 'Настройки', icon: Settings, hint: 'всё остальное' },
]

export default function Sidebar({ view, setView, status, serverCount, killActive }) {
  const connected = status?.connected
  const connecting = status?.connecting || status?.switching

  return (
    <aside className="w-[218px] shrink-0 border-r border-white/[0.06] bg-black/25 backdrop-blur-xl flex flex-col py-3.5 relative">
      <span className="absolute right-0 top-0 bottom-0 w-px bg-gradient-to-b from-transparent via-cyan-400/25 to-transparent" />

      <nav className="flex flex-col gap-1 px-2.5">
        {NAV.map((item, i) => {
          const active = view === item.id
          const Icon = item.icon
          return (
            <motion.button
              key={item.id}
              onClick={() => setView(item.id)}
              initial={{ opacity: 0, x: -16 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.04 * i, type: 'spring', stiffness: 420, damping: 30 }}
              whileHover={{ x: 3 }}
              whileTap={{ scale: 0.97 }}
              className={`group relative flex items-center gap-3 px-3 py-2.5 rounded-xl text-[13.5px] font-medium
                transition-colors duration-150 cursor-pointer overflow-hidden
                ${active ? 'text-white' : 'text-mist-500 hover:text-mist-100'}`}
            >
              {active && (
                <>
                  <motion.span
                    layoutId="nav-pill"
                    transition={{ type: 'spring', stiffness: 520, damping: 42 }}
                    className="absolute inset-0 rounded-xl bg-gradient-to-r from-cyan-500/[0.18] via-indigo-500/[0.12] to-violet-500/[0.16] border border-white/[0.12]"
                  />
                  <motion.span
                    layoutId="nav-glow"
                    transition={{ type: 'spring', stiffness: 520, damping: 42 }}
                    className="absolute inset-0 rounded-xl bg-[radial-gradient(60%_100%_0%_0%,rgba(34,211,238,.28),transparent_70%)]"
                  />
                  <motion.span
                    layoutId="nav-bar"
                    transition={{ type: 'spring', stiffness: 520, damping: 42 }}
                    className="absolute left-0 top-1.5 bottom-1.5 w-[3px] rounded-full bg-gradient-to-b from-cyan-300 via-sky-400 to-violet-500 shadow-[0_0_12px_3px_rgba(34,211,238,.6)]"
                  />
                </>
              )}
              {!active && (
                <span className="absolute inset-0 rounded-xl bg-white/[0.07] opacity-0 group-hover:opacity-100 transition-opacity duration-200" />
              )}

              <span className="relative z-10 flex items-center gap-3 w-full">
                <motion.span
                  animate={active ? { rotate: [0, -8, 8, 0] } : { rotate: 0 }}
                  transition={{ duration: 0.45 }}
                  className={active ? 'text-neon-cyan drop-shadow-[0_0_8px_rgba(34,211,238,.8)]' : ''}
                >
                  <Icon size={16.5} />
                </motion.span>
                <span className="truncate">{item.label}</span>
                {item.id === 'connect' && serverCount > 0 && (
                  <span className={`ml-auto text-[10.5px] px-1.5 py-px rounded-md mono
                    ${active ? 'bg-white/15 text-white' : 'bg-white/[0.06] text-mist-500'}`}>
                    {serverCount}
                  </span>
                )}
                {item.id === 'connect' && connected && (
                  <span className="ml-auto w-1.5 h-1.5 rounded-full bg-neon-emerald status-dot" />
                )}
              </span>
            </motion.button>
          )
        })}
      </nav>

      <div className="mt-auto px-3 space-y-2.5">
        {killActive && (
          <motion.div
            initial={{ opacity: 0, y: 10, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            className="flex items-center gap-2 px-3 py-2 rounded-xl bg-rose-500/12 border border-rose-500/30 text-[11.5px] text-rose-300"
          >
            <Activity size={13} className="animate-blink shrink-0" />
            Kill switch активен
          </motion.div>
        )}

        <motion.div layout className="glass rounded-xl px-3 py-2.5 top-lit overflow-hidden">
          <div className="flex items-center justify-between relative z-10">
            <span className="text-[10.5px] uppercase tracking-[0.14em] text-mist-700">Статус</span>
            <span
              className={`w-1.5 h-1.5 rounded-full ${
                connected ? 'bg-neon-emerald status-dot' :
                connecting ? 'bg-neon-amber animate-blink' : 'bg-mist-700'
              }`}
            />
          </div>
          <div className="text-[13px] font-medium mt-1 truncate text-mist-100 relative z-10">
            {connected ? status.serverName :
             status?.switching ? 'Смена региона…' :
             connecting ? 'Подключение…' : 'Отключено'}
          </div>
          <div className="text-[11px] text-mist-500 mt-0.5 mono truncate relative z-10">
            {connected ? (status.mode === 'tun' ? 'TUN · весь трафик' : 'Прокси · 127.0.0.1') : '—'}
          </div>
        </motion.div>

        <div className="text-[10.5px] text-mist-700 text-center pb-1 mono">
          sing-box core · v1.0.0
        </div>
      </div>
    </aside>
  )
}
