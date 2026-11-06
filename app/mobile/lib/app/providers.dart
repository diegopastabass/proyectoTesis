/// Estado de la app (Riverpod). Las pantallas leen estos proveedores y llaman a
/// las "acciones"; ninguna habla directo con Firebase.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/activity/calendar.dart';
import '../core/activity/reminders.dart';
import '../core/activity/streak.dart';
import '../core/body/energy.dart';
import '../core/body/progress.dart';
import '../core/common/date.dart';
import '../core/nutrition/copy.dart';
import '../core/nutrition/matcher.dart';
import '../core/nutrition/models.dart';
import '../core/nutrition/recipe.dart';
import '../core/nutrition/resolve.dart';
import '../core/nutrition/seed.dart';
import '../core/strength/catalog.dart';
import '../core/strength/models.dart';
import '../core/strength/plan.dart';
import '../core/strength/programs.dart';
import '../core/strength/session.dart';
import '../data/assets/catalog_assets.dart';
import '../data/local/local_store.dart';
import '../data/repositories.dart';
import '../platform/platform_providers.dart';
import 'cardio_providers.dart';
import 'config.dart';

// ---------------------------------------------------------------------------
// Infraestructura (se sobrescriben en main.dart y en las pruebas)
// ---------------------------------------------------------------------------

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

/// Pantalla pedida por el modo de capturas (null en el uso normal).
final captureProvider = Provider<CaptureRequest?>((ref) => null);

final backendProvider = Provider<Backend>((ref) => throw UnimplementedError('backendProvider se define en main.dart'));

final localStoreProvider = Provider<LocalStore>((ref) => throw UnimplementedError('localStoreProvider se define en main.dart'));

final catalogAssetsProvider = Provider<CatalogAssets>((ref) => CatalogAssets());

// ---------------------------------------------------------------------------
// Sesión
// ---------------------------------------------------------------------------

final authStateProvider = StreamProvider<AppUser?>((ref) => ref.watch(backendProvider).auth.watchUser());

/// Usuario con sesión, o null mientras carga o tras cerrar sesión.
final sessionUserProvider = Provider<AppUser?>((ref) => ref.watch(authStateProvider).value);

String _requireUid(Ref ref) => ref.read(sessionUserProvider)?.uid ?? (throw StateError('Inicia sesión para continuar.'));

/// Stream que solo se abre con sesión (sin sesión queda cargando).
Stream<T> _forUser<T>(Ref ref, Stream<T> Function(String uid) open) {
  final user = ref.watch(sessionUserProvider);
  return user == null ? const Stream.empty() : open(user.uid);
}

// ---------------------------------------------------------------------------
// Nutrición
// ---------------------------------------------------------------------------

/// Catálogo público; las reglas de Firestore igual exigen sesión para leerlo.
final foodsProvider = StreamProvider<List<Food>>((ref) => _forUser(ref, (_) => ref.watch(backendProvider).foods.watchFoods()));

final recipesProvider = StreamProvider<List<Recipe>>((ref) => _forUser(ref, ref.watch(backendProvider).recipes.watchRecipes));

final goalsProvider = StreamProvider<Goals>((ref) => _forUser(ref, ref.watch(backendProvider).profile.watchGoals));

class NutritionData {
  NutritionData({required this.foods, required this.recipes, required this.goals})
      : ctx = ResolveContext.build(foods, recipes),
        foodMatcher = Matcher(buildCatalog(foods, const []));

  final List<Food> foods;
  final List<Recipe> recipes;
  final Goals goals;

  /// Catálogo completo (alimentos + recetas) para la lista en lenguaje natural.
  final ResolveContext ctx;

  /// Solo alimentos, para buscadores donde no corresponde elegir recetas.
  final Matcher foodMatcher;
}

/// Combina varios AsyncValue: error si alguno falla, cargando si falta alguno.
AsyncValue<T> combineAsync<T>(List<AsyncValue<Object?>> parts, T Function() build) {
  for (final p in parts) {
    if (p case AsyncError(:final error, :final stackTrace)) return AsyncError(error, stackTrace);
  }
  if (parts.any((p) => !p.hasValue)) return const AsyncLoading();
  return AsyncData(build());
}

