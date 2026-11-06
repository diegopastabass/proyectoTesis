import { CalendarClock, CircleCheck, Flag, Gauge, Scale, Trash2, TriangleAlert, type LucideIcon } from 'lucide-react'
import { useEffect, useMemo, useState, type ReactNode } from 'react'
import { useUser } from '../../app/AuthProvider'
import { useToast } from '../../app/ToastProvider'
import { addDays, fromDateKey, todayKey } from '../../core/date'
import { progressStats, type BodyGoal, type ProgressStats, type WeightEntry } from '../../core/progress'
import { deleteWeight, watchBodyGoal, watchWeights } from '../../services/body'
import { EmptyState } from '../../ui/EmptyState'
import { IconButton } from '../../ui/IconButton'
import { stagger } from '../../ui/motion'
import { GoalCard } from './GoalCard'
import { WeightChart } from './WeightChart'
import { WeightForm } from './WeightForm'

type Range = '30' | '90' | 'all'
const RANGES: { id: Range; label: string; days: number | null }[] = [
  { id: '30', label: '30 d', days: 30 },
  { id: '90', label: '90 d', days: 90 },
  { id: 'all', label: 'Todo', days: null },
]

const shortDate = new Intl.DateTimeFormat('es-CL', { day: 'numeric', month: 'short' })
const longDate = new Intl.DateTimeFormat('es-CL', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' })
const kg = (n: number) => n.toLocaleString('es-CL', { maximumFractionDigits: 1 })
const signed = (n: number) => `${n > 0 ? '+' : n < 0 ? '−' : ''}${kg(Math.abs(n))}`

export function ProgressPage() {
  const user = useUser()
  const toast = useToast()
  const [weights, setWeights] = useState<WeightEntry[] | null>(null)
  const [goal, setGoal] = useState<BodyGoal | null | undefined>(undefined)
  const [range, setRange] = useState<Range>('all')

  useEffect(() => {
    const onError = (e: Error) => toast(e.message, 'error')
    const unsubs = [watchWeights(user.uid, setWeights, onError), watchBodyGoal(user.uid, setGoal, onError)]
    return () => unsubs.forEach((u) => u())
  }, [user.uid, toast])

  const entries = useMemo(() => weights ?? [], [weights])
  const stats = useMemo(() => progressStats(entries, goal ?? null), [entries, goal])

  const visible = useMemo(() => {
    const days = RANGES.find((r) => r.id === range)!.days
    return days === null ? entries : entries.filter((e) => e.date >= addDays(todayKey(), -days))
  }, [entries, range])

  if (weights === null || goal === undefined) return <p className="py-6 text-center text-xs text-muted">Cargando…</p>

  async function remove(entry: WeightEntry) {
    try {
      await deleteWeight(user.uid, entry.date)
      toast('Registro eliminado')
    } catch (err) {
      toast((err as Error).message, 'error')
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <GoalCard goal={goal} stats={stats} />

      {entries.length > 0 && <StatTiles stats={stats} goal={goal} />}

      <section className="card animate-fade-up p-3" aria-label="Evolución del peso" style={stagger(1, 80)}>
        <div className="mb-2 flex items-center justify-between gap-2">
          <h2 className="text-sm font-semibold text-fg-strong">Peso</h2>
          {entries.length > 1 && (
            <div className="flex gap-1" role="radiogroup" aria-label="Período">
              {RANGES.map((r) => (
                <button
                  key={r.id}
                  type="button"
                  role="radio"
                  aria-checked={range === r.id}
                  onClick={() => setRange(r.id)}
                  className={`rounded-lg px-2 py-1 text-xs font-medium transition active:scale-95 ${
                    range === r.id ? 'bg-primary-soft text-primary' : 'text-muted hover:bg-surface-2 hover:text-fg'
                  }`}
                >
                  {r.label}
                </button>
              ))}
            </div>
          )}
        </div>

        {entries.length === 0 ? (
          <EmptyState icon={Scale} title="Aún no registras tu peso">
            Anota tu peso de hoy abajo; con unos pocos registros verás tu gráfica.
          </EmptyState>
        ) : visible.length === 0 ? (
          <p className="py-8 text-center text-xs text-muted">Sin registros en este período.</p>
        ) : (
          <WeightChart entries={visible} target={goal?.targetKg ?? null} />
        )}
        {entries.length === 1 && <p className="mt-1 text-center text-[11px] text-faint">Registra un segundo peso para ver la tendencia.</p>}
      </section>

      <WeightForm entries={entries} />

      {entries.length > 0 && (
        <section className="card animate-fade-up overflow-hidden" aria-label="Historial de pesos">
          <h2 className="border-b border-border bg-surface-2/50 px-3 py-2 text-xs font-medium text-muted">Historial</h2>
          <ul className="divide-y divide-border">
            {[...entries]
              .reverse()
              .slice(0, 60)
              .map((e, i, list) => {
                const older = list[i + 1]
                const delta = older ? Math.round((e.kg - older.kg) * 10) / 10 : null
                return (
                  <li key={e.date} className="flex animate-fade-up items-center gap-3 px-3 py-2" style={stagger(i, 25)}>
                    <span className="flex-1 text-sm capitalize text-muted">{longDate.format(fromDateKey(e.date))}</span>
                    {delta !== null && delta !== 0 && <span className="text-xs tabular-nums text-faint">{signed(delta)}</span>}
                    <span className="w-16 text-right text-sm font-semibold tabular-nums text-fg-strong">{kg(e.kg)} kg</span>
                    <IconButton icon={Trash2} label={`Eliminar el registro del ${shortDate.format(fromDateKey(e.date))}`} variant="danger" onClick={() => remove(e)} />
                  </li>
                )
              })}
          </ul>
        </section>
      )}
    </div>
  )
}

function Tile({ icon: Icon, label, index, children, hint }: { icon: LucideIcon; label: string; index: number; children: ReactNode; hint?: string }) {
  return (
    <div className="card animate-fade-up px-3 py-2.5" style={stagger(index, 60)} title={hint}>
      <p className="flex items-center gap-1.5 text-[11px] text-muted">
        <Icon className="size-3.5" aria-hidden />
        {label}
      </p>
      <div className="mt-0.5">{children}</div>
    </div>
  )
}

function StatTiles({ stats, goal }: { stats: ProgressStats; goal: BodyGoal | null }) {
  const { current, change, remaining, ratePerWeek, eta } = stats

  // Si el cambio va hacia la meta se muestra con ✓; si se aleja, con aviso (nunca solo color).
  let verdict: 'good' | 'bad' | null = null
  if (goal && change !== null && change !== 0) {
    if (goal.type === 'lose') verdict = change < 0 ? 'good' : 'bad'
    else if (goal.type === 'gain') verdict = change > 0 ? 'good' : 'bad'
    else verdict = Math.abs(change) <= 1 ? 'good' : 'bad'
  }

  return (
    <div className="grid grid-cols-2 gap-2">
      <Tile icon={Scale} label="Peso actual" index={0}>
        <p className="text-lg font-bold tabular-nums text-fg-strong">{current ? `${kg(current.kg)} kg` : '—'}</p>
        {current && <p className="text-[11px] text-faint">{shortDate.format(fromDateKey(current.date))}</p>}
      </Tile>

      <Tile icon={Gauge} label={goal ? 'Cambio desde el inicio' : 'Cambio total'} index={1}>
        <p className="flex items-center gap-1.5 text-lg font-bold tabular-nums text-fg-strong">
          {change !== null ? `${signed(change)} kg` : '—'}
          {verdict === 'good' && <CircleCheck className="size-4 text-success" aria-label="Va hacia tu meta" />}
          {verdict === 'bad' && <TriangleAlert className="size-4 text-warning" aria-label="Se aleja de tu meta" />}
        </p>
        {ratePerWeek !== null && <p className="text-[11px] tabular-nums text-faint">{signed(ratePerWeek)} kg por semana</p>}
      </Tile>

      {goal?.targetKg != null && (
        <>
          <Tile icon={Flag} label="Para llegar a la meta" index={2}>
            <p className="text-lg font-bold tabular-nums text-fg-strong">{remaining !== null ? `${signed(remaining)} kg` : '—'}</p>
            <p className="text-[11px] tabular-nums text-faint">Meta {kg(goal.targetKg)} kg</p>
          </Tile>
          <Tile icon={CalendarClock} label="Llegada estimada" index={3} hint="Proyección con la tendencia de las últimas 4 semanas">
            <p className="text-lg font-bold text-fg-strong">{eta ? shortDate.format(fromDateKey(eta)) : '—'}</p>
            <p className="text-[11px] text-faint">{eta ? 'según tu tendencia' : 'sin tendencia hacia la meta'}</p>
          </Tile>
        </>
      )}
    </div>
  )
}
