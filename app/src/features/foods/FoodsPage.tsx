import { BadgeCheck, Barcode, Database, DatabaseZap, Pencil, Plus, Search, User } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useUser } from '../../app/AuthProvider'
import { useData } from '../../app/DataProvider'
import { useToast } from '../../app/ToastProvider'
import type { Food } from '../../core/types'
import { importSeed, seedPlan } from '../../services/foods'
import { EmptyState } from '../../ui/EmptyState'
import { IconButton } from '../../ui/IconButton'
import { MacroInline } from '../../ui/MacroInline'
import { stagger } from '../../ui/motion'
import { FoodForm } from './FoodForm'

const MAX_ROWS = 150

export function FoodsPage() {
  const user = useUser()
  const toast = useToast()
  const { foods, foodMatcher, ready } = useData()
  const [q, setQ] = useState('')
  const [editing, setEditing] = useState<Food | 'new' | null>(null)
  const [importing, setImporting] = useState(false)

  const byId = useMemo(() => new Map(foods.map((f) => [f.id, f])), [foods])
  const plan = useMemo(() => seedPlan(foods, user.uid), [foods, user.uid])
  const pending = plan.missing.length + plan.fiberPatches.length

  const list = useMemo(() => {
    if (!q.trim()) return [...foods].sort((a, b) => a.name.localeCompare(b.name))
    // Solo dígitos: se busca por código de barras.
    const digits = q.replace(/\s/g, '')
    if (/^\d{4,}$/.test(digits)) return foods.filter((f) => f.barcode?.includes(digits))
    return foodMatcher
      .search(q, MAX_ROWS)
      .map((c) => byId.get(c.id))
      .filter((f): f is Food => f !== undefined)
  }, [q, foods, foodMatcher, byId])

  async function runImport() {
    setImporting(true)
    try {
      const { added, updated } = await importSeed(user.uid, foods)
      const parts = [added && `${added} importados`, updated && `${updated} con fibra completada`].filter(Boolean)
      toast(parts.join(' · '))
    } catch (err) {
      toast((err as Error).message, 'error')
    } finally {
      setImporting(false)
    }
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <label className="relative flex-1">
          <Search className="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-faint" aria-hidden />
          <input className="field w-full pl-8" placeholder={`Buscar en ${foods.length} alimentos o por código…`} value={q} onChange={(e) => setQ(e.target.value)} aria-label="Buscar alimento" />
        </label>
        <IconButton
          icon={DatabaseZap}
          label={
            pending === 0
              ? 'Catálogo base al día'
              : plan.missing.length > 0
                ? `Importar catálogo base (${plan.missing.length} alimentos)`
                : `Completar fibra del catálogo base (${plan.fiberPatches.length} alimentos)`
          }
          variant="soft"
          size="md"
          disabled={!ready || importing || pending === 0}
          onClick={runImport}
        />
        <IconButton icon={Plus} label="Nuevo alimento" variant="primary" size="md" onClick={() => setEditing('new')} />
      </div>

      {ready && foods.length === 0 && (
        <div className="card">
          <EmptyState icon={Database} title="El catálogo está vacío">
            Importa el catálogo base con <DatabaseZap className="inline size-3.5 text-primary" /> o crea tu primer alimento.
          </EmptyState>
        </div>
      )}

      {list.length > 0 && (
        <ul className="card divide-y divide-border overflow-hidden">
          {list.slice(0, MAX_ROWS).map((f, i) => (
            <li key={f.id} className="flex animate-fade-up items-center gap-2 px-3 py-2" style={stagger(i, 25)}>
              <div className="min-w-0 flex-1">
                <p className="flex items-center gap-1.5 text-sm text-fg">
                  <span className="truncate">{f.name}</span>
                  {f.brand && <span className="truncate text-xs text-faint">· {f.brand}</span>}
                  {f.barcode && (
                    <span title={`Código ${f.barcode}`}>
                      <Barcode className="size-3.5 shrink-0 text-faint" aria-label="Tiene código de barras" />
                    </span>
                  )}
                  {f.verified && <BadgeCheck className="size-3.5 shrink-0 text-primary" aria-label="Verificado" />}
                  {f.source.type === 'USER' && (
                    <span title={f.createdBy === user.uid ? 'Creado por ti' : 'Creado por otro usuario'}>
                      <User className={`size-3.5 shrink-0 ${f.createdBy === user.uid ? 'text-primary' : 'text-faint'}`} aria-hidden />
                    </span>
                  )}
                </p>
                <p className="flex flex-wrap items-center gap-x-2 text-xs text-faint">
                  <span>100 g</span>
                  <MacroInline macros={f.per100g} />
                  {f.portions.length > 0 && <span className="truncate">· {f.portions.map((p) => `${p.name} ${p.grams} g`).join(', ')}</span>}
                </p>
              </div>
              {f.createdBy === user.uid && <IconButton icon={Pencil} label={`Editar ${f.name}`} onClick={() => setEditing(f)} />}
            </li>
          ))}
        </ul>
      )}

      {q.trim() && list.length === 0 && <p className="py-4 text-center text-xs text-muted">Sin resultados para "{q}".</p>}

      {editing && <FoodForm food={editing === 'new' ? undefined : editing} initialName={editing === 'new' ? q.trim() : ''} onClose={() => setEditing(null)} />}
    </div>
  )
}
