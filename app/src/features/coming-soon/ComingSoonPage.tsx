import { Construction } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { moduleById, type ModuleId } from '../../app/modules'
import { IconButton } from '../../ui/IconButton'

/** Pantalla de un módulo que aún no está disponible. */
export function ComingSoonPage({ module: id }: { module: ModuleId }) {
  const navigate = useNavigate()
  const { label, icon: Icon, summary } = moduleById(id)
  const nutrition = moduleById('nutricion')

  return (
    <section className="card overflow-hidden" aria-labelledby="coming-soon-title">
      <p className="flex items-center justify-center gap-1.5 border-b border-warning/30 bg-warning/15 px-3 py-1.5 text-xs font-semibold tracking-wide text-warning uppercase" role="status">
        <Construction className="size-3.5" strokeWidth={2.5} aria-hidden />
        En desarrollo
      </p>

      <div className="flex flex-col items-center gap-3 px-6 py-10 text-center">
        <div className="relative">
          <span className="flex size-16 animate-pop items-center justify-center rounded-2xl gradient-primary text-on-primary shadow-sm shadow-black/20">
            <Icon className="size-8" strokeWidth={2.25} aria-hidden />
          </span>
          <span
            className="absolute -right-2 -bottom-2 flex size-7 animate-float items-center justify-center rounded-full bg-warning text-on-primary ring-2 ring-surface"
            title="Estamos trabajando en este módulo"
          >
            <Construction className="size-4" strokeWidth={2.5} aria-hidden />
          </span>
        </div>

        <div className="flex flex-col gap-1">
          <h1 id="coming-soon-title" className="text-base font-semibold text-fg-strong">
            Módulo de {label.toLowerCase()}
          </h1>
          <p className="text-xs text-muted">Estamos trabajando en este módulo.</p>
        </div>

        <p className="max-w-xs text-xs leading-relaxed text-faint">{summary}</p>

        <IconButton icon={nutrition.icon} label={`Ir a ${nutrition.label}`} text={nutrition.label} variant="soft" onClick={() => navigate(nutrition.to)} />
      </div>
    </section>
  )
}
