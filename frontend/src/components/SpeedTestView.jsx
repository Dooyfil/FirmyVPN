import React, { useCallback, useEffect, useRef, useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import {
  ArrowDown,
  ArrowUp,
  CheckCircle2,
  Gauge,
  Loader2,
  Play,
  RotateCcw,
  Signal,
  Timer,
  Wifi,
} from 'lucide-react'
import { Btn, Card, SectionTitle } from './ui'
import { SpeedDown, SpeedLatency, SpeedProgress, SpeedUp } from '../../wailsjs/go/main/App'
import { toast } from '../lib/toast'

const STEPS = [
  { id: 'latency', label: 'Пинг', icon: Signal },
  { id: 'down', label: 'Скачивание', icon: ArrowDown },
  { id: 'up', label: 'Загрузка', icon: ArrowUp },
]

const PHASE_LABEL = {
  idle: 'Готов к тесту',
  latency: 'Измеряем задержку до сервера…',
  down: 'Качаем 50 МБ через туннель…',
  up: 'Загружаем 20 МБ наверх…',
  done: 'Тест завершён',
  error: 'Тест прерван',
}

function Ring({ pct, phase, live, unit }) {
  const R = 96
  const C = 2 * Math.PI * R
  const color = phase === 'up' ? '#a78bfa' : phase === 'down' ? '#22d3ee' : phase === 'done' ? '#34d399' : '#fbbf24'
  return (
    <div className="relative w-[224px] h-[224px]">
      <svg width="224" height="224" className="-rotate-90">
        <defs>
          <linearGradient id="ringgrad" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor={color} />
            <stop offset="100%" stopColor="#8b5cf6" />
          </linearGradient>
        </defs>
        <circle cx="112" cy="112" r={R} fill="none" stroke="rgba(255,255,255,0.07)" strokeWidth="9" />
        <motion.circle
          cx="112" cy="112" r={R} fill="none"
          stroke="url(#ringgrad)" strokeWidth="9" strokeLinecap="round"
          strokeDasharray={C}
          animate={{ strokeDashoffset: C - (C * pct) / 100 }}
          transition={{ type: 'spring', stiffness: 90, damping: 24 }}
          style={{ filter: `drop-shadow(0 0 10px ${color}aa)` }}
        />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <motion.div
          key={unit + Math.round(pct)}
          initial={{ scale: 0.94, opacity: 0.6 }}
          animate={{ scale: 1, opacity: 1 }}
          className="text-[34px] font-bold tracking-tighter tabular-nums leading-none"
          style={{ color }}
        >
          {live}
        </motion.div>
        <div className="text-[11.5px] text-mist-500 mt-1.5 mono">{unit}</div>
        <div className="text-[11px] text-mist-700 mt-0.5">{Math.round(pct)}%</div>
      </div>
      {/* вращающиеся блик-точки */}
      <motion.span
        className="absolute inset-0 rounded-full"
        style={{ border: '1px dashed rgba(255,255,255,0.12)' }}
        animate={{ rotate: 360 }}
        transition={{ repeat: Infinity, duration: 22, ease: 'linear' }}
      />
    </div>
  )
}

function ResultBar({ label, value, max, unit, color, delay, icon: Icon }) {
  const pct = Math.max(4, Math.min(100, (value / max) * 100))
  return (
    <div className="flex items-center gap-3">
      <span className={`w-8 h-8 rounded-lg border flex items-center justify-center shrink-0 ${color}`}>
        <Icon size={14} />
      </span>
      <div className="flex-1 min-w-0">
        <div className="flex items-center justify-between mb-1.5">
          <span className="text-[12.5px] text-mist-300">{label}</span>
          <span className="text-[13.5px] font-semibold mono tabular-nums">
            {value} <span className="text-[11px] text-mist-500 font-normal">{unit}</span>
          </span>
        </div>
        <div className="h-2 rounded-full bg-white/[0.06] overflow-hidden">
          <motion.div
            initial={{ width: 0 }}
            animate={{ width: `${pct}%` }}
            transition={{ delay, duration: 1.1, ease: [0.22, 1, 0.36, 1] }}
            className="h-full rounded-full"
            style={{ background: 'linear-gradient(90deg,#22d3ee,#818cf8,#e879f9)', boxShadow: '0 0 14px rgba(34,211,238,.7)' }}
          />
        </div>
      </div>
    </div>
  )
}

export default function SpeedTestView({ connected, onNeedConnect }) {
  const [phase, setPhase] = useState('idle')
  const [prog, setProg] = useState({ phase: '', done: 0, total: 0 })
  const [live, setLive] = useState('0')
  const [lat, setLat] = useState(null)
  const [down, setDown] = useState(0)
  const [up, setUp] = useState(0)
  const [elapsed, setElapsed] = useState(0)
  const running = phase !== 'idle' && phase !== 'done' && phase !== 'error'
  const stopRef = useRef(false)

  // живой прогресс + скорость
  useEffect(() => {
    if (!running) return
    let raf, lastT = 0, lastB = 0, t0 = performance.now()
    const tick = async () => {
      try {
        const p = await SpeedProgress()
        setProg(p)
        const now = performance.now()
        setElapsed((now - t0) / 1000)
        if (p.total > 0) {
          if (lastT && now - lastT > 250) {
            const bps = ((p.done - lastB) * 8) / ((now - lastT) / 1000) / 1e6
            if (bps >= 0) setLive(bps.toFixed(bps < 10 ? 1 : 0))
          }
          lastT = now
          lastB = p.done
        }
      } catch { /* прогресс недоступен — просто крутим таймер */ }
      if (!stopRef.current) raf = setTimeout(tick, 200)
    }
    tick()
    return () => { stopRef.current = true; clearTimeout(raf) }
  }, [running])

  const overall = (() => {
    const ratio = prog.total > 0 ? Math.min(1, prog.done / prog.total) : 0
    if (phase === 'latency') return 4 + 16 * ratio
    if (phase === 'down') return 20 + 50 * ratio
    if (phase === 'up') return 70 + 30 * ratio
    if (phase === 'done') return 100
    return 0
  })()

  const run = useCallback(async () => {
    stopRef.current = false
    setLat(null); setDown(0); setUp(0); setElapsed(0); setLive('0')
    setProg({ phase: '', done: 0, total: 0 })
    try {
      setPhase('latency')
      const l = await SpeedLatency()
      setLat(l)

      setPhase('down')
      setProg({ phase: 'down', done: 0, total: 50_000_000 })
      const d = await SpeedDown()
      setDown(d)

      setPhase('up')
      setProg({ phase: 'up', done: 0, total: 20_000_000 })
      const u = await SpeedUp()
      setUp(u)

      setPhase('done')
      setLive('100')
      toast('Тест скорости завершён', 'success')
    } catch (e) {
      setPhase('error')
      toast(String(e || 'Ошибка теста'), 'error')
    }
  }, [])

  const verdict = (() => {
    if (phase !== 'done') return null
    if (down >= 100) return { stars: 5, text: 'Отлично — 4K-видео, загрузки и звонки без задержек' }
    if (down >= 50) return { stars: 4, text: 'Хорошо — стриминг и работа идут гладко' }
    if (down >= 20) return { stars: 3, text: 'Средне — для серфинга и соцсетей хватает' }
    if (down >= 5) return { stars: 2, text: 'Слабо — тяжёлые задачи будут заметно тормозить' }
    return { stars: 1, text: 'Очень медленно — попробуйте другой регион' }
  })()

  const stepState = (id) => {
    const order = ['latency', 'down', 'up']
    const cur = order.indexOf(phase)
    const idx = order.indexOf(id)
    if (phase === 'done') return 'done'
    if (cur < 0) return 'idle'
    if (idx < cur) return 'done'
    if (idx === cur) return 'active'
    return 'idle'
  }

  return (
    <div className="flex flex-col gap-4 h-full overflow-y-auto pr-1 pb-2">
      <SectionTitle
        icon={Gauge}
        title="Тест скорости"
        sub="три этапа через текущий туннель · speed.cloudflare.com"
        right={
          connected ? (
            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border border-emerald-400/35 bg-emerald-500/10 text-[11.5px] text-emerald-300">
              <span className="w-1.5 h-1.5 rounded-full bg-neon-emerald status-dot" /> через VPN
            </span>
          ) : (
            <span className="text-[11.5px] text-mist-500">тест идёт без VPN</span>
          )
        }
      />

      {!connected && (
        <motion.div initial={{ opacity: 0, y: -8 }} animate={{ opacity: 1, y: 0 }}>
          <Card className="px-4 py-3 flex items-center gap-3 border-amber-400/25 bg-amber-500/[0.07]">
            <Wifi size={16} className="text-neon-amber shrink-0" />
            <span className="text-[12.5px] text-amber-200/90 flex-1">
              Вы не подключены — результат покажет скорость напрямую, без VPN.
            </span>
            <Btn size="sm" variant="ghost" onClick={onNeedConnect}>Подключиться</Btn>
          </Card>
        </motion.div>
      )}

      {/* этапы */}
      <div className="grid grid-cols-3 gap-3">
        {STEPS.map((s, i) => {
          const st = stepState(s.id)
          const Icon = s.icon
          return (
            <motion.div
              key={s.id}
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.07 }}
              className={`glass rounded-2xl px-4 py-3 flex items-center gap-3 transition-all duration-300
                ${st === 'active' ? 'neon-border sweep border-transparent' : ''} ${st === 'done' ? 'border-emerald-400/30' : ''}`}
            >
              <span className={`w-9 h-9 rounded-xl border flex items-center justify-center shrink-0
                ${st === 'done' ? 'bg-emerald-500/15 border-emerald-400/35 text-neon-emerald' :
                  st === 'active' ? 'bg-cyan-500/15 border-cyan-400/40 text-neon-cyan' :
                  'bg-white/[0.05] border-white/10 text-mist-500'}`}>
                {st === 'done' ? <CheckCircle2 size={16} /> :
                  st === 'active' ? <motion.span animate={{ rotate: 360 }} transition={{ repeat: Infinity, duration: 1, ease: 'linear' }}><Loader2 size={16} /></motion.span> :
                  <Icon size={16} />}
              </span>
              <div className="min-w-0">
                <div className="text-[13px] font-medium truncate">{s.label}</div>
                <div className="text-[11px] text-mist-500 truncate">
                  {s.id === 'latency' ? (lat ? `${lat.avgMs} мс · джиттер ${lat.jitterMs}` : '7 замеров') :
                   s.id === 'down' ? (down ? `${down.toFixed(1)} Мбит/с` : '50 МБ') :
                   (up ? `${up.toFixed(1)} Мбит/с` : '20 МБ')}
                </div>
              </div>
            </motion.div>
          )
        })}
      </div>

      {/* главный блок */}
      <Card className="p-6 flex flex-col items-center relative overflow-hidden">
        <span className="absolute -left-24 -top-24 w-72 h-72 rounded-full bg-cyan-500/[0.07] blur-3xl" />
        <span className="absolute -right-24 -bottom-24 w-72 h-72 rounded-full bg-violet-500/[0.07] blur-3xl" />

        <Ring
          pct={overall}
          phase={phase}
          unit={phase === 'up' ? 'Мбит/с ↑' : phase === 'down' ? 'Мбит/с ↓' : phase === 'done' ? 'готово' : (phase === 'latency' ? 'мс' : '')}
          live={phase === 'latency' ? (lat ? String(lat.avgMs) : live) : phase === 'done' ? '100' : live}
        />

        <motion.div
          key={phase}
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-4 text-[13.5px] font-medium text-mist-200 flex items-center gap-2"
        >
          {running && <span className="w-1.5 h-1.5 rounded-full bg-neon-cyan animate-blink" />}
          {PHASE_LABEL[phase]}
        </motion.div>

        {elapsed > 0 && running && (
          <div className="text-[11.5px] text-mist-500 mono mt-1">{elapsed.toFixed(1)} с</div>
        )}

        {phase === 'error' && (
          <Btn className="mt-4" variant="danger" onClick={run}>
            <RotateCcw size={15} /> Повторить
          </Btn>
        )}

        {phase === 'idle' && (
          <motion.div whileHover={{ scale: 1.04 }} whileTap={{ scale: 0.95 }} className="mt-5">
            <Btn size="lg" onClick={run}>
              <Play size={16} fill="currentColor" /> Начать тест
            </Btn>
          </motion.div>
        )}

        {phase === 'done' && (
          <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="mt-5 flex items-center gap-3">
            <Btn onClick={run}><RotateCcw size={15} /> Пройти заново</Btn>
          </motion.div>
        )}
      </Card>

      {/* результаты */}
      <AnimatePresence>
        {phase === 'done' && (
          <motion.div
            initial={{ opacity: 0, y: 18 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ type: 'spring', stiffness: 380, damping: 34 }}
            className="grid grid-cols-[1fr_260px] gap-4"
          >
            <Card className="p-5 flex flex-col gap-4">
              <div className="flex items-center justify-between">
                <span className="text-[13px] font-semibold">Результаты</span>
                <span className="text-[11px] text-mist-500 mono">speed.cloudflare.com</span>
              </div>
              <ResultBar icon={ArrowDown} label="Скачивание" value={down.toFixed(1)} max={200} unit="Мбит/с"
                color="bg-cyan-500/12 border-cyan-400/30 text-neon-cyan" delay={0.05} />
              <ResultBar icon={ArrowUp} label="Загрузка" value={up.toFixed(1)} max={100} unit="Мбит/с"
                color="bg-violet-500/12 border-violet-400/30 text-violet-400" delay={0.15} />
              <ResultBar icon={Signal} label="Пинг" value={lat?.avgMs ?? 0} max={300} unit="мс"
                color="bg-emerald-500/12 border-emerald-400/30 text-neon-emerald" delay={0.25} />
              <div className="flex items-center gap-5 pt-1 text-[11.5px] text-mist-500 mono border-t border-white/[0.06]">
                <span>джиттер <b className="text-mist-300">{lat?.jitterMs ?? 0} мс</b></span>
                <span>мин <b className="text-mist-300">{lat?.minMs ?? 0} мс</b></span>
                <span>макс <b className="text-mist-300">{lat?.maxMs ?? 0} мс</b></span>
                <span className="ml-auto">время теста <b className="text-mist-300">{elapsed.toFixed(1)} с</b></span>
              </div>
            </Card>

            <Card className="p-5 flex flex-col items-center justify-center gap-3 top-lit">
              <div className="flex gap-1.5">
                {[1, 2, 3, 4, 5].map((i) => (
                  <motion.span
                    key={i}
                    initial={{ opacity: 0, scale: 0.4, rotate: -40 }}
                    animate={{ opacity: 1, scale: 1, rotate: 0 }}
                    transition={{ delay: 0.3 + i * 0.09, type: 'spring', stiffness: 420, damping: 16 }}
                    className={`text-[30px] leading-none ${i <= verdict.stars
                      ? 'text-neon-amber drop-shadow-[0_0_10px_rgba(251,191,36,.8)]'
                      : 'text-white/12'}`}
                  >
                    ★
                  </motion.span>
                ))}
              </div>
              <div className="text-[14px] font-semibold text-center">{verdict.stars} из 5</div>
              <div className="text-[12px] text-mist-500 text-center leading-snug">{verdict.text}</div>
              <div className="flex items-center gap-1.5 text-[11px] text-mist-700 mono mt-1">
                <Timer size={11} /> {elapsed.toFixed(1)} с · 70 МБ трафика
              </div>
            </Card>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
