import { ChefHat, ListPlus, Trash2, UtensilsCrossed } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useUser } from '../../app/AuthProvider'
import { useData } from '../../app/DataProvider'
import { useToast } from '../../app/ToastProvider'
import { useDateParam } from '../../app/useDateParam'
import { sumMacros } from '../../core/macros'
import { dailyScore } from '../../core/score'
import { MACRO_KEYS, MEAL_SLOTS, type DiaryEntry } from '../../core/types'
import { deleteEntry, watchDay } from '../../services/diary'
import { DateNav } from '../../ui/DateNav'
import { EmptyState } from '../../ui/EmptyState'
import { IconButton } from '../../ui/IconButton'
import { MacroBar } from '../../ui/MacroBar'
import { MacroInline } from '../../ui/MacroInline'
import { MEAL_META } from '../../ui/meta'
import { stagger } from '../../ui/motion'
import { ScoreRing } from '../../ui/ScoreRing'

export function TodayPage() {
  const user = useUser()
  const toast = useToast()
  const { goals } = useData()
  const navigate = useNavigate()
  const [date, setDate] = useDateParam()
  const [day, setDay] = useState<{ date: string; entries: DiaryEntry[] } | null>(null)

  useEffect(() => watchDay(user.uid, date, (entries) => setDay({ date, entries }), (e) => toast(e.message, 'error')), [user.uid, date, toast])

  const entries = day?.date === date ? day.entries : null
  const totals = useMemo(() => sumMacros((entries ?? []).map((e) => e.macros)), [entries])
  const score = dailyScore(totals, goals)
  const isEmpty = entries !== null && entries.length === 0

  async function remove(e: DiaryEntry) {
    try {
      await deleteEntry(user.uid, date, e.id)
    } catch (err) {
      toast((err as Error).message, 'error')
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <DateNav date={date} onChange={setDate} />
        <IconButton icon={ListPlus} label="Registrar comida" variant="primary" size="md" onClick={() => navigate(`/registrar?d=${date}`)} />
      </div>

      <section className="card flex items-center gap-4 p-4" aria-label="Resumen del día">
        <ScoreRing score={score.total} empty={isEmpty} />
        <div className="flex min-w-0 flex-1 flex-col gap-2.5">
          {MACRO_KEYS.map((k) => (
            <MacroBar key={k} macro={k} value={totals[k]} range={goals.ranges[k]} score={score.perMacro[k]} />
          ))}
        </div>
      </section>

      {entries === null && <p className="py-6 text-center text-xs text-muted">Cargando…</p>}

      {isEmpty && (
        <div className="card">
          <EmptyState icon={UtensilsCrossed} title="Sin registros este día">
            Usa <ListPlus className="inline size-3.5 text-primary" /> para pegar una lista como "Arroz 100g, Huevos x3".
          </EmptyState>
        </div>
      )}

      {entries &&
        MEAL_SLOTS.filter((slot) => entries.some((e) => e.meal === slot)).map((slot, sectionIndex) => {
          const items = entries.filter((e) => e.meal === slot)
          if (!items.length) return null
          const Icon = MEAL_META[slot].icon
          const subtotal = sumMacros(items.map((i) => i.macros))
          return (
            <section key={slot} className="card animate-fade-up overflow-hidden" style={stagger(sectionIndex, 80)} aria-label={MEAL_META[slot].label}>
              <header className="flex items-center justify-between gap-2 border-b border-border bg-surface-2/50 px-3 py-2">
                <span className="flex items-center gap-2 text-sm font-medium text-fg-strong">
                  <Icon className="size-4 text-primary" aria-hidden />
                  {MEAL_META[slot].label}
                </span>
                <MacroInline macros={subtotal} />
              </header>
              <ul className="divide-y divide-border">
                {items.map((e, i) => (
                  <li key={e.id} className="flex animate-fade-up items-center gap-2 px-3 py-2" style={stagger(sectionIndex * 3 + i, 30)}>
                    {e.kind === 'recipe' && <ChefHat className="size-3.5 shrink-0 text-primary" aria-label="Receta" />}
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm text-fg">{e.name}</p>
                      <p className="flex flex-wrap items-center gap-x-2 text-xs text-faint">
                        <span className="tabular-nums">
                          {e.servings !== null ? `${e.servings} porc. · ` : ''}
                          {Math.round(e.grams)} g
                        </span>
                        <MacroInline macros={e.macros} />
                      </p>
                    </div>
                    <IconButton icon={Trash2} label={`Eliminar ${e.name}`} variant="danger" onClick={() => remove(e)} />
                  </li>
                ))}
              </ul>
            </section>
          )
        })}
    </div>
  )
}
