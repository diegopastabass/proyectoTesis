/** Convierte texto a número aceptando coma decimal. Devuelve NaN si no es válido. */
export function parseNum(s: string): number {
  const t = s.trim().replace(',', '.')
  return t === '' ? NaN : Number(t)
}

export function numOr(s: string, fallback: number): number {
  const n = parseNum(s)
  return Number.isFinite(n) ? n : fallback
}
