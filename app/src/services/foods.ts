import {
  addDoc,
  collection,
  doc,
  onSnapshot,
  serverTimestamp,
  updateDoc,
  writeBatch,
  type DocumentData,
} from 'firebase/firestore'
import type { Food, FoodSource, Macros, Portion } from '../core/types'
import { normalizeMacros } from '../core/macros'
import { seedFoods } from '../data/seed'
import { getDb } from './firebase'

const foodsCol = () => collection(getDb(), 'foods')

function toFood(id: string, d: DocumentData): Food {
  return {
    id,
    name: d.name ?? '',
    aliases: d.aliases ?? [],
    brand: d.brand ?? null,
    barcode: d.barcode ?? null,
    per100g: normalizeMacros(d.per100g as Partial<Macros> | undefined),
    portions: (d.portions ?? []) as Portion[],
    density: d.density ?? null,
    source: (d.source ?? { type: 'USER', ref: null, license: null }) as FoodSource,
    verified: Boolean(d.verified),
    createdBy: d.createdBy ?? '',
    fiberMissing: (d.per100g as Partial<Macros> | undefined)?.fiber === undefined,
  }
}

export function watchFoods(cb: (foods: Food[]) => void, onError: (e: Error) => void) {
  return onSnapshot(
    foodsCol(),
    (snap) => cb(snap.docs.map((d) => toFood(d.id, d.data()))),
    onError,
  )
}

/** Campos que el usuario edita en el formulario. */
export type FoodInput = Pick<Food, 'name' | 'aliases' | 'brand' | 'barcode' | 'per100g' | 'portions' | 'density'>

export const USER_SOURCE: FoodSource = { type: 'USER', ref: null, license: null }

export async function createFood(input: FoodInput, uid: string, source: FoodSource = USER_SOURCE): Promise<string> {
  const ref = await addDoc(foodsCol(), {
    ...input,
    source,
    verified: false,
    createdBy: uid,
    createdAt: serverTimestamp(),
  })
  return ref.id
}

export function updateFood(id: string, input: FoodInput) {
  return updateDoc(doc(foodsCol(), id), { ...input, updatedAt: serverTimestamp() })
}

export interface SeedPlan {
  /** Alimentos de la semilla que aún no existen en el catálogo. */
  missing: Food[]
  /** Alimentos de la semilla creados por este usuario que aún no tienen fibra. */
  fiberPatches: Food[]
}

export function seedPlan(existing: Food[], uid: string): SeedPlan {
  const byId = new Map(existing.map((f) => [f.id, f]))
  const seed = seedFoods(uid)
  return {
    missing: seed.filter((f) => !byId.has(f.id)),
    fiberPatches: seed.filter((f) => {
      const current = byId.get(f.id)
      return current !== undefined && current.createdBy === uid && current.fiberMissing && f.per100g.fiber > 0
    }),
  }
}

/** Importa la semilla y completa la fibra de los alimentos propios que no la tenían. */
export async function importSeed(uid: string, existing: Food[]): Promise<{ added: number; updated: number }> {
  const { missing, fiberPatches } = seedPlan(existing, uid)
  const ops = [
    ...missing.map((food) => ({ kind: 'add' as const, food })),
    ...fiberPatches.map((food) => ({ kind: 'fiber' as const, food })),
  ]
  for (let i = 0; i < ops.length; i += 400) {
    const batch = writeBatch(getDb())
    for (const { kind, food } of ops.slice(i, i + 400)) {
      const ref = doc(foodsCol(), food.id)
      if (kind === 'add') {
        const { id: _id, fiberMissing: _fiberMissing, ...data } = food
        batch.set(ref, { ...data, createdAt: serverTimestamp() })
      } else {
        batch.update(ref, { 'per100g.fiber': food.per100g.fiber, updatedAt: serverTimestamp() })
      }
    }
    await batch.commit()
  }
  return { added: missing.length, updated: fiberPatches.length }
}
