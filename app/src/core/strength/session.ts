import { toDateKey } from '../date'
import { lastSetsFor, matchPrevious } from './stats'
import type { Routine, RoutineExercise, SetType, StrengthSet, Workout, WorkoutExercise } from './types'

/** Serie en edición. kg y reps son texto para no pelear con el teclado ("52,"). */
export interface DraftSet {
  key: string
  type: SetType
  kg: string
  reps: string
  done: boolean
  /** Valores de la rutina; sugerencia (placeholder) si no hay sesión anterior. */
  targetKg: number | null
  targetReps: number | null
}

export interface DraftExercise {
  key: string
  exerciseId: string
  sets: DraftSet[]
}

/** Sesión en curso (se guarda en el dispositivo hasta terminarla). */
export interface ActiveWorkout {
  routineId: string | null
  name: string
  startedAt: number
  exercises: DraftExercise[]
}

const DEFAULT_SETS = 3

export const newKey = () => Math.random().toString(36).slice(2, 10)

export function parseAmount(s: string): number | null {
  const t = s.trim().replace(',', '.')
  if (t === '') return null
  const n = Number(t)
  return Number.isFinite(n) && n >= 0 ? n : null
}

const fmt = (n: number | null) => (n === null ? '' : String(n).replace('.', ','))

function draftSet(type: SetType, targetKg: number | null = null, targetReps: number | null = null): DraftSet {
  return { key: newKey(), type, kg: '', reps: '', done: false, targetKg, targetReps }
}

export function emptyWorkout(now: number, name = 'Entrenamiento libre'): ActiveWorkout {
  return { routineId: null, name, startedAt: now, exercises: [] }
}

export function workoutFromRoutine(routine: Routine, now: number): ActiveWorkout {
  return {
    routineId: routine.id,
    name: routine.name,
    startedAt: now,
    exercises: routine.exercises.map((e) => ({
      key: newKey(),
      exerciseId: e.exerciseId,
      sets: e.sets.map((s) => draftSet(s.type, s.kg, s.reps)),
    })),
  }
}

/** Estructura de series al agregar un ejercicio: la de la última vez o 3 series normales. */
export function setsForNewExercise(exerciseId: string, workouts: Workout[]): DraftSet[] {
  const last = lastSetsFor(workouts, exerciseId)
  if (last?.length) return last.map((s) => draftSet(s.type))
  return Array.from({ length: DEFAULT_SETS }, () => draftSet('normal'))
}

/** Nueva serie al final: copia el tipo y la sugerencia de la última. */
export function appendSet(sets: DraftSet[]): DraftSet[] {
  const last = sets.at(-1)
  const type = last && last.type !== 'warmup' ? last.type : 'normal'
  return [...sets, draftSet(type, last?.targetKg ?? null, last?.targetReps ?? null)]
}

export function nextSetType(t: SetType): SetType {
  return t === 'normal' ? 'warmup' : t === 'warmup' ? 'failure' : 'normal'
}

/**
 * Sugerencia para una serie: lo que se hizo la última vez en esa serie o, si no
 * hay registro, lo que dice la rutina (la plantilla se queda atrás al progresar).
 */
export function suggestion(set: DraftSet, previous: StrengthSet | null): { kg: number | null; reps: number | null } {
  if (previous) return { kg: previous.kg, reps: previous.reps }
  return { kg: set.targetKg, reps: set.targetReps }
}

/**
 * Marca o desmarca una serie. Al marcarla, los campos vacíos se completan con la
 * sugerencia. Devuelve null si no hay repeticiones con qué completarla.
 */
export function toggleDone(set: DraftSet, previous: StrengthSet | null): DraftSet | null {
  if (set.done) return { ...set, done: false }
  const hint = suggestion(set, previous)
  const kg = set.kg.trim() ? set.kg : fmt(hint.kg)
  const reps = set.reps.trim() ? set.reps : fmt(hint.reps)
  const r = parseAmount(reps)
  if (r === null || r <= 0) return null
  return { ...set, kg, reps, done: true }
}

/** Anterior de cada serie del ejercicio, según la última sesión con él. */
export function previousFor(exercise: DraftExercise, workouts: Workout[], before: number): (StrengthSet | null)[] {
  const last = lastSetsFor(workouts, exercise.exerciseId, before)
  const types = exercise.sets.map((s) => s.type)
  return exercise.sets.map((_, i) => matchPrevious(last, types, i))
}

export function pendingSets(w: ActiveWorkout): number {
  return w.exercises.reduce((n, e) => n + e.sets.filter((s) => !s.done).length, 0)
}

export function doneSets(w: ActiveWorkout): number {
  return w.exercises.reduce((n, e) => n + e.sets.filter((s) => s.done).length, 0)
}

/** Convierte la sesión en curso en lo que se guarda: solo series hechas y ejercicios con alguna. */
export function finishWorkout(w: ActiveWorkout, now: number, nameOf: (exerciseId: string) => string): Omit<Workout, 'id'> {
  const exercises: WorkoutExercise[] = w.exercises
    .map((e) => ({
      exerciseId: e.exerciseId,
      name: nameOf(e.exerciseId),
      sets: e.sets
        .filter((s) => s.done)
        .map((s) => ({ type: s.type, kg: parseAmount(s.kg), reps: parseAmount(s.reps) }))
        .filter((s) => (s.reps ?? 0) > 0),
    }))
    .filter((e) => e.sets.length > 0)
  return {
    routineId: w.routineId,
    name: w.name,
    date: toDateKey(new Date(w.startedAt)),
    startedAt: w.startedAt,
    finishedAt: now,
    exercises,
  }
}

/** Ejercicios y series de una sesión, para actualizar la rutina con lo que se hizo. */
export function routineExercisesFrom(w: Workout): RoutineExercise[] {
  return w.exercises.map((e) => ({ exerciseId: e.exerciseId, sets: e.sets.map((s) => ({ type: s.type, kg: s.kg, reps: s.reps })) }))
}
