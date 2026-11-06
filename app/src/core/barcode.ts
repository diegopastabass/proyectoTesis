/**
 * Normaliza un código de barras a GTIN: solo dígitos y UPC-A (12) con un 0
 * adelante para que coincida con su EAN-13 equivalente.
 */
export function normalizeBarcode(raw: string): string {
  const digits = raw.replace(/\D/g, '')
  return digits.length === 12 ? `0${digits}` : digits
}

/** Valida longitud (EAN-8, UPC-A, EAN-13, GTIN-14) y dígito verificador módulo 10. */
export function isValidGtin(code: string): boolean {
  if (!/^\d+$/.test(code) || ![8, 12, 13, 14].includes(code.length)) return false
  const digits = code.split('').map(Number)
  const check = digits.pop()!
  // Desde la derecha, los dígitos alternan peso 3 y 1.
  const sum = digits.reverse().reduce((s, d, i) => s + d * (i % 2 === 0 ? 3 : 1), 0)
  return (10 - (sum % 10)) % 10 === check
}
