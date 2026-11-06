/**
 * Genera src/data/exercises.json desde free-exercise-db (dominio público, Unlicense):
 * https://github.com/yuhonas/free-exercise-db
 *
 * Deja solo los campos que usa la app y omite estiramientos y cardio. Las
 * instrucciones (en inglés) no se incluyen: se piden al CDN al abrir un ejercicio.
 *
 * Uso: node scripts/build-exercises.mjs
 */
import { writeFile } from 'node:fs/promises'

/** Commit fijo: las imágenes se sirven desde el mismo commit (ver core/strength/catalog.ts). */
const COMMIT = 'f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5'
const DATA_URL = `https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@${COMMIT}/dist/exercises.json`
const SKIP = new Set(['stretching', 'cardio'])

const res = await fetch(DATA_URL)
if (!res.ok) throw new Error(`HTTP ${res.status} al descargar ${DATA_URL}`)
const all = await res.json()

const exercises = all
  .filter((e) => !SKIP.has(e.category))
  .map((e) => ({
    id: e.id,
    name: e.name,
    category: e.category,
    equipment: e.equipment ?? null,
    primary: e.primaryMuscles,
    secondary: e.secondaryMuscles,
    level: e.level,
    mechanic: e.mechanic ?? null,
    images: e.images.length,
  }))
  .sort((a, b) => a.name.localeCompare(b.name))

const out = { source: { name: 'free-exercise-db', url: 'https://github.com/yuhonas/free-exercise-db', commit: COMMIT, license: 'Unlicense' }, exercises }
await writeFile(new URL('../src/data/exercises.json', import.meta.url), JSON.stringify(out) + '\n')
console.log(`${exercises.length} ejercicios escritos en src/data/exercises.json`)
