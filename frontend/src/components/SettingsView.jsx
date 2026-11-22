import React, { useEffect, useState } from 'react'
import { motion } from 'framer-motion'
import {
  Activity,
  Ban,
  Cpu,
  FolderOpen,
  Globe,
  Keyboard,
  ListFilter,
  Network,
  Rocket,
  ScrollText,
  Settings,
  ShieldCheck,
  Sparkles,
  Timer,
  Waypoints,
  Zap,
} from 'lucide-react'
import { Btn, Card, Row, SectionTitle, Segmented, Toggle } from './ui'
import { toast } from '../lib/toast'

const DNS_OPTIONS = [
  { value: 'auto', label: 'Авто', hint: 'DoH Google 8.8.8.8 — быстрый и умный выбор' },
  { value: 'cloudflare', label: 'Cloudflare', hint: '1.1.1.1 — приватность и скорость' },
  { value: 'google', label: 'Google', hint: '8.8.8.8 — классика, максимум совместимости' },
  { value: 'quad9', label: 'Quad9', hint: '9.9.9.9 — блокировка вредоносных доменов' },
  { value: 'adguard', label: 'AdGuard', hint: '94.140.14.14 — реклама и трекеры' },
  { value: 'direct', label: 'Без фильтров', hint: 'обычный UDP DNS, минимальная задержка' },
]

function GroupHead({ icon: Icon, title, sub }) {
  return (
    <div className="px-4 pt-4 pb-1.5 flex items-center gap-2.5">
      <span className="w-6 h-6 rounded-md bg-white/[0.06] border border-white/10 flex items-center justify-center text-neon-cyan">
        <Icon size={12.5} />
      </span>
      <div className="min-w-0">
        <div className="text-[11.5px] uppercase tracking-[0.14em] text-mist-500 font-medium">{title}</div>
        {sub && <div className="text-[10.5px] text-mist-700 mt-px">{sub}</div>}
      </div>
    </div>
  )
}

