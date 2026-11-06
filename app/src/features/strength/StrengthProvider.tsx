import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { useUser } from '../../app/AuthProvider'
import { useToast } from '../../app/ToastProvider'
import { buildExercises, ExerciseIndex } from '../../core/strength/catalog'
import type { ActiveWorkout } from '../../core/strength/session'
import type { Exercise, Routine, Workout } from '../../core/strength/types'
import { watchCustomExercises, watchRoutines, watchWorkouts } from '../../services/strength'

interface StrengthState {
  routines: Routine[]
  /** De la más reciente a la más antigua. */
  workouts: Workout[]
  exercises: Exercise[]
  exerciseById: Map<string, Exercise>
  index: ExerciseIndex
  ready: boolean
  /** Nombre del ejercicio; si se borró, el guardado en la sesión. */
  nameOf: (exerciseId: string, fallback?: string) => string
  active: ActiveWorkout | null
  setActive: (fn: ActiveWorkout | null | ((w: ActiveWorkout | null) => ActiveWorkout | null)) => void
}

const StrengthContext = createContext<StrengthState | null>(null)

const storageKey = (uid: string) => `fuerza-activa:${uid}`

function readActive(uid: string): ActiveWorkout | null {
  try {
    const raw = localStorage.getItem(storageKey(uid))
    return raw ? (JSON.parse(raw) as ActiveWorkout) : null
  } catch {
    return null
  }
}

/** El catálogo pesa ~165 KB: se carga solo al entrar al módulo de fuerza. */
async function loadCatalog(): Promise<Exercise[]> {
  const [{ default: data }, { EXERCISE_NAMES_ES }] = await Promise.all([import('../../data/exercises.json'), import('../../data/exercisesEs')])
  return buildExercises(data.exercises, EXERCISE_NAMES_ES)
}

export function StrengthProvider({ children }: { children: ReactNode }) {
  const user = useUser()
  const toast = useToast()
  const [catalog, setCatalog] = useState<Exercise[] | null>(null)
  const [custom, setCustom] = useState<Exercise[] | null>(null)
  const [routines, setRoutines] = useState<Routine[] | null>(null)
  const [workouts, setWorkouts] = useState<Workout[] | null>(null)
  const [active, setActiveState] = useState<ActiveWorkout | null>(() => readActive(user.uid))

  useEffect(() => {
    let cancelled = false
    loadCatalog()
      .then((list) => !cancelled && setCatalog(list))
      .catch((e: Error) => toast(`No se pudo cargar el catálogo de ejercicios: ${e.message}`, 'error'))
    return () => {
      cancelled = true
    }
  }, [toast])

  useEffect(() => {
    const onError = (e: Error) => toast(e.message, 'error')
    const unsubs = [watchRoutines(user.uid, setRoutines, onError), watchWorkouts(user.uid, setWorkouts, onError), watchCustomExercises(user.uid, setCustom, onError)]
    return () => unsubs.forEach((u) => u())
  }, [user.uid, toast])

  // La sesión en curso vive en el dispositivo: sobrevive a recargas y a cerrar la pestaña.
  const setActive = useCallback<StrengthState['setActive']>(
    (fn) =>
      setActiveState((prev) => {
        const next = typeof fn === 'function' ? fn(prev) : fn
        try {
          if (next) localStorage.setItem(storageKey(user.uid), JSON.stringify(next))
          else localStorage.removeItem(storageKey(user.uid))
        } catch {
          // Sin almacenamiento: la sesión solo dura mientras la pestaña siga abierta.
        }
        return next
      }),
    [user.uid],
  )

  const value = useMemo<StrengthState>(() => {
    const exercises = [...(custom ?? []), ...(catalog ?? [])]
    const exerciseById = new Map(exercises.map((e) => [e.id, e]))
    return {
      routines: routines ?? [],
      workouts: workouts ?? [],
      exercises,
      exerciseById,
      index: new ExerciseIndex(exercises),
      ready: catalog !== null && custom !== null && routines !== null && workouts !== null,
      nameOf: (id, fallback) => exerciseById.get(id)?.name ?? fallback ?? 'Ejercicio eliminado',
      active,
      setActive,
    }
  }, [catalog, custom, routines, workouts, active, setActive])

  return <StrengthContext.Provider value={value}>{children}</StrengthContext.Provider>
}

export function useStrength(): StrengthState {
  const v = useContext(StrengthContext)
  if (!v) throw new Error('useStrength requiere StrengthProvider')
  return v
}
