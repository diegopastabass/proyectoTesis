import type { MacroKey, Range } from '../core/types'
import { MACRO_META } from './meta'

interface Props {
  macro: MacroKey
  value: number
  range: Range
  score: number
}

/** Barra con la zona objetivo marcada y el consumo actual. */
export function MacroBar({ macro, value, range, score }: Props) {
  const meta = MACRO_META[macro]
  const scale = Math.max(range.max * 1.25, value, 1)
  const pct = (n: number) => `${Math.min(100, (n / scale) * 100)}%`
  const inRange = value >= range.min && value <= range.max
  const fmt = (n: number) => (macro === 'kcal' ? Math.round(n) : Math.round(n * 10) / 10)

  return (
    <div>
      <div className="mb-1 flex items-baseline justify-between gap-2 text-xs">
        <span className="flex min-w-0 items-center gap-1.5">
          <span className={`size-2 rounded-full ${meta.bg}`} aria-hidden />
          <span className="truncate text-muted">{meta.label}</span>
        </span>
        <span className="shrink-0 whitespace-nowrap tabular-nums">
          <span className={`font-semibold ${inRange ? 'text-fg-strong' : meta.text}`}>{fmt(value)}</span>
          <span className="text-faint">
            {' '}/ {range.min}–{range.max} {meta.unit}
          </span>
          <span className="ml-2 hidden text-faint sm:inline" title="Puntaje del macro">
            {Math.round(score)}
          </span>
        </span>
      </div>
      <div className="relative h-2 overflow-hidden rounded-full bg-bg-hard" role="meter" aria-label={meta.label} aria-valuenow={value} aria-valuemin={0} aria-valuemax={scale}>
        <div
          className="absolute inset-y-0 animate-fade-in rounded-full bg-primary-soft ring-1 ring-primary/40"
          style={{ left: pct(range.min), width: `calc(${pct(range.max)} - ${pct(range.min)})` }}
        />
        <div className={`absolute inset-y-0 left-0 origin-left animate-grow-x rounded-full transition-[width] duration-500 ease-out ${meta.bg}`} style={{ width: pct(value) }} />
      </div>
    </div>
  )
}
