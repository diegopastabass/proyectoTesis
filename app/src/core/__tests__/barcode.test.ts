import { describe, expect, it } from 'vitest'
import { isValidGtin, normalizeBarcode } from '../barcode'
import { mapOffProduct } from '../openFoodFacts'

describe('normalizeBarcode', () => {
  it('deja solo dígitos y completa UPC-A a 13', () => {
    expect(normalizeBarcode(' 8410109 109832 ')).toBe('8410109109832')
    expect(normalizeBarcode('078742040370')).toBe('0078742040370')
    expect(normalizeBarcode('20224042')).toBe('20224042')
  })
})

describe('isValidGtin', () => {
  it('acepta EAN-13, UPC-A y EAN-8 con dígito verificador correcto', () => {
    expect(isValidGtin('8410109109832')).toBe(true)
    expect(isValidGtin('0078742040370')).toBe(true)
    expect(isValidGtin('078742040370')).toBe(true)
    expect(isValidGtin('20224042')).toBe(true)
  })

  it('rechaza dígito verificador incorrecto o largos inválidos', () => {
    expect(isValidGtin('8410109109833')).toBe(false)
    expect(isValidGtin('12345')).toBe(false)
    expect(isValidGtin('abc')).toBe(false)
  })
})

describe('mapOffProduct', () => {
  it('toma kcal, macros y porción por 100 g', () => {
    const d = mapOffProduct('8410109109832', {
      product_name: '85% Cacao',
      brands: 'Valor, Chocolates Valor',
      serving_quantity: 20,
      nutriments: { 'energy-kcal_100g': 568, proteins_100g: 11, carbohydrates_100g: 19, fat_100g: 49, fiber_100g: '13,5' },
    })
    expect(d).toMatchObject({
      name: '85% Cacao',
      brand: 'Valor',
      servingGrams: 20,
      per100g: { kcal: 568, protein: 11, carbs: 19, fat: 49, fiber: 13.5 },
    })
  })

  it('prefiere el nombre en español y convierte kJ a kcal', () => {
    const d = mapOffProduct('1', { product_name: 'Milk', product_name_es: 'Leche', nutriments: { 'energy-kj_100g': 209.2 } })
    expect(d.name).toBe('Leche')
    expect(d.per100g?.kcal).toBe(50)
  })

  it('deja per100g en null si no hay información nutricional', () => {
    expect(mapOffProduct('1', { product_name: 'Agua' }).per100g).toBeNull()
  })
})
