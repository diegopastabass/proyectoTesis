/// Sesión de entrenamiento en curso (se guarda en el dispositivo hasta terminarla).
library;

import 'dart:math' as math;

import '../common/date.dart';
import '../common/numbers.dart';
import 'models.dart';
import 'stats.dart';

/// Serie en edición. kg y reps son texto para no pelear con el teclado ("52,").
class DraftSet {
  const DraftSet({
    required this.key,
    this.type = SetType.normal,
    this.kg = '',
    this.reps = '',
    this.done = false,
    this.targetKg,
    this.targetReps,
    this.targetRepsMax,
  });

  factory DraftSet.fromJson(Map<String, dynamic> j) => DraftSet(
        key: j['key'] as String? ?? newKey(),
        type: setTypeFrom(j['type']),
        kg: j['kg'] as String? ?? '',
        reps: j['reps'] as String? ?? '',
        done: j['done'] as bool? ?? false,
        targetKg: (j['targetKg'] as num?)?.toDouble(),
        targetReps: (j['targetReps'] as num?)?.toDouble(),
        targetRepsMax: (j['targetRepsMax'] as num?)?.toDouble(),
      );

  final String key;
  final SetType type;
  final String kg;
  final String reps;
  final bool done;

  /// Valores de la rutina; sugerencia (placeholder) si no hay sesión anterior.
  final double? targetKg;
  final double? targetReps;

  /// Tope del rango de la rutina (8–12 → 12).
  final double? targetRepsMax;

  DraftSet copyWith({SetType? type, String? kg, String? reps, bool? done}) => DraftSet(
        key: key,
        type: type ?? this.type,
        kg: kg ?? this.kg,
        reps: reps ?? this.reps,
        done: done ?? this.done,
        targetKg: targetKg,
        targetReps: targetReps,
        targetRepsMax: targetRepsMax,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'type': type.name,
        'kg': kg,
        'reps': reps,
        'done': done,
        'targetKg': targetKg,
        'targetReps': targetReps,
        'targetRepsMax': targetRepsMax,
      };
}

class DraftExercise {
  const DraftExercise({required this.key, required this.exerciseId, required this.sets, this.restSec = defaultRestSec});

  factory DraftExercise.fromJson(Map<String, dynamic> j) => DraftExercise(
        key: j['key'] as String? ?? newKey(),
        exerciseId: j['exerciseId'] as String,
        sets: [for (final s in j['sets'] as List? ?? const []) DraftSet.fromJson((s as Map).cast<String, dynamic>())],
        restSec: restFrom(j['restSec']) ?? defaultRestSec,
      );

  final String key;
  final String exerciseId;
  final List<DraftSet> sets;

  /// Descanso tras cada serie, en segundos (0 = sin temporizador).
  final int restSec;

  DraftExercise withSets(List<DraftSet> sets) => DraftExercise(key: key, exerciseId: exerciseId, sets: sets, restSec: restSec);

  DraftExercise withRest(int restSec) => DraftExercise(key: key, exerciseId: exerciseId, sets: sets, restSec: restSec);

  Map<String, dynamic> toJson() => {'key': key, 'exerciseId': exerciseId, 'sets': sets.map((s) => s.toJson()).toList(), 'restSec': restSec};
}

/// Descanso en curso: termina en `endsAt` (ms) y dura `seconds` en total (para la barra de progreso).
class RestTimer {
  const RestTimer({required this.endsAt, required this.seconds});

  final int endsAt;
  final int seconds;

  /// Segundos que faltan (0 si ya terminó).
  int remaining(int now) => math.max(0, ((endsAt - now) / 1000).ceil());
}

class ActiveWorkout {
  const ActiveWorkout({this.routineId, required this.name, required this.startedAt, this.exercises = const [], this.rest});

  factory ActiveWorkout.fromJson(Map<String, dynamic> j) => ActiveWorkout(
        routineId: j['routineId'] as String?,
        name: j['name'] as String? ?? 'Entrenamiento',
        startedAt: (j['startedAt'] as num).toInt(),
        exercises: [
          for (final e in j['exercises'] as List? ?? const []) DraftExercise.fromJson((e as Map).cast<String, dynamic>()),
        ],
        rest: switch ((j['restEndsAt'], j['restSec'])) {
          (final num endsAt, final num seconds) => RestTimer(endsAt: endsAt.toInt(), seconds: seconds.toInt()),
          _ => null,
        },
      );

