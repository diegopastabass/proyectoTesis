import type { LucideIcon } from 'lucide-react'
import type { ReactNode } from 'react'

export function EmptyState({ icon: Icon, title, children }: { icon: LucideIcon; title: string; children?: ReactNode }) {
  return (
    <div className="flex animate-fade-up flex-col items-center gap-2 px-6 py-10 text-center">
      <div className="flex size-11 animate-float items-center justify-center rounded-full bg-primary-soft text-primary">
        <Icon className="size-5" aria-hidden />
      </div>
      <p className="text-sm font-medium text-fg">{title}</p>
      {children && <div className="text-xs text-muted">{children}</div>}
    </div>
  )
}
