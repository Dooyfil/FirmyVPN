import React, { useRef, useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import {
  CheckCircle2,
  ClipboardPaste,
  Download,
  FileJson,
  FolderOpen,
  Link2,
  Loader2,
  Plus,
  RefreshCw,
  Rss,
  Trash2,
  Upload,
  XCircle,
} from 'lucide-react'
import { Badge, Btn, Card, IconBtn, SectionTitle, Segmented } from './ui'
import { toast } from '../lib/toast'

const TABS = [
  { value: 'sub', label: 'Подписка', icon: Link2, hint: 'любые ссылки и ключи' },
  { value: 'file', label: 'Файл', icon: FileJson, hint: 'txt / json / yaml' },
]

const SUPPORTED = ['vless://', 'vmess://', 'trojan://', 'ss://', 'hysteria2://', 'tuic://', 'anytls://', 'http(s)://', 'base64', 'JSON', 'Clash YAML']

export default function ImportView({ onImportText, onImportSub, onRefreshSub, onDeleteSub, subs, onDone }) {
  const [tab, setTab] = useState('sub')
  const [busy, setBusy] = useState(false)
  const [result, setResult] = useState(null)
  const [text, setText] = useState('')
  const [dragOver, setDragOver] = useState(false)
  const fileRef = useRef(null)

  const showResult = (r, okMsg) => {
    setResult(r)
    if (r.added > 0) toast(okMsg || `Импортировано серверов: ${r.added}`, 'success')
    else if (r.errors?.length) toast(r.errors[0], 'error')
    else toast('Новых серверов не найдено', 'warn')
  }

  const isSingleUrl = (t) => {
    const s = t.trim()
    return /^https?:\/\/\S+$/.test(s) && !/\s/.test(s)
  }

  const run = async () => {
    const raw = text.trim()
    if (!raw) return toast('Вставьте ссылки, ключ или подписку', 'warn')
    setBusy(true)
    try {
      let r
      // одна ссылка → сразу загружаем как подписку
      if (isSingleUrl(raw)) {
        r = await onImportSub(raw, '')
        showResult(r, `Подписка загружена: +${r.added} серверов`)
      } else {
        r = await onImportText(raw)
        showResult(r, `Импортировано: ${r.added}`)
      }
      if (r.added > 0) setText('')
    } finally {
      setBusy(false)
    }
  }

  const importFile = async (file) => {
    if (!file) return
    if (file.size > 16 * 1024 * 1024) return toast('Файл больше 16 МБ', 'error')
    setBusy(true)
    try {
      const content = await file.text()
      const r = await onImportText(content)
      showResult(r, `Из файла «${file.name}»: +${r.added}`)
    } finally {
      setBusy(false)
    }
  }

  const paste = async () => {
    try {
      const t = await navigator.clipboard.readText()
      if (t) { setText((p) => (p ? p + '\n' + t : t)); toast('Вставлено из буфера', 'info', 1600) }
      else toast('Буфер обмена пуст', 'warn')
    } catch { toast('Нет доступа к буферу обмена', 'error') }
  }

  return (
    <div className="flex flex-col gap-4 h-full overflow-y-auto pr-1 pb-2">
      <SectionTitle
        icon={Download}
        title="Импорт"
        sub="ключи из Telegram-ботов, подписки и файлы — вставляйте что угодно"
        right={
          <div className="flex items-center gap-2">
            <Segmented
              options={TABS.map((t) => ({ value: t.value, label: t.label, icon: t.icon }))}
              value={tab}
              onChange={setTab}
            />
          </div>
        }
      />

      <AnimatePresence mode="wait">
        <motion.div
          key={tab}
          initial={{ opacity: 0, y: 14, filter: 'blur(5px)' }}
          animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
          exit={{ opacity: 0, y: -10, filter: 'blur(4px)' }}
          transition={{ duration: 0.22, ease: [0.22, 1, 0.36, 1] }}
          className="flex flex-col gap-4"
        >
          {tab === 'sub' && (
            <>
              <Card className="p-4 relative overflow-hidden">
                <span className="absolute -right-16 -top-16 w-52 h-52 rounded-full bg-cyan-500/[0.07] blur-2xl" />

                <div className="flex items-center justify-between mb-2.5 relative z-10">
                  <label className="text-[13px] font-medium text-mist-300 flex items-center gap-2">
                    <Rss size={14} className="text-neon-cyan" />
                    Вставьте что угодно: ссылки-ключи, подписку или base64
                  </label>
                  <button
                    onClick={paste}
                    className="flex items-center gap-1.5 text-[12px] text-mist-500 hover:text-neon-cyan transition-colors cursor-pointer"
                  >
                    <ClipboardPaste size={13} /> Из буфера
                  </button>
                </div>

                <textarea
                  className="field w-full h-[210px] p-3.5 text-[12.5px] font-mono leading-relaxed resize-none relative z-10"
                  placeholder={'vless://uuid@host:443?security=reality#Название\nvmess://eyJhZGQiOi...\ntrojan://pass@host:443#Сервер\nss://YWVzLTI1Ni1nY206...@host:8388\nhysteria2://pass@host:443#Hy2\ntuic://uuid:pass@host:443\nanytls://pass@host:443\nhttps://t.me/example_bot/sub/xxxx'}
                  value={text}
                  onChange={(e) => setText(e.target.value)}
                  spellCheck={false}
                />

                <div className="flex items-center justify-between gap-3 mt-3 relative z-10">
                  <div className="flex flex-wrap gap-1.5 min-w-0">
                    {SUPPORTED.map((s) => (
                      <motion.span
                        key={s}
                        whileHover={{ y: -2, scale: 1.06 }}
                        className="px-1.5 py-0.5 rounded text-[10px] mono text-mist-500 bg-white/[0.05] border border-white/[0.08] cursor-default"
                      >
                        {s}
                      </motion.span>
                    ))}
                  </div>
                  <Btn onClick={run} disabled={busy || !text.trim()} loading={busy}>
                    {!busy && <Plus size={15} />}
                    {isSingleUrl(text.trim()) ? 'Загрузить подписку' : 'Импортировать'}
                  </Btn>
                </div>
              </Card>

              {subs.length > 0 && (
                <Card className="p-4">
                  <div className="text-[13px] font-medium text-mist-300 mb-3 flex items-center gap-2">
                    <Rss size={14} className="text-neon-cyan" /> Мои подписки
                  </div>
                  <div className="flex flex-col gap-2">
                    <AnimatePresence initial={false}>
                      {subs.map((s) => (
                        <motion.div
                          key={s.url}
                          layout
                          initial={{ opacity: 0, y: 8 }}
                          animate={{ opacity: 1, y: 0 }}
                          exit={{ opacity: 0, x: -30, height: 0 }}
                          className="flex items-center gap-3 px-3 py-2.5 rounded-xl bg-black/25 border border-white/[0.06]"
                        >
                          <span className="w-8 h-8 rounded-lg bg-cyan-500/12 border border-cyan-400/25 flex items-center justify-center text-neon-cyan shrink-0">
                            <Rss size={14} />
                          </span>
                          <div className="min-w-0 flex-1">
                            <div className="text-[13px] font-medium truncate">{s.name || s.url}</div>
                            <div className="text-[11px] text-mist-500 font-mono truncate">{s.url}</div>
                          </div>
                          <Badge className="bg-white/[0.06] text-mist-400 border-white/10 shrink-0">
                            {s.count} серверов
                          </Badge>
                          <span className="text-[11px] text-mist-700 shrink-0 w-[86px] text-right">
                            {s.lastSync ? new Date(s.lastSync).toLocaleDateString('ru-RU') : '—'}
                          </span>
                          <div className="flex gap-0.5 shrink-0">
                            <IconBtn
                              title="Обновить"
                              onClick={async () => {
                                setBusy(true)
                                try {
                                  const r = await onRefreshSub(s.url)
                                  showResult(r, `Подписка обновлена: +${r.added}`)
                                } finally { setBusy(false) }
                              }}
                            >
                              <RefreshCw size={14} className={busy ? 'animate-spin' : ''} />
                            </IconBtn>
                            <IconBtn title="Удалить" danger onClick={() => onDeleteSub(s.url)}>
                              <Trash2 size={14} />
                            </IconBtn>
                          </div>
                        </motion.div>
                      ))}
                    </AnimatePresence>
                  </div>
                </Card>
              )}
            </>
          )}

          {tab === 'file' && (
            <Card
              className={`p-9 flex flex-col items-center justify-center text-center transition-all duration-300 relative overflow-hidden
                ${dragOver ? 'border-cyan-400/55 shadow-[0_0_60px_-18px_rgba(34,211,238,.9)]' : ''}`}
              onDragOver={(e) => { e.preventDefault(); setDragOver(true) }}
              onDragLeave={() => setDragOver(false)}
              onDrop={(e) => { e.preventDefault(); setDragOver(false); importFile(e.dataTransfer.files?.[0]) }}
            >
              <span className="absolute inset-0 pointer-events-none"
                style={{ background: dragOver ? 'radial-gradient(60% 70% at 50% 0%, rgba(34,211,238,.14), transparent 70%)' : 'none' }} />

              <motion.div
                animate={dragOver ? { y: -10, scale: 1.1, rotate: -6 } : { y: 0, scale: 1, rotate: 0 }}
                transition={{ type: 'spring', stiffness: 320, damping: 18 }}
                className="w-16 h-16 rounded-2xl bg-gradient-to-br from-cyan-500/22 to-violet-500/22 border border-white/10 flex items-center justify-center text-neon-cyan mb-5 relative"
              >
                <Upload size={26} />
              </motion.div>

              <div className="text-[16px] font-semibold relative">Перетащите файл сюда</div>
              <div className="text-[12.5px] text-mist-500 mt-1.5 relative">
                .txt, .json, .yaml, .conf — ключи, подписки, конфиги sing-box или Clash
              </div>

              <input
                ref={fileRef}
                type="file"
                accept=".txt,.json,.yaml,.yml,.conf,.b64,text/*"
                className="hidden"
                onChange={(e) => importFile(e.target.files?.[0])}
              />
              <Btn className="mt-5" variant="ghost" onClick={() => fileRef.current?.click()} disabled={busy}>
                <FolderOpen size={15} /> Выбрать файл
              </Btn>

              {busy && (
                <div className="mt-4 text-[12.5px] text-neon-cyan flex items-center gap-2 relative">
                  <Loader2 size={14} className="animate-spin" /> Обработка…
                </div>
              )}
            </Card>
          )}
        </motion.div>
      </AnimatePresence>

      {/* результат импорта */}
      <AnimatePresence>
        {result && (
          <motion.div
            initial={{ opacity: 0, y: 14, scale: 0.98 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 10 }}
            transition={{ type: 'spring', stiffness: 420, damping: 34 }}
          >
            <Card className={`p-4 ${result.added > 0 ? 'border-emerald-400/30' : result.errors?.length ? 'border-rose-400/30' : ''}`}>
              <div className="flex items-center gap-2.5">
                {result.added > 0
                  ? <CheckCircle2 size={16} className="text-neon-emerald" />
                  : <XCircle size={16} className="text-neon-rose" />}
                <span className="text-[13.5px] font-medium">
                  Добавлено: {result.added}
                  {result.skipped > 0 && ` · пропущено (дубликаты): ${result.skipped}`}
                </span>
                <button className="ml-auto text-mist-700 hover:text-white cursor-pointer" onClick={() => setResult(null)}>
                  <XCircle size={14} />
                </button>
              </div>
              {result.errors?.length > 0 && (
                <div className="mt-2.5 flex flex-col gap-1 max-h-[130px] overflow-y-auto">
                  {result.errors.slice(0, 40).map((e, i) => (
                    <div key={i} className="text-[11.5px] font-mono text-rose-300/80 truncate">• {e}</div>
                  ))}
                </div>
              )}
            </Card>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
