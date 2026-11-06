import { ExternalLink, Plus } from 'lucide-react'
import { useMemo, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { exerciseFrequency } from '../../core/strength/stats'
import { IconButton } from '../../ui/IconButton'
import { Modal } from '../../ui/Modal'
import { ExerciseThumb } from './ExerciseImage'
import { CustomExerciseForm, ExerciseFilters, ExerciseRowInfo } from './ExercisePicker'
import { useStrength } from './StrengthProvider'

const PAGE = 60

export function ExercisesPage() {
  const navigate = useNavigate()
  const { index, ready, exercises, workouts } = useStrength()
  const [query, setQuery] = useState('')
  const [group, setGroup] = useState<string | null>(null)
  const [creating, setCreating] = useState(false)
  const [limit, setLimit] = useState(PAGE)

  const results = useMemo(() => index.search({ query, group }, limit), [index, query, group, limit])
  const sessions = useMemo(() => new Map(exerciseFrequency(workouts).map((f) => [f.exerciseId, f.sessions])), [workouts])

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-sm font-semibold text-fg-strong">Ejercicios</h1>
        <IconButton icon={Plus} label="Crear un ejercicio propio" variant="primary" size="md" onClick={() => setCreating(true)} />
      </div>

      <ExerciseFilters
        query={query}
        group={group}
        onQuery={(q) => {
          setQuery(q)
          setLimit(PAGE)
        }}
        onGroup={(g) => {
          setGroup(g)
          setLimit(PAGE)
        }}
      />

      {!ready && <p className="py-6 text-center text-xs text-muted">Cargando catálogo…</p>}

      {results.length > 0 && (
        <ul className="card divide-y divide-border overflow-hidden">
          {results.map((e) => {
            const n = sessions.get(e.id)
            return (
              <li key={e.id}>
                <Link to={`/fuerza/ejercicios/${encodeURIComponent(e.id)}`} className="flex items-center gap-3 px-3 py-2 hover:bg-surface-2">
                  <ExerciseThumb exercise={e} />
                  <ExerciseRowInfo exercise={e} />
                  {n !== undefined && (
                    <span className="shrink-0 rounded-full bg-primary-soft px-2 py-0.5 text-[10px] font-medium text-primary tabular-nums" title="Sesiones en que lo hiciste">
                      {n}×
                    </span>
                  )}
                </Link>
              </li>
            )
          })}
        </ul>
      )}

      {ready && results.length === 0 && <p className="py-4 text-center text-xs text-muted">Sin resultados.</p>}
      {results.length === limit && (
        <IconButton icon={Plus} label="Mostrar más ejercicios" text="Mostrar más" className="self-center" onClick={() => setLimit((l) => l + PAGE)} />
      )}

      <p className="px-1 text-[11px] leading-relaxed text-faint">
        {exercises.length} ejercicios. Catálogo e imágenes de{' '}
        <a href="https://github.com/yuhonas/free-exercise-db" target="_blank" rel="noreferrer" className="inline-flex items-center gap-0.5 text-primary hover:underline">
          free-exercise-db <ExternalLink className="size-3" aria-hidden />
        </a>{' '}
        (dominio público). Los nombres en español de los ejercicios más comunes son propios; el resto aparece en inglés.
      </p>

      {creating && (
        <Modal title="Nuevo ejercicio" onClose={() => setCreating(false)}>
          <CustomExerciseForm
            initialName={query}
            onCancel={() => setCreating(false)}
            onCreated={(e) => {
              setCreating(false)
              navigate(`/fuerza/ejercicios/${encodeURIComponent(e.id)}`)
            }}
          />
        </Modal>
      )}
    </div>
  )
}
