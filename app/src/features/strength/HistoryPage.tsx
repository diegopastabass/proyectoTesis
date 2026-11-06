import { ChevronRight, History } from 'lucide-react'
import { Link } from 'react-router-dom'
import { fromDateKey } from '../../core/date'
import { workoutTotals } from '../../core/strength/stats'
import { EmptyState } from '../../ui/EmptyState'
import { stagger } from '../../ui/motion'
import { formatDuration, formatVolume } from './format'
import { useStrength } from './StrengthProvider'

const monthFmt = new Intl.DateTimeFormat('es-CL', { month: 'long', year: 'numeric' })
const dayFmt = new Intl.DateTimeFormat('es-CL', { weekday: 'short', day: 'numeric' })

export function HistoryPage() {
  const { workouts, ready } = useStrength()

  const months = new Map<string, typeof workouts>()
  for (const w of workouts) {
    const key = w.date.slice(0, 7)
    months.set(key, [...(months.get(key) ?? []), w])
  }

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-sm font-semibold text-fg-strong">Historial</h1>

      {!ready && <p className="py-6 text-center text-xs text-muted">Cargando…</p>}
      {ready && workouts.length === 0 && (
        <div className="card">
          <EmptyState icon={History} title="Aún no terminas ningún entrenamiento">
            Cuando termines uno, aparecerá aquí con su volumen total y tus avances.
          </EmptyState>
        </div>
      )}

      {[...months].map(([month, list], m) => (
        <section key={month} className="flex flex-col gap-1.5" aria-label={month}>
          <h2 className="px-1 text-xs font-medium capitalize text-muted">
            {monthFmt.format(fromDateKey(`${month}-01`))} · {list.length} {list.length === 1 ? 'entrenamiento' : 'entrenamientos'}
          </h2>
          <ul className="card divide-y divide-border overflow-hidden">
            {list.map((w, i) => {
              const t = workoutTotals(w)
              return (
                <li key={w.id} className="animate-fade-up" style={stagger(m * 4 + i, 30)}>
                  <Link to={`/fuerza/historial/${w.id}`} className="flex items-center gap-3 px-3 py-2.5 hover:bg-surface-2">
                    <span className="w-12 shrink-0 text-xs capitalize text-muted">{dayFmt.format(fromDateKey(w.date))}</span>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm text-fg">{w.name}</p>
                      <p className="text-xs text-faint tabular-nums">
                        {t.exercises} ejercicios · {t.sets} series · {formatDuration(t.durationMin)}
                      </p>
                    </div>
                    <span className="text-sm font-semibold tabular-nums text-fg-strong">{formatVolume(t.volume)}</span>
                    <ChevronRight className="size-4 shrink-0 text-faint" aria-hidden />
                  </Link>
                </li>
              )
            })}
          </ul>
        </section>
      ))}
    </div>
  )
}
