import { X } from 'lucide-react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { IconButton } from './IconButton'

interface Props {
  title: string
  onClose: () => void
  children: ReactNode
}

/** Modales abiertos, del más antiguo al más reciente: Escape cierra solo el último. */
const openModals: symbol[] = []

export function Modal({ title, onClose, children }: Props) {
  const [id] = useState(() => Symbol(title))
  const onCloseRef = useRef(onClose)

  useEffect(() => {
    onCloseRef.current = onClose
  })

  useEffect(() => {
    openModals.push(id)
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && openModals.at(-1) === id) onCloseRef.current()
    }
    window.addEventListener('keydown', onKey)
    return () => {
      window.removeEventListener('keydown', onKey)
      openModals.splice(openModals.indexOf(id), 1)
    }
  }, [id])

  // Portal a <body>: un modal abierto desde otro no queda atrapado en su caja animada.
  return createPortal(
    <div className="fixed inset-0 z-40 flex animate-fade-in items-end justify-center bg-black/60 sm:items-center sm:p-4" onMouseDown={onClose}>
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className="card flex max-h-[90dvh] w-full max-w-lg animate-sheet-up flex-col rounded-b-none bg-bg pb-[env(safe-area-inset-bottom)] sm:animate-scale-in sm:rounded-b-xl sm:pb-0"
        onMouseDown={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between border-b border-border px-4 py-2">
          <h2 className="text-sm font-semibold text-fg-strong">{title}</h2>
          <IconButton icon={X} label="Cerrar" onClick={onClose} />
        </div>
        <div className="overflow-y-auto p-4">{children}</div>
      </div>
    </div>,
    document.body,
  )
}
