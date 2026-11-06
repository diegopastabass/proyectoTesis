import { useEffect, useMemo, useRef, useState } from 'react'
import { todayKey } from '../../core/date'
import { countByDate, heatmapWeeks } from '../../core/strength/calendar'
import { formatLongDate } from './format'

const CELL = 13
const GAP = 3
const STEP = CELL + GAP
const LABEL_W = 16
const TOP = 14
const DAY_LABELS = ['L', '', 'X', '', 'V', '', 'D']
const month = new Intl.DateTimeFormat('es-CL', { month: 'short' })

/** Mapa de calor tipo calendario: una columna por semana (lunes a domingo). */
export function Heatmap({ dates, onSelectDay }: { dates: string[]; onSelectDay?: (date: string) => void }) {
  const wrapRef = useRef<HTMLDivElement>(null)
  const [width, setWidth] = useState(300)

  useEffect(() => {
    const el = wrapRef.current
    if (!el) return
    const observer = new ResizeObserver(([e]) => setWidth(Math.floor(e.contentRect.width)))
    observer.observe(el)
    return () => observer.disconnect()
  }, [])

  const today = todayKey()
  const weeks = Math.max(8, Math.min(53, Math.floor((width - LABEL_W) / STEP)))
  const grid = useMemo(() => heatmapWeeks(countByDate(dates), today, weeks), [dates, today, weeks])
  const trained = grid.flat().filter((d) => d.count > 0).length

  return (
    <div ref={wrapRef} className="w-full">
      <svg width={LABEL_W + weeks * STEP} height={TOP + 7 * STEP} role="img" aria-label={`Calendario de las últimas ${weeks} semanas: ${trained} días con entrenamiento.`}>
        {grid.map((week, w) => {
          const first = week[0].date
          const prev = grid[w - 1]?.[0].date
          const showMonth = w === 0 ? false : first.slice(5, 7) !== prev?.slice(5, 7)
          return (
            <g key={first} transform={`translate(${LABEL_W + w * STEP},0)`}>
              {showMonth && (
                <text x={0} y={10} fontSize={10} fill="var(--faint)">
                  {month.format(new Date(`${first}T12:00:00`)).replace('.', '')}
                </text>
              )}
              {week.map((day, d) => {
                const isToday = day.date === today
                const fill = day.future ? 'transparent' : day.count === 0 ? 'var(--bg-hard)' : 'var(--primary)'
                const opacity = day.count === 1 ? 0.6 : 1
                const label = `${formatLongDate(day.date)}: ${day.count === 0 ? 'sin entrenamiento' : `${day.count} ${day.count === 1 ? 'entrenamiento' : 'entrenamientos'}`}`
                return (
                  <rect
                    key={day.date}
                    y={TOP + d * STEP}
                    width={CELL}
                    height={CELL}
                    rx={3}
                    fill={fill}
                    fillOpacity={day.count > 0 ? opacity : 1}
                    stroke={isToday ? 'var(--fg)' : day.future ? 'var(--border)' : 'none'}
                    strokeWidth={isToday ? 1.5 : 1}
                    strokeDasharray={day.future && !isToday ? '2 2' : undefined}
                    className={`animate-fade-in ${day.count > 0 && onSelectDay ? 'cursor-pointer' : ''}`}
                    style={{ animationDelay: `${Math.min(w, 30) * 12}ms` }}
                    onClick={() => day.count > 0 && onSelectDay?.(day.date)}
                  >
                    <title>{label}</title>
                  </rect>
                )
              })}
            </g>
          )
        })}
        {DAY_LABELS.map((l, d) =>
          l ? (
            <text key={d} x={0} y={TOP + d * STEP + CELL - 3} fontSize={9} fill="var(--faint)">
              {l}
            </text>
          ) : null,
        )}
      </svg>
      <div className="mt-1.5 flex items-center justify-end gap-3 text-[10px] text-faint">
        <Legend fill="var(--bg-hard)" label="Sin entrenar" />
        <Legend fill="var(--primary)" opacity={0.6} label="1" />
        <Legend fill="var(--primary)" label="2 o más" />
      </div>
    </div>
  )
}

function Legend({ fill, opacity = 1, label }: { fill: string; opacity?: number; label: string }) {
  return (
    <span className="flex items-center gap-1">
      <svg width={10} height={10} aria-hidden>
        <rect width={10} height={10} rx={2} fill={fill} fillOpacity={opacity} />
      </svg>
      {label}
    </span>
  )
}
