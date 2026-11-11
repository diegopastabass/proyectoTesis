import 'package:asistente_deportivo/core/common/units.dart';
import 'package:asistente_deportivo/core/nutrition/rule_parser.dart';
import 'package:asistente_deportivo/core/nutrition/units.dart';
import 'package:asistente_deportivo/core/strength/models.dart';
import 'package:asistente_deportivo/core/strength/session.dart';
import 'package:asistente_deportivo/core/strength/stats.dart';
import 'package:asistente_deportivo/core/strength/unit_check.dart';
import 'package:asistente_deportivo/core/strength/weights.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.parse('2026-11-02T18:00:00').millisecondsSinceEpoch;

Workout _workout(int dayOffset, List<StrengthSet> sets, {WeightUnit unit = WeightUnit.kg, String id = 'prensa'}) {
  final at = _t0 + dayOffset * 86400000;
  return Workout(
    id: 'w$dayOffset',
    routineId: null,
    name: 'Pierna',
    date: '2026-11-0${2 + dayOffset}',
    startedAt: at,
    finishedAt: at + 3600000,
    exercises: [WorkoutExercise(exerciseId: id, name: id, sets: sets, unit: unit)],
  );
}

DraftExercise _draft(List<String> kgs, {WeightUnit unit = WeightUnit.kg, String id = 'prensa', double? targetKg}) => DraftExercise(
      key: 'e-$id',
      exerciseId: id,
      unit: unit,
      sets: [for (final (i, kg) in kgs.indexed) DraftSet(key: '$i', kg: kg, reps: '10', done: true, targetKg: targetKg)],
    );

