/// Backend en memoria: modo demostración (sin red ni Firebase) y pruebas.
///
/// Se comporta como Firestore en lo que importa a la app: cada lectura es un
/// stream que emite el valor actual y luego cada cambio.
library;

import 'dart:async';
import 'dart:math' as math;

import '../../core/activity/calendar.dart';
import '../../core/activity/streak.dart';
import '../../core/body/energy.dart';
import '../../core/body/progress.dart';
import '../../core/cardio/activity.dart';
import '../../core/cardio/track.dart';
import '../../core/common/date.dart';
import '../../core/nutrition/macros.dart';
import '../../core/nutrition/models.dart';
import '../../core/nutrition/open_food_facts.dart';
import '../../core/nutrition/recipe.dart';
import '../../core/nutrition/score.dart';
import '../../core/strength/models.dart';
import '../../core/strength/plan.dart';
import '../repositories.dart';

/// Valor observable: emite el valor actual al suscribirse y luego cada cambio.
class _Live<T> {
  _Live(this._value);

  T _value;
  final _changes = StreamController<T>.broadcast();

  T get value => _value;

  set value(T v) {
    _value = v;
    _changes.add(v);
  }

  /// Cada suscriptor tiene su propio buffer: si Riverpod pausa la suscripción
  /// (nadie escucha el proveedor), los cambios llegan al reanudarla.
  Stream<T> get stream => Stream.multi((c) {
        c.add(_value);
        final sub = _changes.stream.listen(c.add);
        c.onCancel = sub.cancel;
      });
}

var _ids = 0;
String _newId(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_ids++}';

const demoUser = AppUser(uid: 'demo', displayName: 'Usuario de prueba', email: 'demo@local');

class MemoryAuthRepository implements AuthRepository {
  MemoryAuthRepository({bool signedIn = false}) : _user = _Live(signedIn ? demoUser : null);

  final _Live<AppUser?> _user;

  @override
  SignInMethod get method => SignInMethod.demo;

  @override
  AppUser? get currentUser => _user.value;

  @override
  Stream<AppUser?> watchUser() => _user.stream;

  @override
  Future<void> signIn() async => _user.value = demoUser;

  @override
  Future<void> signOut() async => _user.value = null;
}

class MemoryFoodRepository implements FoodRepository {
  MemoryFoodRepository([List<Food> initial = const []]) : _foods = _Live(List.of(initial));

  final _Live<List<Food>> _foods;

  @override
  Stream<List<Food>> watchFoods() => _foods.stream;

  @override
  Future<String> createFood(FoodInput input, String uid, FoodSource source) async {
    final id = _newId('food');
    _foods.value = [
      ..._foods.value,
      Food(
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
      ),
    ];
    return id;
  }

  @override
  Future<void> updateFood(String id, FoodInput input) async {
    _foods.value = [for (final f in _foods.value) f.id == id ? f.copyWith(input: input, fiberMissing: false) : f];
  }

  @override
  Future<void> importSeed({required List<Food> missing, required List<Food> fiberPatches}) async {
    final patched = {for (final f in fiberPatches) f.id: f};
    _foods.value = [
      for (final f in _foods.value)
        if (patched[f.id] case final p?)
          f.copyWith(
            input: FoodInput(
              name: f.name,
              aliases: f.aliases,
              brand: f.brand,
              barcode: f.barcode,
              per100g: Macros(kcal: f.per100g.kcal, protein: f.per100g.protein, carbs: f.per100g.carbs, fat: f.per100g.fat, fiber: p.per100g.fiber),
              portions: f.portions,
              density: f.density,
            ),
            fiberMissing: false,
          )
        else
          f,
      ...missing,
    ];
  }
}

class MemoryRecipeRepository implements RecipeRepository {
  MemoryRecipeRepository({List<Recipe> initial = const []}) : _recipes = _Live<List<Recipe>>([...initial]);

  final _Live<List<Recipe>> _recipes;

  @override
  Stream<List<Recipe>> watchRecipes(String uid) =>
      _recipes.stream.map((list) => list.where((r) => r.ownerId == uid).toList()..sort((a, b) => a.name.compareTo(b.name)));

  @override
  Future<String> saveRecipe(Recipe recipe, {String? id}) async {
    final key = id ?? _newId('recipe');
    _recipes.value = [..._recipes.value.where((r) => r.id != key), recipe.copyWith(id: key)];
    return key;
  }

