import { Check, Dumbbell, Plus, Timer, Trash2, Weight } from 'lucide-react'
import { useMemo, useState } from 'react'
import { Navigate, useNavigate } from 'react-router-dom'
import { useUser } from '../../app/AuthProvider'
import { useToast } from '../../app/ToastProvider'
import {
  appendSet,
  doneSets,
  finishWorkout,
  newKey,
  parseAmount,
  pendingSets,
  previousFor,
  setsForNewExercise,
  suggestion,
  toggleDone,
  type ActiveWorkout,
  type DraftExercise,
} from '../../core/strength/session'
import { saveWorkout } from '../../services/strength'
import { EmptyState } from '../../ui/EmptyState'
import { IconButton } from '../../ui/IconButton'
import { ExerciseBlock } from './ExerciseBlock'
import { ExercisePicker } from './ExercisePicker'
import { formatVolume, useElapsed } from './format'
import { useStrength } from './StrengthProvider'

export function WorkoutPage() {
  const { active } = useStrength()
  // Solo se redirige si la pantalla se abrió sin sesión. Al terminar o descartar,
  // la sesión se limpia antes de que llegue la navegación (que va como transición).
  const [openedWithSession] = useState(active !== null)
  if (!active) return openedWithSession ? null : <Navigate to="/fuerza" replace />
  return <ActiveWorkoutView active={active} />
}

