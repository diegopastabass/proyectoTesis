import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { buildCatalog, Matcher } from '../core/matcher'
import { refreshRecipe } from '../core/recipe'
import type { ResolveContext } from '../core/resolve'
import { DEFAULT_GOALS } from '../core/score'
import type { Food, Goals, Recipe } from '../core/types'
import { watchFoods } from '../services/foods'
import { watchGoals } from '../services/profile'
import { watchRecipes } from '../services/recipes'
import { useUser } from './AuthProvider'

interface DataState {
  foods: Food[]
  recipes: Recipe[]
  goals: Goals
  ready: boolean
  error: string | null
  /** Catálogo completo (alimentos + recetas) para la lista en lenguaje natural. */
  ctx: ResolveContext
  /** Solo alimentos, para buscadores donde no corresponde elegir recetas. */
  foodMatcher: Matcher
}

const DataContext = createContext<DataState | null>(null)

export function DataProvider({ children }: { children: ReactNode }) {
  const user = useUser()
  const [foods, setFoods] = useState<Food[] | null>(null)
  const [recipes, setRecipes] = useState<Recipe[] | null>(null)
  const [goals, setGoals] = useState<Goals | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const onError = (e: Error) => setError(e.message)
    const unsubs = [
      watchFoods(setFoods, onError),
      watchRecipes(user.uid, setRecipes, onError),
      watchGoals(user.uid, setGoals, onError),
    ]
    return () => unsubs.forEach((u) => u())
  }, [user.uid])

  const value = useMemo<DataState>(() => {
    const f = foods ?? []
    const foodMap = new Map(f.map((x) => [x.id, x]))
    // Una vez cargado el catálogo, los macros de las recetas se recalculan desde sus ingredientes.
    const r = (recipes ?? []).map((rec) => (foods ? refreshRecipe(rec, foodMap) : rec))
    return {
      foods: f,
      recipes: r,
      goals: goals ?? DEFAULT_GOALS,
      ready: foods !== null && recipes !== null && goals !== null,
      error,
      ctx: {
        matcher: new Matcher(buildCatalog(f, r)),
        foods: foodMap,
        recipes: new Map(r.map((x) => [x.id, x])),
      },
      foodMatcher: new Matcher(buildCatalog(f, [])),
    }
  }, [foods, recipes, goals, error])

  return <DataContext.Provider value={value}>{children}</DataContext.Provider>
}

export function useData(): DataState {
  const v = useContext(DataContext)
  if (!v) throw new Error('useData requiere DataProvider')
  return v
}
