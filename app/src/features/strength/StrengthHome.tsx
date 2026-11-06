import { ChevronRight, Dumbbell, Flame, ListPlus, Pencil, Play, Plus, Timer } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { addDays, todayKey } from '../../core/date'
import { weekStart, weeklyStreak } from '../../core/strength/calendar'
import { emptyWorkout, workoutFromRoutine } from '../../core/strength/session'
import { workoutTotals } from '../../core/strength/stats'
import type { Routine } from '../../core/strength/types'
import { EmptyState } from '../../ui/EmptyState'
import { IconButton } from '../../ui/IconButton'
import { stagger } from '../../ui/motion'
import { formatShortDate, formatVolume, relativeDay, useElapsed } from './format'
import { useStrength } from './StrengthProvider'

const WEEK_DAYS = ['L', 'M', 'X', 'J', 'V', 'S', 'D']

export function StrengthHome() {
  const navigate = useNavigate()
  const { routines, workouts, ready, active, setActive, nameOf } = useStrength()
  const elapsed = useElapsed(active?.startedAt ?? null)

  function start(routine?: Routine) {
    if (active && !confirm('Ya tienes un entrenamiento en curso. ¿Descartarlo y empezar otro?')) return
    setActive(routine ? workoutFromRoutine(routine, Date.now()) : emptyWorkout(Date.now()))
    navigate('/fuerza/entrenar')
  }

  const today = todayKey()
  const monday = weekStart(today)
  const trainedDays = new Set(workouts.map((w) => w.date))
  const streak = weeklyStreak([...trainedDays], today)
  const lastByRoutine = new Map<string, string>()
  for (const w of workouts) if (w.routineId && !lastByRoutine.has(w.routineId)) lastByRoutine.set(w.routineId, w.date)

  return (
    <div className="flex flex-col gap-4">
      {active && (
        <Link to="/fuerza/entrenar" className="card flex animate-scale-in items-center gap-3 border-primary/50 p-3 hover:bg-surface-2">
          <span className="flex size-10 shrink-0 items-center justify-center rounded-xl gradient-primary text-on-primary">
            <Timer className="size-5 animate-pulse" strokeWidth={2.25} aria-hidden />
          </span>
          <span className="min-w-0 flex-1">
            <span className="block text-xs text-muted">Entrenamiento en curso</span>
            <span className="block truncate text-sm font-semibold text-fg-strong">
              {active.name} · <span className="tabular-nums">{elapsed}</span>
            </span>
          </span>
          <ChevronRight className="size-4 text-faint" aria-hidden />
        </Link>
      )}

      <section className="card flex flex-col gap-3 p-3" aria-label="Esta semana">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-semibold text-fg-strong">Esta semana</h2>
          {streak > 0 && (
            <span className="flex items-center gap-1 text-xs font-medium text-warning" title="Semanas seguidas con al menos un entrenamiento">
              <Flame className="size-3.5" aria-hidden /> {streak} {streak === 1 ? 'semana' : 'semanas'} seguidas
            </span>
          )}
        </div>
        <ol className="grid grid-cols-7 gap-1.5">
          {WEEK_DAYS.map((label, i) => {
            const date = addDays(monday, i)
            const done = trainedDays.has(date)
            const isToday = date === today
            return (
              <li key={date} className="flex flex-col items-center gap-1" style={stagger(i, 40)}>
                <span className={`text-[10px] font-medium ${isToday ? 'text-primary' : 'text-faint'}`}>{label}</span>
                <span
                  className={`flex size-8 animate-pop items-center justify-center rounded-full text-xs tabular-nums ${
                    done ? 'gradient-primary font-semibold text-on-primary' : date > today ? 'border border-dashed border-border text-faint' : 'bg-bg-hard text-muted'
                  } ${isToday && !done ? 'ring-1 ring-primary' : ''}`}
                  title={done ? 'Entrenaste' : undefined}
                >
                  {done ? <Dumbbell className="size-3.5" strokeWidth={2.5} aria-label="Entrenaste" /> : Number(date.slice(8))}
                </span>
              </li>
            )
          })}
        </ol>
      </section>

      <div className="flex items-center justify-between gap-2">
        <h2 className="text-sm font-semibold text-fg-strong">Rutinas</h2>
        <div className="flex gap-1.5">
          <IconButton icon={Play} label="Empezar entrenamiento libre (sin rutina)" text="Libre" variant="soft" onClick={() => start()} />
          <IconButton icon={Plus} label="Nueva rutina" variant="primary" size="md" onClick={() => navigate('/fuerza/rutinas/nueva')} />
        </div>
      </div>

      {!ready && <p className="py-6 text-center text-xs text-muted">Cargando…</p>}

      {ready && routines.length === 0 && (
        <div className="card">
          <EmptyState icon={ListPlus} title="Crea tu primera rutina">
            Por ejemplo "Rutina de pecho": eliges los ejercicios y sus series una vez y después solo la empiezas y la rellenas.
          </EmptyState>
        </div>
      )}

      {routines.length > 0 && (
        <ul className="flex flex-col gap-2">
          {routines.map((r, i) => {
            const last = lastByRoutine.get(r.id)
            const names = r.exercises.map((e) => nameOf(e.exerciseId))
            return (
              <li key={r.id} className="card flex animate-fade-up items-center gap-3 p-3" style={stagger(i, 50)}>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold text-fg-strong">{r.name}</p>
                  <p className="truncate text-xs text-muted">
                    {names.slice(0, 3).join(', ')}
                    {names.length > 3 && ` y ${names.length - 3} más`}
                  </p>
                  <p className="text-[11px] text-faint">
                    {r.exercises.length} ejercicios · {r.exercises.reduce((n, e) => n + e.sets.length, 0)} series
                    {last ? ` · última vez ${relativeDay(last)}` : ' · aún no la haces'}
                  </p>
                </div>
                <IconButton icon={Pencil} label={`Editar ${r.name}`} onClick={() => navigate(`/fuerza/rutinas/${r.id}`)} />
                <IconButton icon={Play} label={`Empezar ${r.name}`} variant="primary" size="md" onClick={() => start(r)} />
              </li>
            )
          })}
        </ul>
      )}

      {workouts.length > 0 && (
        <section className="flex flex-col gap-2" aria-label="Últimos entrenamientos">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-semibold text-fg-strong">Últimos entrenamientos</h2>
            <Link to="/fuerza/historial" className="text-xs font-medium text-primary hover:underline">
              Ver todo
            </Link>
          </div>
          <ul className="card divide-y divide-border overflow-hidden">
            {workouts.slice(0, 3).map((w) => {
              const t = workoutTotals(w)
              return (
                <li key={w.id}>
                  <Link to={`/fuerza/historial/${w.id}`} className="flex items-center gap-3 px-3 py-2.5 hover:bg-surface-2">
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm text-fg">{w.name}</p>
                      <p className="text-xs text-faint tabular-nums">
                        {formatShortDate(w.date)} · {t.sets} series · {formatVolume(t.volume)}
                      </p>
                    </div>
                    <ChevronRight className="size-4 text-faint" aria-hidden />
                  </Link>
                </li>
              )
            })}
          </ul>
        </section>
      )}
    </div>
  )
}
