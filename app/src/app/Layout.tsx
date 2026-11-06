import { Apple, CalendarDays, ChartLine, ChefHat, Dumbbell, History, Library, ListPlus, LogOut, Moon, Sun, Target, type LucideIcon } from 'lucide-react'
import { useEffect, useRef } from 'react'
import { Link, NavLink, Outlet, useLocation } from 'react-router-dom'
import { signOutUser } from '../services/auth'
import { usingEmulators } from '../services/firebase'
import { IconButton } from '../ui/IconButton'
import { Logo } from '../ui/Logo'
import { useUser } from './AuthProvider'
import { useData } from './DataProvider'
import { MODULES, moduleForPath, type ModuleId } from './modules'
import { useTheme } from './useTheme'

type NavItem = { to: string; icon: LucideIcon; label: string; end?: boolean }

/** Secciones de cada módulo (barra inferior). Un módulo sin secciones no muestra la barra. */
const SECTION_NAV: Partial<Record<ModuleId, NavItem[]>> = {
  nutricion: [
    { to: '/', icon: CalendarDays, label: 'Diario', end: true },
    { to: '/registrar', icon: ListPlus, label: 'Registrar' },
    { to: '/alimentos', icon: Apple, label: 'Alimentos' },
    { to: '/recetas', icon: ChefHat, label: 'Recetas' },
    { to: '/progreso', icon: ChartLine, label: 'Progreso' },
    { to: '/objetivos', icon: Target, label: 'Objetivos diarios' },
  ],
  fuerza: [
    { to: '/fuerza', icon: Dumbbell, label: 'Entrenar', end: true },
    { to: '/fuerza/historial', icon: History, label: 'Historial' },
    { to: '/fuerza/progreso', icon: ChartLine, label: 'Progreso' },
    { to: '/fuerza/ejercicios', icon: Library, label: 'Ejercicios' },
  ],
}

export function Layout() {
  const user = useUser()
  const { error } = useData()
  const [theme, toggleTheme] = useTheme()
  const { pathname } = useLocation()
  const current = moduleForPath(pathname)
  const sections = SECTION_NAV[current.id]
  const contentRef = useRef<HTMLDivElement>(null)

  // Reinicia la animación de entrada en cada cambio de pantalla sin volver a montar
  // la página (eso reiniciaría las suscripciones de cada módulo).
  useEffect(() => {
    const el = contentRef.current
    if (!el) return
    el.classList.remove('animate-fade-up')
    void el.offsetWidth
    el.classList.add('animate-fade-up')
  }, [pathname])

  return (
    <div className="mx-auto flex min-h-dvh max-w-2xl flex-col">
      <header className="sticky top-0 z-30 flex items-center justify-between gap-2 border-b border-border bg-bg/90 px-4 py-2 backdrop-blur">
        <div className="flex min-w-0 items-center gap-2">
          <Logo className="size-7 shrink-0" />
          <span className="hidden text-sm font-semibold tracking-tight text-fg-strong sm:inline">Nutri</span>
          {usingEmulators && (
            <span className="shrink-0 rounded bg-warning/15 px-1.5 py-0.5 text-[10px] font-medium text-warning" title="Conectado al emulador de Firebase">
              emu<span className="hidden sm:inline">lador</span>
            </span>
          )}
        </div>

        <nav aria-label="Módulos">
          <ul className="flex items-center gap-0.5 rounded-xl border border-border bg-surface p-0.5">
            {MODULES.map(({ id, to, icon: Icon, label, ready }) => {
              const active = current.id === id
              const title = ready ? label : `${label} · en desarrollo`
              return (
                <li key={id}>
                  <Link
                    to={to}
                    aria-label={title}
                    aria-current={active ? 'page' : undefined}
                    title={title}
                    className={`relative flex h-8 items-center gap-1.5 rounded-lg text-xs font-semibold transition active:scale-95 ${
                      active ? 'gradient-primary px-2.5 text-on-primary shadow-sm shadow-black/20' : 'w-8 justify-center text-muted hover:bg-surface-2 hover:text-fg'
                    }`}
                  >
                    <Icon key={String(active)} className={`size-4 shrink-0 ${active ? 'animate-pop' : ''}`} strokeWidth={2.25} aria-hidden />
                    {active && <span className="animate-fade-in">{label}</span>}
                    {!ready && !active && <span className="absolute top-1 right-1 size-1.5 rounded-full bg-warning" aria-hidden />}
                  </Link>
                </li>
              )
            })}
          </ul>
        </nav>

        <div className="flex items-center gap-1">
          <IconButton icon={theme === 'dark' ? Sun : Moon} label={theme === 'dark' ? 'Tema claro' : 'Tema oscuro'} onClick={toggleTheme} />
          {user.photoURL ? (
            <img src={user.photoURL} alt="" className="size-7 rounded-full ring-1 ring-border" referrerPolicy="no-referrer" title={user.displayName ?? user.email ?? ''} />
          ) : (
            <span className="flex size-7 items-center justify-center rounded-full bg-primary-soft text-xs font-semibold text-primary" title={user.email ?? ''}>
              {(user.displayName ?? user.email ?? '?')[0].toUpperCase()}
            </span>
          )}
          <IconButton icon={LogOut} label="Cerrar sesión" onClick={() => signOutUser()} />
        </div>
      </header>

      {error && (
        <p className="mx-4 mt-3 rounded-lg border border-danger/40 bg-danger/10 px-3 py-2 text-xs text-danger" role="alert">
          {error}
        </p>
      )}

      <main className={`flex-1 px-4 pt-4 ${sections ? 'pb-[calc(6rem+env(safe-area-inset-bottom))]' : 'pb-8'}`}>
        <div ref={contentRef} className="animate-fade-up">
          <Outlet />
        </div>
      </main>

      {/* safe-area: en modo app (acceso directo en iOS) la barra de inicio tapa la navegación */}
      {sections && (
        <nav className="fixed inset-x-0 bottom-0 z-30 border-t border-border bg-bg/95 pb-[env(safe-area-inset-bottom)] backdrop-blur" aria-label={`Secciones de ${current.label.toLowerCase()}`}>
          <ul className="mx-auto flex max-w-2xl items-center justify-around px-2 py-1.5">
            {sections.map(({ to, icon: Icon, label, end }) => (
              <li key={to}>
                <NavLink
                  to={to}
                  end={end}
                  aria-label={label}
                  title={label}
                  className={({ isActive }) =>
                    `flex size-10 items-center justify-center rounded-xl transition active:scale-90 ${
                      isActive ? 'gradient-primary text-on-primary shadow-sm shadow-black/20' : 'text-muted hover:bg-surface-2 hover:text-fg'
                    }`
                  }
                >
                  {({ isActive }) => (
                    <Icon key={String(isActive)} className={`size-5 ${isActive ? 'animate-pop' : ''}`} strokeWidth={2.25} aria-hidden />
                  )}
                </NavLink>
              </li>
            ))}
          </ul>
        </nav>
      )}
    </div>
  )
}
