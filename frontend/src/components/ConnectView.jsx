import React, { useMemo, useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import {
  ArrowDown,
  ArrowUp,
  Clock,
  Copy,
  Globe,
  Import as ImportIcon,
  Power,
  Search,
  Server,
  ShieldCheck,
  ShieldOff,
  Shuffle,
  Wifi,
  Zap,
} from 'lucide-react'
import SpeedGraph from './SpeedGraph'
import { AnimatedNumber, Badge, Btn, Card, Empty, IconBtn, Toggle } from './ui'
import { fmtBytes, fmtDuration, fmtPing, fmtSpeed, PROTO_COLOR, PROTO_LABEL, pingColor } from '../lib/format'
import { toast } from '../lib/toast'

function StatTile({ icon: Icon, label, value, sub, accent, delay = 0 }) {
  const accents = {
    cyan: 'text-neon-cyan bg-cyan-500/10 border-cyan-400/25',
    violet: 'text-violet-400 bg-violet-500/10 border-violet-400/25',
    emerald: 'text-neon-emerald bg-emerald-500/10 border-emerald-400/25',
    amber: 'text-neon-amber bg-amber-500/10 border-amber-400/25',
  }
  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay, type: 'spring', stiffness: 420, damping: 32 }}
      className="glass glass-hover rounded-2xl px-3.5 py-3 flex items-start gap-3 min-w-0 relative overflow-hidden group"
    >
      <span className="absolute -right-5 -top-5 w-16 h-16 rounded-full bg-white/[0.04] blur-lg group-hover:scale-150 transition-transform duration-500" />
      <div className={`w-9 h-9 rounded-xl border flex items-center justify-center shrink-0 ${accents[accent]}`}>
        <Icon size={16} />
      </div>
      <div className="min-w-0 flex-1 relative z-10">
        <div className="text-[10.5px] uppercase tracking-[0.13em] text-mist-700 truncate">{label}</div>
        <div className="text-[17px] font-semibold tracking-tight text-mist-100 truncate mt-0.5 tabular-nums">
          {value}
        </div>
        {sub && <div className="text-[10.5px] text-mist-500 truncate">{sub}</div>}
      </div>
    </motion.div>
  )
}

function ServerRow({ s, active, connected, switching, onSelect, index }) {
  const isTarget = switching && active
  return (
    <motion.button
      layout
      initial={{ opacity: 0, x: -14 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: 24, height: 0 }}
      transition={{ delay: Math.min(index * 0.02, 0.18), type: 'spring', stiffness: 460, damping: 38 }}
      whileHover={{ x: 4 }}
      whileTap={{ scale: 0.985 }}
      onClick={() => onSelect(s.id)}
      title={connected ? 'Переключиться на этот регион (без отключения)' : 'Выбрать сервер'}
      className={`relative w-full text-left px-3 py-2.5 rounded-xl border transition-all duration-200 overflow-hidden cursor-pointer
        ${active
          ? 'border-cyan-400/45 bg-gradient-to-r from-cyan-500/[0.14] to-violet-500/[0.09] shadow-[0_0_26px_-14px_rgba(34,211,238,1)]'
          : 'border-white/[0.07] bg-black/25 hover:border-white/[0.18] hover:bg-white/[0.05]'}`}
    >
      {active && (
        <motion.span
          layoutId="srv-active-bar"
          transition={{ type: 'spring', stiffness: 520, damping: 42 }}
          className="absolute left-0 top-1 bottom-1 w-[3px] rounded-full bg-gradient-to-b from-cyan-300 to-violet-500 shadow-[0_0_10px_2px_rgba(34,211,238,.7)]"
        />
      )}

      <div className="flex items-center gap-2.5 min-w-0">
        <span className={`w-8 h-8 rounded-lg bg-gradient-to-br border flex items-center justify-center shrink-0 text-[9.5px] font-bold ${PROTO_COLOR[s.protocol] || 'from-white/10 to-white/5 text-mist-300 border-white/15'}`}>
          {(PROTO_LABEL[s.protocol] || s.protocol || '?').slice(0, 4).toUpperCase()}
        </span>

        <span className="min-w-0 flex-1">
          <span className="flex items-center gap-1.5 min-w-0">
            <span className="text-[13px] font-medium truncate">{s.name}</span>
            {active && connected && !isTarget && (
              <span className="w-1.5 h-1.5 rounded-full bg-neon-emerald status-dot shrink-0" />
            )}
          </span>
          <span className="block text-[11px] text-mist-500 mono truncate mt-0.5">
            {s.host}:{s.port}
          </span>
        </span>

        <span className={`w-[62px] text-right text-[11.5px] mono shrink-0 ${pingColor(s.ping)}`}>
          {s.ping < 0 ? '—' : `${s.ping} мс`}
        </span>

        <span
          className={`shrink-0 w-7 h-7 rounded-lg flex items-center justify-center border transition-all
            ${active && connected
              ? 'border-cyan-400/40 bg-cyan-500/15 text-neon-cyan'
              : 'border-white/10 bg-white/[0.05] text-mist-500 group-hover:text-white'}`}
        >
          {isTarget
            ? <motion.span animate={{ rotate: 360 }} transition={{ repeat: Infinity, duration: 0.9, ease: 'linear' }}
                className="w-3.5 h-3.5 rounded-full border-2 border-cyan-400/30 border-t-cyan-300" />
            : <Zap size={13} />}
        </span>
      </div>
    </motion.button>
  )
}