final nutritionDataProvider = Provider<AsyncValue<NutritionData>>((ref) {
  final foods = ref.watch(foodsProvider);
  final recipes = ref.watch(recipesProvider);
  final goals = ref.watch(goalsProvider);
  return combineAsync([foods, recipes, goals], () {
    final f = foods.requireValue;
    final byId = {for (final x in f) x.id: x};
    // Con el catálogo cargado, los macros de las recetas se recalculan desde sus ingredientes.
    final r = [for (final rec in recipes.requireValue) refreshRecipe(rec, byId)];
    return NutritionData(foods: f, recipes: r, goals: goals.requireValue);
  });
});

final dayEntriesProvider = StreamProvider.autoDispose.family<List<DiaryEntry>, String>(
  (ref, date) => _forUser(ref, (uid) => ref.watch(backendProvider).diary.watchDay(uid, date)),
);

final seedFoodsProvider = FutureProvider<List<Food>>((ref) {
  final uid = ref.watch(sessionUserProvider)?.uid ?? '';
  return ref.watch(catalogAssetsProvider).seedFoods(uid);
});

/// Qué falta importar del catálogo base.
final seedPlanProvider = Provider<SeedPlan?>((ref) {
  final foods = ref.watch(foodsProvider).value;
  final seed = ref.watch(seedFoodsProvider).value;
  final uid = ref.watch(sessionUserProvider)?.uid;
  if (foods == null || seed == null || uid == null) return null;
  return seedPlan(foods, seed, uid);
});

// ---------------------------------------------------------------------------
// Progreso corporal
// ---------------------------------------------------------------------------

final weightsProvider = StreamProvider<List<WeightEntry>>((ref) => _forUser(ref, ref.watch(backendProvider).profile.watchWeights));

final bodyGoalProvider = StreamProvider<BodyGoal?>((ref) => _forUser(ref, ref.watch(backendProvider).profile.watchBodyGoal));

final bodyProfileProvider = StreamProvider<BodyProfile>((ref) => _forUser(ref, ref.watch(backendProvider).profile.watchBodyProfile));

// ---------------------------------------------------------------------------
// Fuerza
// ---------------------------------------------------------------------------

/// El catálogo pesa ~165 KB: se carga la primera vez que se entra al módulo.
final exerciseCatalogProvider = FutureProvider<List<Exercise>>((ref) => ref.watch(catalogAssetsProvider).exercises());

final customExercisesProvider =
    StreamProvider<List<Exercise>>((ref) => _forUser(ref, ref.watch(backendProvider).strength.watchCustomExercises));

final routinesProvider = StreamProvider<List<Routine>>((ref) => _forUser(ref, ref.watch(backendProvider).strength.watchRoutines));

final workoutsProvider = StreamProvider<List<Workout>>((ref) => _forUser(ref, ref.watch(backendProvider).strength.watchWorkouts));

class ExerciseCatalog {
  ExerciseCatalog(this.exercises)
      : byId = {for (final e in exercises) e.id: e},
        index = ExerciseIndex(exercises);

  final List<Exercise> exercises;
  final Map<String, Exercise> byId;
  final ExerciseIndex index;
}

final exercisesProvider = Provider<AsyncValue<ExerciseCatalog>>((ref) {
  final catalog = ref.watch(exerciseCatalogProvider);
  final custom = ref.watch(customExercisesProvider);
  return combineAsync([catalog, custom], () => ExerciseCatalog([...custom.requireValue, ...catalog.requireValue]));
});

class StrengthData {
  const StrengthData({required this.routines, required this.workouts, required this.catalog});

  final List<Routine> routines;

  /// De la más reciente a la más antigua.
  final List<Workout> workouts;
  final ExerciseCatalog catalog;

  Exercise? exercise(String id) => catalog.byId[id];

  /// Nombre del ejercicio; si se borró, el guardado en la sesión.
  String nameOf(String id, [String? fallback]) => catalog.byId[id]?.name ?? fallback ?? 'Ejercicio eliminado';
}

