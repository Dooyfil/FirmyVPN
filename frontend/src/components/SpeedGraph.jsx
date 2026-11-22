import React, { useEffect, useRef } from 'react'

/**
 * Живой график скорости: светящаяся область + линия.
 * samples: [{ up, down }] — байт/с, от старых к новым.
 * Занимает весь доступный контейнер (h-full), высота измеряется сама.
 */
export default function SpeedGraph({ samples = [], minHeight = 168 }) {
  const wrapRef = useRef(null)

  useEffect(() => {
    const wrap = wrapRef.current
    if (!wrap) return

    const draw = () => {
      const canvas = wrap.querySelector('canvas')
      if (!canvas) return
      const parent = wrap
      const dpr = window.devicePixelRatio || 1
      const w = parent.clientWidth
      const h = Math.max(minHeight, parent.clientHeight)
      if (w < 2 || h < 2) return
      canvas.width = Math.max(1, Math.floor(w * dpr))
      canvas.height = Math.max(1, Math.floor(h * dpr))
      canvas.style.width = w + 'px'
      canvas.style.height = h + 'px'
      const ctx = canvas.getContext('2d')
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
      ctx.clearRect(0, 0, w, h)

      const pad = { t: 16, r: 10, b: 20, l: 10 }
      const iw = w - pad.l - pad.r
      const ih = h - pad.t - pad.b

      // сетка
      ctx.strokeStyle = 'rgba(255,255,255,0.05)'
      ctx.lineWidth = 1
      ctx.setLineDash([4, 6])
      for (let i = 0; i <= 3; i++) {
        const y = pad.t + (ih / 3) * i
        ctx.beginPath()
        ctx.moveTo(pad.l, y)
        ctx.lineTo(w - pad.r, y)
        ctx.stroke()
      }
      ctx.setLineDash([])

      if (!samples.length) {
        ctx.fillStyle = 'rgba(139,147,173,0.5)'
        ctx.font = '12px Inter, sans-serif'
        ctx.textAlign = 'center'
        ctx.fillText('ожидание трафика…', w / 2, h / 2)
        return
      }

      const n = samples.length
      const max = Math.max(
        64 * 1024,
        ...samples.map((s) => Math.max(s.down || 0, s.up || 0))
      ) * 1.15

      const xAt = (i) => pad.l + (n === 1 ? iw / 2 : (iw * i) / (n - 1))
      const yAt = (v) => pad.t + ih - (Math.max(0, v) / max) * ih

      const drawSeries = (key, stroke, fillTop, fillBottom, glow) => {
        const pts = samples.map((s, i) => [xAt(i), yAt(s[key] || 0)])
        if (pts.length === 1) pts.unshift([pad.l, pts[0][1]])

        // сглаженная кривая
        const path = new Path2D()
        path.moveTo(pts[0][0], pts[0][1])
        for (let i = 1; i < pts.length; i++) {
          const [x0, y0] = pts[i - 1]
          const [x1, y1] = pts[i]
          const cx = (x0 + x1) / 2
          path.bezierCurveTo(cx, y0, cx, y1, x1, y1)
        }

        // заливка
        const fill = new Path2D(path)
        fill.lineTo(pts[pts.length - 1][0], pad.t + ih)
        fill.lineTo(pts[0][0], pad.t + ih)
        fill.closePath()
        const grad = ctx.createLinearGradient(0, pad.t, 0, pad.t + ih)
        grad.addColorStop(0, fillTop)
        grad.addColorStop(1, fillBottom)
        ctx.fillStyle = grad
        ctx.fill(fill)

        // свечение линии
        ctx.save()
        ctx.shadowColor = glow
        ctx.shadowBlur = 12
        ctx.strokeStyle = stroke
        ctx.lineWidth = 2
        ctx.lineJoin = 'round'
        ctx.stroke(path)
        ctx.restore()

        // точка на последнем значении
        const last = pts[pts.length - 1]
        ctx.beginPath()
        ctx.arc(last[0], last[1], 3, 0, Math.PI * 2)
        ctx.fillStyle = stroke
        ctx.shadowColor = glow
        ctx.shadowBlur = 10
        ctx.fill()
        ctx.shadowBlur = 0
      }

      drawSeries('down', '#22d3ee', 'rgba(34,211,238,0.28)', 'rgba(34,211,238,0.01)', 'rgba(34,211,238,0.9)')
      drawSeries('up', '#a78bfa', 'rgba(167,139,250,0.2)', 'rgba(167,139,250,0.01)', 'rgba(167,139,250,0.8)')

      // подпись шкалы
      ctx.fillStyle = 'rgba(139,147,173,0.55)'
      ctx.font = '10.5px Inter, sans-serif'
      ctx.textAlign = 'left'
      const fmt = (b) => {
        if (b >= 1024 * 1024) return (b / (1024 * 1024)).toFixed(1) + ' МБ/с'
        return Math.round(b / 1024) + ' КБ/с'
      }
      ctx.fillText(fmt(max), pad.l, pad.t - 5)
      ctx.fillText('60 сек назад', pad.l, h - 6)
      ctx.textAlign = 'right'
      ctx.fillText('сейчас', w - pad.r, h - 6)
    }

    draw()

    const ro = new ResizeObserver(() => draw())
    ro.observe(wrap)
    return () => ro.disconnect()
  }, [samples, minHeight])

  return (
    <div ref={wrapRef} className="relative w-full h-full min-h-[168px]">
      <canvas className="absolute inset-0" />
    </div>
  )
}