export default function ConnectView({
  status, settings, servers, selected, now, samples, pinging,
  onToggle, onNeedImport, onPatchSettings, killActive, onSelect, onPingAll,
}) {
  const [q, setQ] = useState('')
  const state = status.connected ? 'on' : (status.connecting || status.switching) ? 'busy' : 'off'

  const ringBg = useMemo(() => {
    if (state === 'on') return 'conic-gradient(from 0deg, #34d399, #22d3ee, #818cf8, #34d399)'
    if (state === 'busy') return 'conic-gradient(from 0deg, rgba(251,191,36,.1), #fbbf24, rgba(34,211,238,.95), rgba(251,191,36,.1))'
    return 'conic-gradient(from 210deg, rgba(34,211,238,.55), rgba(139,92,246,.5), rgba(232,121,249,.45), rgba(34,211,238,.55))'
  }, [state])

  const label = state === 'on' ? 'Отключиться'
    : status.switching ? 'Смена региона…'
    : status.connecting ? 'Подключение…'
    : 'Подключиться'

  const sessionMs = status.connected && status.startedAt ? now - status.startedAt : 0
  const total = (status.downloadTot || 0) + (status.uploadTot || 0)

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase()
    if (!needle) return servers
    return servers.filter((s) =>
      s.name.toLowerCase().includes(needle) ||
      s.host.toLowerCase().includes(needle) ||
      (s.protocol || '').toLowerCase().includes(needle))
  }, [servers, q])

  const modeChange = (mode) => {
    onPatchSettings({ ...settings, mode })
    if (status.connected) toast('Режим применится при следующем подключении', 'info')
  }

  return (
    <div className="grid grid-cols-[minmax(268px,308px)_1fr] gap-4 h-full overflow-y-auto pr-1 pb-2 content-start">
      {/* ================= левая колонка ================= */}
      <div className="flex flex-col gap-4 min-h-0">
        {/* кнопка подключения */}
        <Card className="relative overflow-hidden flex flex-col items-center justify-center py-6 px-4 top-lit">
          <div
            className="absolute pointer-events-none transition-all duration-700"
            style={{
              width: 320, height: 320, left: '50%', top: '46%', transform: 'translate(-50%,-50%)',
              background: state === 'on'
                ? 'radial-gradient(circle, rgba(52,211,153,.2), transparent 62%)'
                : state === 'busy'
                  ? 'radial-gradient(circle, rgba(251,191,36,.16), transparent 62%)'
                  : 'radial-gradient(circle, rgba(34,211,238,.12), transparent 62%)',
            }}
          />

          <motion.button
            onClick={onToggle}
            disabled={state === 'busy'}
            whileHover={state === 'busy' ? {} : { scale: 1.04 }}
            whileTap={state === 'busy' ? {} : { scale: 0.955 }}
            transition={{ type: 'spring', stiffness: 420, damping: 22 }}
            className="relative w-[184px] h-[184px] rounded-full cursor-pointer disabled:cursor-wait group"
          >
            {state === 'on' && (
              <>
                <span className="absolute inset-0 rounded-full border-2 border-emerald-400/55 animate-ring-ping pointer-events-none" />
                <span className="absolute inset-0 rounded-full border-2 border-cyan-400/45 animate-ring-ping-delay pointer-events-none" />
              </>
            )}

            <span
              className={`absolute inset-0 rounded-full ${state === 'busy' ? 'animate-[spin_1.05s_linear_infinite]' : state === 'on' ? 'animate-spin-slow' : ''}`}
              style={{
                background: ringBg,
                WebkitMaskImage: 'radial-gradient(farthest-side, transparent calc(100% - 5px), #000 calc(100% - 4px))',
                maskImage: 'radial-gradient(farthest-side, transparent calc(100% - 5px), #000 calc(100% - 4px))',
                transition: 'background .5s',
              }}
            />
            <span
              className={`absolute inset-[5px] rounded-full flex flex-col items-center justify-center gap-1.5
                border border-white/[0.1] backdrop-blur-xl transition-all duration-500
                ${state === 'on'
                  ? 'bg-[radial-gradient(circle_at_50%_28%,rgba(52,211,153,.2),rgba(6,10,20,.93)_65%)] shadow-[inset_0_0_46px_-16px_rgba(52,211,153,.75)]'
                  : state === 'busy'
                    ? 'bg-[radial-gradient(circle_at_50%_28%,rgba(251,191,36,.16),rgba(6,10,20,.94)_65%)]'
                    : 'bg-[radial-gradient(circle_at_50%_28%,rgba(34,211,238,.14),rgba(6,10,20,.94)_65%)] group-hover:shadow-[inset_0_0_50px_-14px_rgba(34,211,238,.7)]'}`}
            >
              <motion.span
                animate={state === 'busy' ? { rotate: [0, 360], scale: [1, 1.12, 1] } : { rotate: 0, scale: 1 }}
                transition={state === 'busy'
                  ? { rotate: { repeat: Infinity, duration: 1.5, ease: 'linear' }, scale: { repeat: Infinity, duration: 1.1 } }
                  : { type: 'spring', stiffness: 300, damping: 14 }}
                className={`${
                  state === 'on' ? 'text-neon-emerald drop-shadow-[0_0_16px_rgba(52,211,153,.9)]' :
                  state === 'busy' ? 'text-neon-amber' : 'text-mist-300 group-hover:text-neon-cyan'
                } transition-colors duration-300`}
              >
                <Power size={44} strokeWidth={2.2} />
              </motion.span>
              <span className={`text-[12.5px] font-semibold tracking-wide ${
                state === 'on' ? 'text-emerald-200' : state === 'busy' ? 'text-amber-200' : 'text-mist-300'
              }`}>
                {label}
              </span>
              {state === 'on' && (
                <span className="text-[11px] font-mono text-emerald-400/75">{fmtDuration(sessionMs)}</span>
              )}
            </span>
          </motion.button>

          <AnimatePresence mode="wait">
            {status.error && (
              <motion.div
                key={status.error}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -6 }}
                className="mt-3.5 text-[12px] text-rose-300/90 text-center leading-snug max-w-[260px]"
              >
                {status.error}
              </motion.div>
            )}
          </AnimatePresence>

          {!selected && state === 'off' && !status.error && (
            <Btn size="sm" variant="glow" className="mt-4" onClick={onNeedImport}>
              <ImportIcon size={13} /> Добавить сервер
            </Btn>
          )}

          {status.connected && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="mt-3 flex items-center gap-1.5 text-[11px] text-mist-500"
            >
              <Shuffle size={11} className="text-neon-cyan" />
              клик по региону — мгновенная смена
            </motion.div>
          )}
        </Card>

        {/* график */}
        <Card className="px-4 pt-3.5 pb-3 flex-1 min-h-[240px] flex flex-col overflow-hidden">
          <div className="flex items-center justify-between mb-1">
            <div className="flex items-center gap-4 text-[12.5px] font-medium">
              <span className="flex items-center gap-1.5">
                <span className="w-2 h-2 rounded-full bg-cyan-400 shadow-[0_0_8px_2px_rgba(34,211,238,.6)] animate-breathe" />
                Скачивание
              </span>
              <span className="flex items-center gap-1.5">
                <span className="w-2 h-2 rounded-full bg-violet-400 shadow-[0_0_8px_2px_rgba(167,139,250,.6)] animate-breathe" />
                Загрузка
              </span>
            </div>
            {status.connected && status.mode === 'proxy' ? (
              <button
                onClick={() => { navigator.clipboard?.writeText(status.proxyAddr); toast('Адрес прокси скопирован', 'success') }}
                className="flex items-center gap-1.5 text-[11px] font-mono text-mist-500 hover:text-neon-cyan transition-colors cursor-pointer"
              >
                <Copy size={11} /> {status.proxyAddr}
              </button>
            ) : status.connected ? (
              <span className="text-[11px] font-mono text-mist-500">весь трафик системы</span>
            ) : null}
          </div>
          <div className="flex-1 min-h-0 relative">
            <SpeedGraph samples={samples} />
          </div>
        </Card>
      </div>

      {/* ================= правая колонка ================= */}
      <div className="flex flex-col gap-4 min-h-0">
        {/* статы */}
        <div className="grid grid-cols-2 gap-3">
          <StatTile delay={0.02} icon={ArrowDown} accent="cyan" label="Скорость ↓"
            value={<AnimatedNumber value={status.download || 0} format={fmtSpeed} />}
            sub="сейчас" />
          <StatTile delay={0.07} icon={ArrowUp} accent="violet" label="Скорость ↑"
            value={<AnimatedNumber value={status.upload || 0} format={fmtSpeed} />}
            sub="сейчас" />
          <StatTile delay={0.12} icon={Clock} accent="amber" label="Сессия"
            value={status.connected ? fmtDuration(sessionMs) : '—'}
            sub={status.connected ? 'время подключения' : 'не подключено'} />
          <StatTile delay={0.17} icon={Globe} accent="emerald" label="Трафик"
            value={<AnimatedNumber value={total} format={fmtBytes} />}
            sub={`↓ ${fmtBytes(status.downloadTot)} · ↑ ${fmtBytes(status.uploadTot)}`} />
        </div>

        {/* быстрые переключатели */}
        <div className="grid grid-cols-2 gap-3">
          <Card className="px-3.5 py-3 flex items-center justify-between gap-2.5">
            <div className="flex items-center gap-2.5 min-w-0 flex-1">
              <Shuffle size={15} className="text-mist-500 shrink-0" />
              <div className="min-w-0">
                <div className="text-[12.5px] font-medium truncate">Режим</div>
                <div className="text-[10.5px] text-mist-500 truncate">
                  {settings.mode === 'tun' ? 'TUN · весь ПК' : 'Прокси · приложения'}
                </div>
              </div>
            </div>
            <div className="flex gap-0.5 p-0.5 rounded-lg bg-black/35 border border-white/[0.07] shrink-0">
              {[['tun', 'TUN'], ['proxy', 'Прокси']].map(([v, l]) => (
                <button
                  key={v}
                  onClick={() => modeChange(v)}
                  className={`relative px-2.5 py-1 rounded-md text-[11.5px] font-medium transition-colors cursor-pointer
                    ${settings.mode === v ? 'text-white' : 'text-mist-500 hover:text-mist-200'}`}
                >
                  {settings.mode === v && (
                    <motion.span
                      layoutId="mode-pill"
                      transition={{ type: 'spring', stiffness: 500, damping: 38 }}
                      className="absolute inset-0 rounded-md bg-gradient-to-r from-cyan-500/35 to-violet-500/35 border border-white/15"
                    />
                  )}
                  <span className="relative z-10">{l}</span>
                </button>
              ))}
            </div>
          </Card>

          <Card className="px-3.5 py-3 flex items-center justify-between gap-2.5">
            <div className="flex items-center gap-2.5 min-w-0 flex-1">
              {killActive
                ? <ShieldOff size={15} className="text-rose-400 shrink-0 animate-blink" />
                : <ShieldCheck size={15} className="text-mist-500 shrink-0" />}
              <div className="min-w-0">
                <div className="text-[12.5px] font-medium truncate">Kill switch</div>
                <div className="text-[10.5px] text-mist-500 truncate">
                  {killActive ? 'Интернет заблокирован' : 'Блок при обрыве VPN'}
                </div>
              </div>
            </div>
            <Toggle
              checked={!!settings.killSwitch}
              onChange={(v) => onPatchSettings({ ...settings, killSwitch: v })}
              accent="rose"
            />
          </Card>
        </div>

        {/* ================= серверы ================= */}
        <Card className="flex-1 min-h-[240px] flex flex-col overflow-hidden">
          <div className="flex items-center gap-2.5 px-4 pt-3.5 pb-2.5 border-b border-white/[0.06]">
            <Server size={15} className="text-neon-cyan shrink-0" />
            <div className="min-w-0">
              <div className="text-[13px] font-semibold truncate">Регионы и серверы</div>
              <div className="text-[10.5px] text-mist-500">
                {servers.length} шт · {status.connected ? 'клик = мгновенное переключение' : 'выберите для подключения'}
              </div>
            </div>

            <div className="ml-auto flex items-center gap-2">
              <div className="relative">
                <Search size={13} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-mist-700 pointer-events-none" />
                <input
                  className="field w-[150px] pl-8 pr-2.5 py-1.5 text-[12px]"
                  placeholder="Поиск…"
                  value={q}
                  onChange={(e) => setQ(e.target.value)}
                />
              </div>
              <IconBtn title="Пинг всех" onClick={onPingAll} disabled={!servers.length}>
                <Wifi size={14} className={pinging ? 'animate-ping text-neon-cyan' : ''} />
              </IconBtn>
              <Btn size="xs" variant="ghost" onClick={onNeedImport}>
                <ImportIcon size={12} /> Импорт
              </Btn>
            </div>
          </div>

          <div className="flex-1 overflow-y-auto p-2.5 flex flex-col gap-1.5">
            {servers.length === 0 ? (
              <Empty
                icon={Globe}
                title="Пока нет серверов"
                sub="Вставьте ключи из Telegram-бота или ссылку на подписку — FirmyVPN разберёт всё сам."
                action={<Btn size="sm" onClick={onNeedImport}>Импортировать</Btn>}
              />
            ) : filtered.length === 0 ? (
              <Empty icon={Search} title="Ничего не найдено" sub="Попробуйте другой запрос" />
            ) : (
              <AnimatePresence initial={false}>
                {filtered.map((s, i) => (
                  <ServerRow
                    key={s.id}
                    s={s}
                    index={i}
                    active={s.id === (selected?.id || '')}
                    connected={status.connected}
                    switching={!!status.switching}
                    onSelect={onSelect}
                  />
                ))}
              </AnimatePresence>
            )}
          </div>

          {pinging && (
            <div className="px-4 py-2 border-t border-white/[0.06] text-[11px] text-neon-cyan flex items-center gap-2">
              <span className="w-1.5 h-1.5 rounded-full bg-neon-cyan animate-blink" />
              Пингуем все серверы…
            </div>
          )}
        </Card>
      </div>
    </div>
  )
}
