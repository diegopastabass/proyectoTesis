import { ChefHat, ChevronRight, Plus } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { useData } from '../../app/DataProvider'
import { EmptyState } from '../../ui/EmptyState'
import { IconButton } from '../../ui/IconButton'
import { MacroInline } from '../../ui/MacroInline'
import { stagger } from '../../ui/motion'

export function RecipesPage() {
  const { recipes, ready } = useData()
  const navigate = useNavigate()

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <h1 className="text-sm font-semibold text-fg-strong">Mis recetas</h1>
        <IconButton icon={Plus} label="Nueva receta" variant="primary" size="md" onClick={() => navigate('/recetas/nueva')} />
      </div>

      {ready && recipes.length === 0 && (
        <div className="card">
          <EmptyState icon={ChefHat} title="Aún no tienes recetas">
            Crea una y luego escribe su nombre en la lista, por ejemplo "Pollo al limón 2 porciones".
          </EmptyState>
        </div>
      )}

      {recipes.length > 0 && (
        <ul className="card divide-y divide-border overflow-hidden">
          {recipes.map((r, i) => (
            <li key={r.id} className="animate-fade-up" style={stagger(i, 40)}>
              <Link to={`/recetas/${r.id}`} className="flex items-center gap-3 px-3 py-2.5 hover:bg-surface-2">
                <ChefHat className="size-4 shrink-0 text-primary" aria-hidden />
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm text-fg">{r.name}</p>
                  <p className="flex flex-wrap items-center gap-x-2 text-xs text-faint">
                    <span>
                      {r.servings} porc. · {r.ingredients.length} ingr. · por porción
                    </span>
                    <MacroInline macros={r.perServing} />
                  </p>
                </div>
                <ChevronRight className="size-4 text-faint" aria-hidden />
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
