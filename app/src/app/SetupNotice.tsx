import { Logo } from '../ui/Logo'

/** Se muestra cuando faltan las variables de entorno de Firebase. */
export function SetupNotice() {
  return (
    <div className="flex min-h-dvh items-center justify-center p-4">
      <div className="card flex w-full max-w-md flex-col gap-3 p-6 text-sm">
        <div className="flex items-center gap-2">
          <Logo className="size-8" />
          <h1 className="font-semibold text-fg-strong">Falta configurar Firebase</h1>
        </div>
        <p className="text-muted">Elige una de estas opciones y vuelve a iniciar el servidor de desarrollo:</p>
        <ol className="flex list-decimal flex-col gap-2 pl-5 text-fg">
          <li>
            Copia <code className="text-primary">.env.example</code> como <code className="text-primary">.env.local</code> y completa la configuración web de tu proyecto de Firebase.
          </li>
          <li>
            O usa el emulador local: <code className="text-primary">npm run emulators</code> y en otra terminal <code className="text-primary">npm run dev:emu</code>.
          </li>
        </ol>
      </div>
    </div>
  )
}
