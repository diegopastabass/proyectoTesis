import { describe, expect, it } from 'vitest'
import { emptyMacros, macrosForGrams, normalizeMacros, sumMacros } from '../macros'

describe('normalizeMacros', () => {
  it('completa con 0 los datos guardados antes de existir la fibra', () => {
    expect(normalizeMacros({ kcal: 100, protein: 5, carbs: 10, fat: 2 })).toEqual({
      kcal: 100,
      protein: 5,
      carbs: 10,
      fat: 2,
      fiber: 0,
    })
    expect(normalizeMacros(undefined)).toEqual(emptyMacros())
  })
})

describe('macros con fibra', () => {
  const oats = { kcal: 379, protein: 13.2, carbs: 67.7, fat: 6.5, fiber: 10.1 }

  it('escala la fibra con los gramos y redondea a 1 decimal', () => {
    expect(macrosForGrams(oats, 40)).toEqual({ kcal: 152, protein: 5.3, carbs: 27.1, fat: 2.6, fiber: 4 })
  })

  it('suma la fibra de varios alimentos', () => {
    const total = sumMacros([oats, { ...emptyMacros(), fiber: 2.5 }])
    expect(total.fiber).toBeCloseTo(12.6, 5)
  })
})
