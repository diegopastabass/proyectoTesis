import { describe, expect, it } from 'vitest'
import { seedFoods } from '../../data/seed'
import { buildCatalog, Matcher, phraseSimilarity } from '../matcher'
import { computeRecipe, refreshRecipe } from '../recipe'
import { resolveText, withGrams, type ResolveContext } from '../resolve'
import type { Recipe } from '../types'

const foods = seedFoods('test')
const foodsById = new Map(foods.map((f) => [f.id, f]))

function makeRecipe(): Recipe {
  const ingredients = [
    { foodId: 'pechuga-pollo-cocida', grams: 400 },
    { foodId: 'arroz-blanco-cocido', grams: 400 },
    { foodId: 'aceite-oliva', grams: 20 },
  ]
  const t = computeRecipe(ingredients, 4, foodsById)
  return {
    id: 'r1',
    ownerId: 'test',
    name: 'Pollo al limón con arroz',
    aliases: ['pollo al limon'],
    servings: 4,
    ingredients,
    totalGrams: t.totalGrams,
    totals: t.totals,
    perServing: t.perServing,
  }
}

function context(recipes: Recipe[] = []): ResolveContext {
  return {
    matcher: new Matcher(buildCatalog(foods, recipes)),
    foods: foodsById,
    recipes: new Map(recipes.map((r) => [r.id, r])),
  }
}

describe('fibra', () => {
  it('se calcula por cantidad igual que el resto de los macros', () => {
    const [item] = resolveText('avena 50g', context())
    expect(item.macros.fiber).toBeCloseTo(5.1, 1)
  })

  it('las recetas suman la fibra de sus ingredientes', () => {
    const t = computeRecipe(
      [
        { foodId: 'avena-hojuelas', grams: 100 },
        { foodId: 'platano', grams: 100 },
      ],
      2,
      foodsById,
    )
    expect(t.totals.fiber).toBeCloseTo(12.7, 1)
    expect(t.perServing.fiber).toBeCloseTo(6.4, 1)
  })

  it('recalcula una receta guardada sin fibra con el catálogo actual', () => {
    const old = makeRecipe()
    const stale = { ...old, totals: { ...old.totals, fiber: 0 }, perServing: { ...old.perServing, fiber: 0 } }
    const fresh = refreshRecipe(stale, foodsById)
    expect(fresh.totals.fiber).toBeGreaterThan(0)
    expect(fresh.perServing.fiber).toBeCloseTo(fresh.totals.fiber / 4, 1)
  })

  it('conserva lo guardado si falta un ingrediente en el catálogo', () => {
    const r = { ...makeRecipe(), ingredients: [{ foodId: 'no-existe', grams: 100 }] }
    expect(refreshRecipe(r, foodsById)).toBe(r)
  })
})

describe('phraseSimilarity', () => {
  it('es 1 para frases iguales y menor para frases parciales', () => {
    expect(phraseSimilarity('arroz', 'arroz')).toBe(1)
    expect(phraseSimilarity('pan', 'pan marraqueta')).toBeCloseTo(0.667, 2)
    expect(phraseSimilarity('arros', 'arroz')).toBeGreaterThanOrEqual(0.8)
    expect(phraseSimilarity('sushi', 'arroz')).toBe(0)
  })
})

describe('Matcher', () => {
  const m = context().matcher

  it('encuentra por alias exacto y por plural', () => {
    expect(m.search('arroz')[0]).toMatchObject({ id: 'arroz-blanco-cocido', confidence: 1 })
    expect(m.search('huevos')[0]).toMatchObject({ id: 'huevo-entero', confidence: 1 })
    expect(m.search('tomates')[0]).toMatchObject({ id: 'tomate', confidence: 1 })
  })

  it('tolera errores de tipeo', () => {
    expect(m.search('platno')[0].id).toBe('platano')
    expect(m.search('marraquta')[0].id).toBe('pan-marraqueta')
  })

  it('no inventa coincidencias para alimentos ausentes', () => {
    const best = m.search('sushi')[0]
    expect(best === undefined || best.confidence < 0.6).toBe(true)
  })
})

describe('resolveText', () => {
  it('resuelve la lista de ejemplo con gramos y macros', () => {
    const items = resolveText('Arroz 100g\n1 Tomate mediano\nHuevos x3\nAtún 150g', context())
    expect(items.map((i) => [i.match?.id, i.grams, i.status])).toEqual([
      ['arroz-blanco-cocido', 100, 'ok'],
      ['tomate', 123, 'ok'],
      ['huevo-entero', 150, 'ok'],
      ['atun-lata-agua', 150, 'ok'],
    ])
    expect(items[0].macros).toEqual({ kcal: 130, protein: 2.7, carbs: 28.2, fat: 0.3, fiber: 0.4 })
    expect(items[2].macros.protein).toBeCloseTo(18.9, 1)
  })

  it('marca como faltante lo que no está en el catálogo', () => {
    const [item] = resolveText('sushi 200g', context())
    expect(item.status).toBe('missing')
    expect(item.match).toBeNull()
  })

  it('pide revisión cuando la cantidad se supone', () => {
    const [item] = resolveText('un poco de aceite', context())
    expect(item.match?.id).toBe('aceite-oliva')
    expect(item.status).toBe('review')
    expect(item.assumed).toBe(true)
  })

  it('usa porciones genéricas si el alimento no las define', () => {
    const [item] = resolveText('2 tazas de lentejas', context())
    expect(item.grams).toBe(396)
    const [glass] = resolveText('1 vaso de cerveza', context())
    expect(glass.grams).toBe(300)
  })

  it('reconoce recetas por nombre y calcula por porción o por peso', () => {
    const recipe = makeRecipe()
    const ctx = context([recipe])
    const [byServing] = resolveText('pollo al limón 2 porciones', ctx)
    expect(byServing.match).toMatchObject({ kind: 'recipe', id: 'r1' })
    expect(byServing.servings).toBe(2)
    expect(byServing.macros.kcal).toBe(Math.round(recipe.perServing.kcal * 2))

    const [byGrams] = resolveText('pollo al limon 205g', ctx)
    expect(byGrams.servings).toBe(1)
  })

  it('recalcula al corregir gramos', () => {
    const ctx = context()
    const [item] = resolveText('arroz', ctx)
    const edited = withGrams(item, 200, ctx)
    expect(edited.macros.kcal).toBe(260)
    expect(edited.status).toBe('ok')
  })
})
