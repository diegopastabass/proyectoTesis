import { describe, expect, it } from 'vitest'
import { heatmapWeeks, countByDate, weekStart, weeklyStreak } from '../strength/calendar'
import { ExerciseIndex, buildExercises } from '../strength/catalog'
import { sinceText, workoutInsights } from '../strength/insights'
import { emptyWorkout, finishWorkout, toggleDone, workoutFromRoutine, type DraftSet } from '../strength/session'
import { estimate1RM, exerciseHistory, lastSetsFor, matchPrevious, workoutTotals, workoutVolume } from '../strength/stats'
import type { StrengthSet, Workout } from '../strength/types'

const set = (kg: number | null, reps: number, type: StrengthSet['type'] = 'normal'): StrengthSet => ({ type, kg, reps })

let n = 0
function workout(date: string, exercises: Record<string, StrengthSet[]>, extra: Partial<Workout> = {}): Workout {
  const startedAt = new Date(`${date}T18:00:00`).getTime()
  return {
    id: `w${++n}`,
    routineId: 'pecho',
    name: 'Rutina de pecho',
    date,
    startedAt,
    finishedAt: startedAt + 60 * 60_000,
    exercises: Object.entries(exercises).map(([exerciseId, sets]) => ({ exerciseId, name: exerciseId, sets })),
    ...extra,
  }
}

describe('volumen y totales', () => {
  it('suma kg × reps de las series efectivas, sin calentamiento', () => {
    const w = workout('2026-10-20', { banca: [set(30, 6, 'warmup'), set(55, 5), set(55, 5, 'failure')], fondos: [set(null, 12)] })
    expect(workoutVolume(w)).toBe(550)
    expect(workoutTotals(w)).toMatchObject({ volume: 550, sets: 3, reps: 22, exercises: 2, durationMin: 60 })
  })

  it('estima el 1RM con Epley', () => {
    expect(estimate1RM(100, 1)).toBe(100)
    expect(estimate1RM(100, 10)).toBeCloseTo(133.33, 1)
    expect(estimate1RM(0, 10)).toBe(0)
  })
})

describe('sesión anterior', () => {
  const ws = [
    workout('2026-10-13', { banca: [set(30, 6, 'warmup'), set(52.5, 6), set(55, 5)] }),
    workout('2026-10-06', { banca: [set(50, 6)] }),
  ]

  it('toma la sesión más reciente con el ejercicio', () => {
    expect(lastSetsFor(ws, 'banca')).toHaveLength(3)
    expect(lastSetsFor(ws, 'banca', ws[0].startedAt)).toEqual([set(50, 6)])
    expect(lastSetsFor(ws, 'sentadilla')).toBeNull()
  })

  it('empareja calentamiento con calentamiento y efectivas con efectivas', () => {
    const prev = lastSetsFor(ws, 'banca')
    const types: StrengthSet['type'][] = ['warmup', 'normal', 'normal', 'failure']
    expect(matchPrevious(prev, types, 0)).toEqual(set(30, 6, 'warmup'))
    expect(matchPrevious(prev, types, 1)).toEqual(set(52.5, 6))
    expect(matchPrevious(prev, types, 2)).toEqual(set(55, 5))
    expect(matchPrevious(prev, types, 3)).toBeNull()
  })

  it('resume la historia de un ejercicio en orden', () => {
    const h = exerciseHistory(ws, 'banca')
    expect(h.map((x) => x.maxKg)).toEqual([50, 55])
    expect(h[1]).toMatchObject({ repsAtMax: 5, sets: 2, volume: 590 })
  })
})

describe('sesión en curso', () => {
  const routine = { id: 'pecho', name: 'Rutina de pecho', updatedAt: 0, exercises: [{ exerciseId: 'banca', sets: [set(60, 8), set(60, 8)] }] }

  it('parte desde la rutina con sus valores como sugerencia', () => {
    const w = workoutFromRoutine(routine, 1000)
    expect(w.exercises[0].sets).toHaveLength(2)
    expect(w.exercises[0].sets[0]).toMatchObject({ kg: '', reps: '', targetKg: 60, targetReps: 8, done: false })
  })

  it('al marcar una serie vacía usa la sesión anterior o la rutina; sin repeticiones no se marca', () => {
    const s: DraftSet = { key: 'a', type: 'normal', kg: '', reps: '', done: false, targetKg: null, targetReps: null }
    expect(toggleDone(s, set(52.5, 6))).toMatchObject({ kg: '52,5', reps: '6', done: true })
    expect(toggleDone(s, null)).toBeNull()
    expect(toggleDone({ ...s, reps: '10' }, null)).toMatchObject({ kg: '', reps: '10', done: true })
    const fromRoutine = { ...s, targetKg: 50, targetReps: 8 }
    expect(toggleDone(fromRoutine, null)).toMatchObject({ kg: '50', reps: '8' })
    expect(toggleDone(fromRoutine, set(55, 6))).toMatchObject({ kg: '55', reps: '6' })
  })

  it('al terminar guarda solo series hechas y omite ejercicios vacíos', () => {
    const w = workoutFromRoutine(routine, new Date('2026-10-20T18:00:00').getTime())
    w.exercises[0].sets[0] = { ...w.exercises[0].sets[0], kg: '62,5', reps: '8', done: true }
    w.exercises.push({ key: 'x', exerciseId: 'fondos', sets: [] })
    const saved = finishWorkout(w, w.startedAt + 1000, (id) => id.toUpperCase())
    expect(saved.date).toBe('2026-10-20')
    expect(saved.exercises).toEqual([{ exerciseId: 'banca', name: 'BANCA', sets: [set(62.5, 8)] }])
    expect(finishWorkout(emptyWorkout(0), 1, (id) => id).exercises).toEqual([])
  })
})

