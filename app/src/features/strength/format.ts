import { useEffect, useState } from 'react'
import { fromDateKey, todayKey } from '../../core/date'
import { formatKg, sinceText } from '../../core/strength/insights'
import type { SetType, StrengthSet } from '../../core/strength/types'

export { formatKg }

export const SET_META: Record<SetType, { label: string; short: string | null; className: string }> = {
  normal: { label: 'Serie efectiva', short: null, className: 'text-fg-strong' },
  warmup: { label: 'Calentamiento', short: 'C', className: 'text-warning' },
  failure: { label: 'Al fallo', short: 'F', className: 'text-danger' },
}

/** Etiqueta de cada serie: "C" calentamiento, "F" al fallo y el número de serie efectiva. */
export function setLabels(types: SetType[]): string[] {
  let n = 0
  return types.map((t) => {
    if (t === 'warmup') return 'C'
    n++
    return t === 'failure' ? 'F' : String(n)
  })
}

export function formatSet(s: Pick<StrengthSet, 'kg' | 'reps'>): string {
  if (s.reps === null) return '—'
  return s.kg ? `${formatKg(s.kg)} kg × ${s.reps}` : `${s.reps} reps`
}

export const formatVolume = (kg: number) => `${Math.round(kg).toLocaleString('es-CL')} kg`

/** Eje compacto para volúmenes grandes: 12.500 → "12,5 mil". */
export const compactNumber = (n: number) => n.toLocaleString('es-CL', { notation: 'compact', maximumFractionDigits: 1 })

export function formatDuration(min: number): string {
  if (min < 60) return `${min} min`
  const h = Math.floor(min / 60)
  const m = min % 60
  return m ? `${h} h ${m} min` : `${h} h`
}

const longDate = new Intl.DateTimeFormat('es-CL', { weekday: 'long', day: 'numeric', month: 'long' })
const shortDate = new Intl.DateTimeFormat('es-CL', { day: 'numeric', month: 'short' })

export const formatLongDate = (date: string) => longDate.format(fromDateKey(date))
export const formatShortDate = (date: string) => shortDate.format(fromDateKey(date))

/** "hoy", "ayer", "hace 3 días"… */
export function relativeDay(date: string): string {
  return date === todayKey() ? 'hoy' : sinceText(date, todayKey())
}

/** Cronómetro mm:ss (o h:mm:ss) desde `startedAt`. */
export function useElapsed(startedAt: number | null): string {
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => {
    if (startedAt === null) return
    const id = setInterval(() => setNow(Date.now()), 1000)
    return () => clearInterval(id)
  }, [startedAt])
  if (startedAt === null) return ''
  const total = Math.max(0, Math.floor((now - startedAt) / 1000))
  const h = Math.floor(total / 3600)
  const m = Math.floor((total % 3600) / 60)
  const s = total % 60
  const mm = String(m).padStart(h ? 2 : 1, '0')
  return `${h ? `${h}:` : ''}${mm}:${String(s).padStart(2, '0')}`
}
