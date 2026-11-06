import type { SetType, StrengthSet, Workout, WorkoutExercise } from './types'

export const isEffective = (s: StrengthSet) => s.type !== 'warmup'

/** Volumen de una serie: kg × repeticiones (0 si no tiene peso). */
export function setVolume(s: StrengthSet): number {
  return (s.kg ?? 0) * (s.reps ?? 0)
}

/** Volumen de un ejercicio sin contar el calentamiento. */
export function exerciseVolume(e: WorkoutExercise): number {
  return e.sets.filter(isEffective).reduce((sum, s) => sum + setVolume(s), 0)
}

/** Volumen total de la sesión (series efectivas). */
export function workoutVolume(w: Workout): number {
  return w.exercises.reduce((sum, e) => sum + exerciseVolume(e), 0)
}

export interface WorkoutTotals {
  volume: number
  sets: number
  reps: number
  exercises: number
  durationMin: number
}

export function workoutTotals(w: Workout): WorkoutTotals {
  const effective = w.exercises.flatMap((e) => e.sets.filter(isEffective))
  return {
    volume: Math.round(workoutVolume(w)),
    sets: effective.length,
    reps: effective.reduce((s, x) => s + (x.reps ?? 0), 0),
    exercises: w.exercises.length,
    durationMin: Math.max(0, Math.round((w.finishedAt - w.startedAt) / 60_000)),
  }
}

/**
 * 1RM estimado con la fórmula de Epley: kg × (1 + reps / 30). Con 1 repetición
 * es el mismo peso. Sobre 12 repeticiones la estimación pierde precisión.
 */
export function estimate1RM(kg: number, reps: number): number {
  if (kg <= 0 || reps <= 0) return 0
  return reps === 1 ? kg : kg * (1 + reps / 30)
}

/** Sesiones ordenadas de la más antigua a la más reciente. */
export function sortWorkouts(list: Workout[]): Workout[] {
  return [...list].sort((a, b) => a.startedAt - b.startedAt)
}

export interface ExerciseSession {
  workoutId: string
  date: string
  startedAt: number
  /** Mayor peso en una serie efectiva. */
  maxKg: number
  /** Repeticiones hechas con ese mayor peso (la mejor serie). */
  repsAtMax: number
  maxReps: number
  best1RM: number
  volume: number
  sets: number
}

export function summarizeExercise(w: Workout, e: WorkoutExercise): ExerciseSession {
  const eff = e.sets.filter(isEffective)
  let maxKg = 0
  let repsAtMax = 0
  for (const s of eff) {
    const kg = s.kg ?? 0
    const reps = s.reps ?? 0
    if (kg > maxKg || (kg === maxKg && reps > repsAtMax)) {
      maxKg = kg
      repsAtMax = reps
    }
  }
  return {
    workoutId: w.id,
    date: w.date,
    startedAt: w.startedAt,
    maxKg,
    repsAtMax,
    maxReps: Math.max(0, ...eff.map((s) => s.reps ?? 0)),
    best1RM: Math.max(0, ...eff.map((s) => estimate1RM(s.kg ?? 0, s.reps ?? 0))),
    volume: exerciseVolume(e),
    sets: eff.length,
  }
}

/** Historial de un ejercicio, de la sesión más antigua a la más reciente. */
export function exerciseHistory(workouts: Workout[], exerciseId: string): ExerciseSession[] {
  const out: ExerciseSession[] = []
  for (const w of sortWorkouts(workouts)) {
    for (const e of w.exercises) {
      if (e.exerciseId === exerciseId && e.sets.length > 0) out.push(summarizeExercise(w, e))
    }
  }
  return out
}

/** Las series de la sesión más reciente (antes de `before`, si se indica) que incluyó el ejercicio. */
export function lastSetsFor(workouts: Workout[], exerciseId: string, before?: number): StrengthSet[] | null {
  let best: { at: number; sets: StrengthSet[] } | null = null
  for (const w of workouts) {
    if (before !== undefined && w.startedAt >= before) continue
    const e = w.exercises.find((x) => x.exerciseId === exerciseId && x.sets.length > 0)
    if (e && (!best || w.startedAt > best.at)) best = { at: w.startedAt, sets: e.sets }
  }
  return best?.sets ?? null
}

/**
 * Serie "anterior" para la columna ANTERIOR: la que ocupó la misma posición entre
 * las del mismo grupo (calentamiento con calentamiento, efectivas con efectivas).
 */
export function matchPrevious(previous: StrengthSet[] | null, types: SetType[], index: number): StrengthSet | null {
  if (!previous) return null
  const warm = types[index] === 'warmup'
  const position = types.slice(0, index).filter((t) => (t === 'warmup') === warm).length
  return previous.filter((s) => (s.type === 'warmup') === warm)[position] ?? null
}

/** Ejercicios ordenados por cuántas sesiones los incluyen. */
export function exerciseFrequency(workouts: Workout[]): { exerciseId: string; name: string; sessions: number; lastAt: number }[] {
  const map = new Map<string, { exerciseId: string; name: string; sessions: number; lastAt: number }>()
  for (const w of workouts) {
    for (const e of w.exercises) {
      const cur = map.get(e.exerciseId) ?? { exerciseId: e.exerciseId, name: e.name, sessions: 0, lastAt: 0 }
      cur.sessions++
      if (w.startedAt >= cur.lastAt) {
        cur.lastAt = w.startedAt
        cur.name = e.name
      }
      map.set(e.exerciseId, cur)
    }
  }
  return [...map.values()].sort((a, b) => b.sessions - a.sessions || b.lastAt - a.lastAt)
}
