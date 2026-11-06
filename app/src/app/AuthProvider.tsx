import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { watchAuth, type User } from '../services/auth'

interface AuthState {
  user: User | null
  loading: boolean
}

const AuthContext = createContext<AuthState>({ user: null, loading: true })

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({ user: null, loading: true })
  useEffect(() => watchAuth((user) => setState({ user, loading: false })), [])
  return <AuthContext.Provider value={state}>{children}</AuthContext.Provider>
}

export function useAuth() {
  return useContext(AuthContext)
}

/** Usuario autenticado; solo usar dentro de rutas protegidas. */
export function useUser(): User {
  const { user } = useAuth()
  if (!user) throw new Error('useUser requiere una sesión activa')
  return user
}
