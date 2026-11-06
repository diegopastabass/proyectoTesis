import { scoreLevel } from '../core/score'
import { useCountUp } from './motion'

const LEVEL_COLOR = { good: 'var(--success)', mid: 'var(--warning)', low: 'var(--danger)' }

export function ScoreRing({ score, size = 76, empty = false }: { score: number; size?: number; empty?: boolean }) {
  const stroke = 7
  const r = (size - stroke) / 2
  const c = 2 * Math.PI * r
  // El anillo y el número avanzan juntos desde 0 hasta el puntaje.
  const shown = useCountUp(empty ? 0 : score)
  const level = scoreLevel(score)
  const color = empty ? 'var(--faint)' : LEVEL_COLOR[level]
  return (
    <div className="relative shrink-0" style={{ width: size, height: size }} role="img" aria-label={`Puntaje ${score} de 100`}>
      <svg
        width={size}
        height={size}
        className="-rotate-90 transition-[filter] duration-700"
        style={{ filter: !empty && level === 'good' ? `drop-shadow(0 0 6px ${color})` : undefined }}
      >
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--bg-hard)" strokeWidth={stroke} />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke={color}
          strokeWidth={stroke}
          strokeLinecap="round"
          strokeDasharray={c}
          strokeDashoffset={c * (1 - shown / 100)}
          style={{ transition: 'stroke .4s ease' }}
        />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span className="text-xl font-bold tabular-nums text-fg-strong">{empty ? '–' : Math.round(shown)}</span>
        <span className="text-[10px] uppercase tracking-wide text-faint">puntaje</span>
      </div>
    </div>
  )
}
