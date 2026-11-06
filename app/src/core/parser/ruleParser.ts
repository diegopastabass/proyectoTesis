import { normalize, stripAccents } from '../normalize'
import { lookupSize, lookupUnit, type SizeKey, type UnitKey } from '../units'

/** Ítem extraído de una línea de texto, antes de buscarlo en el catálogo. */
export interface ParsedItem {
  raw: string
  /** Texto a buscar en el catálogo (sin cantidad, unidad ni tamaño). */
  query: string
  /** Cantidad ya convertida a la unidad base (kg → g, l → ml). null = no indicada. */
  quantity: number | null
  unit: UnitKey | null
  size: SizeKey | null
}

const BULLET = /^\s*(?:[-*•·]+|\d+\))\s*/
const NUM = /^\d+(?:[.,]\d+)?$/
const FRACTION = /^(\d+)\/(\d+)$/

const WORD_NUMBERS: Record<string, number> = {
  un: 1, una: 1, uno: 1, medio: 0.5, media: 0.5,
  dos: 2, tres: 3, cuatro: 4, cinco: 5, seis: 6,
  siete: 7, ocho: 8, nueve: 9, diez: 10, doce: 12,
}

/** Palabras que indican una cantidad imprecisa: la cantidad se asume. */
const VAGUE = new Set(['poco', 'poquito', 'algo', 'porcioncita'])

const EDGE_CONNECTORS = new Set(['de', 'del', 'el', 'la', 'los', 'las', 'en', 'con', 'y', 'a', 'al'])

/** Sin unidad, un número desde este valor se interpreta como gramos ("arroz 150"). */
const BARE_NUMBER_GRAMS_THRESHOLD = 20

/** Separa el texto en líneas o ítems (salto de línea, punto y coma o coma no decimal). */
export function splitItems(text: string): string[] {
  return text
    .split(/\n|;|,(?!\d)/)
    .map((s) => s.replace(BULLET, '').trim())
    .filter(Boolean)
}

function readNumber(token: string, allowWords: boolean): number | null {
  if (NUM.test(token)) return parseFloat(token.replace(',', '.'))
  const f = FRACTION.exec(token)
  if (f && Number(f[2]) !== 0) return Number(f[1]) / Number(f[2])
  if (allowWords && token in WORD_NUMBERS) return WORD_NUMBERS[token]
  return null
}

function tokenize(raw: string): string[] {
  const s = stripAccents(raw.toLowerCase())
    .replace(/(\d)\s*\/\s*(\d)/g, '$1/$2') // "1 / 2" → "1/2"
    .replace(/(\d)([a-z])/g, '$1 $2') // "100g" → "100 g", "3x" → "3 x"
    .replace(/([a-z])(\d)/g, '$1 $2') // "x3" → "x 3"
    .replace(/[^a-z0-9.,/\s]/g, ' ')
  return s
    .split(/\s+/)
    .map((t) => t.replace(/^[.,]+|[.,]+$/g, ''))
    .filter(Boolean)
}

/** Interpreta una línea como "Arroz 100g", "1 tomate mediano", "Huevos x3". */
export function parseLine(raw: string): ParsedItem | null {
  const tokens = tokenize(raw)
  const used = new Set<number>()
  let quantity: number | null = null
  let unit: UnitKey | null = null
  let factor = 1
  let size: SizeKey | null = null
  let vague = false

  for (let i = 0; i < tokens.length; i++) {
    const t = tokens[i]

    if (quantity === null) {
      // "x 3" (multiplicador antes del número)
      if (t === 'x' && i + 1 < tokens.length) {
        const n = readNumber(tokens[i + 1], false)
        if (n !== null) {
          quantity = n
          used.add(i).add(i + 1)
          i++
          continue
        }
      }
      // Números escritos en palabras solo al inicio: evita "torta tres leches".
      const n = readNumber(t, i === 0)
      if (n !== null) {
        quantity = n
        used.add(i)
        const fr = FRACTION.exec(tokens[i + 1] ?? '')
        if (fr && Number.isInteger(n) && Number(fr[2]) !== 0) {
          quantity += Number(fr[1]) / Number(fr[2]) // "1 1/2"
          used.add(++i)
        }
        if (tokens[i + 1] === 'x') used.add(++i) // "3 x"
        continue
      }
    }

    if (t === 'par') {
      quantity = 2
      used.add(i)
      continue
    }

    if (unit === null) {
      const u = lookupUnit(t)
      if (u) {
        unit = u.unit
        factor = u.factor
        used.add(i)
        continue
      }
    }

    if (size === null) {
      const sz = lookupSize(t)
      if (sz) {
        size = sz
        used.add(i)
        continue
      }
    }

    if (VAGUE.has(t)) {
      vague = true
      used.add(i)
    }
  }

  if (vague) quantity = null
  else if (unit !== null && quantity === null) quantity = 1
  if (quantity !== null && unit === null && quantity >= BARE_NUMBER_GRAMS_THRESHOLD) unit = 'g'
  if (quantity !== null) quantity *= factor

  const rest = normalize(tokens.filter((_, i) => !used.has(i)).join(' ')).split(' ')
  while (rest.length && EDGE_CONNECTORS.has(rest[0])) rest.shift()
  while (rest.length && EDGE_CONNECTORS.has(rest[rest.length - 1])) rest.pop()
  const query = rest.join(' ').trim()
  if (!query) return null

  return { raw: raw.trim(), query, quantity, unit, size }
}

export function parseText(text: string): ParsedItem[] {
  return splitItems(text)
    .map(parseLine)
    .filter((p): p is ParsedItem => p !== null)
}
