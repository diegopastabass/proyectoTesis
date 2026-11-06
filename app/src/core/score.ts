import { MACRO_KEYS, type Goals, type MacroKey, type Macros, type Range } from './types'

/**
 * Puntaje 0–100 de un macro respecto de su rango:
 * 100 dentro del rango; fuera de él cae linealmente según la desviación
 * relativa al límite más cercano.
 */
export function macroScore(value: number, range: Range): number {
  const { min, max } = range
  if (value >= min && value <= max) return 100
  if (value < min) return min <= 0 ? 100 : Math.max(0, 100 * (1 - (min - value) / min))
  return max <= 0 ? 0 : Math.max(0, 100 * (1 - (value - max) / max))
}

export function normalizedWeights(weights: Record<MacroKey, number>): Record<MacroKey, number> {
  const sum = MACRO_KEYS.reduce((s, k) => s + Math.max(0, weights[k]), 0)
  const out = {} as Record<MacroKey, number>
  for (const k of MACRO_KEYS) {
    out[k] = sum > 0 ? Math.max(0, weights[k]) / sum : 1 / MACRO_KEYS.length
  }
  return out
}

export interface DailyScore {
  total: number
  perMacro: Record<MacroKey, number>
}

export function dailyScore(totals: Macros, goals: Goals): DailyScore {
  const w = normalizedWeights(goals.weights)
  const perMacro = {} as Record<MacroKey, number>
  let total = 0
  for (const k of MACRO_KEYS) {
    perMacro[k] = macroScore(totals[k], goals.ranges[k])
    total += w[k] * perMacro[k]
  }
  return { total: Math.round(total), perMacro }
}

export type ScoreLevel = 'good' | 'mid' | 'low'

export function scoreLevel(score: number): ScoreLevel {
  if (score >= 85) return 'good'
  if (score >= 60) return 'mid'
  return 'low'
}

export const DEFAULT_GOALS: Goals = {
  ranges: {
    kcal: { min: 2200, max: 2600 },
    protein: { min: 120, max: 160 },
    carbs: { min: 220, max: 320 },
    fat: { min: 60, max: 90 },
    fiber: { min: 25, max: 40 },
  },
  weights: { kcal: 40, protein: 25, carbs: 20, fat: 15, fiber: 10 },
}
