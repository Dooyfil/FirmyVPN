import React from 'react'
import { motion } from 'framer-motion'
import { Minus, Square, X } from 'lucide-react'
import { WindowHide, WindowToggleMaximise, WindowMinimise, Quit } from '../../wailsjs/runtime/runtime'

export function Logo({ size = 24, animated = true }) {
  return (
    <motion.span
      className="relative inline-flex"
      animate={animated ? { rotate: [0, 0, 0] } : {}}
      whileHover={{ rotate: -8, scale: 1.08 }}
      transition={{ type: 'spring', stiffness: 400, damping: 14 }}
    >
      <span className="absolute inset-0 rounded-full bg-cyan-400/40 blur-lg animate-breathe" />
      <svg width={size} height={size} viewBox="0 0 32 32" fill="none" className="relative">
        <defs>
          <linearGradient id="fvpn-grad" x1="0" y1="0" x2="32" y2="32">
            <stop offset="0%" stopColor="#22d3ee" />
            <stop offset="55%" stopColor="#818cf8" />
            <stop offset="100%" stopColor="#e879f9" />
          </linearGradient>
        </defs>
        <path
          d="M16 2.5 L27.5 7.2 V16.4 C27.5 23.2 22.6 28.3 16 30 C9.4 28.3 4.5 23.2 4.5 16.4 V7.2 Z"
          fill="url(#fvpn-grad)" fillOpacity="0.18"
          stroke="url(#fvpn-grad)" strokeWidth="1.7" strokeLinejoin="round"
        />
        <motion.path
          d="M11 16.2 L14.6 19.8 L21.5 12.4"
          stroke="url(#fvpn-grad)" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"
          initial={{ pathLength: 0 }}
          animate={{ pathLength: 1 }}
          transition={{ duration: 0.9, ease: 'easeOut', delay: 0.2 }}
        />
      </svg>
    </motion.span>
  )
}

export function StatusPill({ status }) {
  const connected = status?.connected
  const switching = status?.switching
  const connecting = status?.connecting || switching
  let dot, text, cls, ring
  if (switching) {
    dot = 'bg-neon-cyan'
    text = 'Смена региона…'
    cls = 'border-cyan-400/35 bg-cyan-500/10 text-cyan-200'
    ring = 'border-cyan-400/60 animate-spin-slow'
  } else if (connecting) {
    dot = 'bg-neon-amber'
    text = 'Подключение…'
    cls = 'border-amber-400/35 bg-amber-500/10 text-amber-200'
    ring = 'border-amber-400/50 animate-spin-slow'
  } else if (connected) {
    dot = 'bg-neon-emerald status-dot'
    text = 'Защищено'
    cls = 'border-emerald-400/35 bg-emerald-500/10 text-emerald-200'
    ring = ''
  } else {
    dot = 'bg-mist-700'
    text = 'Не защищено'
    cls = 'border-white/10 bg-white/[0.05] text-mist-500'
    ring = ''
  }
  return (
    <motion.div
      key={text}
      initial={{ opacity: 0, y: -8, scale: 0.9 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      transition={{ type: 'spring', stiffness: 460, damping: 30 }}
      className={`relative flex items-center gap-2 pl-2.5 pr-3 py-1 rounded-full border text-[11.5px] font-medium tracking-wide ${cls}`}
    >
      {ring && (
        <span className={`absolute left-1.5 w-2.5 h-2.5 rounded-full border-2 border-transparent ${ring}`}
              style={{ borderTopColor: 'currentColor' }} />
      )}
      <span className={`w-1.5 h-1.5 rounded-full ${dot} ${connecting && !switching ? 'animate-blink' : ''} ${ring ? 'ml-2.5' : ''}`} />
      {text}
    </motion.div>
  )
}

export default function TitleBar({ status, settings }) {
  const close = () => {
    if (settings?.closeToTray) WindowHide()
    else Quit()
  }
  const btn = 'w-11 h-full flex items-center justify-center text-mist-500 transition-all duration-150 no-drag relative overflow-hidden'
  return (
    <div className="h-11 shrink-0 flex items-center justify-between border-b border-white/[0.06] bg-black/30 backdrop-blur-2xl drag select-none">
      <span className="absolute bottom-0 left-0 right-0 h-px bg-gradient-to-r from-transparent via-cyan-400/30 to-transparent" />

      <div className="flex items-center gap-2.5 pl-4 min-w-0">
        <Logo />
        <span className="font-semibold text-[14.5px] tracking-tight grad-text">FirmyVPN</span>
        <span className="text-[10.5px] text-mist-700 font-mono mt-0.5 px-1.5 py-px rounded bg-white/[0.05] border border-white/[0.07]">
          v1.0
        </span>
      </div>

      <div className="no-drag">
        <StatusPill status={status} />
      </div>

      <div className="flex items-center h-full no-drag">
        <button className={`${btn} hover:bg-white/[0.08] hover:text-white`} onClick={WindowMinimise} title="Свернуть">
          <Minus size={15} />
        </button>
        <button className={`${btn} hover:bg-white/[0.08] hover:text-white`} onClick={WindowToggleMaximise} title="Развернуть">
          <Square size={11} />
        </button>
        <button className={`${btn} hover:bg-rose-500 hover:text-white rounded-tr-[10px]`} onClick={close} title="Закрыть">
          <span className="absolute inset-0 bg-rose-500 scale-x-0 hover:scale-x-100 transition-transform origin-left" />
          <X size={15} className="relative" />
        </button>
      </div>
    </div>
  )
}
