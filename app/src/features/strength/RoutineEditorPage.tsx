import { ArrowLeft, Check, Dumbbell, Play, Plus, Trash2 } from 'lucide-react'
import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useUser } from '../../app/AuthProvider'
import { useToast } from '../../app/ToastProvider'
import { newKey, parseAmount, workoutFromRoutine } from '../../core/strength/session'
import { lastSetsFor, matchPrevious } from '../../core/strength/stats'
import type { Routine, RoutineExercise } from '../../core/strength/types'
import { deleteRoutine, saveRoutine } from '../../services/strength'
import { EmptyState } from '../../ui/EmptyState'
import { IconButton } from '../../ui/IconButton'
import { ExerciseBlock } from './ExerciseBlock'
import { ExercisePicker } from './ExercisePicker'
import type { SetRow } from './SetTable'
import { useStrength } from './StrengthProvider'

interface Block {
  key: string
  exerciseId: string
  sets: SetRow[]
}

const text = (n: number | null) => (n === null ? '' : String(n).replace('.', ','))

function toBlocks(r: Routine | undefined): Block[] {
  return (r?.exercises ?? []).map((e) => ({
    key: newKey(),
    exerciseId: e.exerciseId,
    sets: e.sets.map((s) => ({ key: newKey(), type: s.type, kg: text(s.kg), reps: text(s.reps) })),
  }))
}

export function RoutineEditorPage() {
  const { id } = useParams()
  const { routines, ready } = useStrength()
  if (!ready) return <p className="py-6 text-center text-xs text-muted">Cargando…</p>
  const routine = id && id !== 'nueva' ? routines.find((r) => r.id === id) : undefined
  if (id !== 'nueva' && !routine) return <p className="py-6 text-center text-xs text-muted">Rutina no encontrada.</p>
  return <RoutineEditor key={routine?.id ?? 'nueva'} routine={routine} />
}

function RoutineEditor({ routine }: { routine?: Routine }) {
  const user = useUser()
  const toast = useToast()
  const navigate = useNavigate()
  const { workouts, exerciseById, nameOf, active, setActive } = useStrength()
  const [name, setName] = useState(routine?.name ?? '')
  const [blocks, setBlocks] = useState<Block[]>(() => toBlocks(routine))
  const [picking, setPicking] = useState(false)
  const [saving, setSaving] = useState(false)

  const updateBlock = (key: string, fn: (b: Block) => Block) => setBlocks((list) => list.map((b) => (b.key === key ? fn(b) : b)))
  const valid = name.trim() !== '' && blocks.length > 0 && blocks.every((b) => b.sets.length > 0)

  function toExercises(): RoutineExercise[] {
    return blocks.map((b) => ({ exerciseId: b.exerciseId, sets: b.sets.map((s) => ({ type: s.type, kg: parseAmount(s.kg), reps: parseAmount(s.reps) })) }))
  }

  async function save(start = false) {
    setSaving(true)
    try {
      const exercises = toExercises()
      const id = await saveRoutine(user.uid, { name: name.trim(), exercises }, routine?.id)
      toast('Rutina guardada')
      if (start) {
        if (active && !confirm('Ya tienes un entrenamiento en curso. ¿Descartarlo y empezar esta rutina?')) {
          navigate('/fuerza', { replace: true })
          return
        }
        setActive(workoutFromRoutine({ id, name: name.trim(), exercises, updatedAt: Date.now() }, Date.now()))
        navigate('/fuerza/entrenar', { replace: true })
      } else navigate('/fuerza', { replace: true })
    } catch (err) {
      toast((err as Error).message, 'error')
      setSaving(false)
    }
  }

  async function remove() {
    if (!routine || !confirm(`¿Eliminar la rutina "${routine.name}"? Los entrenamientos ya hechos se conservan.`)) return
    try {
      await deleteRoutine(user.uid, routine.id)
      toast('Rutina eliminada')
      navigate('/fuerza', { replace: true })
    } catch (err) {
      toast((err as Error).message, 'error')
    }
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-1.5">
        <IconButton icon={ArrowLeft} label="Volver" onClick={() => navigate('/fuerza')} />
        <h1 className="flex-1 truncate text-sm font-semibold text-fg-strong">{routine ? 'Editar rutina' : 'Nueva rutina'}</h1>
        {routine && <IconButton icon={Trash2} label="Eliminar rutina" variant="danger" onClick={remove} />}
        <IconButton icon={Play} label="Guardar y empezar" variant="soft" size="md" disabled={!valid || saving} onClick={() => save(true)} />
        <IconButton icon={Check} label="Guardar rutina" text="Guardar" variant="primary" size="md" disabled={!valid || saving} onClick={() => save()} />
      </div>

      <label className="card flex flex-col gap-1 p-3">
        <span className="text-xs text-muted">Nombre de la rutina</span>
        <input className="field" value={name} onChange={(e) => setName(e.target.value)} placeholder="Rutina de pecho, Pierna A, Torso…" maxLength={60} autoFocus={!routine} />
      </label>

      {blocks.length === 0 && (
        <div className="card">
          <EmptyState icon={Dumbbell} title="Agrega ejercicios a la rutina">
            Define las series de cada uno: las de calentamiento (C), las efectivas y, si quieres, los kilos y repeticiones objetivo.
          </EmptyState>
        </div>
      )}

      {blocks.map((b, i) => {
        const last = lastSetsFor(workouts, b.exerciseId)
        const types = b.sets.map((s) => s.type)
        return (
          <ExerciseBlock
            key={b.key}
            index={i}
            total={blocks.length}
            exercise={exerciseById.get(b.exerciseId)}
            name={nameOf(b.exerciseId)}
            rows={b.sets}
            previous={b.sets.map((_, j) => matchPrevious(last, types, j))}
            onChange={(j, patch) => updateBlock(b.key, (x) => ({ ...x, sets: x.sets.map((s, k) => (k === j ? { ...s, ...patch } : s)) }))}
            onRemoveSet={(j) => updateBlock(b.key, (x) => ({ ...x, sets: x.sets.filter((_, k) => k !== j) }))}
            onAddSet={() =>
              updateBlock(b.key, (x) => {
                const prev = x.sets.at(-1)
                return { ...x, sets: [...x.sets, { key: newKey(), type: prev && prev.type !== 'warmup' ? prev.type : 'normal', kg: prev?.kg ?? '', reps: prev?.reps ?? '' }] }
              })
            }
            onMove={(d) =>
              setBlocks((list) => {
                const next = [...list]
                const [item] = next.splice(i, 1)
                next.splice(i + d, 0, item)
                return next
              })
            }
            onRemove={() => setBlocks((list) => list.filter((x) => x.key !== b.key))}
          />
        )
      })}

      <IconButton icon={Plus} label="Agregar ejercicio" text="Agregar ejercicio" variant="soft" size="md" className="w-full" onClick={() => setPicking(true)} />

      {picking && (
        <ExercisePicker
          selected={blocks.map((b) => b.exerciseId)}
          onClose={() => setPicking(false)}
          onPick={(exercise) => {
            setPicking(false)
            const last = lastSetsFor(workouts, exercise.id)
            const sets: SetRow[] = last?.length
              ? last.map((s) => ({ key: newKey(), type: s.type, kg: text(s.kg), reps: text(s.reps) }))
              : Array.from({ length: 3 }, () => ({ key: newKey(), type: 'normal' as const, kg: '', reps: '' }))
            setBlocks((list) => [...list, { key: newKey(), exerciseId: exercise.id, sets }])
          }}
        />
      )}
    </div>
  )
}
