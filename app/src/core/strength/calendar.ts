import { addDays, fromDateKey } from '../date'

/** Lunes de la semana de `date` (semanas de lunes a domingo). */
export function weekStart(date: string): string {
  const day = fromDateKey(date).getDay() // 0 = domingo
  return addDays(date, -((day + 6) % 7))
}

export interface HeatDay {
  date: string
  count: number
  /** Día posterior a `today`: se dibuja vacío. */
  future: boolean
}

/** Cuántas sesiones hubo cada día. */
export function countByDate(dates: string[]): Map<string, number> {
  const map = new Map<string, number>()
  for (const d of dates) map.set(d, (map.get(d) ?? 0) + 1)
  return map
}

/**
 * Columnas de un mapa de calor tipo calendario: `weeks` semanas (lunes a domingo)
 * que terminan en la semana de `today`.
 */
export function heatmapWeeks(counts: Map<string, number>, today: string, weeks: number): HeatDay[][] {
  const firstMonday = addDays(weekStart(today), -7 * (weeks - 1))
  return Array.from({ length: weeks }, (_, w) =>
    Array.from({ length: 7 }, (_, d) => {
      const date = addDays(firstMonday, w * 7 + d)
      return { date, count: counts.get(date) ?? 0, future: date > today }
    }),
  )
}

/**
 * Semanas seguidas con al menos un entrenamiento. La semana actual cuenta si ya
 * tiene uno; si aún no, la racha se mide hasta la semana pasada (no se corta).
 */
export function weeklyStreak(dates: string[], today: string): number {
  const weeks = new Set(dates.map(weekStart))
  let cursor = weekStart(today)
  if (!weeks.has(cursor)) cursor = addDays(cursor, -7)
  let streak = 0
  while (weeks.has(cursor)) {
    streak++
    cursor = addDays(cursor, -7)
  }
  return streak
}

/** Días distintos con entrenamiento entre `from` y `to` (inclusive). */
export function trainedDaysBetween(dates: string[], from: string, to: string): number {
  return new Set(dates.filter((d) => d >= from && d <= to)).size
}