  @override
  Future<void> deleteRecipe(String id) async => _recipes.value = _recipes.value.where((r) => r.id != id).toList();
}

class MemoryDiaryRepository implements DiaryRepository {
  MemoryDiaryRepository({Map<String, List<NewDiaryEntry>> initial = const {}, String uid = 'demo'}) {
    for (final MapEntry(key: date, value: entries) in initial.entries) {
      _store(uid, date, entries, onTime: true);
    }
  }

  final _days = <String, _Live<List<DiaryEntry>>>{};

  /// Resumen por día de cada usuario (como `users/{uid}/days` en Firestore).
  final _index = <String, _Live<Map<String, LoggedDay>>>{};

  _Live<List<DiaryEntry>> _day(String uid, String date) => _days.putIfAbsent('$uid/$date', () => _Live([]));

  _Live<Map<String, LoggedDay>> _summary(String uid) => _index.putIfAbsent(uid, () => _Live({}));

  void _store(String uid, String date, List<NewDiaryEntry> entries, {required bool onTime}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final day = _day(uid, date);
    day.value = [
      ...day.value,
      for (final e in entries)
        DiaryEntry(
          id: _newId('entry'),
          createdAt: now,
          kind: e.kind,
          refId: e.refId,
          name: e.name,
          grams: e.grams,
          servings: e.servings,
          macros: e.macros,
          meal: e.meal,
          rawInput: e.rawInput,
        ),
    ];
    final index = _summary(uid);
    final previous = index.value[date];
    index.value = {
      ...index.value,
      date: LoggedDay(
        date: date,
        entries: day.value.length,
        kcal: sumMacros(day.value.map((e) => e.macros)).kcal,
        onTime: (previous?.onTime ?? false) || onTime,
      ),
    };
  }

  @override
  Stream<List<DiaryEntry>> watchDay(String uid, String date) => _day(uid, date).stream;

  @override
  Future<void> addEntries(String uid, String date, List<NewDiaryEntry> entries) async =>
      _store(uid, date, entries, onTime: loggedOnTime(date, todayKey()));

  @override
  Future<void> deleteEntry(String uid, String date, DiaryEntry entry) async {
    final day = _day(uid, date);
    day.value = day.value.where((e) => e.id != entry.id).toList();
    final index = _summary(uid);
    final previous = index.value[date];
    if (previous == null) return;
    index.value = {
      ...index.value,
      date: LoggedDay(date: date, entries: day.value.length, kcal: sumMacros(day.value.map((e) => e.macros)).kcal, onTime: previous.onTime),
    };
  }

  @override
  Stream<List<LoggedDay>> watchLoggedDays(String uid) =>
      _summary(uid).stream.map((m) => m.values.where((d) => d.entries > 0).toList()..sort((a, b) => a.date.compareTo(b.date)));

  @override
  Future<void> ensureDayIndex(String uid) async {}
}

class MemoryProfileRepository implements ProfileRepository {
  MemoryProfileRepository({List<WeightEntry> weights = const [], BodyGoal? bodyGoal, BodyProfile body = const BodyProfile()})
      : _weights = _Live(sortByDate(weights)),
        _bodyGoal = _Live(bodyGoal),
        _body = _Live(body);

  final _goals = _Live<Goals>(defaultGoals);
  final _Live<BodyProfile> _body;
  final _celebration = _Live<StreakCelebration?>(null);
  final _restDays = _Live<Set<int>>(const {});
  final _plan = _Live<TrainingPlan>(const TrainingPlan());
  final _Live<BodyGoal?> _bodyGoal;
  final _Live<List<WeightEntry>> _weights;

  @override
  Stream<Goals> watchGoals(String uid) => _goals.stream;

  @override
  Future<void> saveGoals(String uid, Goals goals) async => _goals.value = goals;

  @override
  Stream<BodyGoal?> watchBodyGoal(String uid) => _bodyGoal.stream;

  @override
  Future<void> saveBodyGoal(String uid, BodyGoal goal) async => _bodyGoal.value = goal;

  @override
  Stream<List<WeightEntry>> watchWeights(String uid) => _weights.stream;

  @override
  Future<void> saveWeight(String uid, WeightEntry entry) async =>
      _weights.value = sortByDate([..._weights.value.where((e) => e.date != entry.date), entry]);