  final String? routineId;
  final String name;
  final int startedAt;
  final List<DraftExercise> exercises;
  final RestTimer? rest;

  ActiveWorkout copyWith({String? name, List<DraftExercise>? exercises}) =>
      ActiveWorkout(routineId: routineId, name: name ?? this.name, startedAt: startedAt, exercises: exercises ?? this.exercises, rest: rest);

  ActiveWorkout withRest(RestTimer? rest) => ActiveWorkout(routineId: routineId, name: name, startedAt: startedAt, exercises: exercises, rest: rest);

  Map<String, dynamic> toJson() => {
        'routineId': routineId,
        'name': name,
        'startedAt': startedAt,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'restEndsAt': ?rest?.endsAt,
        'restSec': ?rest?.seconds,
      };
}

const _defaultSets = 3;
final _random = math.Random();

String newKey() => List.generate(8, (_) => _random.nextInt(36).toRadixString(36)).join();

/// Número escrito por el usuario (acepta coma decimal); null si está vacío o no es válido.
double? parseAmount(String s) {
  final n = parseNum(s);
  return n != null && n >= 0 ? n : null;
}

DraftSet _draftSet(SetType type, [double? targetKg, double? targetReps, double? targetRepsMax]) =>
    DraftSet(key: newKey(), type: type, targetKg: targetKg, targetReps: targetReps, targetRepsMax: targetRepsMax);

ActiveWorkout emptyWorkout(int now, [String name = 'Entrenamiento libre']) => ActiveWorkout(name: name, startedAt: now);

ActiveWorkout workoutFromRoutine(Routine routine, int now) => ActiveWorkout(
      routineId: routine.id,
      name: routine.name,
      startedAt: now,
      exercises: [
        for (final e in routine.exercises)
          DraftExercise(
            key: newKey(),
            exerciseId: e.exerciseId,
            sets: [for (final s in e.sets) _draftSet(s.type, s.kg, s.reps, s.repsMax)],
            restSec: e.restSec ?? defaultRestSec,
          ),
      ],
    );

/// Estructura de series al agregar un ejercicio: la de la última vez o 3 series normales.
List<DraftSet> setsForNewExercise(String exerciseId, List<Workout> workouts) {
  final last = lastSetsFor(workouts, exerciseId);
  if (last != null && last.isNotEmpty) return [for (final s in last) _draftSet(s.type)];
  return List.generate(_defaultSets, (_) => _draftSet(SetType.normal));
}

/// Descanso al agregar un ejercicio: el de la última vez o el por defecto.
int restForNewExercise(String exerciseId, List<Workout> workouts) => lastRestFor(workouts, exerciseId) ?? defaultRestSec;

/// Nueva serie al final: copia el tipo y la sugerencia de la última serie
/// (sin contar sus drops; un calentamiento o un drop dan una serie normal).
List<DraftSet> appendSet(List<DraftSet> sets) {
  final last = sets.lastWhere((s) => s.type != SetType.drop, orElse: () => const DraftSet(key: ''));
  final type = last.type == SetType.warmup || sets.lastOrNull?.type == SetType.drop ? SetType.normal : last.type;
  return [...sets, _draftSet(type, last.targetKg, last.targetReps, last.targetRepsMax)];
}

/// Peso sugerido para un drop: 80 % del anterior, redondeado a 2,5 kg (o a 0,5 kg en pesos bajos).
double? dropKg(double? kg) {
  if (kg == null || kg <= 0) return null;
  final step = kg >= 20 ? 2.5 : 0.5;
  final out = (kg * 0.8 / step).round() * step;
  return out > 0 && out < kg ? out : null;
}

/// Dónde va un drop nuevo de la serie `index`: después de ella y de sus drops.
int dropInsertIndex(List<SetType> types, int index) {
  var at = index + 1;
  while (at < types.length && types[at] == SetType.drop) {
    at++;
  }
  return at;
}

