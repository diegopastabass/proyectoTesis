import { CalendarCheck, ChevronLeft, ChevronRight } from 'lucide-react'
import { addDays, todayKey } from '../core/date'
import { IconButton } from './IconButton'
import { formatDateLabel } from './meta'

export function DateNav({ date, onChange }: { date: string; onChange: (d: string) => void }) {
  const today = todayKey()
  return (
    <div className="flex items-center gap-1">
      <IconButton icon={ChevronLeft} label="Día anterior" onClick={() => onChange(addDays(date, -1))} />
      <span className="min-w-28 text-center text-sm font-medium capitalize text-fg-strong">{formatDateLabel(date, today)}</span>
      <IconButton icon={ChevronRight} label="Día siguiente" onClick={() => onChange(addDays(date, 1))} />
      {date !== today && <IconButton icon={CalendarCheck} label="Ir a hoy" variant="soft" onClick={() => onChange(today)} />}
    </div>
  )
}