  @override
  Future<void> deleteWeight(String uid, String date) async => _weights.value = _weights.value.where((e) => e.date != date).toList();

  @override
  Stream<BodyProfile> watchBodyProfile(String uid) => _body.stream;

  @override
  Future<void> saveBodyProfile(String uid, BodyProfile profile) async => _body.value = profile;

  @override
  Stream<Set<int>> watchStreakRestDays(String uid) => _restDays.stream;

  @override
  Future<void> saveStreakRestDays(String uid, Set<int> weekdays) async => _restDays.value = {...weekdays};

  @override
  Stream<StreakCelebration?> watchStreakCelebration(String uid) => _celebration.stream;

  @override
  Future<void> saveStreakCelebration(String uid, StreakCelebration celebration) async => _celebration.value = celebration;

  @override
  Stream<TrainingPlan> watchTrainingPlan(String uid) => _plan.stream;

  @override
  Future<void> saveTrainingPlan(String uid, TrainingPlan plan) async => _plan.value = plan;
}

class MemoryStrengthRepository implements StrengthRepository {
  MemoryStrengthRepository({List<Routine> routines = const [], List<Workout> workouts = const []})
      : _routines = _Live(List.of(routines)),
        _workouts = _Live(List.of(workouts));

  final _Live<List<Routine>> _routines;
  final _Live<List<Workout>> _workouts;
  final _custom = _Live<List<Exercise>>([]);

  @override
  Stream<List<Routine>> watchRoutines(String uid) => _routines.stream.map((l) => [...l]..sort((a, b) => a.name.compareTo(b.name)));

  @override
  Future<String> saveRoutine(String uid, {required String name, required List<RoutineExercise> exercises, String? id}) async {
    final key = id ?? _newId('routine');
    _routines.value = [
      ..._routines.value.where((r) => r.id != key),
      Routine(id: key, name: name, exercises: exercises, updatedAt: DateTime.now().millisecondsSinceEpoch),
    ];
    return key;
  }

  @override
  Future<void> deleteRoutine(String uid, String id) async => _routines.value = _routines.value.where((r) => r.id != id).toList();

  @override
  Stream<List<Workout>> watchWorkouts(String uid) => _workouts.stream.map((l) => [...l]..sort((a, b) => b.startedAt.compareTo(a.startedAt)));

  @override
  Future<String> saveWorkout(String uid, NewWorkout workout) async {
    final id = _newId('workout');
    _workouts.value = [..._workouts.value, Workout.fromNew(id, workout)];
    return id;
  }

  @override
  Future<void> deleteWorkout(String uid, String id) async => _workouts.value = _workouts.value.where((w) => w.id != id).toList();

  @override
  Future<void> setWorkoutRpe(String uid, String id, int rpe) async =>
      _workouts.value = [for (final w in _workouts.value) w.id == id ? w.withRpe(rpe) : w];

  @override
  Stream<List<Exercise>> watchCustomExercises(String uid) => _custom.stream;

  @override
  Future<Exercise> createCustomExercise(String uid, {required String name, String? equipment, required List<String> primary}) async {
    final e = Exercise(id: '$customExercisePrefix${_newId('ex')}', name: name, equipment: equipment, primary: primary, custom: true);
    _custom.value = [..._custom.value, e];
    return e;
  }
}

/// "Nube" en memoria para el respaldo de cardio.
class MemoryCardioRepository implements CardioRepository {
  MemoryCardioRepository({String uid = 'demo', List<({CardioActivity activity, CardioTrack track})> initial = const []}) {
    for (final e in initial) {
      _saved['$uid/${e.activity.id}'] = e;
    }
  }

  final _saved = <String, ({CardioActivity activity, CardioTrack track})>{};

  @override
  Future<void> saveActivity(String uid, CardioActivity activity, [CardioTrack? track]) async {
    final key = '$uid/${activity.id}';
    final current = track ?? _saved[key]?.track ?? const CardioTrack([]);
    _saved[key] = (activity: activity.copyWith(syncState: SyncState.synced), track: current);
  }

  @override
  Future<Map<String, int>> index(String uid) async => {
        for (final e in _saved.entries)
          if (e.key.startsWith('$uid/')) e.value.activity.id: e.value.activity.updatedAt,
      };

