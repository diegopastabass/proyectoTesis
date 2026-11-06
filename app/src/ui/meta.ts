import { Apple, Coffee, Croissant, Moon, Soup, type LucideIcon } from 'lucide-react'
import type { MacroKey, MealSlot } from '../core/types'

export const MACRO_META: Record<MacroKey, { label: string; short: string; unit: string; text: string; bg: string }> = {
  kcal: { label: 'Calorías', short: 'kcal', unit: 'kcal', text: 'text-kcal', bg: 'bg-kcal' },
  protein: { label: 'Proteína', short: 'P', unit: 'g', text: 'text-protein', bg: 'bg-protein' },
  carbs: { label: 'Carbohidratos', short: 'C', unit: 'g', text: 'text-carbs', bg: 'bg-carbs' },
  fat: { label: 'Grasa', short: 'G', unit: 'g', text: 'text-fat', bg: 'bg-fat' },
  fiber: { label: 'Fibra', short: 'Fib', unit: 'g', text: 'text-fiber', bg: 'bg-fiber' },
}

export const MEAL_META: Record<MealSlot, { label: string; icon: LucideIcon }> = {
  desayuno: { label: 'Desayuno', icon: Coffee },
  almuerzo: { label: 'Almuerzo', icon: Soup },
  once: { label: 'Once', icon: Croissant },
  cena: { label: 'Cena', icon: Moon },
  snack: { label: 'Snack', icon: Apple },
}

/** Comida sugerida según la hora local. */
export function mealForNow(date = new Date()): MealSlot {
  const h = date.getHours()
  if (h < 11) return 'desayuno'
  if (h < 16) return 'almuerzo'
  if (h < 20) return 'once'
  return 'cena'
}

export function formatDateLabel(key: string, today: string): string {
  const [y, m, d] = key.split('-').map(Number)
  const date = new Date(y, m - 1, d)
  const label = new Intl.DateTimeFormat('es-CL', { weekday: 'short', day: 'numeric', month: 'short' }).format(date)
  return key === today ? `Hoy · ${label}` : label
}
