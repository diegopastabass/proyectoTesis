import { ArrowLeft, BookOpen, ChevronRight, Dumbbell, LoaderCircle, Repeat, Trophy, Weight, type LucideIcon } from 'lucide-react'
import { useMemo, useState, type ReactNode } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { exerciseSourceUrl } from '../../core/strength/catalog'
import { exerciseHistory, type ExerciseSession } from '../../core/strength/stats'
import type { Exercise } from '../../core/strength/types'
import { IconButton } from '../../ui/IconButton'
import { stagger } from '../../ui/motion'
import { TrendChart } from '../../ui/TrendChart'
import { MuscleChips } from './ExerciseBlock'
import { ExerciseAnimation } from './ExerciseImage'
import { compactNumber, formatKg, formatLongDate, formatSet, formatVolume } from './format'
import { useStrength } from './StrengthProvider'

type Metric = 'e1rm' | 'maxKg' | 'volume' | 'reps'

const METRICS: { id: Metric; label: string; unit: string; hint: string; value: (s: ExerciseSession) => number }[] = [
  { id: 'e1rm', label: '1RM est.', unit: 'kg', hint: 'Fuerza máxima estimada de tu mejor serie (fórmula de Epley)', value: (s) => Math.round(s.best1RM * 10) / 10 },
  { id: 'maxKg', label: 'Peso máx.', unit: 'kg', hint: 'Mayor peso de la sesión', value: (s) => s.maxKg },
  { id: 'volume', label: 'Volumen', unit: 'kg', hint: 'kg × repeticiones de las series efectivas', value: (s) => s.volume },
  { id: 'reps', label: 'Reps máx.', unit: 'reps', hint: 'Más repeticiones en una serie', value: (s) => s.maxReps },
]

export function ExerciseDetailPage() {
  const { id = '' } = useParams()
  const { exerciseById, workouts, ready } = useStrength()
  if (!ready) return <p className="py-6 text-center text-xs text-muted">Cargando…</p>
  const exercise = exerciseById.get(id)
  const fallbackName = workouts.flatMap((w) => w.exercises).find((e) => e.exerciseId === id)?.name
  if (!exercise && !fallbackName) return <p className="py-6 text-center text-xs text-muted">Ejercicio no encontrado.</p>
  return <ExerciseDetail key={id} id={id} exercise={exercise} name={exercise?.name ?? fallbackName!} />
}

