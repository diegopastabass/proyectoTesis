import { useSearchParams } from 'react-router-dom'
import { isDateKey, todayKey } from '../core/date'

/** Fecha seleccionada en la URL (?d=YYYY-MM-DD); por defecto hoy. */
export function useDateParam(): [string, (d: string) => void] {
  const [params, setParams] = useSearchParams()
  const raw = params.get('d')
  const date = isDateKey(raw) ? raw : todayKey()
  const setDate = (d: string) =>
    setParams(
      (p) => {
        if (d === todayKey()) p.delete('d')
        else p.set('d', d)
        return p
      },
      { replace: true },
    )
  return [date, setDate]
}
