import { Calculator, Check, CircleCheck, ExternalLink, Globe, LoaderCircle, Plus, ScanBarcode, Trash2, TriangleAlert } from 'lucide-react'
import { useEffect, useRef, useState, type FormEvent } from 'react'
import { useUser } from '../../app/AuthProvider'
import { useData } from '../../app/DataProvider'
import { useToast } from '../../app/ToastProvider'
import { isValidGtin, normalizeBarcode } from '../../core/barcode'
import { estimateKcal } from '../../core/macros'
import { normalize } from '../../core/normalize'
import type { OffDraft } from '../../core/openFoodFacts'
import { MACRO_KEYS, type Food, type FoodSource, type MacroKey } from '../../core/types'
import { createFood, updateFood, USER_SOURCE, type FoodInput } from '../../services/foods'
import { lookupBarcode } from '../../services/openFoodFacts'
import { BarcodeScanner } from '../barcode/BarcodeScanner'
import { IconButton } from '../../ui/IconButton'
import { MACRO_META } from '../../ui/meta'
import { Modal } from '../../ui/Modal'
import { parseNum } from '../../ui/num'

interface Props {
  food?: Food
  initialName?: string
  initialBarcode?: string
  /** Busca el código inicial en Open Food Facts al abrir. */
  autoLookup?: boolean
  onClose: () => void
  onSaved?: (food: Food) => void
}

interface EquivalenceRow {
  name: string
  grams: string
}

/** Medidas que la lista en lenguaje natural sabe interpretar. "ml" guarda la densidad. */
const MEASURES: { name: string; hint: string }[] = [
  { name: 'unidad', hint: '1 pieza: un huevo, una manzana…' },
  { name: 'pequeño', hint: '"1 tomate pequeño"' },
  { name: 'mediano', hint: '"1 tomate mediano"' },
  { name: 'grande', hint: '"1 tomate grande"' },
  { name: 'taza', hint: '"2 tazas de arroz"' },
  { name: 'vaso', hint: '"1 vaso de leche"' },
  { name: 'cda', hint: 'cucharada' },
  { name: 'cdta', hint: 'cucharadita' },
  { name: 'rebanada', hint: 'rebanada o lámina' },
  { name: 'lata', hint: '"1 lata de atún"' },
  { name: 'scoop', hint: 'medida de proteína en polvo' },
  { name: 'porción', hint: '"2 porciones"' },
  { name: 'ml', hint: 'solo líquidos: cuánto pesa 1 ml (agua = 1)' },
]

type Lookup = { state: 'idle' | 'loading' | 'notfound' } | { state: 'found'; url: string } | { state: 'error'; message: string }

/** Tolerancia para avisar que las kcal no calzan con los macros (alcohol, polialcoholes o errores de etiqueta). */
const KCAL_TOLERANCE = 0.2

const str = (n: number | null | undefined) => (n === null || n === undefined ? '' : String(n))
const sameName = (a: string, b: string) => normalize(a) === normalize(b)