  @override
  Future<({CardioActivity activity, CardioTrack track})?> loadActivity(String uid, String id) async => _saved['$uid/$id'];

  @override
  Future<void> deleteActivity(String uid, String id) async => _saved.remove('$uid/$id');
}

/// Sin red: Open Food Facts y las instrucciones no están disponibles.
class OfflineLookupRepository implements LookupRepository {
  @override
  Future<OffDraft?> lookupBarcode(String code) async => null;

  @override
  Future<List<String>> exerciseInstructions(String exerciseId) async => const [];
}

/// Ruta de ejemplo: un circuito alrededor del Parque O'Higgins (Santiago) a
/// velocidad constante, con subidas y bajadas suaves.
({CardioActivity activity, CardioTrack track}) sampleCardio(Discipline d, {required int daysAgo, required double km, required double speedMs, double climbM = 20, int? rpe}) {
  final start = fromDateKey(addDays(todayKey(), -daysAgo)).add(const Duration(hours: 7, minutes: 30)).millisecondsSinceEpoch;
  final r = Recording(id: 'demo-${d.name}-$daysAgo', discipline: d, startedAt: start);
  final seconds = (km * 1000 / speedMs).round();
  // Un circuito de ~2,4 km de perímetro que se repite.
  const radius = 380.0;
  for (var s = 0; s <= seconds; s += 2) {
    final angle = s * speedMs / radius;
    final wobble = 1 + 0.12 * math.sin(angle * 3);
    r.add(TrackPoint(
      lat: -33.4640 + radius * wobble * math.sin(angle) / 111195,
      lng: -70.6610 + radius * wobble * math.cos(angle) / (111195 * math.cos(33.464 * math.pi / 180)),
      t: start + s * 1000,
      alt: 545 + climbM / 2 * math.sin(angle),
      accuracy: 5,
    ));
  }
  return finishRecording(r, now: start + seconds * 1000, rpe: rpe);
}

