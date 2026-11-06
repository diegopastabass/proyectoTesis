import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  onSnapshot,
  query,
  serverTimestamp,
  setDoc,
  where,
  type DocumentData,
} from 'firebase/firestore'
import { normalizeMacros } from '../core/macros'
import type { Macros, Recipe, RecipeIngredient } from '../core/types'
import { getDb } from './firebase'

const recipesCol = () => collection(getDb(), 'recipes')

function toRecipe(id: string, d: DocumentData): Recipe {
  return {
    id,
    ownerId: d.ownerId,
    name: d.name ?? '',
    aliases: d.aliases ?? [],
    servings: d.servings ?? 1,
    ingredients: (d.ingredients ?? []) as RecipeIngredient[],
    totalGrams: d.totalGrams ?? 0,
    totals: normalizeMacros(d.totals as Partial<Macros> | undefined),
    perServing: normalizeMacros(d.perServing as Partial<Macros> | undefined),
  }
}

export function watchRecipes(uid: string, cb: (recipes: Recipe[]) => void, onError: (e: Error) => void) {
  return onSnapshot(
    query(recipesCol(), where('ownerId', '==', uid)),
    (snap) => cb(snap.docs.map((d) => toRecipe(d.id, d.data())).sort((a, b) => a.name.localeCompare(b.name))),
    onError,
  )
}

export type RecipeInput = Omit<Recipe, 'id'>

export async function saveRecipe(input: RecipeInput, id?: string): Promise<string> {
  if (id) {
    await setDoc(doc(recipesCol(), id), { ...input, updatedAt: serverTimestamp() }, { merge: true })
    return id
  }
  const ref = await addDoc(recipesCol(), { ...input, visibility: 'PRIVATE', createdAt: serverTimestamp() })
  return ref.id
}

export function deleteRecipe(id: string) {
  return deleteDoc(doc(recipesCol(), id))
}
