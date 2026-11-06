import { addDays, fromDateKey } from '../date'
import { weekStart, weeklyStreak } from './calendar'
import { summarizeExercise, workoutVolume, type ExerciseSession } from './stats'
import type { Workout } from './types'

export type InsightKind = 'first' | 'record' | 'weight' | 'reps' | 'sets' | 'volume' | 'streak' | 'week' | 'milestone' | 'new'

export interface Insight {
  kind: InsightKind
  text: string
  exerciseId?: string
  /** Mayor = más relevante. */
  priority: number
}

const MILESTONES = [5, 10, 25, 50, 75, 100, 150, 200, 300, 500]
const DAY_MS = 86_400_000

export const formatKg = (n: number) => n.toLocaleString('es-CL', { maximumFractionDigits: 2 })
const plural = (n: number, one: string, many: string) => (n === 1 ? one : many)

/** "ayer", "la semana pasada", "hace 12 días"… */
export function sinceText(from: string, to: string): string {
  const days = Math.round((fromDateKey(to).getTime() - fromDateKey(from).getTime()) / DAY_MS)
  if (days <= 0) return 'hoy más temprano'
  if (days === 1) return 'ayer'
  if (days >= 6 && days <= 8) return 'la semana pasada'
  return `hace ${days} días`
}

/** Mejor mensaje para un ejercicio comparado con su historial previo. */
function exerciseInsight(name: string, id: string, cur: ExerciseSession, history: ExerciseSession[]): Insight | null {
  const prev = history.at(-1)
  if (!prev) return null
  const bestKg = Math.max(...history.map((h) => h.maxKg))
  const best1RM = Math.max(...history.map((h) => h.best1RM))
  const since = sinceText(prev.date, cur.date)

  if (cur.maxKg > 0 && cur.maxKg > bestKg) {
    return { kind: 'record', priority: 100, exerciseId: id, text: `Nuevo récord en ${name}: ${formatKg(cur.maxKg)} kg × ${cur.repsAtMax}.` }
  }
  if (cur.maxKg > prev.maxKg) {
    return { kind: 'weight', priority: 80, exerciseId: id, text: `Subiste el peso en ${name}: ${formatKg(cur.maxKg)} kg (antes ${formatKg(prev.maxKg)} kg).` }
  }
  if (cur.maxKg > 0 && cur.maxKg === prev.maxKg && cur.repsAtMax > prev.repsAtMax) {
    return {
      kind: 'reps',
      priority: 70,
      exerciseId: id,
      text: `Más repeticiones en ${name} con ${formatKg(cur.maxKg)} kg: ${cur.repsAtMax} (antes ${prev.repsAtMax}).`,
    }
  }
  if (cur.maxKg === 0 && prev.maxKg === 0 && cur.maxReps > prev.maxReps) {
    return { kind: 'reps', priority: 70, exerciseId: id, text: `Más repeticiones en ${name}: ${cur.maxReps} (antes ${prev.maxReps}).` }
  }
  if (cur.best1RM > 0 && cur.best1RM > best1RM + 0.05) {
    return { kind: 'record', priority: 90, exerciseId: id, text: `Mejor 1RM estimado en ${name}: ${formatKg(Math.round(cur.best1RM * 10) / 10)} kg.` }
  }
  if (cur.sets > prev.sets) {
    const n = cur.sets - prev.sets
    return {
      kind: 'sets',
      priority: 60,
      exerciseId: id,
      text: `Hoy hiciste ${n} ${plural(n, 'serie', 'series')} más de ${name} que la última vez (${since}).`,
    }
  }
  if (prev.volume > 0 && cur.volume >= prev.volume * 1.05) {
    const pct = Math.round((cur.volume / prev.volume - 1) * 100)
    return { kind: 'volume', priority: 40, exerciseId: id, text: `Moviste ${pct} % más volumen en ${name} que la última vez.` }
  }
  return null
}

/**
 * Mensajes de motivación de una sesión, comparándola solo con las sesiones
 * anteriores a ella. Solo destaca avances: lo que bajó se ve en el resumen.
 */
export function workoutInsights(current: Workout, all: Workout[], limit = 6): Insight[] {
  const before = all.filter((w) => w.id !== current.id && w.startedAt < current.startedAt).sort((a, b) => a.startedAt - b.startedAt)
  if (before.length === 0) {
    return [{ kind: 'first', priority: 100, text: '¡Primer entrenamiento registrado! Desde ahora verás aquí cómo avanzas.' }]
  }

  const out: Insight[] = []
  const fresh: string[] = []

  for (const e of current.exercises) {
    if (e.sets.length === 0) continue
    const history = before.flatMap((w) => w.exercises.filter((x) => x.exerciseId === e.exerciseId && x.sets.length > 0).map((x) => summarizeExercise(w, x)))
    if (history.length === 0) {
      fresh.push(e.name)
      continue
    }
    const insight = exerciseInsight(e.name, e.exerciseId, summarizeExercise(current, e), history)
    if (insight) out.push(insight)
  }

  if (fresh.length > 0) {
    out.push({
      kind: 'new',
      priority: 30,
      text: fresh.length === 1 ? `Primera vez registrando ${fresh[0]}.` : `Sumaste ${fresh.length} ejercicios nuevos: ${fresh.join(', ')}.`,
    })
  }

  // Volumen contra la última vez que se hizo la misma rutina.
  const same = before.filter((w) => (current.routineId ? w.routineId === current.routineId : w.name === current.name)).at(-1)
  if (same) {
    const cur = workoutVolume(current)
    const prev = workoutVolume(same)
    if (prev > 0 && cur > prev) {
      const pct = Math.round((cur / prev - 1) * 100)
      if (pct >= 1) {
        out.push({
          kind: 'volume',
          priority: 85,
          text: `Volumen total ${pct} % mayor que la última vez que hiciste ${current.name} (${sinceText(same.date, current.date)}).`,
        })
      }
    }
  }

  const dates = [...before.map((w) => w.date), current.date]
  const streak = weeklyStreak(dates, current.date)
  if (streak >= 2) out.push({ kind: 'streak', priority: 55, text: `Llevas ${streak} semanas seguidas entrenando.` })

  const thisWeek = weekStart(current.date)
  const lastWeek = addDays(thisWeek, -7)
  const inThis = dates.filter((d) => weekStart(d) === thisWeek).length
  const inLast = dates.filter((d) => weekStart(d) === lastWeek).length
  if (inLast > 0 && inThis > inLast) {
    out.push({ kind: 'week', priority: 50, text: `Ya llevas ${inThis} entrenamientos esta semana, más que en toda la semana pasada (${inLast}).` })
  }

  const total = before.length + 1
  if (MILESTONES.includes(total)) out.push({ kind: 'milestone', priority: 65, text: `¡Completaste tu entrenamiento número ${total}!` })

  return out.sort((a, b) => b.priority - a.priority).slice(0, limit)
}