/// Agrega un drop a la serie `index` (después de sus drops), con el peso bajado
/// del último que se hizo o se sugirió en ese grupo.
List<DraftSet> insertDrop(List<DraftSet> sets, int index, {double? fromKg}) {
  final at = dropInsertIndex([for (final s in sets) s.type], index);
  final before = sets[at - 1];
  final kg = parseAmount(before.kg) ?? before.targetKg ?? fromKg;
  return [...sets]..insert(at, _draftSet(SetType.drop, dropKg(kg)));
}

/// Descanso al marcar la serie `index`: ninguno si sigue un drop (va sin pausa) o
/// si el ejercicio no usa temporizador.
int? restAfter(DraftExercise e, int index) {
  if (e.restSec <= 0) return null;
  final next = e.sets.elementAtOrNull(index + 1);
  return next?.type == SetType.drop ? null : e.restSec;
}

/// Suma o resta segundos al descanso en curso; null si con eso termina.
RestTimer? adjustRest(RestTimer rest, int deltaSec, int now) {
  final endsAt = rest.endsAt + deltaSec * 1000;
  if (endsAt <= now) return null;
  return RestTimer(endsAt: endsAt, seconds: math.max(1, rest.seconds + deltaSec));
}

/// Sugerencia para una serie: lo que se hizo la última vez en esa serie o, si no
/// hay registro, lo que dice la rutina (la plantilla se queda atrás al progresar).
/// Con `progressKg` (ver [progressionKg]) se sugiere el peso nuevo con el mínimo del rango.
({double? kg, double? reps}) suggestion(DraftSet set, StrengthSet? previous, {double? progressKg}) {
  if (progressKg != null && set.type != SetType.warmup && set.type != SetType.drop) return (kg: progressKg, reps: set.targetReps ?? previous?.reps);
  if (previous != null) return (kg: previous.kg, reps: previous.reps);
  return (kg: set.targetKg, reps: set.targetReps);
}

/// Doble progresión: si la última vez todas las series efectivas llegaron al tope
/// de su rango, se sugiere subir el peso (el más alto usado + `step`) y volver al
/// mínimo del rango. null si alguna serie no tiene rango o no llegó al tope.
double? progressionKg(DraftExercise e, List<StrengthSet?> previous, {double step = 2.5}) {
  var top = 0.0;
  var any = false;
  for (var i = 0; i < e.sets.length; i++) {
    final s = e.sets[i];
    if (s.type == SetType.warmup || s.type == SetType.drop) continue;
    final max = s.targetRepsMax;
    final p = i < previous.length ? previous[i] : null;
    if (max == null || p == null || (p.kg ?? 0) <= 0 || (p.reps ?? 0) < max) return null;
    top = math.max(top, p.kg!);
    any = true;
  }
  return any ? top + step : null;
}

const _lowerBody = {'quadriceps', 'hamstrings', 'glutes', 'adductors', 'abductors', 'lower back'};

/// Cuánto subir: 5 kg en básicos de pierna con barra, 2 kg con mancuernas (cada una) y 2,5 kg en el resto.
double progressionStep(Exercise? e) {
  if (e == null) return 2.5;
  if (e.equipment == 'dumbbell') return 2;
  if (e.equipment == 'barbell' && e.primary.any(_lowerBody.contains)) return 5;
  return 2.5;
}

/// Rango escrito en el editor de rutinas: "8-12" → (8, 12); "10" → (10, null).
({double? min, double? max}) parseRepsRange(String text) {
  final parts = text.split(RegExp(r'\s*[-–]\s*'));
  final min = parseAmount(parts.first);
  final max = parts.length > 1 ? parseAmount(parts[1]) : null;
  if (min == null) return (min: null, max: null);
  return (min: min, max: max != null && max >= min ? max : null);
}

/// Rango para mostrar: "8–12", o "5" si el tope es igual al mínimo.
String repsRangeLabel(double? min, double? max) => max == null || max == min ? plainEs(min) : '${plainEs(min)}–${plainEs(max)}';