describe('calendario', () => {
  it('las semanas parten el lunes', () => {
    expect(weekStart('2026-10-22')).toBe('2026-10-19') // jueves → lunes
    expect(weekStart('2026-10-25')).toBe('2026-10-19') // domingo
    expect(weekStart('2026-10-19')).toBe('2026-10-19')
  })

  it('arma columnas de 7 días que terminan en la semana actual', () => {
    const grid = heatmapWeeks(countByDate(['2026-10-20', '2026-10-20', '2026-10-13']), '2026-10-22', 2)
    expect(grid).toHaveLength(2)
    expect(grid[0][0].date).toBe('2026-10-12')
    expect(grid[1][1]).toEqual({ date: '2026-10-20', count: 2, future: false })
    expect(grid[1][6]).toMatchObject({ date: '2026-10-25', future: true })
  })

  it('cuenta semanas seguidas sin cortar la racha si la semana actual aún no tiene entrenamiento', () => {
    expect(weeklyStreak(['2026-10-06', '2026-10-13', '2026-10-21'], '2026-10-22')).toBe(3)
    expect(weeklyStreak(['2026-10-06', '2026-10-13'], '2026-10-22')).toBe(2)
    expect(weeklyStreak(['2026-09-01', '2026-10-13'], '2026-10-22')).toBe(1)
    expect(weeklyStreak([], '2026-10-22')).toBe(0)
  })
})

describe('mensajes de motivación', () => {
  it('celebra el primer entrenamiento', () => {
    const w = workout('2026-10-20', { banca: [set(50, 5)] })
    expect(workoutInsights(w, [w])[0].kind).toBe('first')
  })

  it('detecta récord, más series, más repeticiones y más volumen', () => {
    const prev = workout('2026-10-13', { banca: [set(52.5, 6)], remo: [set(40, 10)], curl: [set(12, 8)], fondos: [set(null, 10)] })
    const cur = workout('2026-10-20', {
      banca: [set(55, 5)],
      remo: [set(40, 10), set(40, 10)],
      curl: [set(12, 10)],
      fondos: [set(null, 12)],
      sentadilla: [set(80, 5)],
    })
    const texts = workoutInsights(cur, [prev, cur], 20).map((i) => i.text)
    expect(texts).toContain('Nuevo récord en banca: 55 kg × 5.')
    expect(texts).toContain('Hoy hiciste 1 serie más de remo que la última vez (la semana pasada).')
    expect(texts).toContain('Más repeticiones en curl con 12 kg: 10 (antes 8).')
    expect(texts).toContain('Más repeticiones en fondos: 12 (antes 10).')
    expect(texts).toContain('Primera vez registrando sentadilla.')
    expect(texts.some((t) => t.startsWith('Volumen total') && t.includes('Rutina de pecho'))).toBe(true)
    expect(texts).toContain('Llevas 2 semanas seguidas entrenando.')
  })

  it('compara solo con sesiones anteriores', () => {
    const old = workout('2026-10-06', { banca: [set(50, 5)] })
    const mid = workout('2026-10-13', { banca: [set(60, 5)] })
    const later = workout('2026-10-20', { banca: [set(70, 5)] })
    const texts = workoutInsights(mid, [old, mid, later]).map((i) => i.text)
    expect(texts).toContain('Nuevo récord en banca: 60 kg × 5.')
  })

  it('describe cuánto pasó desde la última vez', () => {
    expect(sinceText('2026-10-21', '2026-10-22')).toBe('ayer')
    expect(sinceText('2026-10-15', '2026-10-22')).toBe('la semana pasada')
    expect(sinceText('2026-10-10', '2026-10-22')).toBe('hace 12 días')
  })
})

describe('catálogo', () => {
  const list = buildExercises(
    [
      { id: 'Barbell_Squat', name: 'Barbell Squat', category: 'strength', equipment: 'barbell', primary: ['quadriceps'], secondary: [], images: 2 },
      { id: 'Barbell_Curl', name: 'Barbell Curl', category: 'strength', equipment: 'barbell', primary: ['biceps'], secondary: [], images: 2 },
      { id: 'Zercher_Squats', name: 'Zercher Squats', category: 'strength', equipment: 'barbell', primary: ['quadriceps'], secondary: [], images: 2 },
    ],
    { Barbell_Squat: { name: 'Sentadilla con barra', aliases: ['squat'] }, Barbell_Curl: { name: 'Curl de bíceps con barra' } },
  )
  const index = new ExerciseIndex(list)

  it('encuentra por nombre en español, en inglés y con errores de tipeo', () => {
    expect(index.search({ query: 'sentadila', group: null })[0].id).toBe('Barbell_Squat')
    expect(index.search({ query: 'zercher', group: null })[0].id).toBe('Zercher_Squats')
    expect(index.search({ query: 'biceps', group: null })[0].id).toBe('Barbell_Curl')
  })

  it('filtra por grupo muscular y muestra primero los traducidos', () => {
    expect(index.search({ query: '', group: 'piernas' }).map((e) => e.id)).toEqual(['Barbell_Squat', 'Zercher_Squats'])
  })
})
