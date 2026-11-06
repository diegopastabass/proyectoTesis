import { ChefHat, Plus, Search } from 'lucide-react'
import { useState } from 'react'
import { useData } from '../../app/DataProvider'
import type { Candidate, Matcher } from '../../core/matcher'
import { IconButton } from '../../ui/IconButton'
import { MacroInline } from '../../ui/MacroInline'
import { Modal } from '../../ui/Modal'

interface Props {
  title?: string
  matcher: Matcher
  initialQuery?: string
  onPick: (c: Candidate) => void
  onClose: () => void
  /** Si se entrega, ofrece crear un alimento con el texto buscado. */
  onCreate?: (name: string) => void
}

export function FoodPicker({ title = 'Elegir alimento', matcher, initialQuery = '', onPick, onClose, onCreate }: Props) {
  const { ctx } = useData()
  const [q, setQ] = useState(initialQuery)
  const results = q.trim() ? matcher.search(q, 12) : []

  return (
    <Modal title={title} onClose={onClose}>
      <label className="relative block">
        <Search className="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-faint" aria-hidden />
        <input
          autoFocus
          className="field w-full pl-8"
          placeholder="Buscar en el catálogo…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          aria-label="Buscar alimento"
        />
      </label>

      <ul className="mt-3 flex flex-col gap-1">
        {results.map((c) => {
          const food = c.kind === 'food' ? ctx.foods.get(c.id) : undefined
          const recipe = c.kind === 'recipe' ? ctx.recipes.get(c.id) : undefined
          return (
            <li key={`${c.kind}:${c.id}`}>
              <button
                type="button"
                onClick={() => onPick(c)}
                className="flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left hover:bg-surface-2"
              >
                {c.kind === 'recipe' && <ChefHat className="size-4 shrink-0 text-primary" aria-label="Receta" />}
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-sm text-fg">{c.name}</span>
                  {food && <MacroInline macros={food.per100g} className="mt-0.5" />}
                  {recipe && <MacroInline macros={recipe.perServing} className="mt-0.5" />}
                </span>
                <span className="text-[10px] text-faint tabular-nums">
                  {food ? '/100 g' : 'porción'} · {Math.round(c.confidence * 100)}%
                </span>
              </button>
            </li>
          )
        })}
      </ul>

      {q.trim() && results.length === 0 && <p className="py-4 text-center text-xs text-muted">Sin coincidencias en el catálogo.</p>}

      {onCreate && q.trim() && (
        <div className="mt-3 flex justify-end border-t border-border pt-3">
          <IconButton icon={Plus} label={`Crear alimento "${q.trim()}"`} text={`Crear "${q.trim()}"`} variant="soft" onClick={() => onCreate(q.trim())} />
        </div>
      )}
    </Modal>
  )
}
