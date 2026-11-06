import { useEffect, useState, type ReactNode } from 'react'
import { AlertTriangle, ArrowLeft, Check, ClipboardList, Dumbbell, EyeOff, Flag, Image, LogOut, Plus, Search, ShieldCheck, Users } from 'lucide-react'
import { EQUIPMENT, MUSCLES, initialExercises, initialLog, initialReports, type Exercise, type LogEntry, type Report } from './data'

/** Navegación por hash: cada pantalla y estado tiene su propia dirección. */
function useHash(): string {
  const [hash, setHash] = useState(() => window.location.hash.slice(1) || '/reportes')
  useEffect(() => {
    const on = () => setHash(window.location.hash.slice(1) || '/reportes')
    window.addEventListener('hashchange', on)
    return () => window.removeEventListener('hashchange', on)
  }, [])
  return hash
}

const go = (path: string) => {
  window.location.hash = path
}

function Pill({ tone, children }: { tone: 'ok' | 'warn' | 'bad' | 'muted'; children: ReactNode }) {
  const color = { ok: 'var(--success)', warn: 'var(--warning)', bad: 'var(--danger)', muted: 'var(--muted)' }[tone]
  return (
    <span className="inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-semibold" style={{ color, background: `color-mix(in srgb, ${color} 15%, transparent)` }}>
      {children}
    </span>
  )
}

function Card({ children, className = '' }: { children: ReactNode; className?: string }) {
  return <div className={`rounded-2xl bg-bg-hard ${className}`}>{children}</div>
}

function Button({ children, onClick, disabled, kind = 'primary', type = 'button' }: { children: ReactNode; onClick?: () => void; disabled?: boolean; kind?: 'primary' | 'secondary' | 'danger'; type?: 'button' | 'submit' }) {
  const style = {
    primary: 'bg-primary text-on-primary',
    secondary: 'bg-surface-2 text-fg-strong',
    danger: 'text-white',
  }[kind]
  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      className={`inline-flex items-center justify-center gap-2 rounded-xl px-4 py-2.5 text-sm font-semibold transition enabled:cursor-pointer enabled:hover:opacity-90 disabled:opacity-40 ${style}`}
      style={kind === 'danger' ? { background: 'var(--danger)' } : undefined}
    >
      {children}
    </button>
  )
}

function Header({ title, subtitle, back, action }: { title: string; subtitle?: string; back?: string; action?: ReactNode }) {
  return (
    <div className="mb-6 flex items-end gap-4">
      <div className="flex-1">
        {back && (
          <button onClick={() => go(back)} className="mb-2 inline-flex cursor-pointer items-center gap-1 text-sm font-semibold text-primary">
            <ArrowLeft size={16} /> Volver
          </button>
        )}
        <h1 className="text-[26px] font-bold tracking-tight text-fg-strong">{title}</h1>
        {subtitle && <p className="mt-0.5 text-sm text-muted">{subtitle}</p>}
      </div>
      {action}
    </div>
  )
}

const inputClass = 'w-full rounded-xl border border-transparent bg-surface-2 px-3.5 py-2.5 text-sm text-fg-strong outline-none placeholder:text-faint focus:border-primary'

