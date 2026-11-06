import Fuse from 'fuse.js'
import { normalize } from '../normalize'
import type { Exercise } from './types'

/** Mismo commit con el que se generó src/data/exercises.json (scripts/build-exercises.mjs). */
const IMAGE_BASE = 'https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5/exercises'

/** Foto de la posición inicial (0) o final (1); null si el ejercicio no tiene imágenes. */
export function exerciseImage(e: Pick<Exercise, 'id' | 'images' | 'custom'>, frame: 0 | 1 = 0): string | null {
  if (e.custom || e.images < 2) return null
  return `${IMAGE_BASE}/${encodeURIComponent(e.id)}/${frame}.jpg`
}

/** Ficha original (inglés) con las instrucciones. */
export function exerciseSourceUrl(id: string): string {
  return `${IMAGE_BASE}/${encodeURIComponent(id)}.json`
}

export const MUSCLES_ES: Record<string, string> = {
  abdominals: 'Abdominales',
  abductors: 'Abductores',
  adductors: 'Aductores',
  biceps: 'Bíceps',
  calves: 'Pantorrillas',
  chest: 'Pecho',
  forearms: 'Antebrazos',
  glutes: 'Glúteos',
  hamstrings: 'Isquiotibiales',
  lats: 'Dorsales',
  'lower back': 'Zona lumbar',
  'middle back': 'Espalda media',
  neck: 'Cuello',
  quadriceps: 'Cuádriceps',
  shoulders: 'Hombros',
  traps: 'Trapecio',
  triceps: 'Tríceps',
}

export const EQUIPMENT_ES: Record<string, string> = {
  bands: 'Bandas',
  barbell: 'Barra',
  'body only': 'Peso corporal',
  cable: 'Polea',
  dumbbell: 'Mancuernas',
  'e-z curl bar': 'Barra Z',
  'exercise ball': 'Balón suizo',
  'foam roll': 'Rodillo',
  kettlebells: 'Kettlebell',
  machine: 'Máquina',
  'medicine ball': 'Balón medicinal',
  other: 'Otro',
}

export const CATEGORY_ES: Record<string, string> = {
  strength: 'Fuerza',
  powerlifting: 'Powerlifting',
  'olympic weightlifting': 'Halterofilia',
  strongman: 'Strongman',
  plyometrics: 'Pliometría',
}

/** Grupos para filtrar el catálogo. */
export const MUSCLE_GROUPS: { id: string; label: string; muscles: string[] }[] = [
  { id: 'pecho', label: 'Pecho', muscles: ['chest'] },
  { id: 'espalda', label: 'Espalda', muscles: ['lats', 'middle back', 'lower back', 'traps'] },
  { id: 'hombros', label: 'Hombros', muscles: ['shoulders'] },
  { id: 'brazos', label: 'Brazos', muscles: ['biceps', 'triceps', 'forearms'] },
  { id: 'piernas', label: 'Piernas', muscles: ['quadriceps', 'hamstrings', 'calves', 'adductors', 'abductors'] },
  { id: 'gluteos', label: 'Glúteos', muscles: ['glutes'] },
  { id: 'core', label: 'Core', muscles: ['abdominals'] },
]

export const muscleLabel = (m: string) => MUSCLES_ES[m] ?? m
export const equipmentLabel = (e: string | null) => (e ? (EQUIPMENT_ES[e] ?? e) : 'Sin equipo')

interface RawExercise {
  id: string
  name: string
  category: string
  equipment: string | null
  primary: string[]
  secondary: string[]
  images: number
}

/** Une el catálogo (inglés) con los nombres en español. */
export function buildExercises(raw: RawExercise[], namesEs: Record<string, { name: string; aliases?: string[] }>): Exercise[] {
  return raw.map((r) => {
    const es = namesEs[r.id]
    return {
      id: r.id,
      name: es?.name ?? r.name,
      nameEn: r.name,
      aliases: es?.aliases ?? [],
      category: r.category,
      equipment: r.equipment,
      primary: r.primary,
      secondary: r.secondary,
      images: r.images,
      custom: false,
    }
  })
}

export interface ExerciseFilter {
  query: string
  /** id de MUSCLE_GROUPS o null. */
  group: string | null
}

/**
 * Busca por nombre en español o inglés y por alias, tolerando errores de tipeo.
 * Sin texto, ordena primero los ejercicios con nombre en español (los comunes).
 */
export class ExerciseIndex {
  private readonly fuse: Fuse<Exercise>
  private readonly list: Exercise[]

  constructor(list: Exercise[]) {
    this.list = list
    this.fuse = new Fuse(list, {
      keys: [
        { name: 'name', weight: 3 },
        { name: 'aliases', weight: 2 },
        { name: 'nameEn', weight: 1 },
      ],
      threshold: 0.35,
      ignoreLocation: true,
      ignoreDiacritics: true,
    })
  }

  search({ query, group }: ExerciseFilter, limit = 60): Exercise[] {
    const muscles = group ? (MUSCLE_GROUPS.find((g) => g.id === group)?.muscles ?? []) : null
    const inGroup = (e: Exercise) => !muscles || e.primary.some((m) => muscles.includes(m))
    const q = normalize(query)
    if (!q) {
      const translated = (e: Exercise) => (e.custom ? 0 : e.name !== e.nameEn ? 1 : 2)
      return this.list
        .filter(inGroup)
        .sort((a, b) => translated(a) - translated(b) || a.name.localeCompare(b.name))
        .slice(0, limit)
    }
    return this.fuse
      .search(q, { limit: limit * 3 })
      .map((r) => r.item)
      .filter(inGroup)
      .slice(0, limit)
  }
}
