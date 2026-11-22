// Мини-стор тостов (без контекста — просто модулярный эмиттер).
const listeners = new Set()
let idSeq = 0

export function toast(message, type = 'info', ttl = 3800) {
  const item = { id: ++idSeq, message, type }
  listeners.forEach((fn) => fn(item))
  if (ttl > 0) {
    setTimeout(() => {
      listeners.forEach((fn) => fn({ ...item, gone: true }))
    }, ttl)
  }
  return item.id
}

export function onToast(fn) {
  listeners.add(fn)
  return () => listeners.delete(fn)
}
