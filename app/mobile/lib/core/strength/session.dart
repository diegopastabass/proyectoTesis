/// Sesión de entrenamiento en curso (se guarda en el dispositivo hasta terminarla).
library;

import 'dart:math' as math;

import '../common/date.dart';
import '../common/numbers.dart';
import '../common/units.dart';
import 'models.dart';
import 'stats.dart';
import 'weights.dart';

/// Serie en edición. kg y reps son texto para no pelear con el teclado ("52,").
/// `kg` está escrito en la unidad del ejercicio ([DraftExercise.unit]); los
/// `target*` y todo lo que se guarda están en kg.
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
  const DraftExercise({required this.key, required this.exerciseId, required this.sets, this.restSec = defaultRestSec, this.unit = WeightUnit.kg});

  factory DraftExercise.fromJson(Map<String, dynamic> j) => DraftExercise(
        key: j['key'] as String? ?? newKey(),
        exerciseId: j['exerciseId'] as String,
        sets: [for (final s in j['sets'] as List? ?? const []) DraftSet.fromJson((s as Map).cast<String, dynamic>())],
        restSec: restFrom(j['restSec']) ?? defaultRestSec,
        unit: WeightUnit.from(j['unit']),
      );

  final String key;
  final String exerciseId;
  final List<DraftSet> sets;

  /// Descanso tras cada serie, en segundos (0 = sin temporizador).
  final int restSec;

  /// Unidad en que se escriben los pesos de este ejercicio (la de la máquina).
  final WeightUnit unit;

  DraftExercise withSets(List<DraftSet> sets) => DraftExercise(key: key, exerciseId: exerciseId, sets: sets, restSec: restSec, unit: unit);

  DraftExercise withRest(int restSec) => DraftExercise(key: key, exerciseId: exerciseId, sets: sets, restSec: restSec, unit: unit);

  DraftExercise withUnit(WeightUnit unit) => DraftExercise(key: key, exerciseId: exerciseId, sets: sets, restSec: restSec, unit: unit);

  Map<String, dynamic> toJson() =>
      {'key': key, 'exerciseId': exerciseId, 'sets': sets.map((s) => s.toJson()).toList(), 'restSec': restSec, 'unit': unit.name};
}

/// Descanso en curso: termina en `endsAt` (ms) y dura `seconds` en total (para la
/// barra de progreso). En pausa, `pausedLeft` guarda los ms que faltaban y
/// `endsAt` no se usa hasta reanudar.
class RestTimer {
  const RestTimer({required this.endsAt, required this.seconds, this.pausedLeft});

  final int endsAt;
  final int seconds;

  /// ms que faltaban al pausar (null = corriendo).
  final int? pausedLeft;

  bool get paused => pausedLeft != null;

  /// ms que faltan (0 si ya terminó).
  int leftMs(int now) => math.max(0, pausedLeft ?? endsAt - now);

  /// Segundos que faltan (0 si ya terminó).
  int remaining(int now) => (leftMs(now) / 1000).ceil();

  /// Parte que queda (1 = recién empieza), para la barra de progreso.
  double progress(int now) => seconds <= 0 ? 0 : (leftMs(now) / (seconds * 1000)).clamp(0.0, 1.0);

  RestTimer pause(int now) => paused ? this : RestTimer(endsAt: endsAt, seconds: seconds, pausedLeft: math.max(0, endsAt - now));

  RestTimer resume(int now) => paused ? RestTimer(endsAt: now + pausedLeft!, seconds: seconds) : this;
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
          (final num endsAt, final num seconds) =>
            RestTimer(endsAt: endsAt.toInt(), seconds: seconds.toInt(), pausedLeft: (j['restPausedLeft'] as num?)?.toInt()),
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
        'restPausedLeft': ?rest?.pausedLeft,
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

/// Sesión desde una rutina. La unidad de cada ejercicio es la que indica la rutina
/// o, si no indica, la que entrega `unitFor` (la última usada o la preferida).
ActiveWorkout workoutFromRoutine(Routine routine, int now, {WeightUnit Function(String exerciseId)? unitFor}) => ActiveWorkout(
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
            unit: e.unit ?? unitFor?.call(e.exerciseId) ?? WeightUnit.kg,
          ),
      ],
    );

/// Unidad al agregar un ejercicio: la de la última vez (la máquina suele ser la
/// misma) o la preferida.
WeightUnit unitForExercise(String exerciseId, List<Workout> workouts, {WeightUnit fallback = WeightUnit.kg}) =>
    lastUnitFor(workouts, exerciseId) ?? fallback;

/// Cambia la unidad del ejercicio. Con `convert` los pesos escritos se convierten
/// (100 kg → 220,5 lb); sin él se mantienen los números y cambia solo cómo se leen
/// (anotaste "100" mirando una máquina en libras).
DraftExercise switchUnit(DraftExercise e, WeightUnit to, {required bool convert}) {
  if (e.unit == to) return e;
  if (!convert) return e.withUnit(to);
  return e.withUnit(to).withSets([
    for (final s in e.sets)
      switch (parseAmount(s.kg)) {
        final v? => s.copyWith(kg: plainEs(round1(convertWeight(v, e.unit, to)))),
        null => s,
      },
  ]);
}

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

