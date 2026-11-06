import { useEffect, useMemo, useRef, useState, type KeyboardEvent } from 'react'
import { fromDateKey } from '../core/date'
import { dayIndex } from '../core/progress'

export interface TrendPoint {
  date: string
  value: number
}

interface Props<P extends TrendPoint> {
  points: P[]
  /** Unidad que acompaña a los valores ("kg"). */
  unit: string
  /** Para el resumen accesible: "peso", "volumen"… */
  label: string
  format?: (n: number) => string
  /** Formato del eje Y; por defecto el mismo que `format`. */
  axisFormat?: (n: number) => string
  /** Línea horizontal de referencia (p. ej. la meta). */
  reference?: { value: number; label: string } | null
  /** Holgura mínima del eje Y alrededor de los datos. */
  minPad?: number
  /** Texto bajo el valor del punto activo: "vs. registro anterior". */
  compareLabel?: string
  /** Detalle extra del punto activo (p. ej. "55 kg × 5"). */
  detail?: (p: P) => string | null
  onSelect?: (p: P) => void
}

const HEIGHT = 220
const MARGIN = { top: 18, right: 18, bottom: 26 }
/** Con pocos registros se marcan todos los puntos; con muchos, solo el activo y el último. */
const MAX_MARKED = 24

const dateFmt = new Intl.DateTimeFormat('es-CL', { day: 'numeric', month: 'short' })
const longDateFmt = new Intl.DateTimeFormat('es-CL', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' })
const defaultFormat = (n: number) => (Math.round(n * 10) / 10).toLocaleString('es-CL')

/** Marcas "redondas" del eje: pasos de 1, 2, 2,5 o 5 × 10ⁿ. */
function niceTicks(lo: number, hi: number, approx = 4): number[] {
  const raw = (hi - lo) / approx
  const mag = 10 ** Math.floor(Math.log10(raw))
  const step = [1, 2, 2.5, 5, 10].map((m) => m * mag).find((s) => s >= raw) ?? 10 * mag
  const out: number[] = []
  for (let v = Math.floor(lo / step) * step; v <= Math.ceil(hi / step) * step + step * 1e-6; v += step) out.push(Math.round(v * 1000) / 1000)
  return out
}

/** Gráfica de línea en el tiempo, con cursor, tooltip y navegación con flechas. */
export function TrendChart<P extends TrendPoint>({
  points: data,
  unit,
  label,
  format = defaultFormat,
  axisFormat = format,
  reference = null,
  minPad = 0.5,
  compareLabel = 'vs. registro anterior',
  detail,
  onSelect,
}: Props<P>) {
  const wrapRef = useRef<HTMLDivElement>(null)
  const [width, setWidth] = useState(320)
  const [active, setActive] = useState<number | null>(null)

  useEffect(() => {
    const el = wrapRef.current
    if (!el) return
    const observer = new ResizeObserver(([e]) => setWidth(Math.max(240, Math.floor(e.contentRect.width))))
    observer.observe(el)
    return () => observer.disconnect()
  }, [])

  const geometry = useMemo(() => {
    const xs = data.map((e) => dayIndex(e.date))
    const values = data.map((e) => e.value)
    if (reference) values.push(reference.value)
    const lo = Math.min(...values)
    const hi = Math.max(...values)
    const pad = Math.max(minPad, (hi - lo) * 0.15)
    const ticks = niceTicks(Math.max(0, lo - pad), hi + pad)
    const yMin = ticks[0]
    const yMax = ticks[ticks.length - 1]
    // El margen izquierdo se ajusta al largo de las etiquetas del eje.
    const left = 14 + Math.max(...ticks.map((t) => axisFormat(t).length)) * 6
    let xMin = Math.min(...xs)
    let xMax = Math.max(...xs)
    if (xMin === xMax) {
      xMin -= 3
      xMax += 3
    }
    const innerW = width - left - MARGIN.right
    const innerH = HEIGHT - MARGIN.top - MARGIN.bottom
    const sx = (day: number) => left + ((day - xMin) / (xMax - xMin)) * innerW
    const sy = (v: number) => MARGIN.top + (1 - (v - yMin) / (yMax - yMin)) * innerH
    const points = data.map((e, i) => ({ src: e, x: sx(xs[i]), y: sy(e.value) }))
    const xTickCount = Math.max(2, Math.min(4, Math.floor(innerW / 90)))
    const xTicks = Array.from({ length: xTickCount }, (_, i) => {
      const day = xMin + ((xMax - xMin) * i) / (xTickCount - 1)
      return { x: sx(day), label: dateFmt.format(new Date(Math.round(day) * 86_400_000 + 12 * 3_600_000)) }
    })
    return { points, ticks, sy, xTicks, left }
  }, [data, reference, width, minPad, axisFormat])

  const { points, ticks, sy, xTicks, left } = geometry
  const last = points.at(-1)
  const path = points.map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(' ')
  const marked = points.length <= MAX_MARKED
  const current = active !== null ? points[active] : null

  function nearest(e: { clientX: number; currentTarget: Element }): number {
    const px = e.clientX - e.currentTarget.getBoundingClientRect().left
    let best = 0
    points.forEach((p, i) => {
      if (Math.abs(p.x - px) < Math.abs(points[best].x - px)) best = i
    })
    return best
  }

  function onKeyDown(e: KeyboardEvent<SVGSVGElement>) {
    if (e.key === 'ArrowLeft') setActive((a) => Math.max(0, (a ?? points.length) - 1))
    else if (e.key === 'ArrowRight') setActive((a) => Math.min(points.length - 1, (a ?? -1) + 1))
    else if (e.key === 'Escape') setActive(null)
    else if (e.key === 'Enter' && current && onSelect) onSelect(current.src)
    else return
    e.preventDefault()
  }

  const prev = active !== null && active > 0 ? points[active - 1] : null
  const delta = current && prev ? Math.round((current.src.value - prev.src.value) * 10) / 10 : null
  const summary = `Gráfica de ${label}: ${points.length} registros, de ${format(data[0].value)} ${unit} a ${format(data[data.length - 1].value)} ${unit}.`
  const extra = current && detail ? detail(current.src) : null

  return (
    <div ref={wrapRef} className="relative">
      <svg
        width={width}
        height={HEIGHT}
        role="img"
        aria-label={summary}
        tabIndex={0}
        className={`touch-pan-y select-none rounded-lg outline-none focus-visible:ring-2 focus-visible:ring-primary/60 ${onSelect ? 'cursor-pointer' : ''}`}
        onPointerMove={(e) => setActive(nearest(e))}
        onPointerDown={(e) => setActive(nearest(e))}
        onClick={(e) => onSelect?.(points[nearest(e)].src)}
        onPointerLeave={() => setActive(null)}
        onKeyDown={onKeyDown}
        onBlur={() => setActive(null)}
      >
        {/* Cuadrícula y eje Y: hairline sólido, recesivo */}
        {ticks.map((t) => (
          <g key={t}>
            <line x1={left} x2={width - MARGIN.right} y1={sy(t)} y2={sy(t)} stroke="var(--border)" strokeWidth={1} />
            <text x={left - 8} y={sy(t)} textAnchor="end" dominantBaseline="middle" fontSize={10} fill="var(--faint)" className="tabular-nums">
              {axisFormat(t)}
            </text>
          </g>
        ))}
        {xTicks.map((t, i) => (
          <text key={i} x={t.x} y={HEIGHT - 8} textAnchor={i === 0 ? 'start' : i === xTicks.length - 1 ? 'end' : 'middle'} fontSize={10} fill="var(--faint)">
            {t.label}
          </text>
        ))}

        {/* Referencia (meta): línea en tinta neutra, con su etiqueta */}
        {reference && (
          <g>
            <line x1={left} x2={width - MARGIN.right} y1={sy(reference.value)} y2={sy(reference.value)} stroke="var(--muted)" strokeWidth={1} />
            <text x={width - MARGIN.right - 4} y={sy(reference.value) - 5} textAnchor="end" fontSize={10} fill="var(--muted)">
              {reference.label}
            </text>
          </g>
        )}

        {/* Cursor vertical que se ajusta al registro más cercano */}
        {current && <line x1={current.x} x2={current.x} y1={MARGIN.top} y2={HEIGHT - MARGIN.bottom} stroke="var(--border-strong)" strokeWidth={1} />}

        {/* La línea se dibuja de izquierda a derecha al aparecer */}
        {points.length > 1 && (
          <path
            key={`${points.length}-${data[0].date}`}
            d={path}
            pathLength={1}
            fill="none"
            stroke="var(--chart-line)"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeDasharray={1}
            className="animate-draw"
          />
        )}

        {points.map((p, i) => {
          const isLast = i === points.length - 1
          if (!marked && !isLast && i !== active) return null
          return (
            <circle
              key={i}
              cx={p.x}
              cy={p.y}
              r={i === active ? 6 : 4.5}
              fill="var(--chart-line)"
              stroke="var(--surface)"
              strokeWidth={2}
              className="animate-pop"
              style={{ transformBox: 'fill-box', transformOrigin: 'center', animationDelay: `${Math.min(i, 12) * 40 + 500}ms` }}
            />
          )
        })}

        {/* Etiqueta directa solo en el último registro */}
        {last && active === null && (
          <text
            x={last.x}
            y={last.y - 12}
            textAnchor={last.x > width - 60 ? 'end' : 'middle'}
            fontSize={12}
            fontWeight={600}
            fill="var(--fg-strong)"
            className="tabular-nums"
          >
            {format(last.src.value)} {unit}
          </text>
        )}
      </svg>

      {current && (
        <div
          className="card pointer-events-none absolute z-10 min-w-28 -translate-x-1/2 px-2.5 py-1.5 text-xs shadow-lg shadow-black/30"
          style={{ left: Math.min(Math.max(current.x, 64), width - 64), top: 0 }}
          role="status"
        >
          <p className="text-[11px] capitalize text-muted">{longDateFmt.format(fromDateKey(current.src.date))}</p>
          <p className="flex items-center gap-1.5">
            <span className="h-0.5 w-3 rounded-full bg-chart-line" aria-hidden />
            <span className="text-sm font-semibold tabular-nums text-fg-strong">
              {format(current.src.value)} {unit}
            </span>
          </p>
          {extra && <p className="text-[11px] tabular-nums text-muted">{extra}</p>}
          {delta !== null && delta !== 0 && (
            <p className="text-[11px] tabular-nums text-muted">
              {delta > 0 ? '+' : '−'}
              {format(Math.abs(delta))} {unit} {compareLabel}
            </p>
          )}
        </div>
      )}
    </div>
  )
}
