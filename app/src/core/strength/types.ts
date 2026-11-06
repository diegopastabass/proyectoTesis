/** Calentamiento no cuenta como serie efectiva; al fallo sí. */
export const SET_TYPES = ['normal', 'warmup', 'failure'] as const
export type SetType = (typeof SET_TYPES)[number]

export interface Exercise {
  id: string
  /** Nombre a mostrar (en español si existe). */
  name: string
  /** Nombre original del catálogo (inglés); vacío en ejercicios propios. */
  nameEn: string
  aliases: string[]
  category: string
  equipment: string | null
  primary: string[]
  secondary: string[]
  /** Cantidad de imágenes (0 o 2: posición inicial y final). */
  images: number
  /** true si lo creó el usuario. */
  custom: boolean
}

/** Serie guardada (de una rutina o de una sesión terminada). kg null = sin peso. */
export interface StrengthSet {
  type: SetType
  kg: number | null
  reps: number | null
}

export interface RoutineExercise {
  exerciseId: string
  sets: StrengthSet[]
}

/** Plantilla reutilizable: "Rutina de pecho", "Pierna A"… */
export interface Routine {
  id: string
  name: string
  exercises: RoutineExercise[]
  updatedAt: number
}

export interface WorkoutExercise {
  exerciseId: string
  /** Copia del nombre al guardar, por si el ejercicio se borra o se renombra. */
  name: string
  sets: StrengthSet[]
}

/** Sesión terminada. Solo guarda las series marcadas como hechas. */
export interface Workout {
  id: string
  routineId: string | null
  name: string
  /** YYYY-MM-DD local del inicio. */
  date: string
  startedAt: number
  finishedAt: number
  exercises: WorkoutExercise[]
}
