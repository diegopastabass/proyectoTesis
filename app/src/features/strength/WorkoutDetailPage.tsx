import {
  ArrowLeft,
  Award,
  CalendarCheck,
  Check,
  Dumbbell,
  Flame,
  Layers,
  ListRestart,
  Repeat,
  Sparkles,
  Timer,
  Trash2,
  TrendingUp,
  Trophy,
  Weight,
  type LucideIcon,
} from 'lucide-react'
import { useMemo, useState, type ReactNode } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { useUser } from '../../app/AuthProvider'
import { useToast } from '../../app/ToastProvider'
import { workoutInsights, type InsightKind } from '../../core/strength/insights'
import { routineExercisesFrom } from '../../core/strength/session'
import { estimate1RM, workoutTotals, workoutVolume } from '../../core/strength/stats'
import type { Workout } from '../../core/strength/types'
import { deleteWorkout, saveRoutine } from '../../services/strength'
import { IconButton } from '../../ui/IconButton'
import { stagger, useCountUp } from '../../ui/motion'
import { ExerciseThumb } from './ExerciseImage'
import { formatDuration, formatKg, formatLongDate, formatSet, formatVolume, SET_META, setLabels } from './format'
import { useStrength } from './StrengthProvider'

const INSIGHT_ICON: Record<InsightKind, LucideIcon> = {
  first: Sparkles,
  record: Trophy,
  weight: TrendingUp,
  reps: Repeat,
  sets: Layers,
  volume: Weight,
  streak: Flame,
  week: CalendarCheck,
  milestone: Award,
  new: Sparkles,
}

export function WorkoutDetailPage() {
  const { id } = useParams()
  const { workouts, ready } = useStrength()
  if (!ready) return <p className="py-6 text-center text-xs text-muted">Cargando…</p>
  const workout = workouts.find((w) => w.id === id)
  if (!workout) return <p className="py-6 text-center text-xs text-muted">Entrenamiento no encontrado.</p>
  return <WorkoutDetail key={workout.id} workout={workout} />
}