function ActiveWorkoutView({ active }: { active: ActiveWorkout }) {
  const user = useUser()
  const toast = useToast()
  const navigate = useNavigate()
  const { workouts, exerciseById, nameOf, setActive } = useStrength()
  const [picking, setPicking] = useState(false)
  const [saving, setSaving] = useState(false)
  const elapsed = useElapsed(active.startedAt)

  const previous = useMemo(() => new Map(active.exercises.map((e) => [e.key, previousFor(e, workouts, active.startedAt)])), [active, workouts])

  // Volumen de las series marcadas, sin calentamiento.
  const volume = active.exercises.reduce(
    (sum, e) => sum + e.sets.filter((s) => s.done && s.type !== 'warmup').reduce((v, s) => v + (parseAmount(s.kg) ?? 0) * (parseAmount(s.reps) ?? 0), 0),
    0,
  )
  const done = doneSets(active)

  const update = (fn: (w: ActiveWorkout) => ActiveWorkout) => setActive((w) => (w ? fn(w) : w))
  const updateExercise = (key: string, fn: (e: DraftExercise) => DraftExercise) =>
    update((w) => ({ ...w, exercises: w.exercises.map((e) => (e.key === key ? fn(e) : e)) }))

  function move(index: number, delta: -1 | 1) {
    update((w) => {
      const list = [...w.exercises]
      const [item] = list.splice(index, 1)
      list.splice(index + delta, 0, item)
      return { ...w, exercises: list }
    })
  }

  function toggle(exercise: DraftExercise, setIndex: number) {
    const set = exercise.sets[setIndex]
    const next = toggleDone(set, previous.get(exercise.key)?.[setIndex] ?? null)
    if (!next) {
      toast('Escribe las repeticiones de la serie', 'error')
      return
    }
    if (next.done && navigator.vibrate) navigator.vibrate(30)
    updateExercise(exercise.key, (e) => ({ ...e, sets: e.sets.map((s, i) => (i === setIndex ? next : s)) }))
  }

  async function finish() {
    if (done === 0) {
      toast('Marca al menos una serie como hecha (✓)', 'error')
      return
    }
    const pending = pendingSets(active)
    if (pending > 0 && !confirm(`Hay ${pending} ${pending === 1 ? 'serie sin marcar' : 'series sin marcar'}: no se guardará${pending === 1 ? '' : 'n'}. ¿Terminar igual?`)) return
    setSaving(true)
    try {
      const id = await saveWorkout(user.uid, finishWorkout(active, Date.now(), (exId) => nameOf(exId)))
      navigate(`/fuerza/historial/${id}?nuevo=1`, { replace: true })
      setActive(null)
    } catch (err) {
      toast((err as Error).message, 'error')
      setSaving(false)
    }
  }

  function discard() {
    if (!confirm('¿Descartar este entrenamiento? Se perderán las series registradas.')) return
    navigate('/fuerza', { replace: true })
    setActive(null)
  }

  return (
    <div className="flex flex-col gap-3">
      <section className="card flex flex-col gap-2 p-3" aria-label="Entrenamiento en curso">
        <div className="flex items-center gap-2">
          <input
            className="min-w-0 flex-1 truncate rounded-md bg-transparent px-1 text-base font-semibold text-fg-strong outline-none focus:bg-bg-hard"
            value={active.name}
            onChange={(e) => update((w) => ({ ...w, name: e.target.value }))}
            aria-label="Nombre del entrenamiento"
          />
          <IconButton icon={Trash2} label="Descartar entrenamiento" variant="danger" onClick={discard} />
          <IconButton icon={Check} label="Terminar entrenamiento" text="Terminar" variant="primary" size="md" disabled={saving} onClick={finish} />
        </div>
        <div className="flex flex-wrap items-center gap-x-4 gap-y-1 px-1 text-xs text-muted">
          <span className="flex items-center gap-1.5 tabular-nums" title="Duración">
            <Timer className="size-3.5 text-primary" aria-hidden /> {elapsed}
          </span>
          <span className="flex items-center gap-1.5 tabular-nums" title="Volumen de las series hechas (sin calentamiento)">
            <Weight className="size-3.5 text-primary" aria-hidden /> {formatVolume(volume)}
          </span>
          <span className="flex items-center gap-1.5 tabular-nums" title="Series hechas">
            <Check className="size-3.5 text-primary" aria-hidden /> {done} {done === 1 ? 'serie' : 'series'}
          </span>
        </div>
      </section>

      {active.exercises.length === 0 && (
        <div className="card">
          <EmptyState icon={Dumbbell} title="Agrega tu primer ejercicio">
            Busca en el catálogo de más de 700 ejercicios o crea uno propio.
          </EmptyState>
        </div>
      )}

      {active.exercises.map((ex, i) => {
        const prev = previous.get(ex.key) ?? []
        return (
          <ExerciseBlock
            key={ex.key}
            index={i}
            total={active.exercises.length}
            exercise={exerciseById.get(ex.exerciseId)}
            name={nameOf(ex.exerciseId)}
            previous={prev}
            rows={ex.sets.map((s, j) => {
              const h = suggestion(s, prev[j] ?? null)
              return { ...s, hintKg: h.kg, hintReps: h.reps }
            })}
            onChange={(j, patch) => updateExercise(ex.key, (e) => ({ ...e, sets: e.sets.map((s, k) => (k === j ? { ...s, ...patch } : s)) }))}
            onRemoveSet={(j) => updateExercise(ex.key, (e) => ({ ...e, sets: e.sets.filter((_, k) => k !== j) }))}
            onAddSet={() => updateExercise(ex.key, (e) => ({ ...e, sets: appendSet(e.sets) }))}
            onToggleDone={(j) => toggle(ex, j)}
            onMove={(d) => move(i, d)}
            onRemove={() => {
              if (ex.sets.some((s) => s.done) && !confirm(`¿Quitar ${nameOf(ex.exerciseId)} y sus series?`)) return
              update((w) => ({ ...w, exercises: w.exercises.filter((e) => e.key !== ex.key) }))
            }}
          />
        )
      })}

      <IconButton icon={Plus} label="Agregar ejercicio" text="Agregar ejercicio" variant="soft" size="md" className="w-full" onClick={() => setPicking(true)} />

      {picking && (
        <ExercisePicker
          selected={active.exercises.map((e) => e.exerciseId)}
          onClose={() => setPicking(false)}
          onPick={(exercise) => {
            setPicking(false)
            update((w) => ({ ...w, exercises: [...w.exercises, { key: newKey(), exerciseId: exercise.id, sets: setsForNewExercise(exercise.id, workouts) }] }))
          }}
        />
      )}
    </div>
  )
}
