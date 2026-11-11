/// Modelo del módulo de fuerza (mismos documentos que la versión web).
///
/// Los pesos se guardan siempre en kg (`StrengthSet.kg`). Cada ejercicio de una
/// sesión o rutina guarda además la unidad en que se anotó (`unit`), para volver a
/// mostrar "45 lb" y proponer libras la próxima vez en esa máquina. Sin el campo
/// (documentos antiguos) se entiende kg.
library;

import '../common/units.dart';

/// Calentamiento no cuenta como serie efectiva; al fallo sí. Un drop es la
/// bajada de peso sin descanso tras la serie anterior: suma volumen, pero forma
/// parte de esa serie (no se cuenta aparte).
enum SetType { normal, warmup, failure, drop }

SetType setTypeFrom(Object? v) => SetType.values.where((t) => t.name == v).firstOrNull ?? SetType.normal;

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    this.nameEn = '',
    this.aliases = const [],
    this.category = 'strength',
    this.equipment,
    this.primary = const [],
    this.secondary = const [],
    this.images = 0,
    this.custom = false,
  });

  final String id;

  /// Nombre a mostrar (en español si existe).
  final String name;

  /// Nombre original del catálogo (inglés); vacío en ejercicios propios.
  final String nameEn;
  final List<String> aliases;
  final String category;
  final String? equipment;
  final List<String> primary;
  final List<String> secondary;

  /// Cantidad de imágenes (0 o 2: posición inicial y final).
  final int images;

  /// true si lo creó el usuario.
  final bool custom;
}

/// Serie guardada (de una rutina o de una sesión terminada). kg null = sin peso.
class StrengthSet {
  const StrengthSet({this.type = SetType.normal, this.kg, this.reps, this.repsMax});

  factory StrengthSet.fromMap(Object? data) {
    final m = data is Map ? data : const {};
    return StrengthSet(
      type: setTypeFrom(m['type']),
      kg: (m['kg'] as num?)?.toDouble(),
      reps: (m['reps'] as num?)?.toDouble(),
      repsMax: (m['repsMax'] as num?)?.toDouble(),
    );
  }

  final SetType type;
  final double? kg;

  /// En una rutina, el mínimo del rango objetivo ("8" de 8–12).
  final double? reps;

  /// Solo en rutinas: tope del rango. Al llegar a él en todas las series se sugiere subir el peso.
  final double? repsMax;

  Map<String, dynamic> toMap() => {'type': type.name, 'kg': kg, 'reps': reps, 'repsMax': ?repsMax};

  @override
  bool operator ==(Object other) =>
      other is StrengthSet && other.type == type && other.kg == kg && other.reps == reps && other.repsMax == repsMax;

  @override
  int get hashCode => Object.hash(type, kg, reps, repsMax);

  @override
  String toString() => 'Set(${type.name}, $kg × $reps)';
}

List<StrengthSet> setsFrom(Object? data) => data is List ? data.map(StrengthSet.fromMap).toList() : <StrengthSet>[];

/// Descanso entre series cuando la rutina o la sesión no indica otro.
const defaultRestSec = 90;

int? restFrom(Object? v) => (v as num?)?.toInt();

class RoutineExercise {
  const RoutineExercise({required this.exerciseId, required this.sets, this.restSec, this.unit});

  final String exerciseId;
  final List<StrengthSet> sets;

  /// Descanso entre series en segundos (0 = sin temporizador; null = el por defecto).
  final int? restSec;

  /// Unidad de la máquina o las pesas de este ejercicio. null = no se indicó (se
  /// usa la de la última sesión o la preferida).
  final WeightUnit? unit;

  Map<String, dynamic> toMap() =>
      {'exerciseId': exerciseId, 'sets': sets.map((s) => s.toMap()).toList(), 'restSec': ?restSec, 'unit': ?unit?.name};
}

/// Plantilla reutilizable: "Rutina de pecho", "Pierna A"…
class Routine {
  const Routine({required this.id, required this.name, required this.exercises, this.updatedAt = 0});

  final String id;
  final String name;
  final List<RoutineExercise> exercises;
  final int updatedAt;
}

class WorkoutExercise {
  const WorkoutExercise({required this.exerciseId, required this.name, required this.sets, this.restSec, this.unit = WeightUnit.kg});

  final String exerciseId;

  /// Copia del nombre al guardar, por si el ejercicio se borra o se renombra.
  final String name;
  final List<StrengthSet> sets;

  /// Descanso usado (se propone la próxima vez y al actualizar la rutina).
  final int? restSec;

  /// Unidad en que se anotó (los kg de las series ya están convertidos).
  final WeightUnit unit;

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'name': name,
        'sets': sets.map((s) => s.toMap()).toList(),
        'restSec': ?restSec,
        // Solo se escribe si no es kg: los documentos de siempre no cambian.
        if (unit != WeightUnit.kg) 'unit': unit.name,
      };

  @override
  bool operator ==(Object other) =>
      other is WorkoutExercise &&
      other.exerciseId == exerciseId &&
      other.name == name &&
      other.restSec == restSec &&
      other.unit == unit &&
      _listEquals(other.sets, sets);

  @override
  int get hashCode => Object.hash(exerciseId, name, restSec, unit, Object.hashAll(sets));
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Datos de una sesión terminada, antes de guardarla.
class NewWorkout {
  const NewWorkout({
    required this.routineId,
    required this.name,
    required this.date,
    required this.startedAt,
    required this.finishedAt,
    required this.exercises,
    this.rpe,
  });

  final String? routineId;
  final String name;

  /// YYYY-MM-DD local del inicio.
  final String date;
  final int startedAt;
  final int finishedAt;
  final List<WorkoutExercise> exercises;

  /// Esfuerzo percibido de la sesión (escala CR-10 de Foster, 1–10). null = no se indicó.
  final int? rpe;

  Map<String, dynamic> toMap() => {
        'routineId': routineId,
        'name': name,
        'date': date,
        'startedAt': startedAt,
        'finishedAt': finishedAt,
        'exercises': exercises.map((e) => e.toMap()).toList(),
        'rpe': ?rpe,
      };
}

/// Sesión terminada. Solo guarda las series marcadas como hechas.
class Workout extends NewWorkout {
  const Workout({
    required this.id,
    required super.routineId,
    required super.name,
    required super.date,
    required super.startedAt,
    required super.finishedAt,
    required super.exercises,
    super.rpe,
  });

  factory Workout.fromNew(String id, NewWorkout w) => Workout(
        id: id,
        routineId: w.routineId,
        name: w.name,
        date: w.date,
        startedAt: w.startedAt,
        finishedAt: w.finishedAt,
        exercises: w.exercises,
        rpe: w.rpe,
      );

  final String id;

  Workout withRpe(int rpe) => Workout(
        id: id,
        routineId: routineId,
        name: name,
        date: date,
        startedAt: startedAt,
        finishedAt: finishedAt,
        exercises: exercises,
        rpe: rpe,
      );
}