final strengthDataProvider = Provider<AsyncValue<StrengthData>>((ref) {
  final routines = ref.watch(routinesProvider);
  final workouts = ref.watch(workoutsProvider);
  final catalog = ref.watch(exercisesProvider);
  return combineAsync(
    [routines, workouts, catalog],
    () => StrengthData(routines: routines.requireValue, workouts: workouts.requireValue, catalog: catalog.requireValue),
  );
});

/// Sesión en curso: vive en el dispositivo y sobrevive a cerrar la app.
class ActiveWorkoutController extends Notifier<ActiveWorkout?> {
  @override
  ActiveWorkout? build() {
    final user = ref.watch(sessionUserProvider);
    return user == null ? null : ref.read(localStoreProvider).readActiveWorkout(user.uid);
  }

  void set(ActiveWorkout? w) {
    final restBefore = state?.rest?.endsAt;
    state = w;
    final uid = ref.read(sessionUserProvider)?.uid;
    if (uid != null) ref.read(localStoreProvider).writeActiveWorkout(uid, w);
    // El aviso del fin del descanso sigue al temporizador (también al descartar o terminar).
    final restAfter = w?.rest?.endsAt;
    if (restAfter != restBefore) {
      unawaited(ref.read(notificationServiceProvider).scheduleRestEnd(restAfter == null ? null : DateTime.fromMillisecondsSinceEpoch(restAfter)));
    }
  }

  void update(ActiveWorkout Function(ActiveWorkout w) fn) {
    final current = state;
    if (current != null) set(fn(current));
  }
}

final activeWorkoutProvider = NotifierProvider<ActiveWorkoutController, ActiveWorkout?>(ActiveWorkoutController.new);

// ---------------------------------------------------------------------------
// Actividad: calendario y racha
// ---------------------------------------------------------------------------

/// Días con registros en el diario. La primera vez crea el resumen de los días
/// registrados antes de que existiera.
final loggedDaysProvider = StreamProvider<List<LoggedDay>>((ref) {
  final diary = ref.watch(backendProvider).diary;
  return _forUser(ref, (uid) async* {
    try {
      await diary.ensureDayIndex(uid);
    } on Object catch (e) {
      // Sin red se reintenta en la próxima apertura; mientras, se ven los días ya resumidos.
      debugPrint('No se pudo crear el resumen de días: $e');
    }
    yield* diary.watchLoggedDays(uid);
  });
});

/// Fecha → actividad de cada módulo (nutrición, fuerza y cardio).
final activityProvider = Provider<AsyncValue<Map<String, DayActivity>>>((ref) {
  final days = ref.watch(loggedDaysProvider);
  final workouts = ref.watch(workoutsProvider);
  final cardio = ref.watch(cardioActivitiesProvider);
  return combineAsync(
    [days, workouts, cardio],
    () => buildActivity(days: days.requireValue, workouts: workouts.requireValue, cardio: cardio.requireValue),
  );
});

/// Días de descanso de la racha (1 = lunes … 7 = domingo), guardados en el perfil.
final streakRestDaysProvider = StreamProvider<Set<int>>((ref) => _forUser(ref, ref.watch(backendProvider).profile.watchStreakRestDays));

final streakProvider = Provider<AsyncValue<StreakInfo>>((ref) {
  final activity = ref.watch(activityProvider);
  final rest = ref.watch(streakRestDaysProvider);
  return combineAsync(
    [activity, rest],
    () => computeStreak([for (final d in activity.requireValue.values) if (d.counts) d.date], todayKey(), restWeekdays: rest.requireValue),
  );
});

final streakCelebrationProvider =
    StreamProvider<StreakCelebration?>((ref) => _forUser(ref, ref.watch(backendProvider).profile.watchStreakCelebration));

/// Hito de racha recién alcanzado que aún no se celebra (null si no hay).
final pendingMilestoneProvider = Provider<int?>((ref) {
  final streak = ref.watch(streakProvider).value;
  final last = ref.watch(streakCelebrationProvider);
  if (streak == null || !last.hasValue) return null;
  return milestoneToCelebrate(streak, last.value, todayKey());
});

// ---------------------------------------------------------------------------
// Plan de entrenamiento y recordatorios
// ---------------------------------------------------------------------------

final trainingPlanProvider = StreamProvider<TrainingPlan>((ref) => _forUser(ref, ref.watch(backendProvider).profile.watchTrainingPlan));

