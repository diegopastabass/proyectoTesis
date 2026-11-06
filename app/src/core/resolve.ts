import { emptyMacros, macrosForGrams } from './macros'
import type { Candidate, Matcher } from './matcher'
import { parseText, type ParsedItem } from './parser/ruleParser'
import { foodAmount, recipeAmount, recipeAmountForGrams, type Amount } from './quantity'
import type { Food, Macros, Recipe } from './types'

/** Desde esta confianza el ítem se acepta sin revisión. */
export const ACCEPT_CONFIDENCE = 0.85
/** Bajo esta confianza se considera que el alimento no está en el catálogo. */
export const MISSING_CONFIDENCE = 0.6
/** Si el segundo candidato está así de cerca del primero, se pide revisión. */
const AMBIGUITY_MARGIN = 0.03

export type ItemStatus = 'ok' | 'review' | 'missing'

export interface ResolvedItem {
  key: string
  parsed: ParsedItem
  match: Candidate | null
  alternatives: Candidate[]
  grams: number
  servings: number | null
  macros: Macros
  assumed: boolean
  label: string
  status: ItemStatus
}

export interface ResolveContext {
  matcher: Matcher
  foods: Map<string, Food>
  recipes: Map<string, Recipe>
}

const ZERO: Amount = { grams: 0, servings: null, macros: emptyMacros(), assumed: false, label: '' }

function amountFor(parsed: ParsedItem, match: Candidate, ctx: ResolveContext): Amount | null {
  if (match.kind === 'food') {
    const food = ctx.foods.get(match.id)
    return food ? foodAmount(parsed, food) : null
  }
  const recipe = ctx.recipes.get(match.id)
  return recipe ? recipeAmount(parsed, recipe) : null
}

function statusFor(match: Candidate | null, alternatives: Candidate[], assumed: boolean, forced: boolean): ItemStatus {
  if (!match) return 'missing'
  if (forced) return 'ok'
  const second = alternatives.find((c) => c.id !== match.id || c.kind !== match.kind)
  const ambiguous = match.confidence < 1 && second !== undefined && match.confidence - second.confidence <= AMBIGUITY_MARGIN
  if (match.confidence < ACCEPT_CONFIDENCE || ambiguous || assumed) return 'review'
  return 'ok'
}

/** Resuelve un ítem. `forced` = candidato elegido por el usuario. */
export function resolveItem(parsed: ParsedItem, ctx: ResolveContext, key: string, forced?: Candidate): ResolvedItem {
  const alternatives = ctx.matcher.search(parsed.query, 6)
  const best = forced ?? alternatives[0] ?? null
  const match = best && (forced || best.confidence >= MISSING_CONFIDENCE) ? best : null
  const amount = (match && amountFor(parsed, match, ctx)) ?? ZERO
  return {
    key,
    parsed,
    match,
    alternatives,
    ...amount,
    status: statusFor(match, alternatives, amount.assumed, forced !== undefined),
  }
}

export function resolveText(text: string, ctx: ResolveContext): ResolvedItem[] {
  return parseText(text).map((p, i) => resolveItem(p, ctx, `${i}-${p.raw}`))
}

/** Recalcula un ítem cuando el usuario corrige los gramos a mano. */
export function withGrams(item: ResolvedItem, grams: number, ctx: ResolveContext): ResolvedItem {
  if (!item.match || !(grams >= 0)) return item
  if (item.match.kind === 'food') {
    const food = ctx.foods.get(item.match.id)
    if (!food) return item
    return { ...item, grams, macros: macrosForGrams(food.per100g, grams), assumed: false, label: `${grams} g`, status: 'ok' }
  }
  const recipe = ctx.recipes.get(item.match.id)
  if (!recipe) return item
  return { ...item, ...recipeAmountForGrams(recipe, grams), status: 'ok' }
}
