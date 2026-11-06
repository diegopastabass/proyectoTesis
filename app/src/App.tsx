import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { AuthProvider, useAuth } from './app/AuthProvider'
import { DataProvider } from './app/DataProvider'
import { Layout } from './app/Layout'
import { LoginPage } from './app/LoginPage'
import { SetupNotice } from './app/SetupNotice'
import { ToastProvider } from './app/ToastProvider'
import { ComingSoonPage } from './features/coming-soon/ComingSoonPage'
import { TodayPage } from './features/diary/TodayPage'
import { FoodsPage } from './features/foods/FoodsPage'
import { GoalsPage } from './features/goals/GoalsPage'
import { LogPage } from './features/log/LogPage'
import { ProgressPage } from './features/progress/ProgressPage'
import { ExerciseDetailPage } from './features/strength/ExerciseDetailPage'
import { ExercisesPage } from './features/strength/ExercisesPage'
import { HistoryPage } from './features/strength/HistoryPage'
import { RoutineEditorPage as StrengthRoutineEditorPage } from './features/strength/RoutineEditorPage'
import { StrengthHome } from './features/strength/StrengthHome'
import { StrengthLayout } from './features/strength/StrengthLayout'
import { StrengthProgressPage } from './features/strength/StrengthProgressPage'
import { WorkoutDetailPage } from './features/strength/WorkoutDetailPage'
import { WorkoutPage } from './features/strength/WorkoutPage'
import { RecipeEditorPage } from './features/recipes/RecipeEditorPage'
import { RecipesPage } from './features/recipes/RecipesPage'
import { isConfigured } from './services/firebase'

function Session() {
  const { user, loading } = useAuth()
  if (loading) return <div className="flex min-h-dvh items-center justify-center text-xs text-muted">Cargando…</div>
  if (!user) return <LoginPage />
  return (
    <DataProvider key={user.uid}>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<TodayPage />} />
          <Route path="registrar" element={<LogPage />} />
          <Route path="alimentos" element={<FoodsPage />} />
          <Route path="recetas" element={<RecipesPage />} />
          <Route path="recetas/:id" element={<RecipeEditorPage />} />
          <Route path="progreso" element={<ProgressPage />} />
          <Route path="objetivos" element={<GoalsPage />} />
          <Route path="fuerza" element={<StrengthLayout />}>
            <Route index element={<StrengthHome />} />
            <Route path="entrenar" element={<WorkoutPage />} />
            <Route path="rutinas/:id" element={<StrengthRoutineEditorPage />} />
            <Route path="historial" element={<HistoryPage />} />
            <Route path="historial/:id" element={<WorkoutDetailPage />} />
            <Route path="progreso" element={<StrengthProgressPage />} />
            <Route path="ejercicios" element={<ExercisesPage />} />
            <Route path="ejercicios/:id" element={<ExerciseDetailPage />} />
            <Route path="*" element={<Navigate to="/fuerza" replace />} />
          </Route>
          <Route path="cardio/*" element={<ComingSoonPage module="cardio" />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </DataProvider>
  )
}

export default function App() {
  if (!isConfigured) return <SetupNotice />
  return (
    <BrowserRouter>
      <ToastProvider>
        <AuthProvider>
          <Session />
        </AuthProvider>
      </ToastProvider>
    </BrowserRouter>
  )
}
