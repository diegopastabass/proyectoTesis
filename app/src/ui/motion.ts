import { useEffect, useRef, useState, type CSSProperties } from 'react'

export function prefersReducedMotion(): boolean {
  return typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true
}

/** Retraso escalonado para listas: cada elemento entra un poco después del anterior. */
export function stagger(index: number, stepMs = 35, maxSteps = 12): CSSProperties {
  return { animationDelay: `${Math.min(index, maxSteps) * stepMs}ms` }
}

/** Número que avanza suavemente hacia `target` (desde 0 al montar). */
export function useCountUp(target: number, durationMs = 800): number {
  const reduced = prefersReducedMotion()
  const [value, setValue] = useState(reduced ? target : 0)
  const current = useRef(value)

  useEffect(() => {
    if (reduced) return
    const from = current.current
    const startedAt = performance.now()
    let frame = 0
    const tick = (now: number) => {
      const t = Math.min(1, (now - startedAt) / durationMs)
      const eased = 1 - (1 - t) ** 3
      current.current = from + (target - from) * eased
      setValue(current.current)
      if (t < 1) frame = requestAnimationFrame(tick)
    }
    frame = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(frame)
  }, [target, durationMs, reduced])

  return reduced ? target : value
}
