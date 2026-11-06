import { MACRO_KEYS, type Macros } from '../core/types'
import { MACRO_META } from './meta'

/** Resumen compacto: 320 kcal · P 25 · C 30 · G 8 (· Fib 4 si tiene fibra) */
export function MacroInline({ macros, className = '' }: { macros: Macros; className?: string }) {
  return (
    <span className={`inline-flex flex-wrap items-center gap-x-2 text-xs tabular-nums ${className}`}>
      {MACRO_KEYS.filter((k) => k !== 'fiber' || macros.fiber > 0).map((k) => (
        <span key={k} className="inline-flex items-center gap-1" title={MACRO_META[k].label}>
          <span className={`size-1.5 rounded-full ${MACRO_META[k].bg}`} aria-hidden />
          {k === 'kcal' ? (
            <span className="text-fg">{Math.round(macros.kcal)}</span>
          ) : (
            <span className="text-muted">
              {MACRO_META[k].short} {Math.round(macros[k] * 10) / 10}
            </span>
          )}
        </span>
      ))}
    </span>
  )
}