/// Peso sugerido para un drop en kg: 80 % del anterior, redondeado a 2,5 kg (o a
/// 0,5 kg en pesos bajos). En otra unidad, ver [dropWeight].
double? dropKg(double? kg) => dropWeight(kg, WeightUnit.kg);

/// Dónde va un drop nuevo de la serie `index`: después de ella y de sus drops.
int dropInsertIndex(List<SetType> types, int index) {
  var at = index + 1;
  while (at < types.length && types[at] == SetType.drop) {
    at++;
  }
  return at;
}

/// Agrega un drop a la serie `index` (después de sus drops), con el peso bajado
/// del último que se hizo o se sugirió en ese grupo. El peso escrito está en
/// `unit`; `fromKg` y la sugerencia que queda en el drop, en kg.
List<DraftSet> insertDrop(List<DraftSet> sets, int index, {double? fromKg, WeightUnit unit = WeightUnit.kg}) {
  final at = dropInsertIndex([for (final s in sets) s.type], index);
  final before = sets[at - 1];
  final ref = before.targetKg ?? fromKg;
  final value = parseAmount(before.kg) ?? (ref == null ? null : displayWeight(ref, unit));
  final drop = dropWeight(value, unit);
  return [...sets]..insert(at, _draftSet(SetType.drop, drop == null ? null : toKg(drop, unit)));
}

/// Descanso al marcar la serie `index`: ninguno si sigue un drop (va sin pausa) o
/// si el ejercicio no usa temporizador.
int? restAfter(DraftExercise e, int index) {
  if (e.restSec <= 0) return null;
  final next = e.sets.elementAtOrNull(index + 1);
  return next?.type == SetType.drop ? null : e.restSec;
}

/// Suma o resta segundos al descanso en curso (también en pausa); null si con eso termina.
RestTimer? adjustRest(RestTimer rest, int deltaSec, int now) {
  final seconds = math.max(1, rest.seconds + deltaSec);
  if (rest.paused) {
    final left = rest.pausedLeft! + deltaSec * 1000;
    return left <= 0 ? null : RestTimer(endsAt: rest.endsAt, seconds: seconds, pausedLeft: left);
  }
  final endsAt = rest.endsAt + deltaSec * 1000;
  if (endsAt <= now) return null;
  return RestTimer(endsAt: endsAt, seconds: seconds);
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
/// `step` está en la unidad del ejercicio; el resultado, en kg.
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
  if (!any) return null;
  // Se sube desde el peso redondeado en la unidad de la máquina (45 lb y no 44,9).
  return toKg(displayWeight(top, e.unit) + step, e.unit);
}

/// Cuánto subir en kg: 5 en básicos de pierna con barra, 2 con mancuernas (cada
/// una) y 2,5 en el resto. En otra unidad, ver [progressionStepIn].
double progressionStep(Exercise? e) => progressionStepIn(e, WeightUnit.kg);

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
/// sugerencia (convertida a `unit`). Devuelve null si no hay repeticiones con qué completarla.
DraftSet? toggleDone(DraftSet set, StrengthSet? previous, {double? progressKg, WeightUnit unit = WeightUnit.kg}) {
  if (set.done) return set.copyWith(done: false);
  final hint = suggestion(set, previous, progressKg: progressKg);
  final kg = set.kg.trim().isNotEmpty ? set.kg : (hint.kg == null ? '' : plainEs(displayWeight(hint.kg!, unit)));
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

/// Volumen de las series marcadas, sin calentamiento (en kg).
double activeVolume(ActiveWorkout w) => w.exercises.fold(
      0,
      (sum, e) =>
          sum +
          e.sets
              .where((s) => s.done && s.type != SetType.warmup)
              .fold<double>(0, (v, s) => v + toKg(parseAmount(s.kg) ?? 0, e.unit) * (parseAmount(s.reps) ?? 0)),
    );

/// Convierte la sesión en curso en lo que se guarda: solo series hechas y ejercicios con alguna.
NewWorkout finishWorkout(ActiveWorkout w, int now, String Function(String exerciseId) nameOf, {int? rpe}) {
  final exercises = <WorkoutExercise>[];
  for (final e in w.exercises) {
    final sets = [
      for (final s in e.sets.where((s) => s.done))
        StrengthSet(type: s.type, kg: switch (parseAmount(s.kg)) { final v? => toKg(v, e.unit), null => null }, reps: parseAmount(s.reps)),
    ].where((s) => (s.reps ?? 0) > 0).toList();
    if (sets.isNotEmpty) {
      exercises.add(WorkoutExercise(exerciseId: e.exerciseId, name: nameOf(e.exerciseId), sets: sets, restSec: e.restSec, unit: e.unit));
    }
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
      RoutineExercise(exerciseId: e.exerciseId, restSec: e.restSec ?? routine?.exercises.where((x) => x.exerciseId == e.exerciseId).firstOrNull?.restSec, unit: e.unit, sets: [
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