/** CU-10: lista de ejercicios. */
function ExercisesView({ exercises, onToggle, notice }: { exercises: Exercise[]; onToggle: (id: string) => void; notice?: string }) {
  const [q, setQ] = useState('')
  const [onlyActive, setOnlyActive] = useState(false)
  const shown = exercises.filter((e) => (!onlyActive || e.active) && e.name.toLowerCase().includes(q.toLowerCase()))
  return (
    <>
      <Header
        title="Catálogo de ejercicios"
        subtitle={`${exercises.length} ejercicios · ${exercises.filter((e) => e.active).length} activos`}
        action={
          <Button onClick={() => go('/ejercicios/nuevo')}>
            <Plus size={18} /> Agregar ejercicio
          </Button>
        }
      />
      {notice && (
        <div className="mb-4 flex items-center gap-2 rounded-xl p-3 text-sm text-fg" style={{ background: 'color-mix(in srgb, var(--success) 14%, transparent)' }}>
          <Check size={18} style={{ color: 'var(--success)' }} /> {notice}
        </div>
      )}
      <div className="mb-4 flex items-center gap-3">
        <div className="relative flex-1">
          <Search size={17} className="absolute top-3 left-3 text-muted" />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Buscar por nombre" className={`${inputClass} pl-10`} />
        </div>
        <label className="flex cursor-pointer items-center gap-2 text-sm text-fg">
          <input type="checkbox" checked={onlyActive} onChange={(e) => setOnlyActive(e.target.checked)} className="size-4 accent-[var(--primary)]" />
          Solo activos
        </label>
      </div>
      <Card className="overflow-hidden">
        <table className="w-full text-left text-sm">
          <thead>
            <tr className="border-b border-border text-xs text-muted">
              <th className="px-5 py-3 font-semibold">Ejercicio</th>
              <th className="px-3 py-3 font-semibold">Músculos</th>
              <th className="px-3 py-3 font-semibold">Equipamiento</th>
              <th className="px-3 py-3 text-right font-semibold">Sesiones</th>
              <th className="px-3 py-3 font-semibold">Estado</th>
              <th className="px-5 py-3" />
            </tr>
          </thead>
          <tbody>
            {shown.map((e) => (
              <tr key={e.id} className="border-b border-border/50 last:border-0">
                <td className={`px-5 py-3 font-medium ${e.active ? 'text-fg-strong' : 'text-muted'}`}>{e.name}</td>
                <td className="px-3 py-3 text-fg">{e.muscles.join(', ')}</td>
                <td className="px-3 py-3 text-fg">{e.equipment}</td>
                <td className="px-3 py-3 text-right text-fg tabular-nums">{e.sessions.toLocaleString('es-CL')}</td>
                <td className="px-3 py-3">{e.active ? <Pill tone="ok">Activo</Pill> : <Pill tone="muted">Desactivado</Pill>}</td>
                <td className="px-5 py-3 text-right whitespace-nowrap">
                  <button onClick={() => go(`/ejercicios/${e.id}`)} className="mr-4 cursor-pointer font-semibold text-primary">
                    Editar
                  </button>
                  <button onClick={() => onToggle(e.id)} className="cursor-pointer font-semibold text-muted">
                    {e.active ? 'Desactivar' : 'Activar'}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
      <p className="mt-3 text-xs text-muted">Un ejercicio desactivado deja de aparecer para nuevas sesiones, pero se mantiene en las ya registradas.</p>
    </>
  )
}

/** CU-10: agregar o cambiar un ejercicio; avisa si ya existe. */
function ExerciseForm({ exercises, editing, initialName, onSave }: { exercises: Exercise[]; editing?: Exercise; initialName?: string; onSave: (e: Exercise) => void }) {
  const [name, setName] = useState(editing?.name ?? initialName ?? '')
  const [muscles, setMuscles] = useState<string[]>(editing?.muscles ?? (initialName ? ['Pecho', 'Tríceps'] : []))
  const [equipment, setEquipment] = useState(editing?.equipment ?? (initialName ? 'Barra' : ''))
  const clean = name.trim().toLowerCase()
  const duplicate = exercises.some((e) => e.id !== editing?.id && e.name.toLowerCase() === clean)
  const valid = clean.length > 0 && muscles.length > 0 && equipment !== '' && !duplicate
  const toggle = (m: string) => setMuscles((list) => (list.includes(m) ? list.filter((x) => x !== m) : [...list, m]))
  return (
    <>
      <Header title={editing ? 'Editar ejercicio' : 'Agregar ejercicio'} subtitle="Los cambios quedan disponibles para todos los atletas." back="/ejercicios" />
      <Card className="max-w-2xl space-y-5 p-6">
        <div>
          <label className="mb-1.5 block text-sm font-semibold text-fg-strong">Nombre</label>
          <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Por ejemplo: Press inclinado con mancuernas" className={inputClass} />
          {duplicate && (
            <p className="mt-2 flex items-center gap-1.5 text-sm" style={{ color: 'var(--danger)' }}>
              <AlertTriangle size={16} /> Este ejercicio ya existe en el catálogo. No se puede guardar repetido.
            </p>
          )}
        </div>
        <div>
          <label className="mb-1.5 block text-sm font-semibold text-fg-strong">Músculos que trabaja</label>
          <div className="flex flex-wrap gap-2">
            {MUSCLES.map((m) => (
              <button key={m} onClick={() => toggle(m)} className={`cursor-pointer rounded-full px-3.5 py-1.5 text-sm font-medium ${muscles.includes(m) ? 'bg-primary text-on-primary' : 'bg-surface-2 text-fg'}`}>
                {m}
              </button>
            ))}
          </div>
        </div>
        <div>
          <label className="mb-1.5 block text-sm font-semibold text-fg-strong">Equipamiento</label>
          <div className="flex flex-wrap gap-2">
            {EQUIPMENT.map((m) => (
              <button key={m} onClick={() => setEquipment(m)} className={`cursor-pointer rounded-full px-3.5 py-1.5 text-sm font-medium ${equipment === m ? 'bg-primary text-on-primary' : 'bg-surface-2 text-fg'}`}>
                {m}
              </button>
            ))}
          </div>
        </div>
        <div className="flex gap-3 pt-1">
          <Button disabled={!valid} onClick={() => onSave({ id: editing?.id ?? `e${Date.now()}`, name: name.trim(), muscles, equipment, active: editing?.active ?? true, sessions: editing?.sessions ?? 0 })}>
            Guardar
          </Button>
          <Button kind="secondary" onClick={() => go('/ejercicios')}>
            Cancelar
          </Button>
        </div>
      </Card>
    </>
  )
}

const statusPill = (r: Report) => (r.status === 'pending' ? <Pill tone="warn">Pendiente</Pill> : r.status === 'hidden' ? <Pill tone="bad">Oculta</Pill> : <Pill tone="ok">Visible</Pill>)

/** CU-11: lista de contenido reportado. */
function ReportsView({ reports, log, empty }: { reports: Report[]; log: LogEntry[]; empty: boolean }) {
  const pending = empty ? [] : reports.filter((r) => r.status === 'pending')
  return (
    <>
      <Header title="Contenido reportado" subtitle={pending.length === 0 ? 'No hay reportes pendientes' : `${pending.length} reportes pendientes de revisión`} />
      {pending.length === 0 ? (
        <Card className="flex flex-col items-center p-12 text-center">
          <div className="mb-3 rounded-2xl bg-primary-soft p-3 text-primary">
            <ShieldCheck size={30} />
          </div>
          <p className="text-lg font-semibold text-fg-strong">Todo al día</p>
          <p className="text-sm text-muted">Cuando alguien reporte una publicación, aparecerá aquí.</p>
        </Card>
      ) : (
        <Card className="overflow-hidden">
          {pending.map((r) => (
            <button key={r.id} onClick={() => go(`/reportes/${r.id}`)} className="flex w-full cursor-pointer items-center gap-4 border-b border-border/50 px-5 py-4 text-left last:border-0 hover:bg-surface">
              <div className="rounded-xl bg-surface-2 p-2.5 text-muted">{r.hasPhoto ? <Image size={20} /> : <ClipboardList size={20} />}</div>
              <div className="min-w-0 flex-1">
                <p className="truncate font-semibold text-fg-strong">{r.title}</p>
                <p className="text-sm text-muted">
                  {r.kind} · {r.author} · {r.when}
                </p>
              </div>
              <Pill tone={r.reason === 'Peligroso para la salud' ? 'bad' : 'warn'}>{r.reason}</Pill>
              <span className="w-28 text-right text-sm text-muted tabular-nums">
                {r.reporters} {r.reporters === 1 ? 'reporte' : 'reportes'}
              </span>
            </button>
          ))}
        </Card>
      )}
      <h2 className="mt-7 mb-3 text-lg font-bold text-fg-strong">Decisiones recientes</h2>
      <Card className="overflow-hidden">
        <table className="w-full text-left text-sm">
          <tbody>
            {log.map((l, i) => (
              <tr key={i} className="border-b border-border/50 last:border-0">
                <td className="px-5 py-3 whitespace-nowrap text-muted">{l.when}</td>
                <td className="px-3 py-3 font-medium whitespace-nowrap text-fg-strong">{l.action}</td>
                <td className="px-3 py-3 text-fg">{l.title}</td>
                <td className="px-3 py-3 text-muted">{l.why}</td>
                <td className="px-5 py-3 whitespace-nowrap text-muted">{l.who}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </>
  )
}

/** CU-11: revisar una publicación y decidir; queda quién tomó la decisión y por qué. */
function ReportDetail({ report, onDecide, example }: { report: Report; onDecide: (hide: boolean, why: string) => void; example: boolean }) {
  const [why, setWhy] = useState(example ? 'Promueve una dieta extrema que puede ser peligrosa para la salud.' : '')
  return (
    <>
      <Header title="Revisar reporte" subtitle={`${report.reporters} ${report.reporters === 1 ? 'persona lo reportó' : 'personas lo reportaron'} · ${report.when}`} back="/reportes" />
      <div className="grid grid-cols-[1.4fr_1fr] gap-5">
        <Card className="p-6">
          <div className="mb-3 flex items-center gap-2">
            <Pill tone="muted">{report.kind}</Pill>
            {statusPill(report)}
          </div>
          <h2 className="text-xl font-bold tracking-tight text-fg-strong">{report.title}</h2>
          <p className="mb-3 text-sm text-muted">Publicado por {report.author}</p>
          <p className="mb-4 leading-relaxed text-fg">{report.excerpt}</p>
          {report.hasPhoto && (
            <div className="flex h-52 items-center justify-center rounded-xl text-white" style={{ background: 'linear-gradient(135deg, color-mix(in srgb, var(--kcal) 75%, transparent), color-mix(in srgb, var(--carbs) 55%, transparent))' }}>
              <Image size={52} />
            </div>
          )}
        </Card>
        <div className="space-y-5">
          <Card className="p-5">
            <p className="mb-2 flex items-center gap-2 text-sm font-semibold text-fg-strong">
              <Flag size={16} className="text-primary" /> Motivo principal
            </p>
            <Pill tone={report.reason === 'Peligroso para la salud' ? 'bad' : 'warn'}>{report.reason}</Pill>
          </Card>
          <Card className="p-5">
            <label className="mb-2 block text-sm font-semibold text-fg-strong">Motivo de tu decisión</label>
            <textarea value={why} onChange={(e) => setWhy(e.target.value)} rows={4} placeholder="Explica por qué ocultas la publicación o descartas el reporte." className={inputClass} />
            <p className="mt-2 mb-4 text-xs text-muted">Queda guardado quién tomó la decisión y por qué.</p>
            <div className="flex flex-col gap-2">
              <Button kind="danger" disabled={why.trim() === ''} onClick={() => onDecide(true, why.trim())}>
                <EyeOff size={17} /> Ocultar publicación
              </Button>
              <Button kind="secondary" disabled={why.trim() === ''} onClick={() => onDecide(false, why.trim())}>
                Descartar reporte
              </Button>
            </div>
          </Card>
        </div>
      </div>
    </>
  )
}

export default function AdminApp() {
  const hash = useHash()
  const [path, query] = hash.split('?')
  const params = new URLSearchParams(query)
  const [exercises, setExercises] = useState(initialExercises)
  const [reports, setReports] = useState(initialReports)
  const [log, setLog] = useState(initialLog)
  const [notice, setNotice] = useState<string>()

  const toggleExercise = (id: string) => setExercises((list) => list.map((e) => (e.id === id ? { ...e, active: !e.active } : e)))
  const saveExercise = (e: Exercise) => {
    setExercises((list) => (list.some((x) => x.id === e.id) ? list.map((x) => (x.id === e.id ? e : x)) : [e, ...list]))
    setNotice(`Se guardó «${e.name}».`)
    go('/ejercicios')
  }
  const decide = (report: Report, hide: boolean, why: string) => {
    setReports((list) => list.map((r) => (r.id === report.id ? { ...r, status: hide ? 'hidden' : 'kept' } : r)))
    setLog((list) => [{ when: 'Ahora', who: 'Administrador de prueba', action: hide ? 'Publicación oculta' : 'Reporte descartado', title: report.title, why }, ...list])
    go('/reportes')
  }

  const reportId = path.match(/^\/reportes\/(.+)$/)?.[1]
  const exerciseId = path.match(/^\/ejercicios\/(.+)$/)?.[1]
  const report = reports.find((r) => r.id === reportId)
  const pendingCount = reports.filter((r) => r.status === 'pending').length

  const nav = [
    { to: '/reportes', label: 'Reportes', icon: Flag, badge: pendingCount },
    { to: '/ejercicios', label: 'Ejercicios', icon: Dumbbell, badge: 0 },
  ]

  return (
    <div className="flex min-h-screen bg-surface text-fg">
      <aside className="flex w-60 shrink-0 flex-col bg-bg-hard p-4">
        <div className="mb-7 flex items-center gap-2.5 px-2 pt-1">
          <div className="rounded-xl bg-primary p-2 text-on-primary">
            <Users size={18} />
          </div>
          <div>
            <p className="leading-tight font-bold text-fg-strong">NutriApp</p>
            <p className="text-xs text-muted">Administración</p>
          </div>
        </div>
        <nav className="flex-1 space-y-1">
          {nav.map(({ to, label, icon: Icon, badge }) => {
            const active = path.startsWith(to)
            return (
              <button key={to} onClick={() => go(to)} className={`flex w-full cursor-pointer items-center gap-2.5 rounded-xl px-3 py-2.5 text-sm font-semibold ${active ? 'bg-primary-soft text-primary' : 'text-fg hover:bg-surface'}`}>
                <Icon size={18} /> <span className="flex-1 text-left">{label}</span>
                {badge > 0 && <span className="rounded-full bg-primary px-2 py-0.5 text-xs text-on-primary">{badge}</span>}
              </button>
            )
          })}
        </nav>
        <div className="flex items-center gap-2.5 border-t border-border px-2 pt-3">
          <div className="flex size-8 items-center justify-center rounded-full bg-primary-soft text-sm font-bold text-primary">A</div>
          <p className="flex-1 truncate text-sm text-fg">Administrador de prueba</p>
          <LogOut size={16} className="text-muted" />
        </div>
      </aside>
      <main className="min-w-0 flex-1 p-8">
        {path === '/ejercicios' && <ExercisesView exercises={exercises} onToggle={toggleExercise} notice={notice} />}
        {path === '/ejercicios/nuevo' && <ExerciseForm key={query} exercises={exercises} initialName={params.get('nombre') ?? undefined} onSave={saveExercise} />}
        {exerciseId && exerciseId !== 'nuevo' && <ExerciseForm key={exerciseId} exercises={exercises} editing={exercises.find((e) => e.id === exerciseId)} onSave={saveExercise} />}
        {path === '/reportes' && <ReportsView reports={reports} log={log} empty={params.get('estado') === 'vacio'} />}
        {report && <ReportDetail key={report.id} report={report} example={params.get('ejemplo') === '1'} onDecide={(hide, why) => decide(report, hide, why)} />}
      </main>
    </div>
  )
}
