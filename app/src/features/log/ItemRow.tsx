import { ChefHat, CircleAlert, CircleCheck, CircleHelp, Plus, Search, X } from 'lucide-react'
import { useState } from 'react'
import type { ItemStatus, ResolvedItem } from '../../core/resolve'
import { IconButton } from '../../ui/IconButton'
import { MacroInline } from '../../ui/MacroInline'
import { stagger } from '../../ui/motion'
import { parseNum } from '../../ui/num'

const STATUS: Record<ItemStatus, { icon: typeof CircleCheck; className: string; label: string }> = {
  ok: { icon: CircleCheck, className: 'text-success', label: 'Reconocido' },
  review: { icon: CircleAlert, className: 'text-warning', label: 'Revisar coincidencia o cantidad' },
  missing: { icon: CircleHelp, className: 'text-danger', label: 'No está en el catálogo' },
}

interface Props {
  item: ResolvedItem
  index: number
  onPick: () => void
  onCreate: () => void
  onGrams: (g: number) => void
  onRemove: () => void
}

export function ItemRow({ item, index, onPick, onCreate, onGrams, onRemove }: Props) {
  const status = STATUS[item.status]
  const StatusIcon = status.icon
  return (
    <li className="flex animate-fade-up gap-2 px-3 py-2.5" style={stagger(index, 50)}>
      <span className="mt-0.5 shrink-0" title={status.label}>
        <StatusIcon key={item.status} className={`size-4 animate-pop ${status.className}`} aria-label={status.label} />
      </span>

      <div className="min-w-0 flex-1">
        <p className="truncate font-mono text-[11px] text-faint">{item.parsed.raw}</p>

        {item.match ? (
          <>
            <button
              type="button"
              onClick={onPick}
              className="mt-0.5 flex max-w-full items-center gap-1.5 rounded text-left text-sm text-fg hover:text-primary"
              title="Cambiar coincidencia"
            >
              {item.match.kind === 'recipe' && <ChefHat className="size-3.5 shrink-0 text-primary" aria-label="Receta" />}
              <span className="truncate">{item.match.name}</span>
              <span className="shrink-0 text-[10px] text-faint tabular-nums">{Math.round(item.match.confidence * 100)}%</span>
            </button>
            <div className="mt-1 flex flex-wrap items-center gap-x-2 gap-y-1">
              <GramsInput key={item.grams} grams={item.grams} label={`Gramos de ${item.match.name}`} onCommit={onGrams} />
              <span className={`text-[11px] ${item.assumed ? 'text-warning' : 'text-faint'}`} title={item.assumed ? 'Cantidad supuesta' : undefined}>
                {item.label}
              </span>
              <MacroInline macros={item.macros} />
            </div>
          </>
        ) : (
          <div className="mt-1 flex flex-wrap items-center gap-2">
            <span className="text-sm text-fg">
              "{item.parsed.query}" <span className="text-xs text-muted">no está en el catálogo</span>
            </span>
            <div className="flex gap-1">
              <IconButton icon={Search} label="Buscar en el catálogo" variant="soft" onClick={onPick} />
              <IconButton icon={Plus} label={`Crear alimento "${item.parsed.query}"`} text="Crear" variant="soft" onClick={onCreate} />
            </div>
          </div>
        )}
      </div>

      <IconButton icon={X} label="Quitar de la lista" onClick={onRemove} />
    </li>
  )
}

/** Se reinicia (por `key`) cuando los gramos cambian desde fuera. */
function GramsInput({ grams, label, onCommit }: { grams: number; label: string; onCommit: (g: number) => void }) {
  const [draft, setDraft] = useState(String(grams))
  const commit = () => {
    const g = parseNum(draft)
    if (Number.isFinite(g) && g >= 0 && g !== grams) onCommit(g)
    else setDraft(String(grams))
  }
  return (
    <label className="flex items-center gap-1">
      <input
        className="field h-7 w-16 px-1.5 py-0 text-right text-xs tabular-nums"
        inputMode="decimal"
        value={draft}
        onChange={(e) => setDraft(e.target.value)}
        onBlur={commit}
        onKeyDown={(e) => e.key === 'Enter' && commit()}
        aria-label={label}
      />
      <span className="text-xs text-faint">g</span>
    </label>
  )
}
