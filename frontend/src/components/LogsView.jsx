import React, { useEffect, useMemo, useRef, useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { ArrowDown, Eraser, Info, ScrollText, Search, TriangleAlert } from 'lucide-react'
import { Btn, Card, Empty, SectionTitle, Segmented } from './ui'
import { toast } from '../lib/toast'

const LEVEL_STYLES = {
  debug: { cls: 'text-mist-700 border-white/10 bg-white/[0.03]', label: 'DEBUG' },
  info: { cls: 'text-cyan-300 border-cyan-400/25 bg-cyan-500/[0.08]', label: 'INFO' },
  warn: { cls: 'text-amber-300 border-amber-400/25 bg-amber-500/[0.08]', label: 'WARN' },
  error: { cls: 'text-rose-300 border-rose-400/25 bg-rose-500/[0.08]', label: 'ERROR' },
}

const FILTERS = [
  { value: 'all', label: 'Все' },
  { value: 'info', label: 'Info' },
  { value: 'warn', label: 'Warn' },
  { value: 'error', label: 'Error' },
]

export default function LogsView({ logs, onClear }) {
  const [filter, setFilter] = useState('all')
  const [q, setQ] = useState('')
  const [paused, setPaused] = useState(false)
  const [follow, setFollow] = useState(true)
  const boxRef = useRef(null)

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase()
    return logs.filter((l) => {
      if (filter !== 'all' && l.level !== filter) return false
      if (needle && !String(l.message).toLowerCase().includes(needle)) return false
      return true
    })
  }, [logs, filter, q])

  useEffect(() => {
    if (follow && boxRef.current) {
      boxRef.current.scrollTop = boxRef.current.scrollHeight
    }
  }, [filtered.length, follow])

  const counts = useMemo(() => {
    const c = { all: logs.length, info: 0, warn: 0, error: 0 }
    logs.forEach((l) => { if (c[l.level] !== undefined) c[l.level]++ })
    return c
  }, [logs])

  const exportLogs = async () => {
    try {
      const text = filtered.map((l) => `[${l.time}] [${l.level.toUpperCase()}] ${l.message}`).join('\n')
      await navigator.clipboard.writeText(text)
      toast(`Скопировано строк: ${filtered.length}`, 'success')
    } catch {
      toast('Не удалось скопировать', 'error')
    }
  }

  return (
    <div className="flex flex-col gap-4 h-full overflow-y-auto pr-1 pb-2">
      <SectionTitle
        icon={ScrollText}
        title="Логи"
        sub={`${logs.length} записей · движок sing-box`}
        right={
          <div className="flex items-center gap-2">
            <Btn size="sm" variant="ghost" onClick={exportLogs} disabled={!filtered.length}>
              Копировать
            </Btn>
            <Btn size="sm" variant="danger" onClick={() => { onClear(); toast('Логи очищены', 'info') }} disabled={!logs.length}>
              <Eraser size={13} /> Очистить
            </Btn>
          </div>
        }
      />

      <div className="flex items-center gap-2.5 flex-wrap">
        <Segmented options={FILTERS} value={filter} onChange={setFilter} size="sm" />
        <div className="relative flex-1 min-w-[200px]">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-mist-700 pointer-events-none" />
          <input
            className="field w-full pl-9 pr-3 py-2 text-[13px]"
            placeholder="Фильтр по тексту…"
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
        </div>
        <button
          onClick={() => { setPaused((p) => !p); setFollow(true) }}
          className={`px-3 py-2 rounded-xl text-[12.5px] font-medium border transition-colors cursor-pointer
            ${paused
              ? 'border-amber-400/35 bg-amber-500/10 text-amber-200'
              : 'border-white/10 bg-white/[0.05] text-mist-400 hover:text-white'}`}
        >
          {paused ? '⏸ Пауза' : '▶ Живой поток'}
        </button>
      </div>

      <Card className="flex-1 min-h-[300px] flex flex-col overflow-hidden">
        <div ref={boxRef} className="flex-1 overflow-y-auto p-3 font-mono text-[12px] leading-[1.75]">
          {filtered.length === 0 ? (
            <Empty icon={Info} title="Пока пусто" sub="Здесь появятся события подключения, ошибки и отладочные сообщения." />
          ) : (
            <AnimatePresence initial={false}>
              {filtered.map((l, i) => {
                const st = LEVEL_STYLES[l.level] || LEVEL_STYLES.info
                return (
                  <motion.div
                    key={`${l.time}-${i}-${l.message.slice(0, 24)}`}
                    initial={{ opacity: 0, x: -8 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ duration: 0.15 }}
                    className="group flex items-start gap-2.5 px-2 py-0.5 rounded-md hover:bg-white/[0.04] transition-colors"
                  >
                    <span className="text-mist-700 shrink-0 select-none">{l.time}</span>
                    <span className={`shrink-0 px-1.5 rounded border text-[10px] font-semibold leading-[16px] ${st.cls}`}>
                      {st.label}
                    </span>
                    <span className={`break-all ${l.level === 'error' ? 'text-rose-200/90' : l.level === 'warn' ? 'text-amber-100/85' : 'text-mist-300'}`}>
                      {l.message}
                    </span>
                  </motion.div>
                )
              })}
            </AnimatePresence>
          )}
        </div>

        <div className="flex items-center justify-between px-4 py-2 border-t border-white/[0.06] text-[11px] font-mono text-mist-700">
          <span>
            всего {counts.all} · info {counts.info} · warn {counts.warn} · error {counts.error}
          </span>
          <span className="flex items-center gap-1.5">
            {counts.error > 0 && <TriangleAlert size={11} className="text-rose-400" />}
            {follow ? 'автопрокрутка' : 'прокрутка вручную'}
          </span>
        </div>
      </Card>
    </div>
  )
}
