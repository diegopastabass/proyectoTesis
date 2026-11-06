import { ChevronRight, Timer } from 'lucide-react'
import { Link, Outlet, useLocation } from 'react-router-dom'
import { useElapsed } from './format'
import { StrengthProvider, useStrength } from './StrengthProvider'

/** Contenedor de las rutas de /fuerza: datos del módulo y aviso de sesión en curso. */
export function StrengthLayout() {
  return (
    <StrengthProvider>
      <Outlet />
      <ActiveWorkoutPill />
    </StrengthProvider>
  )
}

/** Acceso rápido a la sesión en curso desde cualquier pantalla del módulo. */
function ActiveWorkoutPill() {
  const { active } = useStrength()
  const { pathname } = useLocation()
  const elapsed = useElapsed(active?.startedAt ?? null)
  if (!active || pathname === '/fuerza/entrenar' || pathname === '/fuerza') return null
  return (
    <Link
      to="/fuerza/entrenar"
      className="fixed inset-x-0 bottom-[calc(4.25rem+env(safe-area-inset-bottom))] z-20 mx-auto flex w-fit animate-sheet-up items-center gap-2 rounded-full gradient-primary px-4 py-2 text-sm font-semibold text-on-primary shadow-lg shadow-black/30"
    >
      <Timer className="size-4 animate-pulse" aria-hidden />
      <span className="max-w-40 truncate">{active.name}</span>
      <span className="tabular-nums">{elapsed}</span>
      <ChevronRight className="size-4" aria-hidden />
    </Link>
  )
}
