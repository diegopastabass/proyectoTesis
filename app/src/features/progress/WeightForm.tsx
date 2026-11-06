import { Plus, Scale } from 'lucide-react'
import { useState, type FormEvent } from 'react'
import { useUser } from '../../app/AuthProvider'
import { useToast } from '../../app/ToastProvider'
import { todayKey } from '../../core/date'
import type { WeightEntry } from '../../core/progress'
import { saveWeight } from '../../services/body'
import { IconButton } from '../../ui/IconButton'
import { parseNum } from '../../ui/num'

const MIN_KG = 20
const MAX_KG = 400

export function WeightForm({ entries }: { entries: WeightEntry[] }) {
  const user = useUser()
  const toast = useToast()
  const [date, setDate] = useState(todayKey())
  const [kg, setKg] = useState('')
  const [invalid, setInvalid] = useState(false)
  const [saving, setSaving] = useState(false)

  const last = entries.at(-1)
  const existing = entries.find((e) => e.date === date)

  async function submit(e: FormEvent) {
    e.preventDefault()
    const value = parseNum(kg)
    if (!(value >= MIN_KG && value <= MAX_KG)) {
      setInvalid(true)
      return
    }
    setSaving(true)
    try {
      await saveWeight(user.uid, { date, kg: Math.round(value * 10) / 10 })
      toast(existing ? 'Peso actualizado' : 'Peso registrado')
      setKg('')
    } catch (err) {
      toast((err as Error).message, 'error')
    } finally {
      setSaving(false)
    }
  }

  return (
    <form onSubmit={submit} className="card flex animate-fade-up flex-col gap-2 p-3" aria-label="Registrar peso">
      <div className="flex items-center gap-2">
        <Scale className="size-4 text-primary" aria-hidden />
        <h2 className="text-sm font-semibold text-fg-strong">Registrar peso</h2>
      </div>
      <div className="flex items-end gap-2">
        <label className="flex min-w-0 flex-1 flex-col gap-1">
          <span className="text-xs text-muted">Fecha</span>
          <input className="field" type="date" max={todayKey()} value={date} onChange={(e) => setDate(e.target.value || todayKey())} />
        </label>
        <label className="flex w-28 flex-col gap-1">
          <span className="text-xs text-muted">Peso (kg)</span>
          <input
            className={`field tabular-nums ${invalid ? 'animate-shake border-danger' : ''}`}
            inputMode="decimal"
            placeholder={last ? String(last.kg) : '0'}
            value={kg}
            onChange={(e) => {
              setKg(e.target.value)
              setInvalid(false)
            }}
            aria-invalid={invalid}
            aria-label="Peso en kilogramos"
          />
        </label>
        <IconButton type="submit" icon={Plus} label={existing ? 'Actualizar el peso de ese día' : 'Registrar peso'} variant="primary" size="md" disabled={saving || !kg.trim()} />
      </div>
      {invalid && <p className="text-xs text-danger">Ingresa un peso entre {MIN_KG} y {MAX_KG} kg.</p>}
      {existing && !invalid && <p className="text-[11px] text-faint">Ya hay un registro de {existing.kg.toLocaleString('es-CL')} kg ese día; se reemplazará.</p>}
    </form>
  )
}