function ExerciseDetail({ id, exercise, name }: { id: string; exercise: Exercise | undefined; name: string }) {
  const navigate = useNavigate()
  const { workouts } = useStrength()
  const history = useMemo(() => exerciseHistory(workouts, id), [workouts, id])
  const weighted = history.some((h) => h.maxKg > 0)
  const [metric, setMetric] = useState<Metric>(weighted ? 'e1rm' : 'reps')
  const current = METRICS.find((m) => m.id === metric)!
  const points = useMemo(() => history.map((h) => ({ date: h.date, value: current.value(h), session: h })), [history, current])

  const bestKg = history.reduce<ExerciseSession | null>((b, h) => (!b || h.maxKg > b.maxKg || (h.maxKg === b.maxKg && h.repsAtMax > b.repsAtMax) ? h : b), null)
  const best1RM = Math.max(0, ...history.map((h) => h.best1RM))
  const bestReps = Math.max(0, ...history.map((h) => h.maxReps))
  const bestVolume = Math.max(0, ...history.map((h) => h.volume))

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center gap-1.5">
        <IconButton icon={ArrowLeft} label="Volver" onClick={() => navigate(-1)} />
        <h1 className="min-w-0 flex-1 truncate text-sm font-semibold text-fg-strong">{name}</h1>
      </div>

      {exercise && (
        <section className="flex flex-col gap-2">
          {!exercise.custom && <ExerciseAnimation exercise={exercise} />}
          <MuscleChips exercise={exercise} />
          {!exercise.custom && <Instructions id={exercise.id} />}
        </section>
      )}

      {history.length === 0 ? (
        <div className="card p-4 text-center text-xs text-muted">
          <Dumbbell className="mx-auto mb-1 size-5 text-primary" aria-hidden />
          Aún no registras este ejercicio. Agrégalo a una rutina o a un entrenamiento para ver tu progreso.
        </div>
      ) : (
        <>
          <div className="grid grid-cols-2 gap-2">
            {weighted && bestKg && (
              <Tile icon={Trophy} label="Mejor serie" index={0}>
                {formatSet({ kg: bestKg.maxKg, reps: bestKg.repsAtMax })}
              </Tile>
            )}
            {weighted && (
              <Tile icon={Weight} label="1RM estimado" index={1}>
                {formatKg(Math.round(best1RM * 10) / 10)} kg
              </Tile>
            )}
            <Tile icon={Repeat} label="Más repeticiones" index={2}>
              {bestReps}
            </Tile>
            {weighted && (
              <Tile icon={Weight} label="Mayor volumen" index={3}>
                {formatVolume(bestVolume)}
              </Tile>
            )}
          </div>

          <section className="card animate-fade-up p-3" aria-label="Curva de progreso">
            <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
              <h2 className="text-sm font-semibold text-fg-strong">Progreso</h2>
              <div className="flex gap-1" role="radiogroup" aria-label="Métrica">
                {METRICS.filter((m) => weighted || m.id === 'reps').map((m) => (
                  <button
                    key={m.id}
                    type="button"
                    role="radio"
                    aria-checked={metric === m.id}
                    title={m.hint}
                    onClick={() => setMetric(m.id)}
                    className={`rounded-lg px-2 py-1 text-xs font-medium transition active:scale-95 ${
                      metric === m.id ? 'bg-primary-soft text-primary' : 'text-muted hover:bg-surface-2 hover:text-fg'
                    }`}
                  >
                    {m.label}
                  </button>
                ))}
              </div>
            </div>
            <TrendChart
              key={metric}
              points={points}
              unit={current.unit}
              label={`${current.label} de ${name}`}
              format={metric === 'volume' ? (n) => Math.round(n).toLocaleString('es-CL') : formatKg}
              axisFormat={metric === 'volume' ? compactNumber : formatKg}
              minPad={metric === 'volume' ? 50 : metric === 'reps' ? 1 : 2.5}
              compareLabel="vs. sesión anterior"
              detail={(p) => `Mejor serie ${formatSet({ kg: p.session.maxKg, reps: p.session.repsAtMax })} · ${p.session.sets} series`}
              onSelect={(p) => navigate(`/fuerza/historial/${p.session.workoutId}`)}
            />
            {history.length === 1 && <p className="mt-1 text-center text-[11px] text-faint">Con una segunda sesión verás la curva.</p>}
            <p className="mt-1 text-[11px] text-faint">{current.hint}.</p>
          </section>

          <section className="card overflow-hidden" aria-label="Historial del ejercicio">
            <h2 className="border-b border-border bg-surface-2/50 px-3 py-2 text-xs font-medium text-muted">Historial</h2>
            <ul className="divide-y divide-border">
              {[...history].reverse().map((h, i) => (
                <li key={`${h.workoutId}-${i}`} className="animate-fade-up" style={stagger(i, 25)}>
                  <Link to={`/fuerza/historial/${h.workoutId}`} className="flex items-center gap-3 px-3 py-2 hover:bg-surface-2">
                    <span className="flex-1 text-sm text-muted first-letter:uppercase">{formatLongDate(h.date)}</span>
                    <span className="text-xs tabular-nums text-faint">{h.sets} series</span>
                    <span className="w-24 text-right text-sm font-semibold tabular-nums text-fg-strong">{formatSet({ kg: h.maxKg, reps: h.maxKg ? h.repsAtMax : h.maxReps })}</span>
                    <ChevronRight className="size-4 shrink-0 text-faint" aria-hidden />
                  </Link>
                </li>
              ))}
            </ul>
          </section>
        </>
      )}
    </div>
  )
}

/** Instrucciones del catálogo original (en inglés), pedidas solo si el usuario las quiere ver. */
function Instructions({ id }: { id: string }) {
  const [state, setState] = useState<{ status: 'idle' | 'loading' | 'error' } | { status: 'ok'; steps: string[] }>({ status: 'idle' })

  async function load() {
    setState({ status: 'loading' })
    try {
      const res = await fetch(exerciseSourceUrl(id))
      if (!res.ok) throw new Error(String(res.status))
      const data = (await res.json()) as { instructions?: string[] }
      setState({ status: 'ok', steps: data.instructions ?? [] })
    } catch {
      setState({ status: 'error' })
    }
  }

  if (state.status === 'ok') {
    return (
      <details open className="card p-3 text-sm">
        <summary className="cursor-pointer text-xs font-medium text-muted">Instrucciones (en inglés)</summary>
        <ol className="mt-2 list-decimal space-y-1 pl-5 text-xs leading-relaxed text-fg" lang="en">
          {state.steps.map((s, i) => (
            <li key={i}>{s}</li>
          ))}
        </ol>
      </details>
    )
  }
  return (
    <div className="flex items-center gap-2">
      <IconButton
        icon={state.status === 'loading' ? LoaderCircle : BookOpen}
        label="Ver instrucciones (en inglés)"
        text="Instrucciones"
        variant="soft"
        disabled={state.status === 'loading'}
        className={state.status === 'loading' ? '[&_svg]:animate-spin' : ''}
        onClick={load}
      />
      {state.status === 'error' && <span className="text-xs text-danger">No se pudieron cargar. Revisa tu conexión.</span>}
    </div>
  )
}

function Tile({ icon: Icon, label, index, children }: { icon: LucideIcon; label: string; index: number; children: ReactNode }) {
  return (
    <div className="card animate-fade-up px-3 py-2" style={stagger(index, 60)}>
      <p className="flex items-center gap-1 text-[11px] text-muted">
        <Icon className="size-3.5" aria-hidden /> {label}
      </p>
      <p className="text-base font-bold tabular-nums text-fg-strong">{children}</p>
    </div>
  )
}
