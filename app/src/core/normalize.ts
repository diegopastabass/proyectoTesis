const DIACRITICS = /[̀-ͯ]/g

export function stripAccents(s: string): string {
  return s.normalize('NFD').replace(DIACRITICS, '')
}

/** Minúsculas, sin tildes ni signos, espacios colapsados. */
export function normalize(s: string): string {
  return stripAccents(s.toLowerCase())
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

/** Singular aproximado en español: tomates → tomate, panes → pan, nueces → nuez. */
export function singularizeWord(w: string): string {
  if (w.length <= 3) return w
  if (w.endsWith('ces')) return w.slice(0, -3) + 'z'
  if (/[lnrdj]es$/.test(w)) return w.slice(0, -2)
  if (w.endsWith('s') && !w.endsWith('ss')) return w.slice(0, -1)
  return w
}

export function singularize(phrase: string): string {
  return phrase.split(' ').map(singularizeWord).join(' ')
}

const STOPWORDS = new Set(['de', 'del', 'el', 'la', 'los', 'las', 'en', 'al', 'a', 'con', 'y'])

/** Tokens significativos (normalizados, en singular, sin artículos ni preposiciones). */
export function keyTokens(s: string): string[] {
  return singularize(normalize(s))
    .split(' ')
    .filter((t) => t && !STOPWORDS.has(t))
}
