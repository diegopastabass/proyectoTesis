import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/nutrition/models.dart';
import '../data/repositories.dart';
import '../features/activity/activity_page.dart';
import '../features/auth/login_page.dart';
import '../features/cardio/activity_detail_page.dart';
import '../features/cardio/cardio_history_page.dart';
import '../features/cardio/cardio_home_page.dart';
import '../features/cardio/export_page.dart';
import '../features/cardio/recording_page.dart';
import '../features/cardio/save_activity_page.dart';
import '../features/nutrition/diary_page.dart';
import '../features/nutrition/foods_page.dart';
import '../features/nutrition/goals_page.dart';
import '../features/nutrition/log_page.dart';
import '../features/nutrition/progress_page.dart';
import '../features/nutrition/recipe_editor_page.dart';
import '../features/nutrition/recipes_page.dart';
import '../features/settings/body_profile_page.dart';
import '../features/settings/notifications_page.dart';
import '../features/settings/settings_page.dart';
import '../features/strength/exercise_detail_page.dart';
import '../features/strength/exercises_page.dart';
import '../features/strength/history_page.dart';
import '../features/strength/programs_page.dart';
import '../features/strength/routine_editor_page.dart';
import '../features/strength/strength_home_page.dart';
import '../features/strength/strength_progress_page.dart';
import '../features/strength/workout_detail_page.dart';
import '../features/strength/workout_page.dart';
import 'providers.dart';
import 'shell.dart';
import 'theme.dart';

/// Secciones de un módulo: como las pestañas de iOS, sin deslizamiento; un fundido
/// breve suaviza el cambio.
Page<void> _section(Widget child) => CustomTransitionPage(
      child: child,
      transitionDuration: Motion.fast,
      reverseTransitionDuration: Motion.fast,
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
    );

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AsyncValue<AppUser?>>(ref.read(authStateProvider));
  ref.listen(authStateProvider, (_, next) => auth.value = next);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final session = auth.value;
      if (!session.hasValue) return null; // aún se lee la sesión guardada
      final signedIn = session.value != null;
      final atLogin = state.matchedLocation == '/login';
      if (!signedIn) return atLogin ? null : '/login';
      return atLogin ? '/' : null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/ajustes', builder: (_, _) => const SettingsPage()),
      GoRoute(path: '/actividad', builder: (_, _) => const ActivityPage()),
      GoRoute(path: '/perfil', builder: (_, _) => const BodyProfilePage()),
      GoRoute(path: '/notificaciones', builder: (_, _) => const NotificationsPage()),
      // Grabar y guardar ocupan toda la pantalla (sin barras), para no tocar nada por error.
      GoRoute(path: '/cardio/grabar', builder: (_, _) => const RecordingPage()),
      GoRoute(path: '/cardio/guardar', builder: (_, _) => const SaveActivityPage()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          // Nutrición
          GoRoute(path: '/', pageBuilder: (_, s) => _section(DiaryPage(initialDate: s.uri.queryParameters['d']))),
          GoRoute(
            path: '/registrar',
            pageBuilder: (_, s) => _section(LogPage(
              // La clave fuerza a releer fecha y comida al llegar desde un aviso.
              key: ValueKey(s.uri.query),
              initialDate: s.uri.queryParameters['d'],
              initialMeal: MealSlot.values.where((m) => m.name == s.uri.queryParameters['m']).firstOrNull,
            )),
          ),
          GoRoute(path: '/alimentos', pageBuilder: (_, _) => _section(const FoodsPage())),
          GoRoute(
            path: '/recetas',
            pageBuilder: (_, _) => _section(const RecipesPage()),
            routes: [GoRoute(path: ':id', builder: (_, s) => RecipeEditorPage(id: s.pathParameters['id']!))],
          ),
          GoRoute(path: '/progreso', pageBuilder: (_, _) => _section(const ProgressPage())),
          GoRoute(path: '/objetivos', pageBuilder: (_, _) => _section(const GoalsPage())),
          // Fuerza: cada sección es una ruta de primer nivel (no se apilan entre sí);
          // los detalles cuelgan de su sección y se abren encima con "volver".
          GoRoute(
            path: '/fuerza',
            pageBuilder: (_, _) => _section(const StrengthHomePage()),
            routes: [
              GoRoute(path: 'entrenar', builder: (_, _) => const WorkoutPage()),
              GoRoute(path: 'programas', builder: (_, _) => const ProgramsPage()),
              GoRoute(path: 'rutinas/:id', builder: (_, s) => RoutineEditorPage(id: s.pathParameters['id']!)),
            ],
          ),
          GoRoute(
            path: '/fuerza/historial',
            pageBuilder: (_, _) => _section(const HistoryPage()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) => WorkoutDetailPage(id: s.pathParameters['id']!, isNew: s.uri.queryParameters['nuevo'] == '1'),
              ),
            ],
          ),
          GoRoute(path: '/fuerza/progreso', pageBuilder: (_, _) => _section(const StrengthProgressPage())),
          GoRoute(
            path: '/fuerza/ejercicios',
            pageBuilder: (_, _) => _section(const ExercisesPage()),
            routes: [GoRoute(path: ':id', builder: (_, s) => ExerciseDetailPage(id: s.pathParameters['id']!))],
          ),
          // Cardio
          GoRoute(path: '/cardio', pageBuilder: (_, _) => _section(const CardioHomePage())),
          GoRoute(
            path: '/cardio/historial',
            pageBuilder: (_, _) => _section(const CardioHistoryPage()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) => ActivityDetailPage(id: s.pathParameters['id']!),
                routes: [GoRoute(path: 'exportar', builder: (_, s) => ExportPage(id: s.pathParameters['id']!))],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    auth.dispose();
  });
  return router;
});
