export const MACRO_KEYS = ['kcal', 'protein', 'carbs', 'fat', 'fiber'] as const
export type MacroKey = (typeof MACRO_KEYS)[number]
export type Macros = Record<MacroKey, number>

export interface Portion {
  /** Nombre de la porción: "unidad", "mediano", "taza", "rebanada"... */
  name: string
  grams: number
}

export type FoodSourceType = 'USDA' | 'OFF' | 'CHILE_TABLE' | 'USER' | 'MANUAL'

export interface FoodSource {
  type: FoodSourceType
  ref: string | null
  license: string | null
}

export interface Food {
  id: string
  name: string
  aliases: string[]
  brand: string | null
  /** GTIN normalizado (ver core/barcode). */
  barcode: string | null
  per100g: Macros
  portions: Portion[]
  /** Gramos por mililitro, para convertir ml → g. Por defecto 1. */
  density: number | null
  source: FoodSource
  verified: boolean
  createdBy: string
  /** true si el documento guardado aún no tiene el campo de fibra (datos anteriores). */
  fiberMissing: boolean
}

export interface RecipeIngredient {
  foodId: string
  grams: number
}

export interface Recipe {
  id: string
  ownerId: string
  name: string
  aliases: string[]
  servings: number
  ingredients: RecipeIngredient[]
  totalGrams: number
  totals: Macros
  perServing: Macros
}

export interface Range {
  min: number
  max: number
}

export interface Goals {
  ranges: Record<MacroKey, Range>
  /** Pesos relativos; se normalizan al calcular el puntaje. */
  weights: Record<MacroKey, number>
}

export const MEAL_SLOTS = ['desayuno', 'almuerzo', 'once', 'cena', 'snack'] as const
export type MealSlot = (typeof MEAL_SLOTS)[number]

export interface DiaryEntry {
  id: string
  kind: 'food' | 'recipe'
  refId: string
  name: string
  grams: number
  servings: number | null
  macros: Macros
  meal: MealSlot
  rawInput: string | null
  createdAt: number
}

export type NewDiaryEntry = Omit<DiaryEntry, 'id' | 'createdAt'>
