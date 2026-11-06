import { macrosForGrams, roundMacros, round1, scaleMacros } from './macros'
import type { ParsedItem } from './parser/ruleParser'
import type { Food, Macros, Portion, Recipe } from './types'
import { GENERIC_G, GENERIC_ML, UNIT_LABELS, samePortionName } from './units'

export interface Amount {
  grams: number
  servings: number | null
  macros: Macros
  /** true cuando la cantidad o la porción se supusieron. */
  assumed: boolean
  /** Descripción legible, p. ej. "3 × unidad (50 g)". */
  label: string
}

const FALLBACK_GRAMS = 100
const DEFAULT_PORTIONS = ['unidad', 'mediano', 'porcion']

function findPortion(food: Food, name: string): Portion | undefined {
  return food.portions.find((p) => samePortionName(p.name, name))
}

function defaultPortion(food: Food): Portion | undefined {
  for (const n of DEFAULT_PORTIONS) {
    const p = findPortion(food, n)
    if (p) return p
  }
  return food.portions[0]
}

function fmt(n: number): string {
  return Number.isInteger(n) ? String(n) : String(round1(n))
}

/** Convierte la cantidad escrita a gramos usando las porciones del alimento. */
export function foodAmount(item: ParsedItem, food: Food): Amount {
  const density = food.density ?? 1
  const q = item.quantity ?? 1
  let assumed = item.quantity === null
  let grams: number
  let label: string

  if (item.unit === 'g') {
    grams = q
    label = `${fmt(q)} g`
  } else if (item.unit === 'ml') {
    grams = q * density
    label = `${fmt(q)} ml`
  } else {
    let portion: Portion | undefined
    if (item.size) portion = findPortion(food, item.size)
    if (!portion && item.unit && item.unit !== 'unidad') portion = findPortion(food, item.unit)
    if (!portion && (item.unit === null || item.unit === 'unidad' || item.size)) portion = defaultPortion(food)

    if (portion) {
      grams = q * portion.grams
      label = `${fmt(q)} × ${portion.name} (${fmt(portion.grams)} g)`
      if (item.size && !samePortionName(portion.name, item.size)) assumed = true
    } else if (item.unit && GENERIC_ML[item.unit]) {
      grams = q * GENERIC_ML[item.unit]! * density
      label = `${fmt(q)} × ${UNIT_LABELS[item.unit]} (${GENERIC_ML[item.unit]} ml)`
      assumed = true
    } else if (item.unit && GENERIC_G[item.unit]) {
      grams = q * GENERIC_G[item.unit]!
      label = `${fmt(q)} × ${UNIT_LABELS[item.unit]} (${GENERIC_G[item.unit]} g)`
      assumed = true
    } else {
      grams = FALLBACK_GRAMS
      label = `${FALLBACK_GRAMS} g (supuesto)`
      assumed = true
    }
  }

  grams = round1(grams)
  return { grams, servings: null, macros: macrosForGrams(food.per100g, grams), assumed, label }
}

/** Cantidad de una receta: por porciones ("2 porciones") o por peso ("300 g"). */
export function recipeAmount(item: ParsedItem, recipe: Recipe): Amount {
  if ((item.unit === 'g' || item.unit === 'ml') && item.quantity !== null) {
    return recipeAmountForGrams(recipe, item.quantity)
  }
  const servings = item.quantity ?? 1
  const gramsPerServing = recipe.servings > 0 ? recipe.totalGrams / recipe.servings : 0
  return {
    grams: round1(gramsPerServing * servings),
    servings,
    macros: roundMacros(scaleMacros(recipe.perServing, servings)),
    assumed: item.quantity === null,
    label: `${fmt(servings)} ${servings === 1 ? 'porción' : 'porciones'}`,
  }
}

export function recipeAmountForGrams(recipe: Recipe, grams: number): Amount {
  const ratio = recipe.totalGrams > 0 ? grams / recipe.totalGrams : 0
  return {
    grams: round1(grams),
    servings: round1(ratio * recipe.servings),
    macros: roundMacros(scaleMacros(recipe.totals, ratio)),
    assumed: false,
    label: `${fmt(grams)} g`,
  }
}
