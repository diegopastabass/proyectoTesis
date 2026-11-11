import 'dart:math' as math;

import '../common/numbers.dart';
import '../common/units.dart';
import 'models.dart';

bool isEffective(StrengthSet s) => s.type != SetType.warmup;

/// Cuenta como una serie más: los drops son parte de la serie que bajan.
bool countsAsSet(StrengthSet s) => isEffective(s) && s.type != SetType.drop;

/// Volumen de una serie: kg × repeticiones (0 si no tiene peso).
double setVolume(StrengthSet s) => (s.kg ?? 0) * (s.reps ?? 0);

/// Volumen de un ejercicio sin contar el calentamiento.
double exerciseVolume(WorkoutExercise e) => e.sets.where(isEffective).fold(0, (sum, s) => sum + setVolume(s));

/// Volumen total de la sesión (series efectivas).
double workoutVolume(NewWorkout w) => w.exercises.fold(0, (sum, e) => sum + exerciseVolume(e));

class WorkoutTotals {
  const WorkoutTotals({required this.volume, required this.sets, required this.reps, required this.exercises, required this.durationMin});

  final int volume;
  final int sets;
  final int reps;
  final int exercises;
  final int durationMin;
}

WorkoutTotals workoutTotals(NewWorkout w) {
  final effective = w.exercises.expand((e) => e.sets.where(isEffective)).toList();
  return WorkoutTotals(
    volume: jsRound(workoutVolume(w)),
    sets: effective.where(countsAsSet).length,
    reps: effective.fold<double>(0, (s, x) => s + (x.reps ?? 0)).round(),
    exercises: w.exercises.length,
    durationMin: math.max(0, jsRound((w.finishedAt - w.startedAt) / 60000)),
  );
}

/// 1RM estimado con la fórmula de Epley: kg × (1 + reps / 30). Con 1 repetición
/// es el mismo peso. Sobre 12 repeticiones la estimación pierde precisión.
double estimate1RM(double kg, double reps) {
  if (kg <= 0 || reps <= 0) return 0;
  return reps == 1 ? kg : kg * (1 + reps / 30);
}

/// Sesiones ordenadas de la más antigua a la más reciente.
List<Workout> sortWorkouts(Iterable<Workout> list) => [...list]..sort((a, b) => a.startedAt.compareTo(b.startedAt));

class ExerciseSession {
  const ExerciseSession({
    required this.workoutId,
    required this.date,
    required this.startedAt,
    required this.maxKg,
    required this.repsAtMax,
    required this.maxReps,
    required this.best1RM,
    required this.volume,
    required this.sets,
  });

  final String workoutId;
  final String date;
  final int startedAt;

  /// Mayor peso en una serie efectiva.
  final double maxKg;

  /// Repeticiones hechas con ese mayor peso (la mejor serie).
  final double repsAtMax;
  final double maxReps;
  final double best1RM;
  final double volume;
  final int sets;
}

ExerciseSession summarizeExercise(Workout w, WorkoutExercise e) {
  final eff = e.sets.where(isEffective).toList();
  var maxKg = 0.0;
  var repsAtMax = 0.0;
  for (final s in eff) {
    final kg = s.kg ?? 0;
    final reps = s.reps ?? 0;
    if (kg > maxKg || (kg == maxKg && reps > repsAtMax)) {
      maxKg = kg;
      repsAtMax = reps;
    }
  }
  return ExerciseSession(
    workoutId: w.id,
    date: w.date,
    startedAt: w.startedAt,
    maxKg: maxKg,
    repsAtMax: repsAtMax,
    maxReps: eff.fold(0.0, (m, s) => math.max(m, s.reps ?? 0)),
    best1RM: eff.fold(0.0, (m, s) => math.max(m, estimate1RM(s.kg ?? 0, s.reps ?? 0))),
    volume: exerciseVolume(e),
    sets: eff.where(countsAsSet).length,
  );
}

