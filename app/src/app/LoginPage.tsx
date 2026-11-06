import { LogIn } from 'lucide-react'
import { useState } from 'react'
import { signInWithGoogle } from '../services/auth'
import { usingEmulators } from '../services/firebase'
import { IconButton } from '../ui/IconButton'
import { Logo } from '../ui/Logo'

export function LoginPage() {
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function login() {
    setError(null)
    setBusy(true)
    try {
      await signInWithGoogle()
    } catch (err) {
      const code = (err as { code?: string }).code
      if (code !== 'auth/popup-closed-by-user' && code !== 'auth/cancelled-popup-request') setError((err as Error).message)
      setBusy(false)
    }
  }

  return (
    <div className="flex min-h-dvh items-center justify-center p-4">
      <div className="card flex w-full max-w-xs animate-scale-in flex-col items-center gap-4 p-6 text-center">
        <Logo className="size-12 animate-float" />
        <div>
          <h1 className="text-lg font-semibold text-fg-strong">Nutri</h1>
          <p className="text-xs text-muted">Prototipo del módulo de nutrición</p>
        </div>
        <IconButton icon={LogIn} label="Ingresar con Google" text="Ingresar con Google" variant="primary" size="md" onClick={login} disabled={busy} className="w-full" />
        {usingEmulators && <p className="text-[11px] text-warning">Modo emulador: la cuenta de Google es simulada.</p>}
        {error && (
          <p className="text-xs text-danger" role="alert">
            {error}
          </p>
        )}
      </div>
    </div>
  )
}
