import React, { useEffect, useId, useRef, useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { onToast } from '../lib/toast'
import { AlertTriangle, CheckCircle2, Info, Loader2, X, XCircle } from 'lucide-react'

/* ---------- стеклянная карточка ---------- */

export function Card({ className = '', hover = false, lift = false, children, ...rest }) {
  const cls = `glass rounded-2xl ${hover ? 'glass-hover' : ''} ${lift ? 'card-lift' : ''} ${className}`
  return (
    <div className={cls} {...rest}>
      {children}
    </div>
  )
}

/* ---------- заголовок секции ---------- */

export function SectionTitle({ icon: Icon, title, sub, right }) {
  return (
    <div className="flex items-center justify-between gap-3 mb-4">
      <div className="flex items-center gap-3 min-w-0">
        {Icon && (
          <motion.div
            initial={{ rotate: -25, scale: 0.7, opacity: 0 }}
            animate={{ rotate: 0, scale: 1, opacity: 1 }}
            transition={{ type: 'spring', stiffness: 400, damping: 18 }}
            className="w-9 h-9 rounded-xl bg-white/[0.06] border border-white/10 flex items-center justify-center text-neon-cyan shadow-[0_0_22px_-8px_rgba(34,211,238,.9)]"
          >
            <Icon size={17} />
          </motion.div>
        )}
        <div className="min-w-0">
          <h2 className="text-[15px] font-semibold tracking-tight text-mist-100 truncate">{title}</h2>
          {sub && <p className="text-xs text-mist-500 mt-0.5 truncate">{sub}</p>}
        </div>
      </div>
      {right && <div className="flex items-center gap-2 shrink-0">{right}</div>}
    </div>
  )
}

/* ---------- переключатель ---------- */

export function Toggle({ checked, onChange, disabled = false, accent = 'cyan' }) {
  const on = accent === 'violet'
    ? 'bg-gradient-to-r from-violet-500 to-fuchsia-500 shadow-[0_0_20px_-4px_rgba(168,85,247,.95)]'
    : accent === 'rose'
      ? 'bg-gradient-to-r from-rose-500 to-orange-500 shadow-[0_0_20px_-4px_rgba(251,113,133,.95)]'
      : 'bg-gradient-to-r from-cyan-500 to-teal-400 shadow-[0_0_20px_-4px_rgba(34,211,238,.95)]'
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className={`relative w-[48px] h-[27px] rounded-full transition-all duration-300 shrink-0
        ${checked ? on : 'bg-white/[0.08] border border-white/12 hover:bg-white/[0.13]'}
        ${disabled ? 'opacity-40 cursor-not-allowed' : 'cursor-pointer'}`}
    >
      <motion.span
        layout
        transition={{ type: 'spring', stiffness: 700, damping: 36 }}
        className={`absolute top-[3px] w-[21px] h-[21px] rounded-full shadow-lg
          ${checked ? 'left-[24px] bg-white' : 'left-[3px] bg-white/85'}`}
      >
        <motion.span
          animate={{ opacity: checked ? 1 : 0, scale: checked ? 1 : 0.4 }}
          className="absolute inset-0 rounded-full bg-white/60 blur-[3px]"
        />
      </motion.span>
    </button>
  )
}

/* ---------- сегмент-контрол ---------- */

export function Segmented({ options, value, onChange, size = 'md' }) {
  const uid = useId().replace(/:/g, '')
  return (
    <div className="inline-flex p-1 rounded-xl bg-black/35 border border-white/[0.07] gap-1">
      {options.map((opt) => {
        const active = opt.value === value
        return (
          <button
            key={opt.value}
            onClick={() => onChange(opt.value)}
            title={opt.title}
            className={`relative rounded-lg ${size === 'sm' ? 'px-3 py-1.5 text-xs' : 'px-3.5 py-1.5 text-[13px]'}
              font-medium transition-colors duration-150 cursor-pointer
              ${active ? 'text-white' : 'text-mist-500 hover:text-mist-200'}`}
          >
            {active && (
              <motion.span
                layoutId={`seg-${uid}`}
                transition={{ type: 'spring', stiffness: 520, damping: 40 }}
                className="absolute inset-0 rounded-lg bg-gradient-to-r from-cyan-500/35 to-violet-500/35 border border-white/15 shadow-[0_0_18px_-6px_rgba(34,211,238,.85)]"
              />
            )}
            <span className="relative z-10 whitespace-nowrap flex items-center gap-1.5">
              {opt.icon && <opt.icon size={12.5} />}
              {opt.label}
            </span>
          </button>
        )
      })}
    </div>
  )
}