/// Rutina que toca según el programa que se sigue (null sin programa).
final nextRoutineProvider = Provider<Routine?>((ref) {
  final plan = ref.watch(trainingPlanProvider).value;
  final data = ref.watch(strengthDataProvider).value;
  if (plan == null || data == null) return null;
  final id = nextRoutineId(plan, data.workouts);
  return data.routines.where((r) => r.id == id).firstOrNull;
});

class ReminderSettingsController extends Notifier<ReminderSettings> {
  @override
  ReminderSettings build() => ref.read(localStoreProvider).reminders;

  void set(ReminderSettings r) {
    state = r;
    ref.read(localStoreProvider).setReminders(r);
  }
}

final reminderSettingsProvider = NotifierProvider<ReminderSettingsController, ReminderSettings>(ReminderSettingsController.new);

/// Cambia al volver a abrir la app, para recalcular los avisos con la hora actual.
class ReminderClock extends Notifier<int> {
  @override
  int build() => 0;

  void tick() => state++;
}

final reminderClockProvider = NotifierProvider<ReminderClock, int>(ReminderClock.new);

/// Avisos que deberían estar programados ahora; null mientras cargan los datos.
final reminderPlanProvider = Provider<List<PlannedReminder>?>((ref) {
  ref.watch(reminderClockProvider);
  final settings = ref.watch(reminderSettingsProvider);
  if (ref.watch(sessionUserProvider) == null || !settings.any) return const [];
  final now = DateTime.now();
  final today = toDateKey(now);
  final entries = ref.watch(dayEntriesProvider(today));
  final workouts = ref.watch(workoutsProvider);
  final plan = ref.watch(trainingPlanProvider);
  final streak = ref.watch(streakProvider);
  if (!entries.hasValue || !workouts.hasValue || !plan.hasValue || !streak.hasValue) return null;
  return planReminders(
    settings,
    ReminderContext(
      now: now,
      mealsLoggedToday: entries.requireValue.map((e) => e.meal).toSet(),
      trainedToday: workouts.requireValue.any((w) => w.date == today),
      trainingWeekdays: plan.requireValue.weekdays,
      nextRoutine: ref.watch(nextRoutineProvider)?.name,
      streak: streak.requireValue.current,
      activeToday: streak.requireValue.activeToday,
      restWeekdays: ref.watch(streakRestDaysProvider).value ?? const {},
    ),
  );
});

