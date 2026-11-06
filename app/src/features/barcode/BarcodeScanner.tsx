import { CameraOff, Check, LoaderCircle } from 'lucide-react'
import { useEffect, useRef, useState, type FormEvent } from 'react'
import { isValidGtin, normalizeBarcode } from '../../core/barcode'
import { IconButton } from '../../ui/IconButton'
import { Modal } from '../../ui/Modal'
import { getDetector } from './detector'

interface Props {
  onDetected: (code: string) => void
  onClose: () => void
}

const SCAN_INTERVAL_MS = 200

function cameraError(err: unknown): string {
  const name = (err as { name?: string }).name
  if (name === 'NotAllowedError') return 'Sin permiso para usar la cámara. Actívalo en los ajustes del navegador o escribe el código.'
  if (name === 'NotFoundError' || name === 'OverconstrainedError') return 'No se encontró una cámara en este dispositivo.'
  if (name === 'NotReadableError') return 'La cámara está ocupada por otra aplicación.'
  return (err as Error).message || 'No se pudo iniciar la cámara.'
}

export function BarcodeScanner({ onDetected, onClose }: Props) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const onDetectedRef = useRef(onDetected)
  const [status, setStatus] = useState<'starting' | 'scanning' | 'error'>('starting')
  const [error, setError] = useState<string | null>(null)
  const [manual, setManual] = useState('')
  const [manualError, setManualError] = useState(false)

  useEffect(() => {
    onDetectedRef.current = onDetected
  })

  useEffect(() => {
    let stream: MediaStream | null = null
    let cancelled = false
    let timer = 0
    const stop = () => {
      stream?.getTracks().forEach((t) => t.stop())
      stream = null
    }

    async function start() {
      if (!navigator.mediaDevices?.getUserMedia) {
        throw new Error(window.isSecureContext ? 'Este navegador no permite usar la cámara.' : 'La cámara requiere una conexión segura (HTTPS).')
      }
      const [media, detector] = await Promise.all([
        navigator.mediaDevices.getUserMedia({
          video: { facingMode: { ideal: 'environment' }, width: { ideal: 1280 }, height: { ideal: 720 } },
          audio: false,
        }),
        getDetector(),
      ])
      if (cancelled) {
        media.getTracks().forEach((t) => t.stop())
        return
      }
      stream = media
      const video = videoRef.current!
      video.srcObject = media
      await video.play()
      setStatus('scanning')

      const scan = async () => {
        if (cancelled) return
        try {
          if (video.readyState >= 2) {
            for (const { rawValue } of await detector.detect(video)) {
              const code = normalizeBarcode(rawValue)
              if (isValidGtin(code)) {
                cancelled = true
                navigator.vibrate?.(60)
                stop()
                onDetectedRef.current(code)
                return
              }
            }
          }
        } catch {
          // Cuadro ilegible: se reintenta en el siguiente.
        }
        timer = window.setTimeout(scan, SCAN_INTERVAL_MS)
      }
      void scan()
    }

    start().catch((err) => {
      if (cancelled) return
      setStatus('error')
      setError(cameraError(err))
    })
    return () => {
      cancelled = true
      clearTimeout(timer)
      stop()
    }
  }, [])

  function submitManual(e: FormEvent) {
    e.preventDefault()
    const code = normalizeBarcode(manual)
    if (!isValidGtin(code)) {
      setManualError(true)
      return
    }
    onDetected(code)
  }

  return (
    <Modal title="Escanear código de barras" onClose={onClose}>
      <div className="relative aspect-[4/3] w-full overflow-hidden rounded-xl bg-black">
        <video ref={videoRef} className="size-full object-cover" playsInline muted autoPlay aria-label="Vista de la cámara" />

        {status === 'scanning' && (
          <div className="pointer-events-none absolute inset-x-[12%] inset-y-[22%] animate-fade-in" aria-hidden>
            {['top-0 left-0 border-t-2 border-l-2', 'top-0 right-0 border-t-2 border-r-2', 'bottom-0 left-0 border-b-2 border-l-2', 'bottom-0 right-0 border-b-2 border-r-2'].map((c) => (
              <span key={c} className={`absolute size-6 rounded-[3px] border-primary ${c}`} />
            ))}
            <span className="absolute inset-x-2 h-0.5 animate-scan rounded-full bg-primary shadow-[0_0_12px_var(--primary)]" />
          </div>
        )}

        {status === 'starting' && (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-2 text-sm text-fg">
            <LoaderCircle className="size-6 animate-spin text-primary" aria-hidden />
            Iniciando cámara…
          </div>
        )}

        {status === 'error' && (
          <div className="absolute inset-0 flex animate-fade-in flex-col items-center justify-center gap-2 p-6 text-center text-sm text-fg" role="alert">
            <CameraOff className="size-7 text-danger" aria-hidden />
            {error}
          </div>
        )}
      </div>

      <p className="mt-2 text-center text-xs text-muted">Apunta al código de barras del envase. Se detecta solo.</p>

      <form onSubmit={submitManual} className="mt-3 flex items-center gap-2 border-t border-border pt-3">
        <input
          className={`field min-w-0 flex-1 tabular-nums ${manualError ? 'animate-shake border-danger' : ''}`}
          inputMode="numeric"
          autoComplete="off"
          placeholder="o escribe el código (8 a 14 dígitos)"
          value={manual}
          onChange={(e) => {
            setManual(e.target.value)
            setManualError(false)
          }}
          aria-label="Código de barras"
          aria-invalid={manualError}
        />
        <IconButton type="submit" icon={Check} label="Usar este código" variant="primary" size="md" disabled={!manual.trim()} />
      </form>
      {manualError && <p className="mt-1 text-xs text-danger">Código inválido: revisa los dígitos.</p>}
    </Modal>
  )
}
