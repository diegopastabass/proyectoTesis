import Fuse from 'fuse.js'
import { keyTokens, normalize, singularize } from './normalize'
import type { Food, Recipe } from './types'

export type CatalogKind = 'food' | 'recipe'

export interface CatalogEntry {
  kind: CatalogKind
  id: string
  name: string
  /** Nombre y alias normalizados, también en singular. */
  terms: string[]
}

export interface Candidate {
  kind: CatalogKind
  id: string
  name: string
  /** 0–1, similitud entre la consulta y el mejor término del catálogo. */
  confidence: number
}

export function buildCatalog(foods: Food[], recipes: Recipe[]): CatalogEntry[] {
  const entry = (kind: CatalogKind, id: string, name: string, aliases: string[]): CatalogEntry => {
    const terms = new Set<string>()
    for (const t of [name, ...aliases]) {
      const n = normalize(t)
      if (!n) continue
      terms.add(n)
      terms.add(singularize(n))
    }
    return { kind, id, name, terms: [...terms] }
  }
  return [
    ...recipes.map((r) => entry('recipe', r.id, r.name, r.aliases)),
    ...foods.map((f) => entry('food', f.id, f.name, f.aliases)),
  ]
}

function levenshtein(a: string, b: string): number {
  if (a === b) return 0
  let prev = Array.from({ length: b.length + 1 }, (_, j) => j)
  for (let i = 1; i <= a.length; i++) {
    const cur = [i]
    for (let j = 1; j <= b.length; j++) {
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1))
    }
    prev = cur
  }
  return prev[b.length]
}

function tokenSimilarity(a: string, b: string): number {
  if (a === b) return 1
  const sim = 1 - levenshtein(a, b) / Math.max(a.length, b.length)
  return sim >= 0.75 ? sim : 0
}

function bestCoverage(from: string[], to: string[]): number {
  if (!from.length) return 0
  let sum = 0
  for (const a of from) sum += Math.max(0, ...to.map((b) => tokenSimilarity(a, b)))
  return sum / from.length
}

/**
 * Similitud entre frases: F1 entre la cobertura de la consulta (recall) y la del
 * término (precision). "pan" vs "pan marraqueta" = 0.67: coincide pero es ambiguo.
 */
export function phraseSimilarity(query: string, term: string): number {
  const q = keyTokens(query)
  const t = keyTokens(term)
  const recall = bestCoverage(q, t)
  const precision = bestCoverage(t, q)
  if (recall + precision === 0) return 0
  return (2 * recall * precision) / (recall + precision)
}

export class Matcher {
  private readonly exact = new Map<string, CatalogEntry[]>()
  private readonly fuse: Fuse<CatalogEntry>
  private readonly entries: CatalogEntry[]

  constructor(entries: CatalogEntry[]) {
    this.entries = entries
    for (const e of entries) {
      for (const t of e.terms) {
        const list = this.exact.get(t) ?? []
        list.push(e)
        this.exact.set(t, list)
      }
    }
    this.fuse = new Fuse(entries, {
      keys: ['terms'],
      includeScore: true,
      ignoreLocation: true,
      ignoreDiacritics: true,
      threshold: 0.45,
    })
  }

  get size(): number {
    return this.entries.length
  }

  /** Candidatos ordenados por confianza. Fuse recupera; la similitud por tokens ordena. */
  search(query: string, limit = 5): Candidate[] {
    const q = normalize(query)
    if (!q) return []
    const qs = singularize(q)

    const pool = new Map<string, CatalogEntry>()
    const key = (e: CatalogEntry) => `${e.kind}:${e.id}`
    for (const e of [...(this.exact.get(q) ?? []), ...(this.exact.get(qs) ?? [])]) pool.set(key(e), e)

    const probes = new Set([q, qs, ...q.split(' ').filter((w) => w.length >= 3)])
    for (const p of probes) {
      for (const r of this.fuse.search(p, { limit: 15 })) pool.set(key(r.item), r.item)
    }

    const exactHits = new Set([...(this.exact.get(q) ?? []), ...(this.exact.get(qs) ?? [])].map(key))
    const candidates: Candidate[] = []
    for (const [k, e] of pool) {
      const confidence = exactHits.has(k) ? 1 : Math.max(...e.terms.map((t) => phraseSimilarity(q, t)))
      if (confidence > 0) candidates.push({ kind: e.kind, id: e.id, name: e.name, confidence })
    }

    return candidates
      .sort(
        (a, b) =>
          b.confidence - a.confidence ||
          (a.kind === b.kind ? 0 : a.kind === 'recipe' ? -1 : 1) ||
          a.name.length - b.name.length,
      )
      .slice(0, limit)
  }
}
