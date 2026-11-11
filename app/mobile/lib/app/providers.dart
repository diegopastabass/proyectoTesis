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
import '../core/common/units.dart';
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
import '../core/strength/rest_sync.dart';
import '../core/strength/session.dart';
import '../core/suggestions/alerts.dart';
import '../core/suggestions/profile.dart';
import '../core/suggestions/reason.dart';
import '../core/training/load.dart';
import '../core/suggestions/weekly_plan.dart';
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
///
/// El descanso se refleja en el temporizador del sistema (isla dinámica y
/// pantalla bloqueada en iOS 26+): cada cambio en la app se le comunica, y lo que
/// se hace desde la pantalla bloqueada (pausar, seguir, cancelar) vuelve a la app.
class ActiveWorkoutController extends Notifier<ActiveWorkout?> {
  /// Hora del último cambio enviado al sistema: los avisos que llegan justo
  /// después son el eco de ese cambio (por ejemplo, la cuenta vieja que se
  /// reemplaza) y no se aplican.
  int _lastCommand = 0;

  @override
  ActiveWorkout? build() {
    final user = ref.watch(sessionUserProvider);
    final timer = ref.watch(restTimerServiceProvider);
    final sub = timer.changes.listen(_fromSystem);
    final lifecycle = AppLifecycleListener(onResume: () => unawaited(_reconcile()));
    ref.onDispose(() {
      sub.cancel();
      lifecycle.dispose();
    });
    final saved = user == null ? null : ref.read(localStoreProvider).readActiveWorkout(user.uid);
    if (saved?.rest != null) Future.microtask(_reconcile);
    return saved;
  }

  void set(ActiveWorkout? w) {
    final before = state?.rest;
    _store(w);
    final command = restCommand(before, w?.rest, DateTime.now().millisecondsSinceEpoch);
    if (command != null) unawaited(_send(command));
  }

  void _store(ActiveWorkout? w) {
    state = w;
    final uid = ref.read(sessionUserProvider)?.uid;
    if (uid != null) ref.read(localStoreProvider).writeActiveWorkout(uid, w);
  }

  /// Subtítulo del temporizador en la pantalla bloqueada: el nombre del entrenamiento.
  String? get _exercise => state?.name;

  /// Vuelve a enviar el descanso al sistema (por ejemplo, recién dado el permiso).
  Future<void> resyncRest() async {
    final rest = state?.rest;
    if (rest == null) return;
    final seconds = rest.remaining(DateTime.now().millisecondsSinceEpoch);
    if (seconds > 0) await _send(StartRest(seconds, paused: rest.paused));
  }

  Future<void> _send(RestCommand command) async {
    _lastCommand = DateTime.now().millisecondsSinceEpoch;
    final timer = ref.read(restTimerServiceProvider);
    try {
      switch (command) {
        case StartRest(:final seconds, :final paused):
          await timer.start(seconds: seconds, exercise: _exercise);
          if (paused) await timer.pause();
        case PauseRest():
          await timer.pause();
        case ResumeRest(:final seconds):
          await timer.resume(seconds: seconds, exercise: _exercise);
        case CancelRest():
          await timer.cancel();
      }
    } on Object catch (e) {
      // Sin permiso o sin AlarmKit, el descanso sigue en la pantalla del entrenamiento.
      debugPrint('No se pudo actualizar el temporizador del sistema: $e');
    }
    _lastCommand = DateTime.now().millisecondsSinceEpoch;
  }

  /// Lo que pasó en la pantalla bloqueada o en la isla dinámica.
  void _fromSystem(RestAlarmSnapshot? snapshot) {
    final w = state;
    final rest = w?.rest;
    if (w == null || rest == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastCommand < 1500) return;
    final next = applyRestSnapshot(rest, snapshot, now);
    if (!identical(next, rest)) _store(w.withRest(next));
  }

