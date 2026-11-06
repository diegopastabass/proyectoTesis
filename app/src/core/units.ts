import { normalize } from './normalize'

export type UnitKey =
  | 'g'
  | 'ml'
  | 'unidad'
  | 'porcion'
  | 'taza'
  | 'vaso'
  | 'cda'
  | 'cdta'
  | 'rebanada'
  | 'lata'
  | 'scoop'

export type SizeKey = 'pequeño' | 'mediano' | 'grande'

interface UnitAlias {
  unit: UnitKey
  /** Multiplicador hacia la unidad base (kg → g = 1000). */
  factor: number
}

const UNIT_ALIASES: Record<string, UnitAlias> = {}

function alias(unit: UnitKey, factor: number, words: string[]) {
  for (const w of words) UNIT_ALIASES[w] = { unit, factor }
}

alias('g', 1, ['g', 'gr', 'grs', 'gramo', 'gramos'])
alias('g', 1000, ['kg', 'kgs', 'kilo', 'kilos', 'kilogramo', 'kilogramos'])
alias('ml', 1, ['ml', 'cc', 'mililitro', 'mililitros'])
alias('ml', 1000, ['l', 'lt', 'lts', 'litro', 'litros'])
alias('unidad', 1, ['unidad', 'unidades', 'u', 'ud', 'uds', 'und', 'pieza', 'piezas'])
alias('porcion', 1, ['porcion', 'porciones', 'plato', 'platos'])
alias('taza', 1, ['taza', 'tazas'])
alias('vaso', 1, ['vaso', 'vasos'])
alias('cda', 1, ['cda', 'cdas', 'cucharada', 'cucharadas'])
alias('cdta', 1, ['cdta', 'cdtas', 'cdita', 'cditas', 'cucharadita', 'cucharaditas'])
alias('rebanada', 1, [
  'rebanada', 'rebanadas', 'lamina', 'laminas', 'lonja', 'lonjas',
  'tajada', 'tajadas', 'rodaja', 'rodajas',
])
alias('lata', 1, ['lata', 'latas'])
alias('scoop', 1, ['scoop', 'scoops', 'medida', 'medidas'])

export function lookupUnit(token: string): UnitAlias | null {
  return UNIT_ALIASES[token] ?? null
}

const SIZE_ALIASES: Record<string, SizeKey> = {
  pequeno: 'pequeño',
  pequena: 'pequeño',
  chico: 'pequeño',
  chica: 'pequeño',
  mediano: 'mediano',
  mediana: 'mediano',
  grande: 'grande',
  grandes: 'grande',
}

export function lookupSize(token: string): SizeKey | null {
  return SIZE_ALIASES[token] ?? null
}

/** Volúmenes genéricos (ml) cuando el alimento no define la porción. */
export const GENERIC_ML: Partial<Record<UnitKey, number>> = {
  taza: 240,
  vaso: 200,
  cda: 15,
  cdta: 5,
}

/** Pesos genéricos (g) cuando el alimento no define la porción. */
export const GENERIC_G: Partial<Record<UnitKey, number>> = {
  scoop: 30,
}

export const UNIT_LABELS: Record<UnitKey, string> = {
  g: 'g',
  ml: 'ml',
  unidad: 'unidad',
  porcion: 'porción',
  taza: 'taza',
  vaso: 'vaso',
  cda: 'cda',
  cdta: 'cdta',
  rebanada: 'rebanada',
  lata: 'lata',
  scoop: 'scoop',
}

export function samePortionName(a: string, b: string): boolean {
  return normalize(a) === normalize(b)
}
