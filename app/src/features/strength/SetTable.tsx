import { Check, X } from 'lucide-react'
import { nextSetType } from '../../core/strength/session'
import type { SetType, StrengthSet } from '../../core/strength/types'
import { stagger } from '../../ui/motion'
import { formatSet, SET_META, setLabels } from './format'

export interface SetRow {
  key: string
  type: SetType
  kg: string
  reps: string
  /** Solo en la sesión en curso. */
  done?: boolean
  /** Sugerencias (placeholder) cuando el campo está vacío. */
  hintKg?: number | null
  hintReps?: number | null
}

interface Props {
  rows: SetRow[]
  /** Serie equivalente de la última sesión con este ejercicio. */
  previous: (StrengthSet | null)[]
  exerciseName: string
  onChange: (index: number, patch: Partial<SetRow>) => void
  onRemove: (index: number) => void
  /** Si se entrega, se muestra la columna ✓ (sesión en curso). */
  onToggleDone?: (index: number) => void
}

const hint = (n: number | null | undefined) => (n === null || n === undefined ? '' : String(n).replace('.', ','))

/** Tabla SERIE · ANTERIOR · KG · REPS · ✓ */
export function SetTable({ rows, previous, exerciseName, onChange, onRemove, onToggleDone }: Props) {
  const labels = setLabels(rows.map((r) => r.type))
  const grid = onToggleDone ? 'grid-cols-[2rem_1fr_3.75rem_3.25rem_2rem_1.5rem]' : 'grid-cols-[2rem_1fr_3.75rem_3.25rem_1.5rem]'

  return (
    <div className="text-sm" role="table" aria-label={`Series de ${exerciseName}`}>
      <div role="row" className={`grid ${grid} items-center gap-1.5 px-3 pb-1 text-[10px] font-semibold tracking-wide text-faint uppercase`}>
        <span role="columnheader" className="text-center">Serie</span>
        <span role="columnheader">Anterior</span>
        <span role="columnheader" className="text-center">kg</span>
        <span role="columnheader" className="text-center">Reps</span>
        {onToggleDone && (
          <span role="columnheader" className="flex justify-center">
            <Check className="size-3.5" aria-label="Hecha" />
          </span>
        )}
        <span role="columnheader" className="sr-only">Quitar</span>
      </div>

      {rows.map((row, i) => {
        const meta = SET_META[row.type]
        const prev = previous[i] ?? null
        const done = row.done === true
        return (
          <div
            key={row.key}
            role="row"
            className={`grid ${grid} animate-fade-up items-center gap-1.5 px-3 py-1 transition-colors ${done ? 'bg-primary-soft' : ''}`}
            style={stagger(i, 30)}
          >
            <button
              type="button"
              role="cell"
              onClick={() => onChange(i, { type: nextSetType(row.type) })}
              title={`${meta.label}. Toca para cambiar el tipo`}
              aria-label={`Serie ${labels[i]}, ${meta.label}. Cambiar tipo`}
              className={`flex h-8 items-center justify-center rounded-md text-sm font-bold tabular-nums transition hover:bg-surface-2 active:scale-90 ${meta.className}`}
            >
              {labels[i]}
            </button>

            <button
              type="button"
              role="cell"
              disabled={!prev}
              onClick={() => prev && onChange(i, { kg: hint(prev.kg), reps: hint(prev.reps) })}
              title={prev ? 'Usar estos valores' : 'Sin registro anterior'}
              className="truncate rounded-md py-1 text-left text-xs tabular-nums text-faint transition enabled:hover:text-primary"
            >
              {prev ? formatSet(prev) : '—'}
            </button>

            <input
              role="cell"
              className={`field h-8 w-full min-w-0 px-1 text-center tabular-nums ${done ? 'border-transparent bg-transparent font-semibold' : ''}`}
              inputMode="decimal"
              placeholder={hint(row.hintKg) || '0'}
              value={row.kg}
              onChange={(e) => onChange(i, { kg: e.target.value })}
              aria-label={`Kilos de la serie ${labels[i]}`}
            />
            <input
              role="cell"
              className={`field h-8 w-full min-w-0 px-1 text-center tabular-nums ${done ? 'border-transparent bg-transparent font-semibold' : ''}`}
              inputMode="numeric"
              placeholder={hint(row.hintReps) || '0'}
              value={row.reps}
              onChange={(e) => onChange(i, { reps: e.target.value })}
              aria-label={`Repeticiones de la serie ${labels[i]}`}
            />

            {onToggleDone && (
              <button
                type="button"
                role="cell"
                onClick={() => onToggleDone(i)}
                aria-pressed={done}
                aria-label={done ? `Desmarcar serie ${labels[i]}` : `Marcar serie ${labels[i]} como hecha`}
                className={`flex size-8 items-center justify-center rounded-lg transition active:scale-90 ${
                  done ? 'gradient-primary text-on-primary shadow-sm shadow-black/20' : 'bg-surface-2 text-faint hover:text-fg'
                }`}
              >
                <Check key={String(done)} className={`size-4 ${done ? 'animate-pop' : ''}`} strokeWidth={3} aria-hidden />
              </button>
            )}

            <button
              type="button"
              role="cell"
              onClick={() => onRemove(i)}
              aria-label={`Quitar serie ${labels[i]}`}
              title="Quitar serie"
              className="flex size-6 items-center justify-center rounded-md text-faint transition hover:bg-danger/10 hover:text-danger"
            >
              <X className="size-3.5" aria-hidden />
            </button>
          </div>
        )
      })}
    </div>
  )
}
