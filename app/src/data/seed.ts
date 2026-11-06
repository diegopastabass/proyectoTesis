import type { Food, FoodSource, Macros, Portion } from '../core/types'
import seed from './foods.seed.json'

interface SeedFood {
  id: string
  name: string
  aliases: string[]
  per100g: Macros
  portions: Portion[]
  density?: number
}

/** Alimentos de la semilla listos para guardar, sin `createdBy`. */
export function seedFoods(createdBy: string): Food[] {
  const source = seed.source as FoodSource
  return (seed.foods as SeedFood[]).map((f) => ({
    id: f.id,
    name: f.name,
    aliases: f.aliases,
    brand: null,
    barcode: null,
    per100g: f.per100g,
    portions: f.portions,
    density: f.density ?? null,
    source,
    verified: false,
    createdBy,
    fiberMissing: false,
  }))
}
