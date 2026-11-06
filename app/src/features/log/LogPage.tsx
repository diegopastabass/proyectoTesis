import { Check, ScanBarcode, ScanText } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useUser } from '../../app/AuthProvider'
import { useData } from '../../app/DataProvider'
import { useToast } from '../../app/ToastProvider'
import { useDateParam } from '../../app/useDateParam'
import { sumMacros } from '../../core/macros'
import type { Candidate } from '../../core/matcher'
import { resolveItem, resolveText, withGrams, type ResolvedItem } from '../../core/resolve'
import { MEAL_SLOTS, type Food, type MealSlot, type NewDiaryEntry } from '../../core/types'
import { addEntries } from '../../services/diary'
import { DateNav } from '../../ui/DateNav'
import { IconButton } from '../../ui/IconButton'
import { MacroInline } from '../../ui/MacroInline'
import { MEAL_META, mealForNow } from '../../ui/meta'
import { BarcodeScanner } from '../barcode/BarcodeScanner'
import { FoodForm } from '../foods/FoodForm'
import { FoodPicker } from '../foods/FoodPicker'
import { ItemRow } from './ItemRow'

const PLACEHOLDER = 'Arroz 100g\n1 Tomate mediano\nHuevos x3\nAtún 150g'

export function LogPage() {
  const user = useUser()
  const toast = useToast()
  const navigate = useNavigate()
  const { ctx, ready } = useData()
  const [date, setDate] = useDateParam()
  const [meal, setMeal] = useState<MealSlot>(() => mealForNow())
  const [text, setText] = useState('')
  const [items, setItems] = useState<ResolvedItem[] | null>(null)
  const [picking, setPicking] = useState<ResolvedItem | null>(null)
  const [creating, setCreating] = useState<{ key: string; name: string } | null>(null)
  const [saving, setSaving] = useState(false)
  const [scanning, setScanning] = useState(false)
  /** Código escaneado que no está en el catálogo: se abre el formulario para crearlo. */
  const [unknownCode, setUnknownCode] = useState<string | null>(null)

  const analyze = () => {
    // Los ítems escaneados se conservan al volver a analizar el texto.
    const scanned = (items ?? []).filter((it) => it.key.startsWith('scan-'))
    // Con el campo vacío (y nada escaneado) se analiza el ejemplo, para probar rápido el flujo.
    const input = text.trim() ? text : scanned.length ? '' : PLACEHOLDER
    if (input !== text) setText(input)
    setItems([...resolveText(input, ctx), ...scanned])
  }

  /** Agrega un alimento escaneado con su porción por defecto, para que el usuario la ajuste. */
  const addScanned = (food: Food, code: string) => {
    const local = { ...ctx, foods: new Map(ctx.foods).set(food.id, food) }
    const parsed = { raw: `Código ${code}`, query: food.name, quantity: null, unit: null, size: null }
    const item = resolveItem(parsed, local, `scan-${code}-${Date.now()}`, { kind: 'food', id: food.id, name: food.name, confidence: 1 })
    setItems((list) => [...(list ?? []), { ...item, status: item.assumed ? 'review' : 'ok' }])
    toast(`${food.name}: ajusta la porción`)
  }

  const onScanned = (code: string) => {
    setScanning(false)
    const matches = [...ctx.foods.values()].filter((f) => f.barcode === code)
    if (matches.length === 0) {
      setUnknownCode(code)
      return
    }
    addScanned(matches[0], code)
  }
  const update = (key: string, fn: (it: ResolvedItem) => ResolvedItem) =>
    setItems((list) => list?.map((it) => (it.key === key ? fn(it) : it)) ?? null)

  /** Asigna un alimento recién creado sin esperar a que llegue al catálogo. */
  const assignCreated = (key: string, food: Food) => {
    const local = { ...ctx, foods: new Map(ctx.foods).set(food.id, food) }
    update(key, (it) => resolveItem(it.parsed, local, it.key, { kind: 'food', id: food.id, name: food.name, confidence: 1 }))
  }

  const pick = (c: Candidate) => {
    if (picking) update(picking.key, (it) => resolveItem(it.parsed, ctx, it.key, c))
    setPicking(null)
  }

  const counts = useMemo(() => {
    const c = { ok: 0, review: 0, missing: 0 }
    for (const it of items ?? []) c[it.status]++
    return c
  }, [items])
  const totals = sumMacros((items ?? []).filter((i) => i.match).map((i) => i.macros))
  const canSave = !!items?.length && counts.missing === 0 && !saving

  async function save() {
    if (!items) return
    const entries: NewDiaryEntry[] = items.map((it) => ({
      kind: it.match!.kind,
      refId: it.match!.id,
      name: it.match!.name,
      grams: it.grams,
      servings: it.servings,
      macros: it.macros,
      meal,
      rawInput: it.parsed.raw,
    }))
    setSaving(true)
    try {
      await addEntries(user.uid, date, entries)
      toast(`${entries.length} alimento${entries.length === 1 ? '' : 's'} registrado${entries.length === 1 ? '' : 's'}`)
      navigate(`/?d=${date}`)
    } catch (err) {
      toast((err as Error).message, 'error')
      setSaving(false)
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <DateNav date={date} onChange={setDate} />
        <div className="flex gap-1" role="radiogroup" aria-label="Comida">
          {MEAL_SLOTS.map((m) => {
            const Icon = MEAL_META[m].icon
            return (
              <IconButton
                key={m}
                icon={Icon}
                label={MEAL_META[m].label}
                role="radio"
                aria-checked={meal === m}
                variant={meal === m ? 'soft' : 'ghost'}
                className={meal === m ? 'ring-1 ring-primary/50' : ''}
                onClick={() => setMeal(m)}
              />
            )
          })}
        </div>
      </div>

      <section className="card p-3">
        <textarea
          className="field min-h-32 w-full resize-y font-mono leading-relaxed"
          placeholder={PLACEHOLDER}
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) analyze()
          }}
          aria-label="Lista de alimentos, uno por línea"
          spellCheck={false}
        />
        <div className="mt-2 flex items-center justify-between gap-2">
          <p className="text-[11px] text-faint">Una línea por alimento · Ctrl+Enter para analizar</p>
          <div className="flex gap-1.5">
            <IconButton icon={ScanBarcode} label="Escanear código de barras" variant="soft" onClick={() => setScanning(true)} disabled={!ready} />
            <IconButton icon={ScanText} label="Analizar lista" text="Analizar" variant="primary" onClick={analyze} disabled={!ready} />
          </div>
        </div>
      </section>

      {items && (
        <section className="card overflow-hidden" aria-label="Resultado">
          {items.length === 0 ? (
            <p className="p-4 text-center text-xs text-muted">No se reconocieron ítems en el texto.</p>
          ) : (
            <ul className="divide-y divide-border">
              {items.map((it, i) => (
                <ItemRow
                  key={it.key}
                  index={i}
                  item={it}
                  onPick={() => setPicking(it)}
                  onCreate={() => setCreating({ key: it.key, name: it.parsed.query })}
                  onGrams={(g) => update(it.key, (x) => withGrams(x, g, ctx))}
                  onRemove={() => setItems((l) => l?.filter((x) => x.key !== it.key) ?? null)}
                />
              ))}
            </ul>
          )}

          {items.length > 0 && (
            <footer className="flex flex-wrap items-center justify-between gap-2 border-t border-border bg-surface-2/50 px-3 py-2">
              <div className="flex flex-col gap-0.5">
                <MacroInline macros={totals} className="text-sm" />
                <span className="text-[11px] text-faint">
                  {counts.ok} ok · {counts.review} revisar · {counts.missing} faltan
                  {counts.missing > 0 && ' — crea o busca los faltantes para guardar'}
                </span>
              </div>
              <IconButton icon={Check} label="Guardar en el diario" text="Guardar" variant="primary" size="md" onClick={save} disabled={!canSave} />
            </footer>
          )}
        </section>
      )}

      {picking && (
        <FoodPicker
          title="Elegir alimento o receta"
          matcher={ctx.matcher}
          initialQuery={picking.parsed.query}
          onPick={pick}
          onClose={() => setPicking(null)}
          onCreate={(name) => {
            setCreating({ key: picking.key, name })
            setPicking(null)
          }}
        />
      )}

      {scanning && <BarcodeScanner onDetected={onScanned} onClose={() => setScanning(false)} />}

      {unknownCode && (
        <FoodForm
          initialBarcode={unknownCode}
          autoLookup
          onClose={() => setUnknownCode(null)}
          onSaved={(food) => addScanned(food, unknownCode)}
        />
      )}

      {creating && (
        <FoodForm
          initialName={creating.name}
          onClose={() => setCreating(null)}
          onSaved={(food) => assignCreated(creating.key, food)}
        />
      )}
    </div>
  )
}
