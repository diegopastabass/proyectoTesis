import { Dumbbell, Pause, Play } from 'lucide-react'
import { useEffect, useState } from 'react'
import { exerciseImage } from '../../core/strength/catalog'
import type { Exercise } from '../../core/strength/types'
import { IconButton } from '../../ui/IconButton'
import { prefersReducedMotion } from '../../ui/motion'

/** Miniatura: foto de la posición inicial. */
export function ExerciseThumb({ exercise, className = 'size-10' }: { exercise: Exercise | undefined; className?: string }) {
  const src = exercise ? exerciseImage(exercise, 0) : null
  const [failed, setFailed] = useState(false)
  if (!src || failed) {
    return (
      <span className={`flex shrink-0 items-center justify-center rounded-lg bg-primary-soft text-primary ${className}`} aria-hidden>
        <Dumbbell className="size-1/2" strokeWidth={2.25} />
      </span>
    )
  }
  return <img src={src} alt="" loading="lazy" decoding="async" onError={() => setFailed(true)} className={`shrink-0 rounded-lg bg-surface-2 object-cover ${className}`} />
}

const FRAME_MS = 900

/**
 * "Animación" del ejercicio: alterna la foto de la posición inicial y la final
 * con un fundido. Se detiene si el sistema pide reducir el movimiento.
 */
export function ExerciseAnimation({ exercise }: { exercise: Exercise }) {
  const start = exerciseImage(exercise, 0)
  const end = exerciseImage(exercise, 1)
  const [playing, setPlaying] = useState(() => !prefersReducedMotion())
  const [frame, setFrame] = useState<0 | 1>(0)
  const [failed, setFailed] = useState(false)

  useEffect(() => {
    if (!playing || !end) return
    const id = setInterval(() => setFrame((f) => (f === 0 ? 1 : 0)), FRAME_MS)
    return () => clearInterval(id)
  }, [playing, end])

  if (!start || !end || failed) {
    return (
      <div className="flex aspect-[3/2] w-full items-center justify-center rounded-xl bg-primary-soft text-primary">
        <Dumbbell className="size-12 animate-float" strokeWidth={2} aria-hidden />
        <span className="sr-only">Sin imagen</span>
      </div>
    )
  }

  return (
    <div className="relative aspect-[3/2] w-full overflow-hidden rounded-xl bg-surface-2">
      {[start, end].map((src, i) => (
        <img
          key={src}
          src={src}
          alt={i === 0 ? `${exercise.name}: posición inicial` : `${exercise.name}: posición final`}
          onError={() => setFailed(true)}
          className="absolute inset-0 size-full object-cover transition-opacity duration-500"
          style={{ opacity: frame === i ? 1 : 0 }}
          aria-hidden={frame !== i}
        />
      ))}
      <div className="absolute bottom-2 left-2 flex gap-1">
        {[0, 1].map((i) => (
          <span key={i} className={`h-1 w-5 rounded-full transition-colors ${frame === i ? 'bg-primary' : 'bg-white/40'}`} aria-hidden />
        ))}
      </div>
      <IconButton
        icon={playing ? Pause : Play}
        label={playing ? 'Pausar animación' : 'Reproducir animación'}
        variant="soft"
        className="absolute right-2 bottom-2 bg-bg/80 backdrop-blur"
        onClick={() => setPlaying((p) => !p)}
      />
    </div>
  )
}
