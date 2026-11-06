import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/nutrition/models.dart';
import '../data/repositories.dart';
import '../features/account/account_pages.dart';
import '../features/account/onboarding_pages.dart';
import '../features/activity/activity_page.dart';
import '../features/ai/ai_pages.dart';
import '../features/auth/login_page.dart';
import '../features/cardio/activity_detail_page.dart';
import '../features/cardio/cardio_history_page.dart';
import '../features/cardio/cardio_sources_pages.dart';
import '../features/cardio/cardio_home_page.dart';
import '../features/cardio/export_page.dart';
import '../features/cardio/recording_page.dart';
import '../features/cardio/save_activity_page.dart';
import '../features/community/compose_page.dart';
import '../features/community/post_pages.dart';
import '../features/community/wall_page.dart';
import '../features/load/load_pages.dart';
import '../features/nutrition/barcode_scanner_page.dart';
import '../features/nutrition/day_targets_page.dart';
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
import 'sim_providers.dart';
import 'theme.dart';

/// Secciones de un módulo: como las pestañas de iOS, sin deslizamiento; un fundido
/// breve suaviza el cambio.
Page<void> _section(Widget child) => CustomTransitionPage(
      child: child,
      transitionDuration: Motion.fast,
      reverseTransitionDuration: Motion.fast,
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
    );

