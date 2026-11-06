import { CalendarDays, ChartLine, ChevronRight, Dumbbell, Flame, Hash, type LucideIcon } from 'lucide-react'
import { useMemo, useState, type ReactNode } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { todayKey } from '../../core/date'
import { trainedDaysBetween, weeklyStreak } from '../../core/strength/calendar'
import { exerciseFrequency, exerciseHistory, sortWorkouts, workoutTotals } from '../../core/strength/stats'
import type { Workout } from '../../core/strength/types'
import { EmptyState } from '../../ui/EmptyState'
import { stagger } from '../../ui/motion'
import { TrendChart } from '../../ui/TrendChart'
import { ExerciseThumb } from './ExerciseImage'
import { compactNumber, formatKg, formatSet } from './format'
import { Heatmap } from './Heatmap'
import { useStrength } from './StrengthProvider'

interface VolumePoint {
  date: string
  value: number
  workout: Workout
}

/** Rutina de cada sesión: su id o, si fue libre, su nombre. */
const groupKey = (w: Workout) => w.routineId ?? `nombre:${w.name}`

export function StrengthProgressPage() {
  const navigate = useNavigate()
  const { workouts, ready, exerciseById, nameOf } = useStrength()
  const today = todayKey()
  const dates = useMemo(() => workouts.map((w) => w.date), [workouts])

  // Grupos para la curva de volumen, del más frecuente al menos frecuente.
  const groups = useMemo(() => {
    const map = new Map<string, { key: string; name: string; count: number }>()
    for (const w of sortWorkouts(workouts)) {
      const g = map.get(groupKey(w)) ?? { key: groupKey(w), name: w.name, count: 0 }
      g.count++
      g.name = w.name
      map.set(g.key, g)
    }
    return [...map.values()].sort((a, b) => b.count - a.count)
  }, [workouts])
  const [group, setGroup] = useState<string | null>(null)
  const selected = group ?? groups[0]?.key ?? 'todas'

  const volumePoints = useMemo<VolumePoint[]>(
    () =>
      sortWorkouts(workouts)
        .filter((w) => selected === 'todas' || groupKey(w) === selected)
        .map((w) => ({ date: w.date, value: workoutTotals(w).volume, workout: w })),
    [workouts, selected],
  )

  const frequent = useMemo(() => exerciseFrequency(workouts), [workouts])

  if (!ready) return <p className="py-6 text-center text-xs text-muted">Cargando…</p>
  if (workouts.length === 0) {
    return (
      <div className="card">
        <EmptyState icon={ChartLine} title="Tu progreso aparecerá aquí">
          Termina tu primer entrenamiento para ver el calendario, el volumen por sesión y la curva de cada ejercicio.
        </EmptyState>
      </div>
    )
  }

  const monthStart = `${today.slice(0, 7)}-01`

  return (
    <div className="flex flex-col gap-4">
      <div className="grid grid-cols-3 gap-2">
        <Tile icon={CalendarDays} label="Este mes" index={0} hint="Días con entrenamiento este mes">
          {trainedDaysBetween(dates, monthStart, today)} <span className="text-xs font-normal text-muted">días</span>
        </Tile>
        <Tile icon={Flame} label="Racha" index={1} hint="Semanas seguidas con al menos un entrenamiento">
          {weeklyStreak(dates, today)} <span className="text-xs font-normal text-muted">sem.</span>
        </Tile>
        <Tile icon={Hash} label="Total" index={2} hint="Entrenamientos registrados">
          {workouts.length}
        </Tile>
      </div>

      <section className="card animate-fade-up p-3" aria-label="Constancia">
        <h2 className="mb-2 text-sm font-semibold text-fg-strong">Constancia</h2>
        <Heatmap
          dates={dates}
          onSelectDay={(date) => {
            const w = workouts.find((x) => x.date === date)
            if (w) navigate(`/fuerza/historial/${w.id}`)
          }}
        />
      </section>

      <section className="card animate-fade-up p-3" aria-label="Peso total por sesión">
        <h2 className="text-sm font-semibold text-fg-strong">Peso total por sesión</h2>
        <p className="mb-2 text-[11px] text-faint">kg × repeticiones de las series efectivas. Compara sesiones de la misma rutina.</p>
        <div className="-mx-1 mb-2 flex gap-1 overflow-x-auto px-1 pb-1" role="radiogroup" aria-label="Rutina">
          {[...groups, { key: 'todas', name: 'Todas', count: workouts.length }].map((g) => (
            <button
              key={g.key}
              type="button"
              role="radio"
              aria-checked={selected === g.key}
              onClick={() => setGroup(g.key)}
              className={`shrink-0 rounded-full border px-2.5 py-0.5 text-xs font-medium transition active:scale-95 ${
                selected === g.key ? 'border-primary bg-primary-soft text-primary' : 'border-border text-muted hover:border-border-strong hover:text-fg'
              }`}
            >
              {g.name} <span className="text-faint">{g.count}</span>
            </button>
          ))}
        </div>
        {volumePoints.length > 0 ? (
          <TrendChart
            key={selected}
            points={volumePoints}
            unit="kg"
            label="peso total por sesión"
            format={(n) => Math.round(n).toLocaleString('es-CL')}
            axisFormat={compactNumber}
            minPad={50}
            compareLabel="vs. sesión anterior"
            detail={(p) => p.workout.name}
            onSelect={(p) => navigate(`/fuerza/historial/${p.workout.id}`)}
          />
        ) : (
          <p className="py-6 text-center text-xs text-muted">Sin sesiones.</p>
        )}
        {volumePoints.length === 1 && <p className="mt-1 text-center text-[11px] text-faint">Repite esta rutina para ver la curva.</p>}
      </section>

      <section className="card animate-fade-up overflow-hidden" aria-label="Progreso por ejercicio">
        <h2 className="border-b border-border bg-surface-2/50 px-3 py-2 text-xs font-medium text-muted">Progreso por ejercicio</h2>
        <ul className="divide-y divide-border">
          {frequent.map((f, i) => {
            const history = exerciseHistory(workouts, f.exerciseId)
            const best = history.reduce((b, h) => (h.maxKg > b.maxKg || (h.maxKg === b.maxKg && h.repsAtMax > b.repsAtMax) ? h : b), history[0])
            const first = history[0]
            const last = history.at(-1)!
            const gain = last.best1RM - first.best1RM
            return (
              <li key={f.exerciseId} className="animate-fade-up" style={stagger(i, 30)}>
                <Link to={`/fuerza/ejercicios/${encodeURIComponent(f.exerciseId)}`} className="flex items-center gap-3 px-3 py-2 hover:bg-surface-2">
                  <ExerciseThumb exercise={exerciseById.get(f.exerciseId)} className="size-9" />
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm text-fg">{nameOf(f.exerciseId, f.name)}</p>
                    <p className="text-xs text-faint tabular-nums">
                      {f.sessions} {f.sessions === 1 ? 'sesión' : 'sesiones'} · mejor {formatSet({ kg: best.maxKg, reps: best.repsAtMax })}
                    </p>
                  </div>
                  {history.length > 1 && gain !== 0 && (
                    <span className={`text-xs font-medium tabular-nums ${gain > 0 ? 'text-success' : 'text-faint'}`} title="Cambio del 1RM estimado desde la primera sesión">
                      {gain > 0 ? '+' : '−'}
                      {formatKg(Math.abs(Math.round(gain * 10) / 10))} kg
                    </span>
                  )}
                  <ChevronRight className="size-4 shrink-0 text-faint" aria-hidden />
                </Link>
              </li>
            )
          })}
        </ul>
        {frequent.length === 0 && (
          <p className="flex items-center justify-center gap-1.5 p-4 text-xs text-muted">
            <Dumbbell className="size-3.5" aria-hidden /> Sin ejercicios registrados.
          </p>
        )}
      </section>
    </div>
  )
}

function Tile({ icon: Icon, label, index, hint, children }: { icon: LucideIcon; label: string; index: number; hint: string; children: ReactNode }) {
  return (
    <div className="card animate-fade-up px-3 py-2" style={stagger(index, 60)} title={hint}>
      <p className="flex items-center gap-1 text-[11px] text-muted">
        <Icon className="size-3.5" aria-hidden /> {label}
      </p>
      <p className="text-lg font-bold tabular-nums text-fg-strong">{children}</p>
    </div>
  )
}
