import { ArrowLeft, Check, Plus, Trash2 } from 'lucide-react'
import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useUser } from '../../app/AuthProvider'
import { useData } from '../../app/DataProvider'
import { useToast } from '../../app/ToastProvider'
import { macrosForGrams } from '../../core/macros'
import { computeRecipe } from '../../core/recipe'
import type { Recipe, RecipeIngredient } from '../../core/types'
import { deleteRecipe, saveRecipe } from '../../services/recipes'
import { IconButton } from '../../ui/IconButton'
import { MacroInline } from '../../ui/MacroInline'
import { numOr } from '../../ui/num'
import { FoodForm } from '../foods/FoodForm'
import { FoodPicker } from '../foods/FoodPicker'

export function RecipeEditorPage() {
  const { id } = useParams()
  const { recipes, ready } = useData()
  if (!ready) return <p className="py-6 text-center text-xs text-muted">Cargando…</p>
  const recipe = id && id !== 'nueva' ? recipes.find((r) => r.id === id) : undefined
  if (id !== 'nueva' && !recipe) return <p className="py-6 text-center text-xs text-muted">Receta no encontrada.</p>
  return <RecipeEditor key={recipe?.id ?? 'nueva'} recipe={recipe} />
}

interface Row {
  foodId: string
  grams: string
}

function RecipeEditor({ recipe }: { recipe?: Recipe }) {
  const user = useUser()
  const toast = useToast()
  const navigate = useNavigate()
  const { ctx, foodMatcher } = useData()
  const [name, setName] = useState(recipe?.name ?? '')
  const [aliases, setAliases] = useState(recipe?.aliases.join(', ') ?? '')
  const [servings, setServings] = useState(String(recipe?.servings ?? 1))
  const [rows, setRows] = useState<Row[]>(recipe?.ingredients.map((i) => ({ foodId: i.foodId, grams: String(i.grams) })) ?? [])
  const [picking, setPicking] = useState(false)
  const [creating, setCreating] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  const ingredients: RecipeIngredient[] = rows.map((r) => ({ foodId: r.foodId, grams: Math.max(0, numOr(r.grams, 0)) }))
  const nServings = Math.max(0, numOr(servings, 0))
  const totals = computeRecipe(ingredients, nServings, ctx.foods)
  const valid = name.trim() !== '' && nServings > 0 && ingredients.length > 0 && totals.missing.length === 0 && ingredients.every((i) => i.grams > 0)

  const addFood = (foodId: string) => setRows((r) => [...r, { foodId, grams: '100' }])

  async function save() {
    setSaving(true)
    try {
      await saveRecipe(
        {
          ownerId: user.uid,
          name: name.trim(),
          aliases: aliases
            .split(',')
            .map((a) => a.trim())
            .filter(Boolean),
          servings: nServings,
          ingredients,
          totalGrams: totals.totalGrams,
          totals: totals.totals,
          perServing: totals.perServing,
        },
        recipe?.id,
      )
      toast('Receta guardada')
      navigate('/recetas', { replace: true })
    } catch (err) {
      toast((err as Error).message, 'error')
    } finally {
      setSaving(false)
    }
  }

  async function remove() {
    if (!recipe || !confirm(`¿Eliminar la receta "${recipe.name}"?`)) return
    try {
      await deleteRecipe(recipe.id)
      toast('Receta eliminada')
      navigate('/recetas', { replace: true })
    } catch (err) {
      toast((err as Error).message, 'error')
    }
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between gap-2">
        <IconButton icon={ArrowLeft} label="Volver a recetas" onClick={() => navigate('/recetas')} />
        <h1 className="flex-1 truncate text-sm font-semibold text-fg-strong">{recipe ? 'Editar receta' : 'Nueva receta'}</h1>
        {recipe && <IconButton icon={Trash2} label="Eliminar receta" variant="danger" onClick={remove} />}
        <IconButton icon={Check} label="Guardar receta" text="Guardar" variant="primary" size="md" disabled={!valid || saving} onClick={save} />
      </div>

      <section className="card grid gap-2 p-3 sm:grid-cols-[1fr_6rem]">
        <label className="flex flex-col gap-1">
          <span className="text-xs text-muted">Nombre (así la reconocerá la lista)</span>
          <input className="field" value={name} onChange={(e) => setName(e.target.value)} placeholder="Pollo al limón con arroz" maxLength={120} />
        </label>
        <label className="flex flex-col gap-1">
          <span className="text-xs text-muted">Porciones</span>
          <input className="field tabular-nums" inputMode="decimal" value={servings} onChange={(e) => setServings(e.target.value)} />
        </label>
        <label className="flex flex-col gap-1 sm:col-span-2">
          <span className="text-xs text-muted">Alias, separados por coma</span>
          <input className="field" value={aliases} onChange={(e) => setAliases(e.target.value)} placeholder="pollo al limon" />
        </label>
      </section>

      <section className="card overflow-hidden" aria-label="Ingredientes">
        <header className="flex items-center justify-between border-b border-border px-3 py-2">
          <span className="text-xs text-muted">Ingredientes</span>
          <IconButton icon={Plus} label="Agregar ingrediente" variant="soft" onClick={() => setPicking(true)} />
        </header>
        {rows.length === 0 && <p className="p-4 text-center text-xs text-muted">Agrega ingredientes desde el catálogo.</p>}
        <ul className="divide-y divide-border">
          {rows.map((row, i) => {
            const food = ctx.foods.get(row.foodId)
            const grams = numOr(row.grams, 0)
            return (
              <li key={i} className="flex items-center gap-2 px-3 py-2">
                <div className="min-w-0 flex-1">
                  <p className={`truncate text-sm ${food ? 'text-fg' : 'text-danger'}`}>{food?.name ?? 'Alimento eliminado'}</p>
                  {food && <MacroInline macros={macrosForGrams(food.per100g, grams)} />}
                </div>
                <input
                  className="field h-7 w-16 px-1.5 py-0 text-right text-xs tabular-nums"
                  inputMode="decimal"
                  value={row.grams}
                  onChange={(e) => setRows((r) => r.map((x, j) => (j === i ? { ...x, grams: e.target.value } : x)))}
                  aria-label={`Gramos de ${food?.name ?? 'ingrediente'}`}
                />
                <span className="text-xs text-faint">g</span>
                <IconButton icon={Trash2} label="Quitar ingrediente" variant="danger" onClick={() => setRows((r) => r.filter((_, j) => j !== i))} />
              </li>
            )
          })}
        </ul>
        {rows.length > 0 && (
          <footer className="grid gap-1 border-t border-border bg-surface-2/50 px-3 py-2 text-xs">
            <p className="flex flex-wrap items-center justify-between gap-2">
              <span className="text-muted">Total · {totals.totalGrams} g</span>
              <MacroInline macros={totals.totals} />
            </p>
            <p className="flex flex-wrap items-center justify-between gap-2">
              <span className="text-muted">Por porción · {nServings > 0 ? Math.round(totals.totalGrams / nServings) : 0} g</span>
              <MacroInline macros={totals.perServing} className="font-medium" />
            </p>
          </footer>
        )}
      </section>

      {picking && (
        <FoodPicker
          title="Agregar ingrediente"
          matcher={foodMatcher}
          onPick={(c) => {
            addFood(c.id)
            setPicking(false)
          }}
          onClose={() => setPicking(false)}
          onCreate={(n) => {
            setCreating(n)
            setPicking(false)
          }}
        />
      )}
      {creating !== null && <FoodForm initialName={creating} onClose={() => setCreating(null)} onSaved={(f) => addFood(f.id)} />}
    </div>
  )
}
