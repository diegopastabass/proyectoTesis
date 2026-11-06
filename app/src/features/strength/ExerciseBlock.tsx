import { ArrowDown, ArrowUp, ChartLine, Plus, Trash2 } from 'lucide-react'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { equipmentLabel, muscleLabel } from '../../core/strength/catalog'
import type { Exercise, StrengthSet } from '../../core/strength/types'
import { IconButton } from '../../ui/IconButton'
import { Modal } from '../../ui/Modal'
import { stagger } from '../../ui/motion'
import { ExerciseAnimation, ExerciseThumb } from './ExerciseImage'
import { SetTable, type SetRow } from './SetTable'

interface Props {
  index: number
  total: number
  exercise: Exercise | undefined
  name: string
  rows: SetRow[]
  previous: (StrengthSet | null)[]
  onChange: (setIndex: number, patch: Partial<SetRow>) => void
  onRemoveSet: (setIndex: number) => void
  onAddSet: () => void
  onMove: (delta: -1 | 1) => void
  onRemove: () => void
  onToggleDone?: (setIndex: number) => void
}

/** Tarjeta de un ejercicio con su tabla de series (rutina o sesión en curso). */
export function ExerciseBlock({ index, total, exercise, name, rows, previous, onChange, onRemoveSet, onAddSet, onMove, onRemove, onToggleDone }: Props) {
  const [info, setInfo] = useState(false)
  const done = rows.filter((r) => r.done).length

  return (
    <section className="card animate-fade-up overflow-hidden" style={stagger(index, 60)} aria-label={name}>
      <header className="flex items-center gap-2.5 px-3 py-2">
        <button type="button" onClick={() => setInfo(true)} className="flex min-w-0 flex-1 items-center gap-2.5 text-left" title="Ver cómo se hace">
          <ExerciseThumb exercise={exercise} />
          <span className="min-w-0">
            <span className="line-clamp-2 text-sm leading-tight font-semibold text-primary">{name}</span>
            <span className="block truncate text-[11px] text-faint">
              {onToggleDone ? `${done}/${rows.length} series` : `${rows.length} ${rows.length === 1 ? 'serie' : 'series'}`}
              {exercise && exercise.primary.length > 0 && ` · ${exercise.primary.map(muscleLabel).join(', ')}`}
            </span>
          </span>
        </button>
        <div className="flex shrink-0">
          <IconButton icon={ArrowUp} label={`Subir ${name}`} disabled={index === 0} onClick={() => onMove(-1)} />
          <IconButton icon={ArrowDown} label={`Bajar ${name}`} disabled={index === total - 1} onClick={() => onMove(1)} />
          <IconButton icon={Trash2} label={`Quitar ${name}`} variant="danger" onClick={onRemove} />
        </div>
      </header>

      <SetTable rows={rows} previous={previous} exerciseName={name} onChange={onChange} onRemove={onRemoveSet} onToggleDone={onToggleDone} />

      <div className="px-3 pt-1 pb-2.5">
        <button
          type="button"
          onClick={onAddSet}
          className="flex h-8 w-full items-center justify-center gap-1.5 rounded-lg bg-surface-2 text-xs font-medium text-muted transition hover:text-fg active:scale-[0.98]"
        >
          <Plus className="size-3.5" aria-hidden /> Agregar serie
        </button>
      </div>

      {info && exercise && <ExerciseInfoModal exercise={exercise} onClose={() => setInfo(false)} />}
    </section>
  )
}

export function ExerciseInfoModal({ exercise, onClose }: { exercise: Exercise; onClose: () => void }) {
  const navigate = useNavigate()
  return (
    <Modal title={exercise.name} onClose={onClose}>
      <div className="flex flex-col gap-3">
        <ExerciseAnimation exercise={exercise} />
        <MuscleChips exercise={exercise} />
        <div className="flex justify-end">
          <IconButton
            icon={ChartLine}
            label="Ver progreso e historial del ejercicio"
            text="Progreso"
            variant="soft"
            onClick={() => navigate(`/fuerza/ejercicios/${encodeURIComponent(exercise.id)}`)}
          />
        </div>
      </div>
    </Modal>
  )
}

export function MuscleChips({ exercise }: { exercise: Exercise }) {
  return (
    <div className="flex flex-wrap items-center gap-1.5 text-xs">
      {exercise.primary.map((m) => (
        <span key={m} className="rounded-full bg-primary-soft px-2 py-0.5 font-medium text-primary">
          {muscleLabel(m)}
        </span>
      ))}
      {exercise.secondary.map((m) => (
        <span key={m} className="rounded-full border border-border px-2 py-0.5 text-muted">
          {muscleLabel(m)}
        </span>
      ))}
      <span className="text-faint">· {equipmentLabel(exercise.equipment)}</span>
      {exercise.nameEn && exercise.nameEn !== exercise.name && <span className="text-faint">· {exercise.nameEn}</span>}
    </div>
  )
}