export default function SettingsView({ settings, onSave, status, admin, version, onOpenFolder, killActive, onUnblock }) {
  const [draft, setDraft] = useState(settings)
  const [dirty, setDirty] = useState(false)

  // если настройки пришли снаружи (например, только что сохранились) — синхронизируем
  useEffect(() => { setDraft(settings); setDirty(false) }, [settings])

  const patch = (p) => {
    setDraft((d) => ({ ...d, ...p }))
    setDirty(true)
  }

  const save = async () => {
    try {
      await onSave(draft)
      setDirty(false)
      toast('Настройки сохранены', 'success')
    } catch (e) {
      toast(String(e || 'Ошибка сохранения'), 'error')
    }
  }

  const reset = () => { setDraft(settings); setDirty(false) }

  const selectedDns = DNS_OPTIONS.find((d) => d.value === draft.dns) || DNS_OPTIONS[0]
  const customDnsOn = !!draft.customDNS && draft.customDNS.trim().length > 0

  return (
    <div className="flex flex-col gap-4 h-full overflow-y-auto pr-1 pb-16">
      <SectionTitle
        icon={Settings}
        title="Настройки"
        sub="сеть, защита, автоподключение, DNS и поведение приложения"
        right={
          <div className="flex items-center gap-2">
            {dirty && (
              <motion.span
                initial={{ opacity: 0, x: 8 }}
                animate={{ opacity: 1, x: 0 }}
                className="text-[11.5px] text-neon-amber flex items-center gap-1.5"
              >
                <span className="w-1.5 h-1.5 rounded-full bg-neon-amber animate-blink" /> не сохранено
              </motion.span>
            )}
            <Btn size="sm" variant="ghost" onClick={reset} disabled={!dirty}>Сбросить</Btn>
            <Btn size="sm" onClick={save} disabled={!dirty}>Сохранить</Btn>
          </div>
        }
      />

      {killActive && (
        <motion.div
          initial={{ opacity: 0, y: -8 }}
          animate={{ opacity: 1, y: 0 }}
          className="rounded-2xl border border-rose-500/30 bg-rose-500/[0.08] px-4 py-3.5 flex items-center gap-3"
        >
          <Activity size={17} className="text-neon-rose animate-blink shrink-0" />
          <div className="flex-1 min-w-0">
            <div className="text-[13.5px] font-semibold text-rose-200">Интернет заблокирован (kill switch)</div>
            <div className="text-[11.5px] text-rose-300/75">Соединение с VPN было потеряно — трафик остановлен до восстановления.</div>
          </div>
          <Btn size="sm" variant="danger" onClick={onUnblock}>Разблокировать</Btn>
        </motion.div>
      )}

      <div className="grid grid-cols-2 gap-4 items-stretch">
        {/* ================= сеть и режим ================= */}
        <Card className="overflow-hidden">
          <GroupHead icon={Network} title="Сеть и режим" sub="как трафик идёт через туннель" />

          <Row icon={Zap} title="Режим работы" desc="TUN — весь трафик ПК; Прокси — только приложения с настройкой прокси">
            <Segmented
              size="sm"
              value={draft.mode}
              onChange={(v) => patch({ mode: v })}
              options={[{ value: 'tun', label: 'TUN' }, { value: 'proxy', label: 'Прокси' }]}
            />
          </Row>

          <Row icon={Globe} title="Системный прокси" desc="Выставлять прокси Windows в режиме «Прокси»" accent="violet">
            <Toggle
              checked={!!draft.setSystemProxy}
              disabled={draft.mode !== 'proxy'}
              onChange={(v) => patch({ setSystemProxy: v })}
              accent="violet"
            />
          </Row>

          <Row icon={Cpu} title="Порт прокси" desc="HTTP/SOCKS5 на 127.0.0.1 — для браузеров и других приложений">
            <input
              type="number"
              min={1}
              max={65535}
              className="field w-[92px] px-2.5 py-1.5 text-[13px] font-mono text-center"
              value={draft.proxyPort || 10808}
              onChange={(e) => patch({ proxyPort: Number(e.target.value) || 10808 })}
            />
          </Row>

          <Row icon={Sparkles} title="Строгий маршрут" desc="Запрет обхода туннеля, защита от утечек DNS и IP" accent="amber">
            <Toggle checked={!!draft.strictRoute} onChange={(v) => patch({ strictRoute: v })} accent="violet" />
          </Row>

          <Row
            icon={Waypoints}
            title="MTU туннеля"
            desc={`Размер пакета TUN-интерфейса · ${draft.mtu || 9000} (9000 по умолчанию)`}
            accent="violet"
          >
            <input
              type="number"
              min={1280}
              max={9000}
              step={100}
              className="field w-[92px] px-2.5 py-1.5 text-[13px] font-mono text-center"
              value={draft.mtu || 9000}
              onChange={(e) => patch({ mtu: Number(e.target.value) || 9000 })}
            />
          </Row>

          <Row icon={Ban} title="Отключить IPv6" desc="Не пускать IPv6 через туннель — защита от утечек по v6" accent="rose">
            <Toggle checked={!!draft.disableIPv6} onChange={(v) => patch({ disableIPv6: v })} accent="rose" />
          </Row>
        </Card>

        {/* ================= защита ================= */}
        <Card className="overflow-hidden">
          <GroupHead icon={ShieldCheck} title="Защита" sub="что блокировать и когда" />

          <Row icon={ShieldCheck} title="Kill switch" desc="Блокировать интернет при обрыве VPN или падении приложения" accent="rose">
            <Toggle checked={!!draft.killSwitch} onChange={(v) => patch({ killSwitch: v })} accent="rose" />
          </Row>

          <Row icon={Activity} title="Блокировать LAN" desc="Закрыть доступ к локальной сети через туннель" accent="rose">
            <Toggle checked={!!draft.blockLan} onChange={(v) => patch({ blockLan: v })} accent="rose" />
          </Row>

          <Row icon={Activity} title="Блокировать P2P / торренты" desc="Не пропускать торрент-трафик через VPN" accent="rose">
            <Toggle checked={!!draft.blockBt} onChange={(v) => patch({ blockBt: v })} accent="rose" />
          </Row>

          <Row icon={Ban} title="Блокировать рекламу" desc="Отсекать рекламные и трекер-домены на уровне ядра" accent="amber">
            <Toggle checked={!!draft.blockAds} onChange={(v) => patch({ blockAds: v })} accent="violet" />
          </Row>

          <Row icon={Network} title="Блокировать UDP" desc="Только TCP через туннель — для стабильности на плохих линиях" accent="amber">
            <Toggle checked={!!draft.udpBlock} onChange={(v) => patch({ udpBlock: v })} accent="violet" />
          </Row>
        </Card>
      </div>

      <div className="grid grid-cols-2 gap-4 items-stretch">
        {/* ================= автоподключение ================= */}
        <Card className="overflow-hidden">
          <GroupHead icon={Rocket} title="Автоподключение" sub="старт и быстрый выбор сервера" />

          <Row icon={Rocket} title="Автоподключение" desc="Сразу поднимать VPN при запуске FirmyVPN" accent="violet">
            <Toggle checked={!!draft.autoConnect} onChange={(v) => patch({ autoConnect: v })} accent="violet" />
          </Row>

          <Row icon={Timer} title="Быстрый сервер" desc="Выбирать сервер с наименьшим пингом при подключении" accent="emerald">
            <Toggle checked={!!draft.fastestServer} onChange={(v) => patch({ fastestServer: v })} accent="cyan" />
          </Row>

          <Row icon={Rocket} title="Автозагрузка" desc="Запускать FirmyVPN вместе со входом в Windows" accent="violet">
            <Toggle checked={!!draft.autostart} onChange={(v) => patch({ autostart: v })} accent="violet" />
          </Row>

          <Row icon={Sparkles} title="Сворачивать при запуске" desc="Окно стартует свёрнутым в трей">
            <Toggle checked={!!draft.startMinimized} onChange={(v) => patch({ startMinimized: v })} />
          </Row>

          <Row icon={Sparkles} title="Сворачивать в трей" desc="Кнопка «Закрыть» прячет окно, а не завершает работу">
            <Toggle checked={!!draft.closeToTray} onChange={(v) => patch({ closeToTray: v })} />
          </Row>

          <Row icon={Keyboard} title="Горячая клавиша" desc="Ctrl+Alt+V — мгновенно подключить или отключить VPN" accent="amber">
            <Toggle checked={!!draft.hotkeyEnabled} onChange={(v) => patch({ hotkeyEnabled: v })} accent="violet" />
          </Row>
        </Card>

        {/* ================= DNS ================= */}
        <Card className="overflow-hidden">
          <GroupHead icon={Globe} title="DNS-сервер" sub={selectedDns.hint} />

          <div className="px-4 pt-2 pb-3">
            <div className="grid grid-cols-3 gap-1.5">
              {DNS_OPTIONS.map((d) => {
                const active = d.value === draft.dns && !customDnsOn
                return (
                  <button
                    key={d.value}
                    onClick={() => patch({ dns: d.value, customDNS: '' })}
                    className={`relative rounded-lg px-2 py-2 text-[11.5px] font-medium transition-all cursor-pointer border
                      ${active
                        ? 'border-cyan-400/45 bg-cyan-500/12 text-white shadow-[0_0_18px_-8px_rgba(34,211,238,0.9)]'
                        : 'border-white/[0.08] bg-white/[0.03] text-mist-500 hover:text-mist-200 hover:bg-white/[0.07]'}`}
                  >
                    {active && (
                      <motion.span
                        layoutId="dns-active"
                        transition={{ type: 'spring', stiffness: 500, damping: 38 }}
                        className="absolute inset-0 rounded-lg border border-cyan-400/30"
                      />
                    )}
                    <span className="relative z-10">{d.label}</span>
                  </button>
                )
              })}
            </div>
          </div>

          <div className="px-4 pb-4">
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-[11.5px] text-mist-500">Свой DNS (перебивает пресет)</span>
              {customDnsOn && (
                <button
                  onClick={() => patch({ customDNS: '' })}
                  className="text-[11px] text-neon-rose hover:text-rose-300 cursor-pointer"
                >
                  очистить
                </button>
              )}
            </div>
            <input
              className="field w-full px-3 py-2 text-[12.5px] font-mono"
              placeholder="1.1.1.1 · dns.google · https://dns.adguard-dns.com/dns-query"
              value={draft.customDNS || ''}
              onChange={(e) => patch({ customDNS: e.target.value })}
              spellCheck={false}
            />
            <div className="text-[10.5px] text-mist-700 mt-1.5 leading-snug">
              IP — обычный UDP, домен — DoH, полный <span className="font-mono">https://…</span> — DoH по адресу.
            </div>
          </div>
        </Card>
      </div>

      {/* ================= обход VPN ================= */}
      <Card className="overflow-hidden">
        <GroupHead icon={ListFilter} title="Обход VPN" sub="домены и IP, которые идут мимо туннеля (прямое подключение)" />
        <div className="px-4 pb-4 pt-1">
          <textarea
            className="field w-full h-[86px] p-3 text-[12.5px] font-mono leading-relaxed resize-none"
            placeholder={'bank.ru\n*.local\n192.168.0.0/16\n10.0.0.0/8'}
            value={draft.bypassDomains || ''}
            onChange={(e) => patch({ bypassDomains: e.target.value })}
            spellCheck={false}
          />
          <div className="text-[10.5px] text-mist-700 mt-1.5">
            Каждый с новой строки: домен, <span className="font-mono">*.суффикс</span> или CIDR — трафик пойдёт напрямую.
          </div>
        </div>
      </Card>

      {/* ================= приложение ================= */}
      <Card className="overflow-hidden">
        <GroupHead icon={ScrollText} title="Приложение" sub="логи, папка данных, идентификация" />

        <div className="grid grid-cols-2">
          <div className="border-r border-white/[0.05]">
            <Row icon={ScrollText} title="Уровень логов" desc="debug — максимум деталей, warn — только проблемы">
              <Segmented
                size="sm"
                value={draft.logLevel}
                onChange={(v) => patch({ logLevel: v })}
                options={[
                  { value: 'debug', label: 'Debug' },
                  { value: 'info', label: 'Info' },
                  { value: 'warn', label: 'Warn' },
                ]}
              />
            </Row>
          </div>
          <div>
            <Row icon={FolderOpen} title="Папка данных" desc="%AppData%\FirmyVPN — серверы, подписки, логи" accent="violet">
              <Btn size="sm" variant="ghost" onClick={onOpenFolder}>Открыть</Btn>
            </Row>
          </div>
        </div>
      </Card>

      {/* ---------- о программе ---------- */}
      <Card className="px-5 py-4 flex items-center gap-4">
        <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-cyan-500/25 via-indigo-500/20 to-fuchsia-500/25 border border-white/10 flex items-center justify-center">
          <Sparkles size={20} className="text-neon-cyan" />
        </div>
        <div className="min-w-0">
          <div className="text-[15px] font-semibold tracking-tight grad-text">FirmyVPN {version ? `v${version}` : ''}</div>
          <div className="text-[12px] text-mist-500 mt-0.5">
            Ядро sing-box 1.14 · TUN / прокси / kill switch · импорт vless, vmess, trojan, ss, hysteria2, tuic, anytls
          </div>
        </div>
        <div className="ml-auto flex items-center gap-2">
          {admin ? (
            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border border-emerald-400/30 bg-emerald-500/10 text-[11.5px] text-emerald-300">
              <ShieldCheck size={12} /> права администратора
            </span>
          ) : (
            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border border-amber-400/30 bg-amber-500/10 text-[11.5px] text-amber-200">
              <ShieldCheck size={12} /> TUN недоступен без админа
            </span>
          )}
          <span className="text-[11.5px] font-mono text-mist-700">
            {status?.connected ? `IP: ${status.assignedIp || '—'}` : 'не подключено'}
          </span>
        </div>
      </Card>
    </div>
  )
}
