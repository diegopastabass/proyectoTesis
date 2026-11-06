import { describe, expect, it } from 'vitest'
import { progressStats, trendPerDay, type BodyGoal } from '../progress'

const entries = [
  { date: '2026-09-01', kg: 85 },
  { date: '2026-09-15', kg: 84 },
  { date: '2026-10-01', kg: 82 },
]

describe('trendPerDay', () => {
  it('calcula la pendiente por mínimos cuadrados', () => {
    expect(trendPerDay([{ date: '2026-01-01', kg: 80 }, { date: '2026-01-08', kg: 79.3 }])).toBeCloseTo(-0.1, 5)
  })

  it('es null con un solo registro', () => {
    expect(trendPerDay([{ date: '2026-01-01', kg: 80 }])).toBeNull()
  })
})

describe('progressStats', () => {
  const lose: BodyGoal = { type: 'lose', targetKg: 78, startDate: '2026-09-01' }

  it('mide cambio, faltante y porcentaje hacia la meta', () => {
    const s = progressStats(entries, lose)
    expect(s.start?.kg).toBe(85)
    expect(s.current?.kg).toBe(82)
    expect(s.change).toBe(-3)
    expect(s.remaining).toBe(-4)
    expect(s.percent).toBe(43) // 3 de 7 kg
  })

  it('estima ritmo semanal y fecha de llegada si va en la dirección correcta', () => {
    const s = progressStats(entries, lose)
    expect(s.ratePerWeek).toBeLessThan(0)
    expect(s.eta).not.toBeNull()
    expect(s.eta! > '2026-10-01').toBe(true)
  })

  it('no estima llegada si la tendencia va en contra de la meta', () => {
    const gain: BodyGoal = { type: 'gain', targetKg: 90, startDate: '2026-09-01' }
    const s = progressStats(entries, gain)
    expect(s.percent).toBe(0)
    expect(s.eta).toBeNull()
  })

  it('usa el primer registro desde la fecha de inicio de la meta', () => {
    const s = progressStats(entries, { ...lose, startDate: '2026-09-10' })
    expect(s.start?.kg).toBe(84)
  })

  it('para mantener no calcula porcentaje', () => {
    expect(progressStats(entries, { type: 'maintain', targetKg: 82, startDate: '2026-09-01' }).percent).toBeNull()
  })

  it('funciona sin registros', () => {
    expect(progressStats([], lose)).toMatchObject({ start: null, current: null, change: null, eta: null })
  })
})