function WorkoutDetail({ workout }: { workout: Workout }) {
  const user = useUser()
  const toast = useToast()
  const navigate = useNavigate()
  const [params] = useSearchParams()
  const isNew = params.get('nuevo') === '1'
  const { workouts, routines, exerciseById, nameOf } = useStrength()
  const [routineUpdated, setRoutineUpdated] = useState(false)

  const totals = workoutTotals(workout)
  const insights = useMemo(() => workoutInsights(workout, workouts), [workout, workouts])
  const shownVolume = useCountUp(totals.volume, 1200)

  // Misma rutina (o mismo nombre si fue libre), la vez anterior.
  const previous = workouts
    .filter((w) => w.startedAt < workout.startedAt && (workout.routineId ? w.routineId === workout.routineId : w.name === workout.name))
    .sort((a, b) => b.startedAt - a.startedAt)[0]
  const prevVolume = previous ? workoutVolume(previous) : null
  const delta = prevVolume ? Math.round((totals.volume / prevVolume - 1) * 100) : null

  const routine = workout.routineId ? routines.find((r) => r.id === workout.routineId) : undefined

  async function updateRoutine() {
    if (!routine) return
    try {
      await saveRoutine(user.uid, { name: routine.name, exercises: routineExercisesFrom(workout) }, routine.id)
      setRoutineUpdated(true)
      toast('Rutina actualizada con esta sesión')
    } catch (err) {
      toast((err as Error).message, 'error')
    }
  }

  async function remove() {
    if (!confirm('¿Eliminar este entrenamiento del historial?')) return
    try {
      await deleteWorkout(user.uid, workout.id)
      toast('Entrenamiento eliminado')
      navigate('/fuerza/historial', { replace: true })
    } catch (err) {
      toast((err as Error).message, 'error')
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center gap-1.5">
        <IconButton icon={ArrowLeft} label="Volver" onClick={() => navigate(isNew ? '/fuerza' : '/fuerza/historial')} />
        <div className="min-w-0 flex-1">
          <h1 className="truncate text-sm font-semibold text-fg-strong">{workout.name}</h1>
          <p className="text-xs text-muted first-letter:uppercase">{formatLongDate(workout.date)}</p>
        </div>
        <IconButton icon={Trash2} label="Eliminar entrenamiento" variant="danger" onClick={remove} />
      </div>

      {isNew && (
        <div className="flex animate-scale-in flex-col items-center gap-1 py-2 text-center">
          <span className="flex size-12 animate-pop items-center justify-center rounded-2xl gradient-primary text-on-primary shadow-sm shadow-black/20">
            <Check className="size-6" strokeWidth={3} aria-hidden />
          </span>
          <p className="text-base font-semibold text-fg-strong">¡Entrenamiento terminado!</p>
        </div>
      )}

      <section className="card p-4 text-center" aria-label="Volumen total">
        <p className="text-xs text-muted">Peso total levantado</p>
        <p className="text-3xl font-bold tabular-nums text-fg-strong">{formatVolume(shownVolume)}</p>
        {delta !== null && previous && (
          <p className={`mt-0.5 text-xs tabular-nums ${delta > 0 ? 'text-success' : 'text-muted'}`}>
            {delta > 0 ? '+' : delta < 0 ? '−' : ''}
            {Math.abs(delta)} % vs. {formatVolume(prevVolume!)} la vez anterior ({formatLongDate(previous.date)})
          </p>
        )}
        <p className="mt-1 text-[11px] text-faint">Suma de kg × repeticiones de las series efectivas (sin calentamiento).</p>
      </section>

      <div className="grid grid-cols-3 gap-2">
        <Tile icon={Layers} label="Series" index={0}>
          {totals.sets}
        </Tile>
        <Tile icon={Repeat} label="Repeticiones" index={1}>
          {totals.reps}
        </Tile>
        <Tile icon={Timer} label="Duración" index={2}>
          {formatDuration(totals.durationMin)}
        </Tile>
      </div>

      {insights.length > 0 && (
        <section className="card overflow-hidden" aria-label="Tus avances">
          <h2 className="border-b border-border bg-surface-2/50 px-3 py-2 text-xs font-medium text-muted">Tus avances</h2>
          <ul className="divide-y divide-border">
            {insights.map((ins, i) => {
              const Icon = INSIGHT_ICON[ins.kind]
              const tone = ins.kind === 'record' || ins.kind === 'milestone' ? 'bg-warning/15 text-warning' : 'bg-primary-soft text-primary'
              return (
                <li key={i} className="flex animate-fade-up items-start gap-3 px-3 py-2.5" style={stagger(i, 90)}>
                  <span className={`flex size-7 shrink-0 animate-pop items-center justify-center rounded-lg ${tone}`} style={stagger(i, 90)}>
                    <Icon className="size-4" strokeWidth={2.25} aria-hidden />
                  </span>
                  <p className="pt-1 text-sm leading-snug text-fg">{ins.text}</p>
                </li>
              )
            })}
          </ul>
        </section>
      )}

      {routine && (
        <div className="flex items-center justify-between gap-2 rounded-lg border border-border px-3 py-2">
          <p className="text-xs text-muted">¿Usar lo de hoy como plantilla de «{routine.name}»?</p>
          <IconButton
            icon={routineUpdated ? Check : ListRestart}
            label="Actualizar la rutina con los ejercicios, series y pesos de hoy"
            text={routineUpdated ? 'Listo' : 'Actualizar'}
            variant="soft"
            disabled={routineUpdated}
            onClick={updateRoutine}
          />
        </div>
      )}

      <section className="flex flex-col gap-2" aria-label="Ejercicios">
        {workout.exercises.map((e, i) => {
          const labels = setLabels(e.sets.map((s) => s.type))
          const best = Math.max(0, ...e.sets.filter((s) => s.type !== 'warmup').map((s) => estimate1RM(s.kg ?? 0, s.reps ?? 0)))
          return (
            <article key={i} className="card animate-fade-up overflow-hidden" style={stagger(i, 50)}>
              <Link to={`/fuerza/ejercicios/${encodeURIComponent(e.exerciseId)}`} className="flex items-center gap-2.5 px-3 py-2 hover:bg-surface-2">
                <ExerciseThumb exercise={exerciseById.get(e.exerciseId)} className="size-8" />
                <span className="min-w-0 flex-1 truncate text-sm font-semibold text-primary">{nameOf(e.exerciseId, e.name)}</span>
                {best > 0 && <span className="text-[11px] tabular-nums text-faint">1RM est. {formatKg(Math.round(best * 10) / 10)} kg</span>}
              </Link>
              <ol className="px-3 pb-2">
                {e.sets.map((s, j) => (
                  <li key={j} className="flex items-center gap-3 py-0.5 text-sm tabular-nums">
                    <span className={`w-5 text-center text-xs font-bold ${SET_META[s.type].className}`} title={SET_META[s.type].label}>
                      {labels[j]}
                    </span>
                    <span className="text-fg">{formatSet(s)}</span>
                  </li>
                ))}
              </ol>
            </article>
          )
        })}
      </section>

      {isNew && (
        <IconButton icon={Dumbbell} label="Volver al inicio de fuerza" text="Listo" variant="primary" size="md" className="w-full" onClick={() => navigate('/fuerza', { replace: true })} />
      )}
    </div>
  )
}

function Tile({ icon: Icon, label, index, children }: { icon: LucideIcon; label: string; index: number; children: ReactNode }) {
  return (
    <div className="card animate-fade-up px-3 py-2" style={stagger(index, 60)}>
      <p className="flex items-center gap-1 text-[11px] text-muted">
        <Icon className="size-3.5" aria-hidden /> {label}
      </p>
      <p className="text-lg font-bold tabular-nums text-fg-strong">{children}</p>
    </div>
  )
}
