import { Check, Plus, Search } from 'lucide-react'
import { useMemo, useState, type FormEvent } from 'react'
import { useUser } from '../../app/AuthProvider'
import { useToast } from '../../app/ToastProvider'
import { EQUIPMENT_ES, equipmentLabel, MUSCLE_GROUPS, muscleLabel, MUSCLES_ES } from '../../core/strength/catalog'
import type { Exercise } from '../../core/strength/types'
import { createCustomExercise } from '../../services/strength'
import { IconButton } from '../../ui/IconButton'
import { Modal } from '../../ui/Modal'
import { ExerciseThumb } from './ExerciseImage'
import { useStrength } from './StrengthProvider'

/** Buscador del catálogo con filtro por grupo muscular. */
export function ExerciseFilters({
  query,
  group,
  onQuery,
  onGroup,
  autoFocus,
}: {
  query: string
  group: string | null
  onQuery: (q: string) => void
  onGroup: (g: string | null) => void
  autoFocus?: boolean
}) {
  return (
    <div className="flex flex-col gap-2">
      <label className="relative block">
        <Search className="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-faint" aria-hidden />
        <input
          autoFocus={autoFocus}
          className="field w-full pl-8"
          placeholder="Buscar en español o inglés…"
          value={query}
          onChange={(e) => onQuery(e.target.value)}
          aria-label="Buscar ejercicio"
        />
      </label>
      <div className="-mx-1 flex gap-1 overflow-x-auto px-1 pb-1" role="radiogroup" aria-label="Grupo muscular">
        {[{ id: null, label: 'Todos' }, ...MUSCLE_GROUPS].map((g) => (
          <button
            key={g.id ?? 'todos'}
            type="button"
            role="radio"
            aria-checked={group === g.id}
            onClick={() => onGroup(g.id)}
            className={`shrink-0 rounded-full border px-2.5 py-0.5 text-xs font-medium transition active:scale-95 ${
              group === g.id ? 'border-primary bg-primary-soft text-primary' : 'border-border text-muted hover:border-border-strong hover:text-fg'
            }`}
          >
            {g.label}
          </button>
        ))}
      </div>
    </div>
  )
}

export function ExerciseRowInfo({ exercise }: { exercise: Exercise }) {
  const muscles = exercise.primary.map(muscleLabel).join(', ')
  return (
    <span className="min-w-0 flex-1">
      <span className="block truncate text-sm text-fg">{exercise.name}</span>
      <span className="block truncate text-[11px] text-faint">
        {[muscles, equipmentLabel(exercise.equipment)].filter(Boolean).join(' · ')}
        {exercise.custom && ' · propio'}
      </span>
    </span>
  )
}

interface Props {
  onPick: (exercise: Exercise) => void
  onClose: () => void
  /** Ejercicios ya agregados: se marcan en la lista. */
  selected?: string[]
}

export function ExercisePicker({ onPick, onClose, selected = [] }: Props) {
  const { index, ready } = useStrength()
  const [query, setQuery] = useState('')
  const [group, setGroup] = useState<string | null>(null)
  const [creating, setCreating] = useState(false)
  const results = useMemo(() => index.search({ query, group }), [index, query, group])

  return (
    <Modal title={creating ? 'Nuevo ejercicio' : 'Agregar ejercicio'} onClose={onClose}>
      {creating ? (
        <CustomExerciseForm initialName={query} onCancel={() => setCreating(false)} onCreated={onPick} />
      ) : (
        <>
          <ExerciseFilters query={query} group={group} onQuery={setQuery} onGroup={setGroup} autoFocus />
          {!ready && <p className="py-6 text-center text-xs text-muted">Cargando catálogo…</p>}
          <ul className="mt-2 flex flex-col">
            {results.map((e) => {
              const already = selected.includes(e.id)
              return (
                <li key={e.id}>
                  <button type="button" onClick={() => onPick(e)} className="flex w-full items-center gap-3 rounded-lg px-1.5 py-1.5 text-left hover:bg-surface-2">
                    <ExerciseThumb exercise={e} />
                    <ExerciseRowInfo exercise={e} />
                    {already && <Check className="size-4 shrink-0 text-primary" aria-label="Ya agregado" />}
                  </button>
                </li>
              )
            })}
          </ul>
          {ready && results.length === 0 && <p className="py-4 text-center text-xs text-muted">Sin resultados.</p>}
          <div className="mt-3 flex justify-end border-t border-border pt-3">
            <IconButton icon={Plus} label="Crear un ejercicio propio" text="Crear ejercicio" variant="soft" onClick={() => setCreating(true)} />
          </div>
        </>
      )}
    </Modal>
  )
}

export function CustomExerciseForm({ initialName = '', onCancel, onCreated }: { initialName?: string; onCancel: () => void; onCreated: (e: Exercise) => void }) {
  const user = useUser()
  const toast = useToast()
  const [name, setName] = useState(initialName)
  const [muscle, setMuscle] = useState('chest')
  const [equipment, setEquipment] = useState<string>('barbell')
  const [saving, setSaving] = useState(false)

  async function submit(e: FormEvent) {
    e.preventDefault()
    const clean = name.trim()
    if (!clean) return
    setSaving(true)
    try {
      const input = { name: clean, primary: [muscle], equipment: equipment || null }
      const id = await createCustomExercise(user.uid, input)
      toast('Ejercicio creado')
      onCreated({ id, nameEn: '', aliases: [], category: 'strength', secondary: [], images: 0, custom: true, ...input })
    } catch (err) {
      toast((err as Error).message, 'error')
      setSaving(false)
    }
  }

  return (
    <form onSubmit={submit} className="flex flex-col gap-3">
      <label className="flex flex-col gap-1">
        <span className="text-xs text-muted">Nombre</span>
        <input className="field" required maxLength={80} autoFocus value={name} onChange={(e) => setName(e.target.value)} placeholder="Ej.: Remo en máquina del gimnasio" />
      </label>
      <div className="grid grid-cols-2 gap-2">
        <label className="flex flex-col gap-1">
          <span className="text-xs text-muted">Músculo principal</span>
          <select className="field" value={muscle} onChange={(e) => setMuscle(e.target.value)}>
            {Object.entries(MUSCLES_ES)
              .sort((a, b) => a[1].localeCompare(b[1]))
              .map(([id, label]) => (
                <option key={id} value={id}>
                  {label}
                </option>
              ))}
          </select>
        </label>
        <label className="flex flex-col gap-1">
          <span className="text-xs text-muted">Equipo</span>
          <select className="field" value={equipment} onChange={(e) => setEquipment(e.target.value)}>
            <option value="">Sin equipo</option>
            {Object.entries(EQUIPMENT_ES).map(([id, label]) => (
              <option key={id} value={id}>
                {label}
              </option>
            ))}
          </select>
        </label>
      </div>
      <p className="text-[11px] text-faint">Los ejercicios propios son privados y no tienen imagen.</p>
      <div className="flex justify-end gap-1.5">
        <IconButton icon={Search} label="Volver al catálogo" text="Catálogo" onClick={onCancel} />
        <IconButton type="submit" icon={Check} label="Guardar ejercicio" text="Guardar" variant="primary" size="md" disabled={saving || !name.trim()} />
      </div>
    </form>
  )
}