// ---------------------------------------------------------------------------
// Preferencias
// ---------------------------------------------------------------------------

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.values.where((m) => m.name == ref.read(localStoreProvider).themeMode).firstOrNull ?? ThemeMode.system;

  void set(ThemeMode mode) {
    state = mode;
    ref.read(localStoreProvider).setThemeMode(mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

// ---------------------------------------------------------------------------
// Acciones (escrituras). Leen el usuario al momento de llamar.
// ---------------------------------------------------------------------------

class NutritionActions {
  NutritionActions(this._ref);

  final Ref _ref;

  Backend get _b => _ref.read(backendProvider);

  String get uid => _requireUid(_ref);

  Future<Food> createFood(FoodInput input, {FoodSource source = FoodSource.userSource}) async {
    final id = await _b.foods.createFood(input, uid, source);
    return Food(
      id: id,
      name: input.name,
      aliases: input.aliases,
      brand: input.brand,
      barcode: input.barcode,
      per100g: input.per100g,
      portions: input.portions,
      density: input.density,
      source: source,
      createdBy: uid,
    );
  }

  Future<Food> updateFood(Food food, FoodInput input) async {
    await _b.foods.updateFood(food.id, input);
    return food.copyWith(input: input, fiberMissing: false);
  }

  /// Importa la semilla y completa la fibra de los alimentos propios que no la tenían.
  Future<SeedPlan> importSeed() async {
    final plan = _ref.read(seedPlanProvider);
    if (plan == null || plan.pending == 0) return const SeedPlan(missing: [], fiberPatches: []);
    await _b.foods.importSeed(missing: plan.missing, fiberPatches: plan.fiberPatches);
    return plan;
  }

  Future<String> saveRecipe(Recipe recipe, {String? id}) => _b.recipes.saveRecipe(recipe, id: id);

  Future<void> deleteRecipe(String id) => _b.recipes.deleteRecipe(id);

  Future<void> addEntries(String date, List<NewDiaryEntry> entries) => _b.diary.addEntries(uid, date, entries);

  Future<void> deleteEntry(String date, DiaryEntry entry) => _b.diary.deleteEntry(uid, date, entry);

  /// Copia registros de otro día a `date`, con los macros del catálogo actual.
  Future<int> repeatEntries(String date, List<DiaryEntry> source) async {
    final data = _ref.read(nutritionDataProvider).value;
    final copies = copyEntries(source, foods: data?.ctx.foods ?? const {}, recipes: data?.ctx.recipes ?? const {});
    if (copies.isNotEmpty) await addEntries(date, copies);
    return copies.length;
  }

  Future<void> saveGoals(Goals goals) => _b.profile.saveGoals(uid, goals);

  Future<void> saveWeight(WeightEntry entry) => _b.profile.saveWeight(uid, entry);

  Future<void> deleteWeight(String date) => _b.profile.deleteWeight(uid, date);

  Future<void> saveBodyGoal(BodyGoal goal) => _b.profile.saveBodyGoal(uid, goal);

  Future<void> saveBodyProfile(BodyProfile profile) => _b.profile.saveBodyProfile(uid, profile);

  Future<void> saveTrainingPlan(TrainingPlan plan) => _b.profile.saveTrainingPlan(uid, plan);

  Future<void> saveStreakRestDays(Set<int> weekdays) => _b.profile.saveStreakRestDays(uid, weekdays);

  /// Marca el hito como celebrado en esta racha (no se repite en otro dispositivo).
  Future<void> markStreakCelebrated(StreakCelebration c) => _b.profile.saveStreakCelebration(uid, c);
}

final nutritionActionsProvider = Provider<NutritionActions>(NutritionActions.new);

class StrengthActions {
  StrengthActions(this._ref);

  final Ref _ref;

  StrengthRepository get _repo => _ref.read(backendProvider).strength;

  String get _uid => _requireUid(_ref);

  Future<String> saveRoutine({required String name, required List<RoutineExercise> exercises, String? id}) =>
      _repo.saveRoutine(_uid, name: name, exercises: exercises, id: id);

  Future<void> deleteRoutine(String id) => _repo.deleteRoutine(_uid, id);

  Future<String> saveWorkout(NewWorkout w) => _repo.saveWorkout(_uid, w);

  Future<void> deleteWorkout(String id) => _repo.deleteWorkout(_uid, id);

  Future<void> setWorkoutRpe(String id, int rpe) => _repo.setWorkoutRpe(_uid, id, rpe);

  Future<Exercise> createCustomExercise({required String name, String? equipment, required List<String> primary}) =>
      _repo.createCustomExercise(_uid, name: name, equipment: equipment, primary: primary);

  /// Crea las rutinas del programa y lo deja como plan: los recordatorios y la
  /// pantalla de Fuerza sabrán qué rutina toca. Devuelve cuántas rutinas creó.
  Future<int> adoptProgram(Program program, {Set<int>? weekdays}) async {
    final ids = [
      for (final r in routinesFromProgram(program)) await _repo.saveRoutine(_uid, name: r.name, exercises: r.exercises),
    ];
    await _ref.read(backendProvider).profile.saveTrainingPlan(
          _uid,
          TrainingPlan(weekdays: weekdays ?? defaultWeekdays(program.days), programId: program.id, routineIds: ids, startDate: todayKey()),
        );
    return ids.length;
  }

  /// Deja de seguir el programa; las rutinas y los días de entrenamiento se conservan.
  Future<void> leaveProgram() async {
    final plan = _ref.read(trainingPlanProvider).value ?? const TrainingPlan();
    await _ref.read(backendProvider).profile.saveTrainingPlan(_uid, plan.withoutProgram());
  }
}

final strengthActionsProvider = Provider<StrengthActions>(StrengthActions.new);

final lookupProvider = Provider<LookupRepository>((ref) => ref.watch(backendProvider).lookup);
