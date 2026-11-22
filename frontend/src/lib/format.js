// Форматирование чисел для русского интерфейса.

export function fmtSpeed(bytesPerSec) {
  const b = Math.max(0, bytesPerSec || 0)
  if (b < 1024) return `${Math.round(b)} Б/с`
  if (b < 1024 * 1024) return `${(b / 1024).toFixed(b < 10 * 1024 ? 1 : 0)} КБ/с`
  if (b < 1024 * 1024 * 1024) return `${(b / (1024 * 1024)).toFixed(1)} МБ/с`
  return `${(b / (1024 * 1024 * 1024)).toFixed(2)} ГБ/с`
}

export function fmtBytes(bytes) {
  const b = Math.max(0, bytes || 0)
  if (b < 1024) return `${Math.round(b)} Б`
  if (b < 1024 * 1024) return `${(b / 1024).toFixed(1)} КБ`
  if (b < 1024 * 1024 * 1024) return `${(b / (1024 * 1024)).toFixed(1)} МБ`
  if (b < 1024 * 1024 * 1024 * 1024) return `${(b / (1024 * 1024 * 1024)).toFixed(2)} ГБ`
  return `${(b / (1024 * 1024 * 1024 * 1024)).toFixed(2)} ТБ`
}

export function fmtDuration(ms) {
  const s = Math.max(0, Math.floor((ms || 0) / 1000))
  const days = Math.floor(s / 86400)
  const h = Math.floor((s % 86400) / 3600)
  const m = Math.floor((s % 3600) / 60)
  const sec = s % 60
  const pad = (n) => String(n).padStart(2, '0')
  const time = `${pad(h)}:${pad(m)}:${pad(sec)}`
  return days > 0 ? `${days}д ${time}` : time
}

export function fmtPing(ms) {
  if (ms === undefined || ms === null || ms < 0) return '—'
  return `${ms} мс`
}

export function pingColor(ms) {
  if (ms === undefined || ms === null || ms < 0) return 'text-mist-500'
  if (ms < 100) return 'text-neon-emerald'
  if (ms < 250) return 'text-neon-amber'
  return 'text-neon-rose'
}

export const PROTO_LABEL = {
  vless: 'VLESS',
  vmess: 'VMess',
  trojan: 'Trojan',
  shadowsocks: 'SS',
  hysteria2: 'Hysteria2',
  tuic: 'TUIC',
  anytls: 'AnyTLS',
  wireguard: 'WireGuard',
}

export const PROTO_COLOR = {
  vless: 'from-cyan-400/25 to-blue-500/25 text-cyan-300 border-cyan-400/30',
  vmess: 'from-violet-400/25 to-fuchsia-500/25 text-violet-300 border-violet-400/30',
  trojan: 'from-rose-400/25 to-orange-500/25 text-rose-300 border-rose-400/30',
  shadowsocks: 'from-emerald-400/25 to-teal-500/25 text-emerald-300 border-emerald-400/30',
  hysteria2: 'from-amber-400/25 to-yellow-500/25 text-amber-300 border-amber-400/30',
  tuic: 'from-blue-400/25 to-indigo-500/25 text-blue-300 border-blue-400/30',
  anytls: 'from-fuchsia-400/25 to-pink-500/25 text-fuchsia-300 border-fuchsia-400/30',
  wireguard: 'from-sky-400/25 to-cyan-500/25 text-sky-300 border-sky-400/30',
}