void main() {
  group('conversiones', () {
    test('kg ↔ lb son exactas de ida y vuelta', () {
      expect(toKg(45, WeightUnit.lb), closeTo(20.4117, 1e-4));
      expect(fromKg(toKg(45, WeightUnit.lb), WeightUnit.lb), closeTo(45, 1e-9));
      expect(displayWeight(toKg(135, WeightUnit.lb), WeightUnit.lb), 135);
      expect(displayWeight(100, WeightUnit.lb), 220.5);
      expect(convertWeight(220.5, WeightUnit.lb, WeightUnit.kg), closeTo(100.02, 0.01));
      expect(WeightUnit.from(null), WeightUnit.kg);
      expect(WeightUnit.from('lb'), WeightUnit.lb);
      expect(WeightUnit.tryParse('stone'), isNull);
    });

    test('distancia, ritmo, velocidad, estatura, energía y volumen', () {
      expect(metersTo(10000, DistanceUnit.mi), closeTo(6.2137, 1e-4));
      expect(toMeters(1, DistanceUnit.mi), 1609.344);
      expect(paceSecPerKmToMile(300), closeTo(482.8, 0.1)); // 5:00 /km ≈ 8:03 /mi
      expect(paceSecPerMileToKm(paceSecPerKmToMile(300)), closeTo(300, 1e-9));
      expect(kmhToMph(100), closeTo(62.137, 1e-3));
      expect(mphToKmh(kmhToMph(42)), closeTo(42, 1e-9));
      expect(kmhToPaceSecPerKm(12), 300);
      expect(kmhToPaceSecPerKm(0), isNull);
      expect(cmToFeetInches(175), (feet: 5, inches: 9));
      expect(feetInchesToCm(5, 9), closeTo(175.26, 1e-9));
      expect(metersToFeet(1000), closeTo(3280.84, 0.01));
      expect(kcalToKj(100), closeTo(418.4, 1e-9));
      expect(kjToKcal(418.4), closeTo(100, 1e-9));
      expect(ozToG(1), closeTo(28.3495, 1e-4));
      expect(flOzToMl(12), closeTo(354.88, 0.01)); // una lata de EE. UU.
    });

    test('la lista de comidas entiende onzas y libras', () {
      final oz = parseLine('8 oz de pechuga de pollo')!;
      expect(oz.unit, Unit.g);
      expect(oz.quantity, closeTo(226.8, 0.1));
      final lb = parseLine('1 lb carne molida')!;
      expect(lb.quantity, closeTo(453.6, 0.1));
    });
  });

  group('pesos según la unidad', () {
    test('drop sets e incrementos usan los saltos de cada unidad', () {
      expect(dropWeight(100, WeightUnit.kg), 80);
      expect(dropWeight(135, WeightUnit.lb), 110); // 108 → al múltiplo de 5 lb
      expect(dropWeight(15, WeightUnit.lb), 12);
      expect(dropKg(60), 47.5);
      expect(progressionStepIn(const Exercise(id: 's', name: 's', equipment: 'barbell', primary: ['quadriceps']), WeightUnit.lb), 10);
      expect(progressionStepIn(const Exercise(id: 'd', name: 'd', equipment: 'dumbbell'), WeightUnit.lb), 5);
      expect(progressionStepIn(null, WeightUnit.kg), 2.5);
    });

    test('calculadora de discos', () {
      final kg = platesFor(100, WeightUnit.kg);
      expect(kg.perSide, [25, 15]);
      expect(kg.exact, isTrue);
      expect(platesLabel(kg.perSide), '1 × 25 + 1 × 15');
      final lb = platesFor(225, WeightUnit.lb);
      expect(lb.perSide, [45, 45]);
      expect(platesFor(62.5, WeightUnit.kg).perSide, [20, 1.25]);
      expect(platesFor(61.25, WeightUnit.kg).missing, 1.25);
      final odd = platesFor(101, WeightUnit.kg);
      expect(odd.exact, isFalse);
      expect(odd.missing, 1);
      expect(platesFor(20, WeightUnit.kg).perSide, isEmpty);
      expect(platesLabel(const []), 'Solo la barra');
      expect(platesFor(60, WeightUnit.kg, bar: 15).perSide, [20, 2.5]);
    });
  });

  group('sesión en libras', () {
    test('se guarda en kg con la unidad anotada', () {
      final active = ActiveWorkout(name: 'Pierna', startedAt: _t0, exercises: [_draft(['100', '110'], unit: WeightUnit.lb)]);
      final saved = finishWorkout(active, _t0 + 1000, (id) => id);
      final e = saved.exercises.single;
      expect(e.unit, WeightUnit.lb);
      expect(e.sets.first.kg, closeTo(45.36, 0.01));
      expect(e.toMap()['unit'], 'lb');
      expect(activeVolume(active), closeTo((100 + 110) * kgPerLb * 10, 1e-6));
      // En kg no se escribe el campo: los documentos de siempre no cambian.
      expect(const WorkoutExercise(exerciseId: 'x', name: 'x', sets: []).toMap().containsKey('unit'), isFalse);
    });

    test('la sesión anterior y la rutina deciden la unidad', () {
      final history = [_workout(0, [StrengthSet(kg: toKg(100, WeightUnit.lb), reps: 10)], unit: WeightUnit.lb)];
      expect(lastUnitFor(history, 'prensa'), WeightUnit.lb);
      expect(unitForExercise('otro', history, fallback: WeightUnit.kg), WeightUnit.kg);
      const routine = Routine(id: 'r', name: 'Pierna', exercises: [
        RoutineExercise(exerciseId: 'prensa', sets: [StrengthSet(reps: 10)]),
        RoutineExercise(exerciseId: 'banca', sets: [StrengthSet(reps: 10)], unit: WeightUnit.kg),
      ]);
      final w = workoutFromRoutine(routine, _t0 + 86400000, unitFor: (id) => unitForExercise(id, history));
      expect(w.exercises.map((e) => e.unit), [WeightUnit.lb, WeightUnit.kg]);
      // Sobrevive a cerrar la app.
      expect(ActiveWorkout.fromJson(w.toJson()).exercises.first.unit, WeightUnit.lb);
    });

    test('sugerencias, progresión y drops en la unidad de la máquina', () {
      final prev = StrengthSet(kg: toKg(45, WeightUnit.lb), reps: 12);
      final e = DraftExercise(key: 'e', exerciseId: 'x', unit: WeightUnit.lb, sets: const [DraftSet(key: 'a', targetRepsMax: 12, targetReps: 8)]);
      final progress = progressionKg(e, [prev], step: 5)!;
      expect(displayWeight(progress, WeightUnit.lb), 50);
      final done = toggleDone(e.sets.first, prev, progressKg: progress, unit: WeightUnit.lb)!;
      expect(done.kg, '50');
      final withDrop = insertDrop([const DraftSet(key: 'a', kg: '100')], 0, unit: WeightUnit.lb);
      expect(displayWeight(withDrop[1].targetKg!, WeightUnit.lb), 80);
    });

    test('cambiar de unidad mantiene o convierte los números', () {
      final e = _draft(['100']);
      expect(switchUnit(e, WeightUnit.lb, convert: false).sets.first.kg, '100');
      expect(switchUnit(e, WeightUnit.lb, convert: true).sets.first.kg, '220,5');
      expect(switchUnit(e, WeightUnit.lb, convert: true).unit, WeightUnit.lb);
      expect(identical(switchUnit(e, WeightUnit.kg, convert: true), e), isTrue);
    });

    test('routineExercisesFrom guarda la unidad en la rutina', () {
      final w = _workout(0, [StrengthSet(kg: toKg(90, WeightUnit.lb), reps: 10)], unit: WeightUnit.lb);
      expect(routineExercisesFrom(w).single.unit, WeightUnit.lb);
      expect(routineExercisesFrom(w).single.toMap()['unit'], 'lb');
    });
  });

  group('detección de unidad equivocada', () {
    final history = [_workout(0, [const StrengthSet(kg: 45, reps: 10), const StrengthSet(kg: 45, reps: 10)])];

    test('números de libras anotados en kg', () {
      final w = ActiveWorkout(name: 'Pierna', startedAt: _t0 + 86400000, exercises: [_draft(['100', '100'])]);
      final found = suspectUnits(w, history);
      expect(found, hasLength(1));
      expect(found.single.likely, WeightUnit.lb);
      expect(found.single.typical, 100);
      expect(found.single.correctedKg, closeTo(45.36, 0.01));
      final fixed = applyUnitFixes(w, found);
      expect(fixed.exercises.single.unit, WeightUnit.lb);
      expect(fixed.exercises.single.sets.first.kg, '100');
    });

    test('números de kg anotados en libras', () {
      final w = ActiveWorkout(name: 'Pierna', startedAt: _t0 + 86400000, exercises: [_draft(['47,5'], unit: WeightUnit.lb)]);
      expect(suspectUnits(w, history).single.likely, WeightUnit.kg);
    });

    test('una progresión normal, el calentamiento o la falta de referencia no avisan', () {
      final normal = ActiveWorkout(name: 'P', startedAt: _t0 + 86400000, exercises: [_draft(['50', '52,5'])]);
      expect(suspectUnits(normal, history), isEmpty);
      final bigJump = ActiveWorkout(name: 'P', startedAt: _t0 + 86400000, exercises: [_draft(['70'])]);
      expect(suspectUnits(bigJump, history), isEmpty, reason: '×1,55 no calza con ninguna unidad');
      final fresh = ActiveWorkout(name: 'P', startedAt: _t0 + 86400000, exercises: [_draft(['100'], id: 'nuevo')]);
      expect(suspectUnits(fresh, history), isEmpty);
      final warmupOnly = ActiveWorkout(name: 'P', startedAt: _t0 + 86400000, exercises: [
        const DraftExercise(key: 'w', exerciseId: 'prensa', sets: [DraftSet(key: 'a', type: SetType.warmup, kg: '100', reps: '10', done: true)]),
      ]);
      expect(suspectUnits(warmupOnly, history), isEmpty);
    });

    test('sin historial compara con la rutina', () {
      final w = ActiveWorkout(name: 'P', startedAt: _t0, exercises: [_draft(['132'], id: 'nuevo', targetKg: 60)]);
      expect(suspectUnits(w, const []).single.likely, WeightUnit.lb);
    });
  });
}
