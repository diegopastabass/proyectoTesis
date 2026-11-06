import { useMemo } from 'react'
import type { WeightEntry } from '../../core/progress'
import { TrendChart } from '../../ui/TrendChart'

interface Props {
  entries: WeightEntry[]
  /** Peso objetivo: se dibuja como línea de referencia. */
  target: number | null
}

const fmtKg = (n: number) => (Math.round(n * 10) / 10).toLocaleString('es-CL')

export function WeightChart({ entries, target }: Props) {
  const points = useMemo(() => entries.map((e) => ({ date: e.date, value: e.kg })), [entries])
  const reference = useMemo(() => (target === null ? null : { value: target, label: `Meta ${fmtKg(target)} kg` }), [target])
  return <TrendChart points={points} unit="kg" label="peso" format={fmtKg} reference={reference} />
}
