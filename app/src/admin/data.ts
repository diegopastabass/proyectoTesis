// Datos simulados del panel de administración (CU-10 y CU-11). El panel es una
// pantalla de diseño: no se conecta a ningún backend y las personas son ficticias.

export const MUSCLES = ['Pecho', 'Espalda', 'Hombros', 'Bíceps', 'Tríceps', 'Cuádriceps', 'Isquiotibiales', 'Glúteos', 'Abdomen', 'Pantorrillas']
export const EQUIPMENT = ['Barra', 'Mancuernas', 'Máquina', 'Polea', 'Kettlebell', 'Peso corporal']

export interface Exercise {
  id: string
  name: string
  muscles: string[]
  equipment: string
  active: boolean
  sessions: number
}

export const initialExercises: Exercise[] = [
  { id: 'e1', name: 'Press de banca con barra', muscles: ['Pecho', 'Tríceps'], equipment: 'Barra', active: true, sessions: 1842 },
  { id: 'e2', name: 'Sentadilla con barra', muscles: ['Cuádriceps', 'Glúteos'], equipment: 'Barra', active: true, sessions: 1620 },
  { id: 'e3', name: 'Peso muerto rumano', muscles: ['Isquiotibiales', 'Glúteos'], equipment: 'Barra', active: true, sessions: 974 },
  { id: 'e4', name: 'Dominadas', muscles: ['Espalda', 'Bíceps'], equipment: 'Peso corporal', active: true, sessions: 1133 },
  { id: 'e5', name: 'Remo con mancuerna', muscles: ['Espalda'], equipment: 'Mancuernas', active: true, sessions: 806 },
  { id: 'e6', name: 'Press militar', muscles: ['Hombros', 'Tríceps'], equipment: 'Barra', active: true, sessions: 712 },
  { id: 'e7', name: 'Prensa de piernas', muscles: ['Cuádriceps', 'Glúteos'], equipment: 'Máquina', active: true, sessions: 655 },
  { id: 'e8', name: 'Jalón al pecho', muscles: ['Espalda', 'Bíceps'], equipment: 'Polea', active: true, sessions: 590 },
  { id: 'e9', name: 'Máquina de aductores antigua', muscles: ['Glúteos'], equipment: 'Máquina', active: false, sessions: 41 },
]

export type ReportStatus = 'pending' | 'hidden' | 'kept'

export interface Report {
  id: string
  kind: string
  title: string
  author: string
  excerpt: string
  reason: string
  reporters: number
  when: string
  status: ReportStatus
  hasPhoto: boolean
}

export const initialReports: Report[] = [
  {
    id: 'r1',
    kind: 'Receta',
    title: 'Dieta detox de 500 calorías',
    author: 'Usuario 4821',
    excerpt: 'Una semana con 500 calorías al día y solo jugos. Bajas 5 kilos seguro, no necesitas consultar a nadie.',
    reason: 'Peligroso para la salud',
    reporters: 6,
    when: 'Hace 2 horas',
    status: 'pending',
    hasPhoto: true,
  },
  {
    id: 'r2',
    kind: 'Sesión de fuerza',
    title: 'Rutina de pecho y empuje',
    author: 'Usuario 1190',
    excerpt: 'Hoy tocó empuje antes de la salida larga del domingo. Dejé dos repeticiones en reserva.',
    reason: 'Publicidad o spam',
    reporters: 1,
    when: 'Hace 5 horas',
    status: 'pending',
    hasPhoto: false,
  },
  {
    id: 'r3',
    kind: 'Comida',
    title: 'Almuerzo en el gimnasio',
    author: 'Usuario 7735',
    excerpt: 'Foto del almuerzo con el equipo después de entrenar.',
    reason: 'Foto sin permiso',
    reporters: 2,
    when: 'Ayer',
    status: 'pending',
    hasPhoto: true,
  },
  {
    id: 'r4',
    kind: 'Ruta',
    title: 'Vuelta por el parque',
    author: 'Usuario 3052',
    excerpt: 'Trote suave de media hora.',
    reason: 'Contenido inapropiado',
    reporters: 1,
    when: 'Hace 3 días',
    status: 'kept',
    hasPhoto: false,
  },
]

export interface LogEntry {
  when: string
  who: string
  action: string
  title: string
  why: string
}

export const initialLog: LogEntry[] = [
  { when: 'Hace 3 días', who: 'Administrador de prueba', action: 'Reporte descartado', title: 'Vuelta por el parque', why: 'La publicación cumple las normas de la comunidad.' },
  { when: 'Hace 6 días', who: 'Administrador de prueba', action: 'Publicación oculta', title: 'Suplementos sin receta', why: 'Promueve el consumo de sustancias sin indicación médica.' },
]
