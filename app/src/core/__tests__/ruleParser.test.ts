import { describe, expect, it } from 'vitest'
import { parseLine, parseText, splitItems } from '../parser/ruleParser'

describe('splitItems', () => {
  it('separa por líneas, punto y coma y comas no decimales', () => {
    expect(splitItems('Arroz 100g\n1 Tomate mediano; Huevos x3, Atún 150g')).toEqual([
      'Arroz 100g',
      '1 Tomate mediano',
      'Huevos x3',
      'Atún 150g',
    ])
  })

  it('no corta la coma decimal y quita viñetas', () => {
    expect(splitItems('- pollo 1,5 kg\n2) palta\n• avena')).toEqual(['pollo 1,5 kg', 'palta', 'avena'])
  })
})

describe('parseLine', () => {
  const cases: [string, { query: string; quantity: number | null; unit: string | null; size: string | null }][] = [
    ['Arroz 100g', { query: 'arroz', quantity: 100, unit: 'g', size: null }],
    ['1 Tomate mediano', { query: 'tomate', quantity: 1, unit: null, size: 'mediano' }],
    ['Huevos x3', { query: 'huevos', quantity: 3, unit: null, size: null }],
    ['3x huevos', { query: 'huevos', quantity: 3, unit: null, size: null }],
    ['Atún 150g', { query: 'atun', quantity: 150, unit: 'g', size: null }],
    ['2 tazas de leche', { query: 'leche', quantity: 2, unit: 'taza', size: null }],
    ['200ml de leche', { query: 'leche', quantity: 200, unit: 'ml', size: null }],
    ['pollo 1,5 kg', { query: 'pollo', quantity: 1500, unit: 'g', size: null }],
    ['medio plátano', { query: 'platano', quantity: 0.5, unit: null, size: null }],
    ['1/2 palta', { query: 'palta', quantity: 0.5, unit: null, size: null }],
    ['1 1/2 taza de avena', { query: 'avena', quantity: 1.5, unit: 'taza', size: null }],
    ['3 rebanadas de pan de molde', { query: 'pan de molde', quantity: 3, unit: 'rebanada', size: null }],
    ['Pollo al limón 2 porciones', { query: 'pollo al limon', quantity: 2, unit: 'porcion', size: null }],
    ['un huevo', { query: 'huevo', quantity: 1, unit: null, size: null }],
    ['torta tres leches', { query: 'torta tres leches', quantity: null, unit: null, size: null }],
    ['un poco de aceite', { query: 'aceite', quantity: null, unit: null, size: null }],
    ['arroz 150', { query: 'arroz', quantity: 150, unit: 'g', size: null }],
    ['café', { query: 'cafe', quantity: null, unit: null, size: null }],
    ['taza de leche', { query: 'leche', quantity: 1, unit: 'taza', size: null }],
    ['un par de huevos', { query: 'huevos', quantity: 2, unit: null, size: null }],
    ['2 cdas de mantequilla de maní', { query: 'mantequilla de mani', quantity: 2, unit: 'cda', size: null }],
    ['1 scoop proteína', { query: 'proteina', quantity: 1, unit: 'scoop', size: null }],
  ]

  it.each(cases)('%s', (raw, expected) => {
    expect(parseLine(raw)).toMatchObject(expected)
  })

  it('devuelve null si solo hay cantidad', () => {
    expect(parseLine('100 g')).toBeNull()
  })
})

describe('parseText', () => {
  it('procesa la lista de ejemplo de la tesis', () => {
    const items = parseText('Arroz 100g\n1 Tomate mediano\nHuevos x3\nAtún 150g')
    expect(items.map((i) => i.query)).toEqual(['arroz', 'tomate', 'huevos', 'atun'])
  })
})
