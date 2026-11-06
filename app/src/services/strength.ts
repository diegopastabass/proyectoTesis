import { addDoc, collection, deleteDoc, doc, onSnapshot, serverTimestamp, setDoc, type DocumentData } from 'firebase/firestore'
import type { Exercise, Routine, RoutineExercise, StrengthSet, Workout, WorkoutExercise } from '../core/strength/types'
import { getDb } from './firebase'

const routinesCol = (uid: string) => collection(getDb(), 'users', uid, 'routines')
const workoutsCol = (uid: string) => collection(getDb(), 'users', uid, 'workouts')
const exercisesCol = (uid: string) => collection(getDb(), 'users', uid, 'exercises')

/** Prefijo de los ejercicios propios, para no chocar con los ids del catálogo. */
export const CUSTOM_PREFIX = 'u:'

const toSet = (s: DocumentData): StrengthSet => ({ type: s.type ?? 'normal', kg: s.kg ?? null, reps: s.reps ?? null })

export function watchRoutines(uid: string, cb: (list: Routine[]) => void, onError: (e: Error) => void) {
  return onSnapshot(
    routinesCol(uid),
    (snap) =>
      cb(
        snap.docs
          .map((d) => {
            const data = d.data({ serverTimestamps: 'estimate' })
            return {
              id: d.id,
              name: data.name ?? '',
              exercises: ((data.exercises ?? []) as DocumentData[]).map((e) => ({ exerciseId: e.exerciseId, sets: (e.sets ?? []).map(toSet) })),
              updatedAt: data.updatedAt?.toMillis?.() ?? 0,
            }
          })
          .sort((a, b) => a.name.localeCompare(b.name)),
      ),
    onError,
  )
}

export async function saveRoutine(uid: string, input: { name: string; exercises: RoutineExercise[] }, id?: string): Promise<string> {
  const data = { ...input, updatedAt: serverTimestamp() }
  if (id) {
    await setDoc(doc(routinesCol(uid), id), data, { merge: true })
    return id
  }
  return (await addDoc(routinesCol(uid), { ...data, createdAt: serverTimestamp() })).id
}

export function deleteRoutine(uid: string, id: string) {
  return deleteDoc(doc(routinesCol(uid), id))
}

export function watchWorkouts(uid: string, cb: (list: Workout[]) => void, onError: (e: Error) => void) {
  return onSnapshot(
    workoutsCol(uid),
    (snap) =>
      cb(
        snap.docs
          .map((d) => {
            const data = d.data()
            return {
              id: d.id,
              routineId: data.routineId ?? null,
              name: data.name ?? 'Entrenamiento',
              date: data.date,
              startedAt: data.startedAt,
              finishedAt: data.finishedAt,
              exercises: ((data.exercises ?? []) as DocumentData[]).map(
                (e): WorkoutExercise => ({ exerciseId: e.exerciseId, name: e.name ?? '', sets: (e.sets ?? []).map(toSet) }),
              ),
            }
          })
          .sort((a, b) => b.startedAt - a.startedAt),
      ),
    onError,
  )
}

export async function saveWorkout(uid: string, w: Omit<Workout, 'id'>): Promise<string> {
  return (await addDoc(workoutsCol(uid), { ...w, createdAt: serverTimestamp() })).id
}

export function deleteWorkout(uid: string, id: string) {
  return deleteDoc(doc(workoutsCol(uid), id))
}

export function watchCustomExercises(uid: string, cb: (list: Exercise[]) => void, onError: (e: Error) => void) {
  return onSnapshot(
    exercisesCol(uid),
    (snap) =>
      cb(
        snap.docs.map((d) => {
          const data = d.data()
          return {
            id: CUSTOM_PREFIX + d.id,
            name: data.name ?? '',
            nameEn: '',
            aliases: [],
            category: 'strength',
            equipment: data.equipment ?? null,
            primary: data.primary ?? [],
            secondary: [],
            images: 0,
            custom: true,
          }
        }),
      ),
    onError,
  )
}

export async function createCustomExercise(uid: string, input: { name: string; equipment: string | null; primary: string[] }): Promise<string> {
  const ref = await addDoc(exercisesCol(uid), { ...input, createdAt: serverTimestamp() })
  return CUSTOM_PREFIX + ref.id
}
