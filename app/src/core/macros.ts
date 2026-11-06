import { MACRO_KEYS, type Macros } from './types'

export function emptyMacros(): Macros {
  return { kcal: 0, protein: 0, carbs: 0, fat: 0, fiber: 0 }
}

/** Completa macros guardados antes de existir la fibra (o parciales) con ceros. */
export function normalizeMacros(m: Partial<Macros> | null | undefined): Macros {
  return {
    kcal: m?.kcal ?? 0,
    protein: m?.protein ?? 0,
    carbs: m?.carbs ?? 0,
    fat: m?.fat ?? 0,
    fiber: m?.fiber ?? 0,
  }
}

export function round1(n: number): number {
  return Math.round(n * 10) / 10
}

export function roundMacros(m: Macros): Macros {
  const out = emptyMacros()
  for (const k of MACRO_KEYS) out[k] = k === 'kcal' ? Math.round(m[k]) : round1(m[k])
  return out
}

export function scaleMacros(m: Macros, factor: number): Macros {
  const out = emptyMacros()
  for (const k of MACRO_KEYS) out[k] = m[k] * factor
  return out
}

/** Macros de `grams` gramos de un alimento con valores por 100 g. */
export function macrosForGrams(per100g: Macros, grams: number): Macros {
  return roundMacros(scaleMacros(per100g, grams / 100))
}

export function sumMacros(list: Macros[]): Macros {
  const total = emptyMacros()
  for (const m of list) for (const k of MACRO_KEYS) total[k] += m[k]
  return total
}

/** Estimación de Atwater: 4 kcal/g proteína y carbohidratos, 9 kcal/g grasa. */
export function estimateKcal(protein: number, carbs: number, fat: number): number {
  return Math.round(protein * 4 + carbs * 4 + fat * 9)
}