export function FoodForm({ food, initialName = '', initialBarcode = '', autoLookup = false, onClose, onSaved }: Props) {
  const user = useUser()
  const toast = useToast()
  const { foods } = useData()
  const [barcode, setBarcode] = useState(food?.barcode ?? initialBarcode)
  const [scanning, setScanning] = useState(false)
  const [lookup, setLookup] = useState<Lookup>({ state: autoLookup && initialBarcode ? 'loading' : 'idle' })
  const [offSource, setOffSource] = useState<FoodSource | null>(null)
  const [name, setName] = useState(food?.name ?? capitalize(initialName))
  const [brand, setBrand] = useState(food?.brand ?? '')
  const [aliases, setAliases] = useState(food?.aliases.join(', ') ?? '')
  const [macros, setMacros] = useState<Record<MacroKey, string>>({
    kcal: str(food?.per100g.kcal),
    protein: str(food?.per100g.protein),
    carbs: str(food?.per100g.carbs),
    fat: str(food?.per100g.fat),
    fiber: str(food?.per100g.fiber),
  })
  const [rows, setRows] = useState<EquivalenceRow[]>(() => {
    if (!food) return [{ name: 'unidad', grams: '' }]
    const list = food.portions.map((p) => ({ name: p.name, grams: String(p.grams) }))
    if (food.density) list.push({ name: 'ml', grams: String(food.density) })
    return list
  })
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const p = parseNum(macros.protein)
  const c = parseNum(macros.carbs)
  const f = parseNum(macros.fat)
  const canEstimate = [p, c, f].every(Number.isFinite)

  const k = parseNum(macros.kcal)
  const estimated = canEstimate ? estimateKcal(p, c, f) : NaN
  const kcalMismatch = Number.isFinite(k) && estimated > 0 && Math.abs(k - estimated) > Math.max(25, estimated * KCAL_TOLERANCE)

  const code = normalizeBarcode(barcode)
  const codeValid = isValidGtin(code)
  const duplicate = codeValid ? foods.find((x) => x.barcode === code && x.id !== food?.id) : undefined

  const setMacro = (key: MacroKey, v: string) => setMacros((m) => ({ ...m, [key]: v }))

  /** Completa solo los campos vacíos, para no pisar lo que el usuario ya escribió. */
  function applyDraft(draft: OffDraft) {
    if (draft.name) setName((v) => v.trim() || draft.name)
    if (draft.brand) setBrand((v) => v.trim() || draft.brand!)
    const per100g = draft.per100g
    if (per100g) setMacros((m) => Object.fromEntries(MACRO_KEYS.map((key) => [key, m[key].trim() || String(per100g[key])])) as Record<MacroKey, string>)
    if (draft.servingGrams) {
      const grams = String(draft.servingGrams)
      setRows((r) => (r.some((x) => sameName(x.name, 'porción')) ? r : [...r.filter((x) => x.name !== 'unidad' || x.grams), { name: 'porción', grams }]))
    }
    setOffSource({ type: 'OFF', ref: draft.barcode, license: 'ODbL' })
  }

  async function fetchDraft(target: string) {
    try {
      const draft = await lookupBarcode(target)
      if (!draft) {
        setLookup({ state: 'notfound' })
        return
      }
      applyDraft(draft)
      setLookup({ state: 'found', url: draft.url })
    } catch (err) {
      setLookup({ state: 'error', message: (err as Error).message })
    }
  }

  function searchOff(target: string) {
    setLookup({ state: 'loading' })
    void fetchDraft(target)
  }

  // Al abrir desde un escaneo sin coincidencias, se busca el producto de inmediato.
  const autoLookupDone = useRef(false)
  useEffect(() => {
    if (!autoLookup || !initialBarcode || autoLookupDone.current) return
    autoLookupDone.current = true
    void fetchDraft(normalizeBarcode(initialBarcode))
    // eslint-disable-next-line react-hooks/exhaustive-deps -- solo al montar
  }, [])
  const setGrams = (name: string, grams: string) => setRows((r) => r.map((x) => (x.name === name ? { ...x, grams } : x)))
  const available = MEASURES.filter((m) => !rows.some((r) => sameName(r.name, m.name)))

  async function submit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (barcode.trim() && !codeValid) {
      setError('El código de barras no es válido: revisa los dígitos.')
      return
    }
    const per100g = {} as Record<MacroKey, number>
    for (const key of MACRO_KEYS) {
      let v = parseNum(macros[key])
      if (key === 'kcal' && !Number.isFinite(v) && canEstimate) v = estimateKcal(p, c, f)
      if (key === 'fiber' && macros.fiber.trim() === '') v = 0
      if (!Number.isFinite(v) || v < 0) {
        setError(`Revisa el valor de ${MACRO_META[key].label.toLowerCase()}.`)
        return
      }
      per100g[key] = v
    }
    if (per100g.protein + per100g.carbs + per100g.fat > 100) {
      setError('La suma de proteína, carbohidratos y grasa supera 100 g por 100 g.')
      return
    }
    const ml = rows.find((r) => r.name === 'ml')
    const density = ml ? parseNum(ml.grams) : NaN
    const input: FoodInput = {
      name: name.trim(),
      brand: brand.trim() || null,
      barcode: barcode.trim() ? code : null,
      aliases: aliases
        .split(',')
        .map((a) => a.trim())
        .filter(Boolean),
      per100g,
      portions: rows
        .filter((r) => r.name !== 'ml')
        .map((r) => ({ name: r.name.trim(), grams: parseNum(r.grams) }))
        .filter((r) => r.name && Number.isFinite(r.grams) && r.grams > 0),
      density: Number.isFinite(density) && density > 0 ? density : null,
    }
    setSaving(true)
    try {
      let saved: Food
      if (food) {
        await updateFood(food.id, input)
        saved = { ...food, ...input, fiberMissing: false }
      } else {
        const source = offSource ?? USER_SOURCE
        const id = await createFood(input, user.uid, source)
        saved = { ...input, id, source, verified: false, createdBy: user.uid, fiberMissing: false }
      }
      toast(food ? 'Alimento actualizado' : 'Alimento creado')
      onSaved?.(saved)
      onClose()
    } catch (err) {
      setError((err as Error).message)
      setSaving(false)
    }
  }

  return (
    <Modal title={food ? 'Editar alimento' : 'Nuevo alimento'} onClose={onClose}>
      <form onSubmit={submit} className="flex flex-col gap-4">
        <div className="flex flex-col gap-1">
          <span className="text-xs text-muted">Código de barras (opcional)</span>
          <div className="flex items-center gap-1.5">
            <input
              className="field min-w-0 flex-1 tabular-nums"
              inputMode="numeric"
              autoComplete="off"
              placeholder="Escanéalo o escríbelo"
              value={barcode}
              onChange={(e) => {
                setBarcode(e.target.value)
                setLookup({ state: 'idle' })
              }}
              aria-label="Código de barras"
            />
            <IconButton icon={ScanBarcode} label="Escanear con la cámara" variant="soft" size="md" onClick={() => setScanning(true)} />
            <IconButton
              icon={Globe}
              label="Buscar datos en Open Food Facts"
              variant="soft"
              size="md"
              disabled={!codeValid || lookup.state === 'loading'}
              onClick={() => searchOff(code)}
            />
          </div>
          {lookup.state === 'loading' && (
            <p className="flex items-center gap-1.5 text-[11px] text-muted">
              <LoaderCircle className="size-3.5 animate-spin" aria-hidden /> Buscando en Open Food Facts…
            </p>
          )}
          {lookup.state === 'found' && (
            <p className="flex animate-fade-in flex-wrap items-center gap-1.5 text-[11px] text-muted">
              <CircleCheck className="size-3.5 text-success" aria-hidden />
              Datos de Open Food Facts cargados. Compáralos con la etiqueta antes de guardar.
              <a href={lookup.url} target="_blank" rel="noreferrer" className="inline-flex items-center gap-0.5 text-primary hover:underline">
                ver ficha <ExternalLink className="size-3" aria-hidden />
              </a>
            </p>
          )}
          {lookup.state === 'notfound' && <p className="animate-fade-in text-[11px] text-muted">No está en Open Food Facts: complétalo con la etiqueta.</p>}
          {lookup.state === 'error' && <p className="animate-fade-in text-[11px] text-danger">{lookup.message}</p>}
          {duplicate && (
            <p className="flex animate-fade-in items-center gap-1.5 text-[11px] text-warning">
              <TriangleAlert className="size-3.5" aria-hidden /> Ya existe «{duplicate.name}» con este código.
            </p>
          )}
        </div>

        <div className="grid gap-2 sm:grid-cols-2">
          <label className="flex flex-col gap-1 sm:col-span-2">
            <span className="text-xs text-muted">Nombre</span>
            <input className="field" required maxLength={120} value={name} onChange={(e) => setName(e.target.value)} autoFocus={!autoLookup} />
          </label>
          <label className="flex flex-col gap-1">
            <span className="text-xs text-muted">Marca (opcional)</span>
            <input className="field" value={brand} onChange={(e) => setBrand(e.target.value)} />
          </label>
          <label className="flex flex-col gap-1">
            <span className="text-xs text-muted">Alias, separados por coma</span>
            <input className="field" value={aliases} onChange={(e) => setAliases(e.target.value)} placeholder="ej: palta, aguacate" />
          </label>
        </div>

        <fieldset className="flex flex-col gap-2">
          <legend className="mb-1 flex w-full items-center justify-between text-xs text-muted">
            <span>Valores por 100 g</span>
            <IconButton
              icon={Calculator}
              label="Calcular kcal desde los macros (4/4/9)"
              disabled={!canEstimate}
              onClick={() => setMacro('kcal', String(estimateKcal(p, c, f)))}
            />
          </legend>
          <div className="grid grid-cols-5 gap-1.5">
            {MACRO_KEYS.map((key) => (
              <label key={key} className="flex min-w-0 flex-col gap-1">
                <span className={`truncate text-[11px] ${MACRO_META[key].text}`} title={MACRO_META[key].label}>
                  {MACRO_META[key].short}
                  {key !== 'kcal' && <span className="text-faint"> {MACRO_META[key].unit}</span>}
                </span>
                <input
                  className="field w-full min-w-0 px-1.5 text-center tabular-nums"
                  inputMode="decimal"
                  value={macros[key]}
                  onChange={(e) => setMacro(key, e.target.value)}
                  placeholder={key === 'kcal' && canEstimate ? String(estimated) : '0'}
                  aria-label={`${MACRO_META[key].label} por 100 g`}
                />
              </label>
            ))}
          </div>
          {kcalMismatch && (
            <p className="flex animate-fade-in items-start gap-1.5 text-[11px] leading-snug text-warning">
              <TriangleAlert className="mt-px size-3.5 shrink-0" aria-hidden />
              Las kcal no calzan con los macros (≈ {estimated} kcal según 4/4/9). Revisa la etiqueta; puede ser un error de digitación.
            </p>
          )}
          <p className="text-[11px] leading-snug text-faint">
            La fibra es opcional. Copia los carbohidratos tal como vienen en la etiqueta (según el país o la fuente, pueden incluir o no la fibra).
          </p>
        </fieldset>

        <fieldset className="flex flex-col gap-2">
          <legend className="mb-1 text-xs text-muted">Equivalencias en gramos (opcional)</legend>
          <p className="text-[11px] leading-snug text-faint">
            Sirven para que la lista entienda medidas como <span className="text-muted">"Huevos x3"</span> o <span className="text-muted">"2 tazas de arroz"</span>.
            Toca una medida y escribe cuánto pesa. Ej.: <span className="text-muted">1 unidad = 50 g</span>. Si no pones nada, solo se entenderán gramos
            (<span className="text-muted">"150g"</span>).
          </p>

          {rows.length > 0 && (
            <ul className="flex flex-col gap-1.5">
              {rows.map((row) => (
                <li key={row.name} className="flex items-center gap-2">
                  <span className="w-24 shrink-0 text-sm text-fg">1 {row.name}</span>
                  <span className="text-faint">=</span>
                  <input
                    className="field w-20 min-w-0 tabular-nums"
                    inputMode="decimal"
                    placeholder={row.name === 'ml' ? '1' : '0'}
                    value={row.grams}
                    onChange={(e) => setGrams(row.name, e.target.value)}
                    aria-label={`Gramos de 1 ${row.name}`}
                  />
                  <span className="text-xs text-faint">g</span>
                  <IconButton icon={Trash2} label={`Quitar ${row.name}`} variant="danger" onClick={() => setRows((r) => r.filter((x) => x.name !== row.name))} />
                </li>
              ))}
            </ul>
          )}

          {available.length > 0 && (
            <div className="flex flex-wrap items-center gap-1.5">
              <span className="text-[11px] text-faint">Agregar:</span>
              {available.map((m) => (
                <button
                  key={m.name}
                  type="button"
                  title={m.hint}
                  aria-label={`Agregar equivalencia de ${m.name}`}
                  onClick={() => setRows((r) => [...r, { name: m.name, grams: '' }])}
                  className="inline-flex items-center gap-1 rounded-full border border-border px-2 py-0.5 text-xs text-muted transition hover:border-primary hover:text-primary"
                >
                  <Plus className="size-3" aria-hidden />
                  {m.name}
                </button>
              ))}
            </div>
          )}
        </fieldset>

        {error && <p className="animate-shake text-xs text-danger" role="alert">{error}</p>}

        <div className="flex justify-end">
          <IconButton type="submit" icon={Check} label="Guardar alimento" text="Guardar" variant="primary" size="md" disabled={saving || !name.trim()} />
        </div>
      </form>

      {scanning && (
        <BarcodeScanner
          onClose={() => setScanning(false)}
          onDetected={(scanned) => {
            setScanning(false)
            setBarcode(scanned)
            // Si el formulario aún está vacío, se intenta completar con Open Food Facts.
            if (!name.trim() || MACRO_KEYS.every((key) => !macros[key].trim())) searchOff(scanned)
            else setLookup({ state: 'idle' })
          }}
        />
      )}
    </Modal>
  )
}

function capitalize(s: string): string {
  return s ? s[0].toUpperCase() + s.slice(1) : s
}