/// Historial de un ejercicio, de la sesión más antigua a la más reciente.
List<ExerciseSession> exerciseHistory(List<Workout> workouts, String exerciseId) => [
      for (final w in sortWorkouts(workouts))
        for (final e in w.exercises)
          if (e.exerciseId == exerciseId && e.sets.isNotEmpty) summarizeExercise(w, e),
    ];

/// Las series de la sesión más reciente (antes de `before`, si se indica) que incluyó el ejercicio.
List<StrengthSet>? lastSetsFor(List<Workout> workouts, String exerciseId, {int? before}) {
  int? bestAt;
  List<StrengthSet>? best;
  for (final w in workouts) {
    if (before != null && w.startedAt >= before) continue;
    final e = w.exercises.where((x) => x.exerciseId == exerciseId && x.sets.isNotEmpty).firstOrNull;
    if (e != null && (bestAt == null || w.startedAt > bestAt)) {
      bestAt = w.startedAt;
      best = e.sets;
    }
  }
  return best;
}

int _group(SetType t) => switch (t) {
      SetType.warmup => 0,
      SetType.drop => 1,
      SetType.normal || SetType.failure => 2,
    };

/// Serie "anterior" para la columna ANTERIOR: la que ocupó la misma posición entre
/// las del mismo grupo (calentamiento con calentamiento, drops con drops, efectivas
/// con efectivas).
StrengthSet? matchPrevious(List<StrengthSet>? previous, List<SetType> types, int index) {
  if (previous == null) return null;
  final group = _group(types[index]);
  final position = types.take(index).where((t) => _group(t) == group).length;
  final same = previous.where((s) => _group(s.type) == group).toList();
  return position < same.length ? same[position] : null;
}

/// Descanso usado la última vez con el ejercicio (null si nunca se registró).
int? lastRestFor(List<Workout> workouts, String exerciseId) {
  int? bestAt;
  int? rest;
  for (final w in workouts) {
    final e = w.exercises.where((x) => x.exerciseId == exerciseId && x.restSec != null).firstOrNull;
    if (e != null && (bestAt == null || w.startedAt > bestAt)) {
      bestAt = w.startedAt;
      rest = e.restSec;
    }
  }
  return rest;
}

/// Unidad en que se anotó el ejercicio la última vez (null si nunca se registró).
/// Sirve para recordar que una máquina está en libras.
WeightUnit? lastUnitFor(List<Workout> workouts, String exerciseId, {int? before}) {
  int? bestAt;
  WeightUnit? unit;
  for (final w in workouts) {
    if (before != null && w.startedAt >= before) continue;
    final e = w.exercises.where((x) => x.exerciseId == exerciseId && x.sets.isNotEmpty).firstOrNull;
    if (e != null && (bestAt == null || w.startedAt > bestAt)) {
      bestAt = w.startedAt;
      unit = e.unit;
    }
  }
  return unit;
}

class ExerciseFrequency {
  ExerciseFrequency({required this.exerciseId, required this.name});

  final String exerciseId;
  String name;
  int sessions = 0;
  int lastAt = 0;
}

/// Ejercicios ordenados por cuántas sesiones los incluyen.
List<ExerciseFrequency> exerciseFrequency(List<Workout> workouts) {
  final map = <String, ExerciseFrequency>{};
  for (final w in workouts) {
    for (final e in w.exercises) {
      final cur = map[e.exerciseId] ??= ExerciseFrequency(exerciseId: e.exerciseId, name: e.name);
      cur.sessions++;
      if (w.startedAt >= cur.lastAt) {
        cur.lastAt = w.startedAt;
        cur.name = e.name;
      }
    }
  }
  return map.values.toList()
    ..sort((a, b) {
      final bySessions = b.sessions.compareTo(a.sessions);
      return bySessions != 0 ? bySessions : b.lastAt.compareTo(a.lastAt);
    });
}
