import { Dumbbell, HeartPulse, Salad, type LucideIcon } from 'lucide-react'

export type ModuleId = 'nutricion' | 'fuerza' | 'cardio'

export interface AppModule {
  id: ModuleId
  label: string
  icon: LucideIcon
  /** Ruta de entrada del módulo. */
  to: string
  /** false mientras el módulo se muestra como "En desarrollo". */
  ready: boolean
  /** Qué hará el módulo; se muestra en la pantalla "En desarrollo". */
  summary: string
}

export const MODULES: AppModule[] = [
  {
    id: 'nutricion',
    label: 'Nutrición',
    icon: Salad,
    to: '/',
    ready: true,
    summary: 'Registro de comidas, macros, recetas y progreso corporal.',
  },
  {
    id: 'fuerza',
    label: 'Fuerza',
    icon: Dumbbell,
    to: '/fuerza',
    ready: true,
    summary: 'Registro de rutinas, ejercicios, series, repeticiones y carga.',
  },
  {
    id: 'cardio',
    label: 'Cardio',
    icon: HeartPulse,
    to: '/cardio',
    ready: false,
    summary: 'Registro de sesiones cardiovasculares: duración, distancia, ritmo y frecuencia cardiaca.',
  },
]

export const moduleById = (id: ModuleId) => MODULES.find((m) => m.id === id)!

/** Las rutas de nutrición viven en la raíz; los demás módulos, bajo su propio prefijo. */
export function moduleForPath(pathname: string): AppModule {
  return MODULES.find((m) => m.to !== '/' && (pathname === m.to || pathname.startsWith(`${m.to}/`))) ?? MODULES[0]
}
