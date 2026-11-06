import type { LucideIcon } from 'lucide-react'
import type { ButtonHTMLAttributes } from 'react'

type Variant = 'primary' | 'soft' | 'ghost' | 'danger'

interface Props extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'children'> {
  icon: LucideIcon
  /** Texto accesible; también se muestra como tooltip. */
  label: string
  variant?: Variant
  size?: 'sm' | 'md'
  /** Texto visible opcional junto al ícono (para acciones principales). */
  text?: string
}

const VARIANTS: Record<Variant, string> = {
  primary: 'gradient-primary text-on-primary hover:brightness-110 shadow-sm shadow-black/20',
  soft: 'bg-primary-soft text-primary hover:bg-primary/25',
  ghost: 'text-muted hover:text-fg hover:bg-surface-2',
  danger: 'text-muted hover:text-danger hover:bg-danger/10',
}

export function IconButton({ icon: Icon, label, variant = 'ghost', size = 'sm', text, className = '', type = 'button', ...rest }: Props) {
  const dims = text ? (size === 'sm' ? 'h-8 px-2.5 gap-1.5' : 'h-9 px-3 gap-2') : size === 'sm' ? 'size-8' : 'size-9'
  return (
    <button
      type={type}
      aria-label={label}
      title={label}
      className={`inline-flex shrink-0 items-center justify-center rounded-lg text-sm font-medium transition active:scale-95 disabled:pointer-events-none disabled:opacity-40 focus-visible:outline-2 focus-visible:outline-primary ${dims} ${VARIANTS[variant]} ${className}`}
      {...rest}
    >
      <Icon className={size === 'sm' ? 'size-4' : 'size-[18px]'} strokeWidth={2.25} aria-hidden />
      {text && <span>{text}</span>}
    </button>
  )
}