/// Rutas de las pantallas de diseño con datos simulados (solo en modo demostración).
const _previewPaths = ['/escaner', '/comunidad', '/ia/', '/carga', '/metas', '/premium', '/bienvenida', '/ajustes/datos', '/cardio/manual', '/cardio/reloj', '/cardio/archivo', '/diario/comida'];

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
      if (atLogin) return '/';
      // Las pantallas de diseño no tienen backend: con Firebase real se vuelve al inicio.
      final preview = ref.read(previewEnabledProvider);
      return !preview && _previewPaths.any(state.matchedLocation.startsWith) ? '/' : null;
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
      // Pantallas de diseño con datos simulados (solo en modo demostración, ver _previewPaths).
      GoRoute(path: '/escaner', builder: (_, _) => const BarcodeScannerPage(simulated: true)),
      GoRoute(path: '/ia/fuerza', builder: (_, s) => AiStrengthPage(estado: s.uri.queryParameters['estado'])),
      GoRoute(path: '/ia/comida', builder: (_, s) => AiMealTextPage(estado: s.uri.queryParameters['estado'])),
      GoRoute(path: '/ia/foto', builder: (_, s) => AiPhotoPage(estado: s.uri.queryParameters['estado'])),
      GoRoute(path: '/carga', builder: (_, s) => TrainingLoadPage(showShortHistory: s.uri.queryParameters['estado'] == 'faltan')),
      GoRoute(path: '/carga/alerta', builder: (_, _) => const FatigueAlertPage()),
      GoRoute(path: '/metas', builder: (_, s) => DayTargetsPage(rest: s.uri.queryParameters['dia'] == 'descanso')),
      GoRoute(
        path: '/diario/comida/:slot',
        builder: (_, s) => MealDetailPage(
          slot: MealSlot.values.where((m) => m.name == s.pathParameters['slot']).firstOrNull ?? MealSlot.almuerzo,
          date: s.uri.queryParameters['d'],
          example: s.uri.queryParameters['ejemplo'] == '1',
        ),
      ),
      GoRoute(path: '/cardio/manual', builder: (_, s) => ManualCardioPage(example: s.uri.queryParameters['ejemplo'] == '1')),
      GoRoute(path: '/cardio/reloj', builder: (_, s) => WatchImportPage(connected: s.uri.queryParameters['estado'] == 'conectado')),
      GoRoute(path: '/cardio/archivo', builder: (_, s) => FitUploadPage(estado: s.uri.queryParameters['estado'])),
      GoRoute(
        path: '/bienvenida/terminos',
        builder: (_, s) => TermsPage(
          updated: s.uri.queryParameters['estado'] == 'cambios',
          refused: s.uri.queryParameters['estado'] == 'rechazo',
          accepted: s.uri.queryParameters['estado'] == 'listo',
        ),
      ),
      GoRoute(
        path: '/bienvenida/cuestionario',
        builder: (_, s) => OnboardingPage(
          step: int.tryParse(s.uri.queryParameters['paso'] ?? '') ?? 0,
          example: s.uri.queryParameters['ejemplo'] == '1',
          missing: s.uri.queryParameters['estado'] == 'falta',
        ),
      ),
      GoRoute(path: '/bienvenida/plan', builder: (_, s) => WeeklyPlanPage(accepted: s.uri.queryParameters['estado'] == 'listo')),
      GoRoute(path: '/ajustes/datos', builder: (_, _) => const PrivacyPage()),
      GoRoute(path: '/ajustes/datos/eliminar', builder: (_, s) => DeleteAccountPage(example: s.uri.queryParameters['ejemplo'] == '1')),
      GoRoute(path: '/premium', builder: (_, s) => PremiumPage(estado: s.uri.queryParameters['estado'])),
      GoRoute(path: '/premium/suscripcion', builder: (_, s) => SubscriptionPage(canceled: s.uri.queryParameters['estado'] == 'cancelada')),
      GoRoute(path: '/comunidad/publicar', builder: (_, s) => ComposePostPage(initialKind: s.uri.queryParameters['tipo'], example: s.uri.queryParameters['ejemplo'] == '1')),
      GoRoute(path: '/comunidad/usuario/:id', builder: (_, s) => UserProfilePage(id: s.pathParameters['id']!)),
      GoRoute(path: '/comunidad/post/:id', builder: (_, s) => PostDetailPage(id: s.pathParameters['id']!)),
      GoRoute(
        path: '/comunidad/post/:id/agregar',
        builder: (_, s) => AddPostPage(id: s.pathParameters['id']!, done: s.uri.queryParameters['estado'] == 'listo', repeated: s.uri.queryParameters['estado'] == 'repetido'),
      ),
      GoRoute(
        path: '/comunidad/post/:id/receta',
        builder: (_, s) => AddRecipePage(id: s.pathParameters['id']!, done: s.uri.queryParameters['estado'] == 'listo', goalsMet: s.uri.queryParameters['estado'] == 'metas'),
      ),
      GoRoute(
        path: '/comunidad/post/:id/reportar',
        builder: (_, s) => ReportPostPage(id: s.pathParameters['id']!, done: s.uri.queryParameters['estado'] == 'listo', selected: int.tryParse(s.uri.queryParameters['motivo'] ?? '')),
      ),
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
              demo: s.uri.queryParameters['ejemplo'],
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
                builder: (_, s) => WorkoutDetailPage(id: s.pathParameters['id']!, isNew: s.uri.queryParameters['nuevo'] == '1', exampleNote: s.uri.queryParameters['nota']),
              ),
            ],
          ),
          GoRoute(path: '/fuerza/progreso', pageBuilder: (_, _) => _section(const StrengthProgressPage())),
          GoRoute(
            path: '/fuerza/ejercicios',
            pageBuilder: (_, _) => _section(const ExercisesPage()),
            routes: [GoRoute(path: ':id', builder: (_, s) => ExerciseDetailPage(id: s.pathParameters['id']!))],
          ),
          // Comunidad
          GoRoute(path: '/comunidad', pageBuilder: (_, _) => _section(const WallPage())),
          GoRoute(path: '/comunidad/buscar', pageBuilder: (_, s) => _section(SearchPeoplePage(initialQuery: s.uri.queryParameters['q']))),
          GoRoute(path: '/comunidad/perfil', pageBuilder: (_, _) => _section(const MyCommunityProfilePage())),
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
  // Modo de capturas: abre la pantalla pedida cuando ya se leyó la sesión.
  final capture = ref.read(captureProvider);
  if (capture != null) {
    Timer(const Duration(milliseconds: 500), () {
      capture.replace ? router.go(capture.route) : router.push(capture.route);
      // Tiempo para la transición y la entrada escalonada de los bloques.
      Timer(const Duration(milliseconds: 1800), () => capture.onReady?.call());
    });
  }
  ref.onDispose(() {
    router.dispose();
    auth.dispose();
  });
  return router;
});