/// Texto del rango para el editor: "8-12", o "10" sin tope.
String formatRepsRange(double? min, double? max) => max == null ? plainEs(min) : '${plainEs(min)}-${plainEs(max)}';

/// Marca o desmarca una serie. Al marcarla, los campos vacíos se completan con la
/// sugerencia. Devuelve null si no hay repeticiones con qué completarla.
DraftSet? toggleDone(DraftSet set, StrengthSet? previous, {double? progressKg}) {
  if (set.done) return set.copyWith(done: false);
  final hint = suggestion(set, previous, progressKg: progressKg);
  final kg = set.kg.trim().isNotEmpty ? set.kg : plainEs(hint.kg);
  final reps = set.reps.trim().isNotEmpty ? set.reps : plainEs(hint.reps);
  final r = parseAmount(reps);
  if (r == null || r <= 0) return null;
  return set.copyWith(kg: kg, reps: reps, done: true);
}

/// Anterior de cada serie del ejercicio, según la última sesión con él.
List<StrengthSet?> previousFor(DraftExercise exercise, List<Workout> workouts, int before) {
  final last = lastSetsFor(workouts, exercise.exerciseId, before: before);
  final types = exercise.sets.map((s) => s.type).toList();
  return [for (var i = 0; i < exercise.sets.length; i++) matchPrevious(last, types, i)];
}

int pendingSets(ActiveWorkout w) => w.exercises.fold(0, (n, e) => n + e.sets.where((s) => !s.done).length);

int doneSets(ActiveWorkout w) => w.exercises.fold(0, (n, e) => n + e.sets.where((s) => s.done).length);

/// Volumen de las series marcadas, sin calentamiento.
double activeVolume(ActiveWorkout w) => w.exercises.fold(
      0,
      (sum, e) =>
          sum +
          e.sets
              .where((s) => s.done && s.type != SetType.warmup)
              .fold<double>(0, (v, s) => v + (parseAmount(s.kg) ?? 0) * (parseAmount(s.reps) ?? 0)),
    );

/// Convierte la sesión en curso en lo que se guarda: solo series hechas y ejercicios con alguna.
NewWorkout finishWorkout(ActiveWorkout w, int now, String Function(String exerciseId) nameOf, {int? rpe}) {
  final exercises = <WorkoutExercise>[];
  for (final e in w.exercises) {
    final sets = [
      for (final s in e.sets.where((s) => s.done)) StrengthSet(type: s.type, kg: parseAmount(s.kg), reps: parseAmount(s.reps)),
    ].where((s) => (s.reps ?? 0) > 0).toList();
    if (sets.isNotEmpty) exercises.add(WorkoutExercise(exerciseId: e.exerciseId, name: nameOf(e.exerciseId), sets: sets, restSec: e.restSec));
  }
  return NewWorkout(
    routineId: w.routineId,
    name: w.name,
    date: toDateKey(DateTime.fromMillisecondsSinceEpoch(w.startedAt)),
    startedAt: w.startedAt,
    finishedAt: now,
    exercises: exercises,
    rpe: rpe,
  );
}

/// Ejercicios y series de una sesión, para actualizar la rutina con lo que se hizo.
/// Si la serie de la rutina tenía un rango de repeticiones, se conserva el rango y
/// se actualiza solo el peso.
List<RoutineExercise> routineExercisesFrom(Workout w, [Routine? routine]) {
  final before = {for (final e in routine?.exercises ?? const <RoutineExercise>[]) e.exerciseId: e.sets};
  return [
    for (final e in w.exercises)
      RoutineExercise(exerciseId: e.exerciseId, restSec: e.restSec ?? routine?.exercises.where((x) => x.exerciseId == e.exerciseId).firstOrNull?.restSec, sets: [
        for (var i = 0; i < e.sets.length; i++)
          () {
            final s = e.sets[i];
            final old = before[e.exerciseId]?.elementAtOrNull(i);
            return old?.repsMax != null && old!.type == s.type
                ? StrengthSet(type: s.type, kg: s.kg, reps: old.reps, repsMax: old.repsMax)
                : StrengthSet(type: s.type, kg: s.kg, reps: s.reps);
          }(),
      ]),
  ];
}
