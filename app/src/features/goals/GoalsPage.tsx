import { Check, RotateCcw } from 'lucide-react'
import { useState } from 'react'
import { useUser } from '../../app/AuthProvider'
import { useData } from '../../app/DataProvider'
import { useToast } from '../../app/ToastProvider'
import { DEFAULT_GOALS, normalizedWeights } from '../../core/score'
import { MACRO_KEYS, type Goals, type MacroKey } from '../../core/types'
import { saveGoals } from '../../services/profile'
import { IconButton } from '../../ui/IconButton'
import { MACRO_META } from '../../ui/meta'
import { stagger } from '../../ui/motion'
import { parseNum } from '../../ui/num'

type Draft = Record<MacroKey, { min: string; max: string; weight: number }>

function toDraft(g: Goals): Draft {
  const d = {} as Draft
  for (const k of MACRO_KEYS) d[k] = { min: String(g.ranges[k].min), max: String(g.ranges[k].max), weight: g.weights[k] }
  return d
}

export function GoalsPage() {
  const { goals, ready } = useData()
  if (!ready) return <p className="py-6 text-center text-xs text-muted">Cargando…</p>
  return <GoalsEditor key={JSON.stringify(goals)} goals={goals} />
}

function GoalsEditor({ goals }: { goals: Goals }) {
  const user = useUser()
  const toast = useToast()
  const [draft, setDraft] = useState<Draft>(() => toDraft(goals))
  const [saving, setSaving] = useState(false)

  const set = (k: MacroKey, patch: Partial<Draft[MacroKey]>) => setDraft((d) => ({ ...d, [k]: { ...d[k], ...patch } }))
  const weights = normalizedWeights(Object.fromEntries(MACRO_KEYS.map((k) => [k, draft[k].weight])) as Record<MacroKey, number>)

  const errors = MACRO_KEYS.filter((k) => {
    const min = parseNum(draft[k].min)
    const max = parseNum(draft[k].max)
    return !(Number.isFinite(min) && Number.isFinite(max) && min >= 0 && max >= min)
  })

  async function save() {
    const next: Goals = { ranges: { ...goals.ranges }, weights: { ...goals.weights } }
    for (const k of MACRO_KEYS) {
      next.ranges[k] = { min: parseNum(draft[k].min), max: parseNum(draft[k].max) }
      next.weights[k] = draft[k].weight
    }
    setSaving(true)
    try {
      await saveGoals(user.uid, next)
      toast('Objetivos guardados')
    } catch (err) {
      toast((err as Error).message, 'error')
      setSaving(false)
    }
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-sm font-semibold text-fg-strong">Objetivos diarios</h1>
        <div className="flex gap-1">
          <IconButton icon={RotateCcw} label="Restaurar valores por defecto" onClick={() => setDraft(toDraft(DEFAULT_GOALS))} />
          <IconButton icon={Check} label="Guardar objetivos" text="Guardar" variant="primary" size="md" disabled={errors.length > 0 || saving} onClick={save} />
        </div>
      </div>

      <ul className="card divide-y divide-border">
        {MACRO_KEYS.map((k, i) => {
          const meta = MACRO_META[k]
          const invalid = errors.includes(k)
          return (
            <li key={k} className="grid animate-fade-up grid-cols-[1fr_auto] gap-x-3 gap-y-2 p-3" style={stagger(i, 50)}>
              <span className="flex min-w-0 items-center gap-2 text-sm text-fg">
                <span className={`size-2.5 shrink-0 rounded-full ${meta.bg}`} aria-hidden />
                <span className="truncate">{meta.label}</span>
                <span className="text-xs text-faint">{meta.unit}</span>
              </span>
              <span className="flex items-center gap-1">
                <input
                  className={`field h-8 w-18 text-right tabular-nums ${invalid ? 'border-danger' : ''}`}
                  inputMode="decimal"
                  value={draft[k].min}
                  onChange={(e) => set(k, { min: e.target.value })}
                  aria-label={`${meta.label} mínimo`}
                />
                <span className="text-faint">–</span>
                <input
                  className={`field h-8 w-18 text-right tabular-nums ${invalid ? 'border-danger' : ''}`}
                  inputMode="decimal"
                  value={draft[k].max}
                  onChange={(e) => set(k, { max: e.target.value })}
                  aria-label={`${meta.label} máximo`}
                />
              </span>
              <label className="col-span-2 flex items-center gap-3 text-xs text-muted">
                <span className="w-24 shrink-0">Peso en puntaje</span>
                <input
                  type="range"
                  min={0}
                  max={100}
                  step={5}
                  value={draft[k].weight}
                  onChange={(e) => set(k, { weight: Number(e.target.value) })}
                  className="flex-1 accent-(--primary)"
                  aria-label={`Peso de ${meta.label} en el puntaje`}
                />
                <span className="w-10 text-right tabular-nums text-fg">{Math.round(weights[k] * 100)}%</span>
              </label>
            </li>
          )
        })}
      </ul>

      <p className="px-1 text-xs leading-relaxed text-faint">
        Cada macro suma 100 puntos si queda dentro de su rango y baja en proporción a cuánto se aleja del límite más cercano. El
        puntaje del día es el promedio ponderado con estos pesos (se normalizan para sumar 100%).
      </p>
    </div>
  )
}
