import { describe, expect, it } from 'vitest'
import { estimateKcal } from '../macros'
import { DEFAULT_GOALS, dailyScore, macroScore, normalizedWeights } from '../score'

describe('macroScore', () => {
  const range = { min: 100, max: 200 }

  it('da 100 dentro del rango, incluidos los bordes', () => {
    expect(macroScore(100, range)).toBe(100)
    expect(macroScore(150, range)).toBe(100)
    expect(macroScore(200, range)).toBe(100)
  })

  it('cae linealmente fuera del rango', () => {
    expect(macroScore(90, range)).toBe(90)
    expect(macroScore(300, range)).toBe(50)
    expect(macroScore(0, range)).toBe(0)
    expect(macroScore(500, range)).toBe(0)
  })

  it('tolera rangos con mínimo o máximo cero', () => {
    expect(macroScore(0, { min: 0, max: 50 })).toBe(100)
    expect(macroScore(10, { min: 0, max: 0 })).toBe(0)
  })
})

describe('dailyScore', () => {
  it('pondera con pesos normalizados', () => {
    const w = normalizedWeights({ kcal: 2, protein: 1, carbs: 1, fat: 0, fiber: 0 })
    expect(w).toEqual({ kcal: 0.5, protein: 0.25, carbs: 0.25, fat: 0, fiber: 0 })
  })

  it('reparte en partes iguales si todos los pesos son cero', () => {
    const w = normalizedWeights({ kcal: 0, protein: 0, carbs: 0, fat: 0, fiber: 0 })
    expect(w.kcal).toBe(0.2)
  })

  it('da 100 con todo dentro del rango y menos con desvíos', () => {
    const inside = { kcal: 2400, protein: 140, carbs: 250, fat: 70, fiber: 30 }
    expect(dailyScore(inside, DEFAULT_GOALS).total).toBe(100)
    const low = { ...inside, protein: 60 }
    const s = dailyScore(low, DEFAULT_GOALS)
    expect(s.perMacro.protein).toBe(50)
    // pesos por defecto 40/25/20/15/10 (suman 110): la proteína pesa 25/110
    expect(s.total).toBe(Math.round(100 - (25 / 110) * 50))
  })

  it('la fibra baja el puntaje cuando queda fuera de su rango', () => {
    const low = { kcal: 2400, protein: 140, carbs: 250, fat: 70, fiber: 0 }
    const s = dailyScore(low, DEFAULT_GOALS)
    expect(s.perMacro.fiber).toBe(0)
    expect(s.total).toBe(Math.round(100 - (10 / 110) * 100))
  })
})

describe('estimateKcal', () => {
  it('usa los factores de Atwater', () => {
    expect(estimateKcal(10, 20, 5)).toBe(165)
  })
})
