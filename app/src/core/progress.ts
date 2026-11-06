import { addDays, fromDateKey } from './date'
import { round1 } from './macros'

export type GoalType = 'lose' | 'maintain' | 'gain'

export interface BodyGoal {
  type: GoalType
  targetKg: number | null
  /** Desde esta fecha se mide el progreso (YYYY-MM-DD). */
  startDate: string
}

export interface WeightEntry {
  date: string
  kg: number
}

export interface ProgressStats {
  start: WeightEntry | null
  current: WeightEntry | null
  /** current - start, en kg. */
  change: number | null
  /** target - current, en kg. */
  remaining: number | null
  /** 0–100 hacia la meta (solo perder o ganar). */
  percent: number | null
  /** Tendencia en kg por semana (regresión lineal de los últimos 28 días). */
  ratePerWeek: number | null
  /** Fecha estimada para alcanzar la meta con la tendencia actual. */
  eta: string | null
}

const DAY_MS = 86_400_000
const TREND_WINDOW_DAYS = 28

export function sortByDate(entries: WeightEntry[]): WeightEntry[] {
  return [...entries].sort((a, b) => a.date.localeCompare(b.date))
}

export const dayIndex = (date: string) => Math.round(fromDateKey(date).getTime() / DAY_MS)

/** Pendiente de mínimos cuadrados en kg/día; null con menos de 2 días distintos. */
export function trendPerDay(entries: WeightEntry[]): number | null {
  if (entries.length < 2) return null
  const xs = entries.map((e) => dayIndex(e.date))
  const n = xs.length
  const mx = xs.reduce((s, x) => s + x, 0) / n
  const my = entries.reduce((s, e) => s + e.kg, 0) / n
  let num = 0
  let den = 0
  entries.forEach((e, i) => {
    num += (xs[i] - mx) * (e.kg - my)
    den += (xs[i] - mx) ** 2
  })
  return den === 0 ? null : num / den
}

export function progressStats(entries: WeightEntry[], goal: BodyGoal | null): ProgressStats {
  const sorted = sortByDate(entries)
  const current = sorted.at(-1) ?? null
  const start = goal
    ? (sorted.find((e) => e.date >= goal.startDate) ?? sorted.filter((e) => e.date < goal.startDate).at(-1) ?? null)
    : (sorted[0] ?? null)

  const recent = current ? sorted.filter((e) => e.date >= addDays(current.date, -TREND_WINDOW_DAYS)) : []
  const slope = trendPerDay(recent)
  const ratePerWeek = slope === null ? null : Math.round(slope * 7 * 100) / 100

  const target = goal?.targetKg ?? null
  const change = start && current ? round1(current.kg - start.kg) : null
  const remaining = target !== null && current ? round1(target - current.kg) : null

  let percent: number | null = null
  if (goal && goal.type !== 'maintain' && target !== null && start && current) {
    const total = target - start.kg
    percent = total === 0 ? 100 : Math.max(0, Math.min(100, ((current.kg - start.kg) / total) * 100))
  }

  let eta: string | null = null
  if (remaining !== null && slope !== null && current && Math.abs(remaining) >= 0.1 && Math.sign(slope) === Math.sign(remaining)) {
    const days = Math.ceil(remaining / slope)
    if (days > 0 && days < 365 * 3) eta = addDays(current.date, days)
  }

  return { start, current, change, remaining, percent: percent === null ? null : Math.round(percent), ratePerWeek, eta }
}