/* ---------- бейдж ---------- */

export function Badge({ children, className = '' }) {
  return (
    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[11px] font-medium border ${className}`}>
      {children}
    </span>
  )
}

/* ---------- анимированное число ---------- */

export function AnimatedNumber({ value, format = (v) => String(Math.round(v)), duration = 600 }) {
  const [shown, setShown] = useState(value || 0)
  const fromRef = useRef(value || 0)
  const rafRef = useRef(0)

  useEffect(() => {
    const from = fromRef.current
    const to = value || 0
    if (from === to) return
    const start = performance.now()
    cancelAnimationFrame(rafRef.current)
    const tick = (now) => {
      const t = Math.min(1, (now - start) / duration)
      const eased = 1 - Math.pow(1 - t, 3)
      setShown(from + (to - from) * eased)
      if (t < 1) rafRef.current = requestAnimationFrame(tick)
      else fromRef.current = to
    }
    rafRef.current = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(rafRef.current)
  }, [value, duration])

  return <>{format(shown)}</>
}

/* ---------- кнопка-иконка ---------- */

export function IconBtn({ children, onClick, title, danger = false, active = false, className = '' }) {
  return (
    <motion.button
      type="button"
      whileHover={{ scale: 1.1, y: -1 }}
      whileTap={{ scale: 0.88 }}
      onClick={onClick}
      title={title}
      className={`w-8 h-8 rounded-lg flex items-center justify-center transition-colors duration-150 cursor-pointer
        ${active ? 'bg-cyan-500/15 text-neon-cyan border border-cyan-400/30' :
          danger ? 'text-mist-500 hover:text-rose-400 hover:bg-rose-500/12 border border-transparent hover:border-rose-500/25'
                 : 'text-mist-500 hover:text-white hover:bg-white/10 border border-transparent hover:border-white/15'}
        ${className}`}
    >
      {children}
    </motion.button>
  )
}

/* ---------- кнопка ---------- */

const VARIANTS = {
  primary: `bg-gradient-to-r from-cyan-500 via-sky-500 to-violet-600 text-white
    shadow-[0_10px_34px_-12px_rgba(34,211,238,.85)]
    hover:shadow-[0_14px_40px_-10px_rgba(139,92,246,.95)] hover:brightness-110`,
  success: `bg-gradient-to-r from-emerald-500 to-teal-500 text-white
    shadow-[0_10px_34px_-12px_rgba(52,211,153,.85)] hover:brightness-110`,
  ghost: `bg-white/[0.06] border border-white/10 text-mist-300
    hover:bg-white/[0.11] hover:text-white hover:border-white/20`,
  danger: `bg-rose-500/15 border border-rose-500/35 text-rose-300
    hover:bg-rose-500/28 hover:text-white`,
  glow: `bg-white/[0.05] border border-cyan-400/35 text-cyan-200
    hover:bg-cyan-500/12 hover:border-cyan-400/60 hover:shadow-[0_0_28px_-8px_rgba(34,211,238,.9)]`,
}

const SIZES = {
  xs: 'px-2.5 py-1 text-[11.5px] rounded-lg gap-1.5',
  sm: 'px-3 py-1.5 text-xs rounded-lg gap-1.5',
  md: 'px-4 py-2.5 text-sm rounded-xl gap-2',
  lg: 'px-6 py-3 text-[15px] rounded-xl gap-2.5',
}

export function Btn({
  children, onClick, variant = 'primary', size = 'md', disabled = false,
  loading = false, className = '', ...rest
}) {
  return (
    <motion.button
      type="button"
      whileHover={disabled ? {} : { y: -2, scale: 1.02 }}
      whileTap={disabled ? {} : { y: 0, scale: 0.97 }}
      transition={{ type: 'spring', stiffness: 500, damping: 26 }}
      onClick={onClick}
      disabled={disabled || loading}
      className={`inline-flex items-center justify-center font-medium transition-all duration-200 shine cursor-pointer
        ${VARIANTS[variant]} ${SIZES[size]}
        ${disabled ? 'opacity-40 pointer-events-none' : ''}
        ${className}`}
      {...rest}
    >
      {loading && <Loader2 size={14} className="animate-spin" />}
      {children}
    </motion.button>
  )
}

/* ---------- модалка ---------- */

export function Modal({ open, onClose, title, icon: Icon, children, width = 'w-[560px]' }) {
  return (
    <AnimatePresence>
      {open && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.18 }}
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/65 backdrop-blur-[3px] no-drag"
          onMouseDown={(e) => { if (e.target === e.currentTarget) onClose() }}
        >
          <motion.div
            initial={{ opacity: 0, scale: 0.93, y: 22, rotateX: 6 }}
            animate={{ opacity: 1, scale: 1, y: 0, rotateX: 0 }}
            exit={{ opacity: 0, scale: 0.96, y: 12 }}
            transition={{ type: 'spring', stiffness: 420, damping: 32 }}
            className={`glass-strong neon-border rounded-2xl ${width} max-h-[82vh] flex flex-col overflow-hidden`}
          >
            <div className="flex items-center justify-between px-5 py-4 border-b border-white/[0.07]">
              <div className="flex items-center gap-2.5">
                {Icon && (
                  <span className="w-8 h-8 rounded-lg bg-gradient-to-br from-cyan-500/25 to-violet-500/25 border border-white/10 flex items-center justify-center text-neon-cyan">
                    <Icon size={16} />
                  </span>
                )}
                <h3 className="font-semibold text-[15px] tracking-tight">{title}</h3>
              </div>
              <IconBtn onClick={onClose} title="Закрыть"><X size={16} /></IconBtn>
            </div>
            <div className="p-5 overflow-y-auto">{children}</div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}

/* ---------- подтверждение ---------- */

export function Confirm({ open, title, message, onConfirm, onCancel, confirmLabel = 'Удалить' }) {
  return (
    <Modal open={open} onClose={onCancel} title={title} icon={AlertTriangle} width="w-[430px]">
      <p className="text-sm text-mist-300 leading-relaxed">{message}</p>
      <div className="flex justify-end gap-2 mt-5">
        <Btn variant="ghost" onClick={onCancel}>Отмена</Btn>
        <Btn variant="danger" onClick={onConfirm}>{confirmLabel}</Btn>
      </div>
    </Modal>
  )
}

/* ---------- тосты ---------- */

const TOAST_STYLES = {
  info: { icon: Info, cls: 'text-neon-cyan border-cyan-400/35' },
  success: { icon: CheckCircle2, cls: 'text-neon-emerald border-emerald-400/35' },
  error: { icon: XCircle, cls: 'text-neon-rose border-rose-400/35' },
  warn: { icon: AlertTriangle, cls: 'text-neon-amber border-amber-400/35' },
}

export function ToastHost() {
  const [items, setItems] = useState([])
  useEffect(() => onToast((t) => {
    setItems((prev) => {
      if (t.gone) return prev.filter((x) => x.id !== t.id)
      if (prev.some((x) => x.id === t.id)) return prev
      return [...prev.slice(-3), t]
    })
  }), [])
  return (
    <div className="fixed bottom-5 right-5 z-[60] flex flex-col gap-2 no-drag pointer-events-none">
      <AnimatePresence>
        {items.map((t) => {
          const st = TOAST_STYLES[t.type] || TOAST_STYLES.info
          const Icon = st.icon
          return (
            <motion.div
              key={t.id}
              layout
              initial={{ opacity: 0, x: 70, scale: 0.85, filter: 'blur(6px)' }}
              animate={{ opacity: 1, x: 0, scale: 1, filter: 'blur(0px)' }}
              exit={{ opacity: 0, x: 50, scale: 0.9, filter: 'blur(4px)' }}
              transition={{ type: 'spring', stiffness: 460, damping: 34 }}
              className={`glass-strong flex items-center gap-2.5 px-4 py-3 rounded-xl border ${st.cls} min-w-[260px] max-w-[380px]`}
            >
              <motion.span
                initial={{ rotate: -30, scale: 0.5 }}
                animate={{ rotate: 0, scale: 1 }}
                transition={{ type: 'spring', stiffness: 500, damping: 15, delay: 0.05 }}
              >
                <Icon size={16} className="shrink-0" />
              </motion.span>
              <span className="text-[13px] text-mist-100 leading-snug">{t.message}</span>
            </motion.div>
          )
        })}
      </AnimatePresence>
    </div>
  )
}

/* ---------- пустое состояние ---------- */

export function Empty({ icon: Icon, title, sub, action }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 14 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.35 }}
      className="flex flex-col items-center justify-center py-14 text-center"
    >
      <div className="relative mb-5">
        <span className="absolute inset-0 rounded-2xl bg-cyan-500/25 blur-2xl animate-breathe" />
        <motion.div
          animate={{ y: [0, -8, 0] }}
          transition={{ repeat: Infinity, duration: 3.4, ease: 'easeInOut' }}
          className="relative w-16 h-16 rounded-2xl bg-gradient-to-br from-cyan-500/18 to-violet-500/18 border border-white/10 flex items-center justify-center text-neon-cyan"
        >
          <Icon size={26} />
        </motion.div>
      </div>
      <div className="text-[15px] font-semibold text-mist-100">{title}</div>
      {sub && <div className="text-[13px] text-mist-500 mt-1.5 max-w-[380px] leading-relaxed">{sub}</div>}
      {action && <div className="mt-5">{action}</div>}
    </motion.div>
  )
}

/* ---------- строка настройки ---------- */

export function Row({ icon: Icon, title, desc, children, accent = 'cyan', badge }) {
  const accents = {
    cyan: 'text-neon-cyan bg-cyan-500/10 border-cyan-400/25 shadow-[0_0_18px_-10px_rgba(34,211,238,.9)]',
    violet: 'text-violet-400 bg-violet-500/10 border-violet-400/25 shadow-[0_0_18px_-10px_rgba(139,92,246,.9)]',
    emerald: 'text-neon-emerald bg-emerald-500/10 border-emerald-400/25 shadow-[0_0_18px_-10px_rgba(52,211,153,.9)]',
    amber: 'text-neon-amber bg-amber-500/10 border-amber-400/25 shadow-[0_0_18px_-10px_rgba(251,191,36,.9)]',
    rose: 'text-neon-rose bg-rose-500/10 border-rose-400/25 shadow-[0_0_18px_-10px_rgba(251,113,133,.9)]',
  }
  return (
    <div className="flex items-center gap-3.5 px-4 py-3.5 border-b border-white/[0.05] last:border-0 transition-colors hover:bg-white/[0.025]">
      <div className={`min-w-[34px] min-h-[34px] w-[34px] h-[34px] rounded-lg border flex items-center justify-center ${accents[accent]}`}>
        <Icon size={15} />
      </div>
      <div className="min-w-0 flex-1">
        <div className="text-[13.5px] font-medium text-mist-100 flex items-center gap-2">
          {title}
          {badge}
        </div>
        {desc && <div className="text-[11.5px] text-mist-500 mt-0.5 leading-snug">{desc}</div>}
      </div>
      <div className="shrink-0">{children}</div>
    </div>
  )
}
