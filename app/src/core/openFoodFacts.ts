import { round1 } from './macros'
import type { Macros } from './types'

/** Borrador de alimento armado desde un producto de Open Food Facts; el usuario lo revisa. */
export interface OffDraft {
  barcode: string
  name: string
  brand: string | null
  /** null cuando el producto no trae información nutricional. */
  per100g: Macros | null
  /** Gramos de una porción según la etiqueta. */
  servingGrams: number | null
  url: string
}

const KJ_PER_KCAL = 4.184

function num(v: unknown): number | null {
  const n = typeof v === 'string' ? Number(v.replace(',', '.')) : v
  return typeof n === 'number' && Number.isFinite(n) && n >= 0 ? n : null
}

function text(v: unknown): string | null {
  return typeof v === 'string' && v.trim() ? v.trim() : null
}

/** Convierte la respuesta `product` de la API v2 en un borrador. */
export function mapOffProduct(code: string, product: Record<string, unknown>): OffDraft {
  const n = (product.nutriments ?? {}) as Record<string, unknown>
  const kj = num(n['energy-kj_100g']) ?? num(n['energy_100g'])
  const kcal = num(n['energy-kcal_100g']) ?? (kj !== null ? kj / KJ_PER_KCAL : null)
  const protein = num(n['proteins_100g'])
  const carbs = num(n['carbohydrates_100g'])
  const fat = num(n['fat_100g'])
  const hasNutrition = [kcal, protein, carbs, fat].some((v) => v !== null)

  return {
    barcode: code,
    name: text(product.product_name_es) ?? text(product.product_name) ?? text(product.generic_name) ?? '',
    brand: text(product.brands)?.split(',')[0].trim() ?? null,
    per100g: hasNutrition
      ? {
          kcal: Math.round(kcal ?? 0),
          protein: round1(protein ?? 0),
          carbs: round1(carbs ?? 0),
          fat: round1(fat ?? 0),
          fiber: round1(num(n['fiber_100g']) ?? 0),
        }
      : null,
    servingGrams: num(product.serving_quantity),
    url: `https://world.openfoodfacts.org/product/${code}`,
  }
}
