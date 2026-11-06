import { macrosForGrams, roundMacros, scaleMacros, sumMacros } from './macros'
import type { Food, Macros, Recipe, RecipeIngredient } from './types'

export interface RecipeTotals {
  totalGrams: number
  totals: Macros
  perServing: Macros
  /** foodIds que no existen en el catálogo. */
  missing: string[]
}

export function computeRecipe(
  ingredients: RecipeIngredient[],
  servings: number,
  foods: Map<string, Food>,
): RecipeTotals {
  const missing: string[] = []
  const parts: Macros[] = []
  let totalGrams = 0
  for (const ing of ingredients) {
    const food = foods.get(ing.foodId)
    if (!food) {
      missing.push(ing.foodId)
      continue
    }
    totalGrams += ing.grams
    parts.push(macrosForGrams(food.per100g, ing.grams))
  }
  const totals = roundMacros(sumMacros(parts))
  const perServing = roundMacros(scaleMacros(totals, servings > 0 ? 1 / servings : 0))
  return { totalGrams, totals, perServing, missing }
}

/**
 * Recalcula los macros de una receta desde sus ingredientes actuales, de modo que
 * reflejen cambios en el catálogo. Si falta algún ingrediente conserva lo guardado.
 */
export function refreshRecipe(recipe: Recipe, foods: Map<string, Food>): Recipe {
  const t = computeRecipe(recipe.ingredients, recipe.servings, foods)
  if (t.missing.length > 0) return recipe
  return { ...recipe, totalGrams: t.totalGrams, totals: t.totals, perServing: t.perServing }
}
