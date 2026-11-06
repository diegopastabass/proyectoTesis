import { Leaf } from 'lucide-react'

export function Logo({ className = 'size-8' }: { className?: string }) {
  return (
    <span className={`gradient-primary inline-flex items-center justify-center rounded-lg text-on-primary ${className}`} aria-hidden>
      <Leaf className="size-[60%]" strokeWidth={2.5} />
    </span>
  )
}
