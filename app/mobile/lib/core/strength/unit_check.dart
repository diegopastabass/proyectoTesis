/// Detecta ejercicios que se anotaron con la unidad equivocada (kg en una máquina
/// que está en libras, o al revés), para sugerir el cambio al terminar la sesión.
///
/// La señal es la razón entre lo que se anotó y lo que se hizo antes en el mismo
/// ejercicio (la última sesión o, si no hay, la rutina). Una libra es 0,4536 kg:
/// quien escribe en libras un peso que antes anotó en kg pone un número ~2,2 veces
/// mayor. Un salto así no es una progresión real de una semana a otra, y una
/// caída a menos de la mitad tampoco es habitual sin una razón (lesión, descarga),
/// por eso se pregunta y nunca se cambia solo.
library;

import 'dart:math' as math;

import '../common/units.dart';
import 'models.dart';
import 'session.dart';
import 'stats.dart';

/// Margen alrededor de la razón esperada (±20 %): cubre una progresión o una
/// bajada normal además del cambio de unidad.
const unitRatioTolerance = 0.2;

class UnitSuspicion {
  const UnitSuspicion({
    required this.exerciseKey,
    required this.exerciseId,
    required this.entered,
    required this.typical,
    required this.referenceKg,
  });

  /// [DraftExercise.key] del ejercicio en la sesión.
  final String exerciseKey;
  final String exerciseId;

  /// Unidad con la que se anotó.
  final WeightUnit entered;

  /// Número típico que se escribió (mediana de las series con peso).
  final double typical;

  /// Peso típico de antes, en kg.
  final double referenceKg;

  /// Unidad que probablemente tenía la máquina.
  WeightUnit get likely => entered.other;

  /// Lo que se guardaría si la máquina estaba en [likely] (en kg).
  double get correctedKg => toKg(typical, likely);
}

double? _median(Iterable<double> values) {
  final list = values.where((v) => v > 0).toList()..sort();
  if (list.isEmpty) return null;
  final mid = list.length ~/ 2;
  return list.length.isOdd ? list[mid] : (list[mid - 1] + list[mid]) / 2;
}

/// Revisa un ejercicio: null si lo anotado calza con su unidad o no hay con qué comparar.
UnitSuspicion? checkExerciseUnit(DraftExercise e, List<StrengthSet>? previous) {
  final typed = _median([
    for (final s in e.sets)
      if (s.done && s.type != SetType.warmup) parseAmount(s.kg) ?? 0,
  ]);
  if (typed == null) return null;
  final reference = _median([for (final s in previous ?? const <StrengthSet>[]) if (isEffective(s)) s.kg ?? 0]) ??
      _median([for (final s in e.sets) if (s.type != SetType.warmup) s.targetKg ?? 0]);
  if (reference == null) return null;

  final ratio = typed / fromKg(reference, e.unit);
  // Si la máquina estaba en la otra unidad, el número escrito sería este múltiplo del de antes.
  final expected = fromKg(1, e.unit.other) / fromKg(1, e.unit);
  final fitsOther = (ratio / expected - 1).abs() <= unitRatioTolerance;
  final fitsSame = (ratio - 1).abs() <= math.max(unitRatioTolerance, 0.3);
  if (!fitsOther || fitsSame) return null;
  return UnitSuspicion(exerciseKey: e.key, exerciseId: e.exerciseId, entered: e.unit, typical: typed, referenceKg: reference);
}

/// Ejercicios de la sesión que parecen anotados en la unidad equivocada.
List<UnitSuspicion> suspectUnits(ActiveWorkout w, List<Workout> history) => [
      for (final e in w.exercises)
        ?checkExerciseUnit(e, lastSetsFor(history, e.exerciseId, before: w.startedAt)),
    ];

/// Aplica las correcciones elegidas: la unidad cambia y los números escritos se
/// mantienen (eran los de la máquina).
ActiveWorkout applyUnitFixes(ActiveWorkout w, Iterable<UnitSuspicion> fixes) {
  final byKey = {for (final f in fixes) f.exerciseKey: f.likely};
  return w.copyWith(exercises: [
    for (final e in w.exercises) byKey[e.key] == null ? e : switchUnit(e, byKey[e.key]!, convert: false),
  ]);
}