/// Backend de demostración con el catálogo base cargado y algunos datos de ejemplo,
/// para recorrer la app sin configurar nada.
Backend memoryBackend({required List<Food> seedFoods, required LookupRepository lookup, bool withSampleData = true, bool signedIn = false, bool richSample = false}) {
  final today = todayKey();
  final weights = withSampleData
      ? [for (var i = 35; i >= 0; i -= 3) WeightEntry(date: addDays(today, -i), kg: 84.6 - (35 - i) * 0.07 + (i % 2) * 0.2)]
      : <WeightEntry>[];

  Workout sample(int daysAgo, double kg, String id, {int? rpe, int minutes = 55}) {
    final start = fromDateKey(addDays(today, -daysAgo)).add(const Duration(hours: 19)).millisecondsSinceEpoch;
    return Workout(
      id: id,
      routineId: 'demo-pecho',
      name: 'Rutina de pecho',
      date: addDays(today, -daysAgo),
      startedAt: start,
      finishedAt: start + minutes * 60000,
      rpe: rpe,
      exercises: [
        WorkoutExercise(exerciseId: 'Barbell_Bench_Press_-_Medium_Grip', name: 'Press de banca con barra', sets: [
          const StrengthSet(type: SetType.warmup, kg: 30, reps: 10),
          StrengthSet(kg: kg, reps: 8),
          StrengthSet(kg: kg, reps: 7),
          StrengthSet(kg: kg, reps: 6),
        ]),
        const WorkoutExercise(exerciseId: 'Dips_-_Triceps_Version', name: 'Fondos en paralelas (tríceps)', sets: [
          StrengthSet(reps: 12),
          StrengthSet(reps: 10),
        ]),
      ],
    );
  }

  // Desayuno y almuerzo de los últimos 12 días (no hoy): muestran la racha, el
  // calendario y el botón para repetir las comidas de ayer.
  final foods = {for (final f in seedFoods) f.id: f};
  NewDiaryEntry? item(String foodId, double grams, MealSlot meal) {
    final f = foods[foodId];
    if (f == null) return null;
    return NewDiaryEntry(kind: EntryKind.food, refId: f.id, name: f.name, grams: grams, macros: macrosForGrams(f.per100g, grams), meal: meal);
  }

  final sampleDiary = <String, List<NewDiaryEntry>>{
    if (withSampleData)
      for (var i = 12; i >= 1; i--)
        addDays(today, -i): [
          ?item('avena-hojuelas', 60, MealSlot.desayuno),
          ?item('leche-semidescremada', 250, MealSlot.desayuno),
          ?item(i.isEven ? 'pechuga-pollo-cocida' : 'salmon-cocido', 170, MealSlot.almuerzo),
          ?item('arroz-blanco-cocido', 200, MealSlot.almuerzo),
        ],
    // Para las capturas: el día de hoy no parte vacío.
    if (withSampleData && richSample)
      today: [
        ?item('avena-hojuelas', 60, MealSlot.desayuno),
        ?item('leche-semidescremada', 250, MealSlot.desayuno),
        ?item('pechuga-pollo-cocida', 170, MealSlot.almuerzo),
        ?item('arroz-blanco-cocido', 200, MealSlot.almuerzo),
      ],
  };

  return Backend(
    kind: BackendKind.memory,
    auth: MemoryAuthRepository(signedIn: signedIn),
    foods: MemoryFoodRepository(seedFoods),
    // Para las capturas de la tesis: una receta ya guardada, para ver la lista de «Mis recetas».
    recipes: MemoryRecipeRepository(
      initial: withSampleData && richSample
          ? [
              () {
                const items = [RecipeIngredient(foodId: 'pechuga-pollo-cocida', grams: 150), RecipeIngredient(foodId: 'arroz-blanco-cocido', grams: 180), RecipeIngredient(foodId: 'tomate', grams: 80), RecipeIngredient(foodId: 'aceite-oliva', grams: 5)];
                final t = computeRecipe(items, 1, foods);
                return Recipe(id: 'demo-bowl', ownerId: demoUser.uid, name: 'Bowl de pollo y arroz', servings: 1, ingredients: items, totalGrams: t.totalGrams, totals: t.totals, perServing: t.perServing);
              }(),
            ]
          : const [],
    ),
    diary: MemoryDiaryRepository(initial: sampleDiary, uid: demoUser.uid),
    profile: MemoryProfileRepository(
      weights: weights,
      bodyGoal: withSampleData ? BodyGoal(type: GoalType.lose, targetKg: 80, startDate: addDays(today, -35)) : null,
    ),
    strength: MemoryStrengthRepository(
      routines: withSampleData
          ? const [
              Routine(id: 'demo-pecho', name: 'Rutina de pecho', exercises: [
                RoutineExercise(exerciseId: 'Barbell_Bench_Press_-_Medium_Grip', sets: [
                  StrengthSet(type: SetType.warmup, kg: 30, reps: 10),
                  StrengthSet(kg: 55, reps: 8),
                  StrengthSet(kg: 55, reps: 8),
                  StrengthSet(kg: 55, reps: 8),
                ]),
                RoutineExercise(exerciseId: 'Dips_-_Triceps_Version', sets: [StrengthSet(reps: 12), StrengthSet(reps: 12)]),
              ]),
            ]
          : const [],
      workouts: withSampleData
          ? [
              sample(9, 52.5, 'demo-w1', rpe: 7),
              sample(2, 55, 'demo-w2', rpe: richSample ? 8 : null, minutes: richSample ? 60 : 55),
              // Para las capturas: seis semanas de historia, con una última semana más exigente,
              // para que el resumen de carga tenga datos confiables y muestre la alerta.
              if (richSample) ...[
                for (final d in const [44, 40, 37, 33, 30, 26, 23, 19, 16, 12]) sample(d, 50, 'rich-w$d', rpe: 7, minutes: 60),
              ],
            ]
          : const [],
    ),
    cardio: MemoryCardioRepository(
      uid: demoUser.uid,
      initial: withSampleData
          ? [
              sampleCardio(Discipline.running, daysAgo: 1, km: 7.2, speedMs: 3.1, rpe: 6),
              sampleCardio(Discipline.cycling, daysAgo: 4, km: 24, speedMs: 7.5, climbM: 40),
              sampleCardio(Discipline.trekking, daysAgo: 6, km: richSample ? 5 : 9.5, speedMs: 1.3, climbM: 120),
              if (richSample)
                for (final d in const [42, 38, 35, 31, 28, 24, 21, 17, 14, 10]) sampleCardio(Discipline.running, daysAgo: d, km: 8, speedMs: 3, rpe: 6),
            ]
          : const [],
    ),
    lookup: lookup,
  );
}