  /// Al volver a la app (o al abrirla), se lee el estado del sistema: pudo
  /// cambiar desde la pantalla bloqueada mientras la app no corría.
  Future<void> _reconcile() async {
    final timer = ref.read(restTimerServiceProvider);
    if (state?.rest == null || !await timer.systemTimer) return;
    _fromSystem(await timer.current());
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

// ---------------------------------------------------------------------------
// Perfil del deportista y plan semanal (motor de sugerencias, fase 1)
// ---------------------------------------------------------------------------

/// Respuestas del cuestionario inicial (null si no lo ha respondido).
final athleteProfileProvider = StreamProvider<AthleteProfile?>((ref) => _forUser(ref, ref.watch(backendProvider).profile.watchAthleteProfile));

/// Plan semanal aceptado (null si no hay).
final weeklyPlanProvider = StreamProvider<WeeklyPlan?>((ref) => _forUser(ref, ref.watch(backendProvider).profile.watchWeeklyPlan));

/// Plan que sugiere el motor para el perfil guardado (null sin cuestionario).
/// Se calcula una vez por perfil: revisa todas las semanas posibles (decenas de ms).
final suggestedPlanProvider = Provider<WeeklyPlan?>((ref) {
  final profile = ref.watch(athleteProfileProvider).value;
  return profile == null ? null : buildWeeklyPlan(profile);
});

// ---------------------------------------------------------------------------
// Alertas de fatiga (motor de sugerencias, fase 2)
// ---------------------------------------------------------------------------

/// Razón ATL/CTL desde la que se avisa (configurable; 1,3 por defecto).
class FatigueThresholdController extends Notifier<double> {
  @override
  double build() => ref.read(localStoreProvider).fatigueThreshold ?? defaultRatioThreshold;

  void set(double value) {
    state = value;
    ref.read(localStoreProvider).setFatigueThreshold(value);
  }
}

final fatigueThresholdProvider = NotifierProvider<FatigueThresholdController, double>(FatigueThresholdController.new);

/// Respuestas a las alertas (las respondidas no vuelven a aparecer).
final suggestionResponsesProvider =
    StreamProvider<Map<String, SuggestionResponse>>((ref) => _forUser(ref, ref.watch(backendProvider).profile.watchSuggestionResponses));

/// Gasto diario estimado: con los registros de comida y peso o, si aún no
/// alcanzan, con la fórmula (null si faltan datos del perfil).
final dailyExpenditureProvider = Provider<int?>((ref) {
  final today = todayKey();
  final days = ref.watch(loggedDaysProvider).value ?? const [];
  final weights = ref.watch(weightsProvider).value ?? const [];
  final observed = observedEnergy(days, weights, today);
  if (observed != null) return observed.tdee;
  final body = ref.watch(bodyProfileProvider).value ?? const BodyProfile();
  return formulaEnergy(body, weights.lastOrNull?.kg, today)?.tdee;
});

/// Alertas vigentes sin responder, de la más importante a la menos. Se recalculan
/// al registrar algo y al volver a abrir la app.
final fatigueAlertsProvider = Provider<AsyncValue<List<FatigueAlert>>>((ref) {
  ref.watch(reminderClockProvider);
  final workouts = ref.watch(workoutsProvider);
  final cardio = ref.watch(cardioActivitiesProvider);
  final responses = ref.watch(suggestionResponsesProvider);
  return combineAsync([workouts, cardio, responses], () {
    final answered = responses.requireValue;
    return [
      for (final a in fatigueAlerts(AlertContext(
        now: DateTime.now(),
        workouts: workouts.requireValue,
        cardio: cardio.requireValue,
        plan: ref.watch(weeklyPlanProvider).value,
        days: ref.watch(loggedDaysProvider).value ?? const [],
        dailyExpenditure: ref.watch(dailyExpenditureProvider),
        ratioThreshold: ref.watch(fatigueThresholdProvider),
      )))
        if (!answered.containsKey(a.id)) a,
    ];
  });
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
  final alerts = settings.fatigue ? ref.watch(fatigueAlertsProvider).value ?? const <FatigueAlert>[] : const <FatigueAlert>[];
  final reminders = planReminders(
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
  return [...reminders, ...fatigueReminders(alerts, now: now, trainingAt: settings.trainingAt)]..sort((a, b) => a.at.compareTo(b.at));
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

/// Unidad de peso preferida: la de los ejercicios que nunca se anotaron y la de los
/// totales (volumen, gráficos). Cada ejercicio recuerda además la suya (una máquina
/// en libras sigue en libras aunque la preferida sea kg).
class WeightUnitController extends Notifier<WeightUnit> {
  @override
  WeightUnit build() => WeightUnit.from(ref.read(localStoreProvider).weightUnit);

  void set(WeightUnit unit) {
    state = unit;
    ref.read(localStoreProvider).setWeightUnit(unit.name);
  }
}

final weightUnitProvider = NotifierProvider<WeightUnitController, WeightUnit>(WeightUnitController.new);

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

  /// Guarda el cuestionario: las respuestas del deportista, sus datos corporales y
  /// su peso de hoy (si cambió), que también usa el gasto calórico.
  Future<void> saveAthleteAnswers(AthleteProfile profile, {BodyProfile? body, double? weightKg}) async {
    await _b.profile.saveAthleteProfile(uid, profile.copyWith(answeredAt: todayKey()));
    if (body != null) await _b.profile.saveBodyProfile(uid, body);
    // Del repositorio y no del proveedor: este puede estar en pausa si ninguna pantalla lo escucha.
    final last = (await _b.profile.watchWeights(uid).first).lastOrNull?.kg;
    if (weightKg != null && weightKg != last) await _b.profile.saveWeight(uid, WeightEntry(date: todayKey(), kg: weightKg));
  }

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
  /// Si ya se sigue ese programa y sus rutinas existen, no las duplica.
  /// `offset`: con qué rutina parte la rotación (la que calza con la semana sugerida).
  Future<int> adoptProgram(Program program, {Set<int>? weekdays, int offset = 0}) async {
    // Del repositorio y no de los proveedores: pueden estar en pausa si ninguna pantalla los escucha.
    final current = await _ref.read(backendProvider).profile.watchTrainingPlan(_uid).first;
    final routines = await _repo.watchRoutines(_uid).first;
    final existing = {for (final r in routines) r.id};
    final reuse = current.programId == program.id && current.routineIds.length == program.routines.length && current.routineIds.every(existing.contains);
    // routineIds del plan guardado pueden venir rotados: se reordenan según el programa.
    final ids = reuse
        ? _programOrder(current, program, routines)
        : [for (final r in routinesFromProgram(program)) await _repo.saveRoutine(_uid, name: r.name, exercises: r.exercises)];
    final n = ids.length;
    final rotated = n == 0 ? ids : [for (var i = 0; i < n; i++) ids[(offset + i) % n]];
    await _ref.read(backendProvider).profile.saveTrainingPlan(
          _uid,
          TrainingPlan(weekdays: weekdays ?? defaultWeekdays(program.days), programId: program.id, routineIds: rotated, startDate: todayKey()),
        );
    return reuse ? 0 : n;
  }

  /// Ids del plan en el orden de las rutinas del programa (por nombre).
  List<String> _programOrder(TrainingPlan plan, Program program, List<Routine> routines) {
    final byName = {for (final r in routines) if (plan.routineIds.contains(r.id)) r.name: r.id};
    final ordered = [for (final day in program.routines) ?byName[day.name]];
    return ordered.length == plan.routineIds.length ? ordered : plan.routineIds;
  }

  /// Acepta el plan semanal: deja su programa de fuerza con los días de fuerza
  /// del plan y lo guarda para los recordatorios y las alertas. Devuelve las rutinas creadas.
  Future<int> acceptWeeklyPlan(WeeklyPlan plan) async {
    final program = programById(plan.programId);
    var created = 0;
    if (program != null) created = await adoptProgram(program, weekdays: plan.strengthWeekdays, offset: plan.routineOffset);
    await _ref.read(backendProvider).profile.saveWeeklyPlan(_uid, plan.accepted(todayKey()));
    return created;
  }

  /// Guarda qué hizo el usuario con una alerta: no vuelve a aparecer y queda registrado.
  Future<void> respondToAlert(FatigueAlert alert, ResponseKind response) => _ref.read(backendProvider).profile.saveSuggestionResponse(
        _uid,
        SuggestionResponse(id: alert.id, kind: alert.kind.name, response: response, date: todayKey(), title: alert.title),
      );

  /// Deja de seguir el programa; las rutinas y los días de entrenamiento se conservan.
  Future<void> leaveProgram() async {
    final plan = _ref.read(trainingPlanProvider).value ?? const TrainingPlan();
    await _ref.read(backendProvider).profile.saveTrainingPlan(_uid, plan.withoutProgram());
  }
}

final strengthActionsProvider = Provider<StrengthActions>(StrengthActions.new);

final lookupProvider = Provider<LookupRepository>((ref) => ref.watch(backendProvider).lookup);
