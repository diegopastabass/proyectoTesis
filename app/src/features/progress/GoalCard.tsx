import { Check, Equal, Pencil, Target, TrendingDown, TrendingUp, TriangleAlert, type LucideIcon } from 'lucide-react'
import { useState } from 'react'
import { useUser } from '../../app/AuthProvider'
import { useToast } from '../../app/ToastProvider'
import { todayKey } from '../../core/date'
import type { BodyGoal, GoalType, ProgressStats } from '../../core/progress'
import { saveBodyGoal } from '../../services/body'
import { IconButton } from '../../ui/IconButton'
import { parseNum } from '../../ui/num'

export const GOAL_META: Record<GoalType, { label: string; short: string; icon: LucideIcon; hint: string }> = {
  lose: { label: 'Perder peso', short: 'Perder', icon: TrendingDown, hint: 'Peso objetivo menor al actual' },
  maintain: { label: 'Mantener peso', short: 'Mantener', icon: Equal, hint: 'Peso que quieres sostener' },
  gain: { label: 'Ganar masa muscular', short: 'Ganar', icon: TrendingUp, hint: 'Peso objetivo mayor al actual' },
}

const GOAL_TYPES: GoalType[] = ['lose', 'maintain', 'gain']
const MIN_KG = 20
const MAX_KG = 400

interface Props {
  goal: BodyGoal | null
  stats: ProgressStats
}

export function GoalCard({ goal, stats }: Props) {
  const [editing, setEditing] = useState(false)
  if (!goal || editing) return <GoalForm goal={goal} currentKg={stats.current?.kg ?? null} onDone={() => setEditing(false)} />

  const meta = GOAL_META[goal.type]
  const Icon = meta.icon
  return (
    <section className="card animate-fade-up p-3" aria-label="Meta">
      <div className="flex items-center gap-3">
        <span className="flex size-10 shrink-0 items-center justify-center rounded-xl gradient-primary text-on-primary">
          <Icon className="size-5" strokeWidth={2.25} aria-hidden />
        </span>
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold text-fg-strong">{meta.label}</p>
          <p className="text-xs text-muted">
            {goal.targetKg !== null ? (
              <>
                Meta <span className="font-medium tabular-nums text-fg">{goal.targetKg.toLocaleString('es-CL')} kg</span>
              </>
            ) : (
              'Sin peso objetivo'
            )}
            {stats.percent !== null && <span className="tabular-nums"> · {stats.percent}% logrado</span>}
          </p>
        </div>
        <IconButton icon={Pencil} label="Editar meta" onClick={() => setEditing(true)} />
      </div>
      {stats.percent !== null && (
        <div className="mt-3 h-2 overflow-hidden rounded-full bg-bg-hard" role="progressbar" aria-label="Avance hacia la meta" aria-valuenow={stats.percent} aria-valuemin={0} aria-valuemax={100}>
          <div className="h-full origin-left animate-grow-x rounded-full gradient-primary transition-[width] duration-700 ease-out" style={{ width: `${stats.percent}%` }} />
        </div>
      )}
    </section>
  )
}

function GoalForm({ goal, currentKg, onDone }: { goal: BodyGoal | null; currentKg: number | null; onDone: () => void }) {
  const user = useUser()
  const toast = useToast()
  const [type, setType] = useState<GoalType>(goal?.type ?? 'lose')
  const [target, setTarget] = useState(goal?.targetKg !== null && goal?.targetKg !== undefined ? String(goal.targetKg) : '')
  const [startDate, setStartDate] = useState(goal?.startDate ?? todayKey())
  const [saving, setSaving] = useState(false)

  const kg = parseNum(target)
  const hasTarget = target.trim() !== ''
  const targetInvalid = hasTarget && !(kg >= MIN_KG && kg <= MAX_KG)
  const direction =
    hasTarget && !targetInvalid && currentKg !== null && ((type === 'lose' && kg >= currentKg) || (type === 'gain' && kg <= currentKg))
  const missingTarget = type !== 'maintain' && !hasTarget

  async function save() {
    setSaving(true)
    try {
      await saveBodyGoal(user.uid, { type, targetKg: hasTarget ? kg : null, startDate })
      toast('Meta guardada')
      onDone()
    } catch (err) {
      toast((err as Error).message, 'error')
      setSaving(false)
    }
  }

  return (
    <section className="card animate-scale-in flex flex-col gap-3 p-3" aria-label="Definir meta">
      <div className="flex items-center gap-2">
        <Target className="size-4 text-primary" aria-hidden />
        <h2 className="text-sm font-semibold text-fg-strong">{goal ? 'Editar meta' : '¿Cuál es tu meta?'}</h2>
      </div>

      <div className="grid grid-cols-3 gap-2" role="radiogroup" aria-label="Tipo de meta">
        {GOAL_TYPES.map((t) => {
          const { icon: Icon, short } = GOAL_META[t]
          const selected = type === t
          return (
            <button
              key={t}
              type="button"
              role="radio"
              aria-checked={selected}
              title={GOAL_META[t].label}
              onClick={() => setType(t)}
              className={`flex flex-col items-center gap-1 rounded-xl border px-2 py-2.5 text-xs font-medium transition active:scale-95 ${
                selected ? 'border-primary bg-primary-soft text-primary' : 'border-border text-muted hover:border-border-strong hover:text-fg'
              }`}
            >
              <Icon key={String(selected)} className={`size-5 ${selected ? 'animate-pop' : ''}`} strokeWidth={2.25} aria-hidden />
              {short}
            </button>
          )
        })}
      </div>
      <p className="-mt-1 text-[11px] text-faint">{GOAL_META[type].label}. {GOAL_META[type].hint}.</p>

      <div className="grid grid-cols-2 gap-2">
        <label className="flex flex-col gap-1">
          <span className="text-xs text-muted">Peso objetivo (kg){type === 'maintain' ? ' · opcional' : ''}</span>
          <input
            className={`field tabular-nums ${targetInvalid ? 'border-danger' : ''}`}
            inputMode="decimal"
            placeholder={currentKg !== null ? String(currentKg) : 'ej: 78'}
            value={target}
            onChange={(e) => setTarget(e.target.value)}
            aria-invalid={targetInvalid}
          />
        </label>
        <label className="flex flex-col gap-1">
          <span className="text-xs text-muted">Desde</span>
          <input className="field" type="date" max={todayKey()} value={startDate} onChange={(e) => setStartDate(e.target.value || todayKey())} />
        </label>
      </div>

      {targetInvalid && <p className="text-xs text-danger">El peso debe estar entre {MIN_KG} y {MAX_KG} kg.</p>}
      {direction && (
        <p className="flex animate-fade-in items-start gap-1.5 text-[11px] leading-snug text-warning">
          <TriangleAlert className="mt-px size-3.5 shrink-0" aria-hidden />
          Tu último peso es {currentKg!.toLocaleString('es-CL')} kg: para «{GOAL_META[type].short.toLowerCase()}» la meta debería estar {type === 'lose' ? 'por debajo' : 'por encima'}.
        </p>
      )}

      <div className="flex justify-end gap-1.5">
        {goal && <IconButton icon={Pencil} label="Cancelar edición" text="Cancelar" onClick={onDone} />}
        <IconButton icon={Check} label="Guardar meta" text="Guardar" variant="primary" size="md" disabled={saving || targetInvalid || missingTarget} onClick={save} />
      </div>
    </section>
  )
}
