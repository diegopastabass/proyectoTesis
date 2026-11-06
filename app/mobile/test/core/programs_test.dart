import 'dart:convert';
import 'dart:io';

import 'package:asistente_deportivo/core/strength/models.dart';
import 'package:asistente_deportivo/core/strength/programs.dart';
import 'package:asistente_deportivo/core/strength/session.dart';
import 'package:flutter_test/flutter_test.dart';

String top(ProgramAnswers a) => recommendPrograms(a).first.program.id;

DraftSet draft(SetType type, {double? reps, double? max}) => DraftSet(key: 'k', type: type, targetReps: reps, targetRepsMax: max);

void main() {
  group('catálogo de programas', () {
    final catalog = {
      for (final e in (jsonDecode(File('assets/data/exercises.json').readAsStringSync()) as Map)['exercises'] as List) (e as Map)['id'],
    };
    final spanish = (jsonDecode(File('assets/data/exercises_es.json').readAsStringSync()) as Map).keys.toSet();

    test('todos los ejercicios existen en el catálogo y tienen nombre en español', () {
      for (final p in programs) {
        expect(p.routines.length, greaterThanOrEqualTo(2), reason: p.id);
        for (final day in p.routines) {
          for (final e in day.exercises) {
            expect(catalog, contains(e.exerciseId), reason: '${p.id}: ${e.exerciseId}');
            expect(spanish, contains(e.exerciseId), reason: '${p.id}: ${e.exerciseId}');
            expect(e.repsMax, greaterThanOrEqualTo(e.repsMin));
          }
        }
      }
      expect(programs.map((p) => p.id).toSet().length, programs.length);
    });

    test('las rutinas llevan calentamiento y el rango de repeticiones', () {
      final [a, _] = routinesFromProgram(programById('torso-pierna-4')!).take(2).toList();
      expect(a.name, 'Torso A');
      final bench = a.exercises.first.sets;
      expect(bench.map((s) => (s.type, s.reps, s.repsMax)).toList(), [
        (SetType.warmup, 8.0, null),
        for (var i = 0; i < 4; i++) (SetType.normal, 5.0, 8.0),
      ]);
    });
  });

  group('sugerencias', () {
    test('principiante con 3 días: cuerpo completo con progresión lineal', () {
      expect(top(const ProgramAnswers(days: 3, experience: Experience.beginner, goal: TrainingGoal.both)), 'cuerpo-completo-3');
    });

    test('intermedio con 4 días que busca músculo: torso/pierna', () {
      expect(top(const ProgramAnswers(days: 4, experience: Experience.intermediate, goal: TrainingGoal.hypertrophy)), 'torso-pierna-4');
    });

    test('corredor con mucho cardio: fuerza para resistencia, aunque pida más días', () {
      const a = ProgramAnswers(days: 4, experience: Experience.intermediate, goal: TrainingGoal.endurance, cardioDays: 5);
      expect(strengthDaysFor(a), 3);
      expect(top(a), 'resistencia-2');
      expect(concurrentTips(a).join(' '), allOf(contains('6 horas'), contains('fondo'), contains('3 días de fuerza')));
    });

    test('principiante que pide 6 días: se sugieren 4', () {
      const a = ProgramAnswers(days: 6, experience: Experience.beginner);
      expect((strengthDaysFor(a), top(a)), (4, 'torso-pierna-4'));
    });

    test('respeta el equipo disponible', () {
      final bodyweight = recommendPrograms(const ProgramAnswers(equipment: Equipment.bodyweight));
      expect(bodyweight.map((m) => m.program.equipment).toSet(), {Equipment.bodyweight});
      final home = recommendPrograms(const ProgramAnswers(equipment: Equipment.dumbbells));
      expect(home.first.program.id, 'mancuernas-3');
      expect(home.every((m) => m.program.equipment != Equipment.gym), isTrue);
    });

    test('nunca sugiere más días de los pedidos', () {
      for (var d = 2; d <= 6; d++) {
        for (final m in recommendPrograms(ProgramAnswers(days: d, experience: Experience.advanced), limit: 10)) {
          expect(m.program.days, lessThanOrEqualTo(d));
        }
      }
    });
  });

  group('rango de repeticiones y progresión', () {
    test('lee y escribe rangos', () {
      expect(parseRepsRange('8-12'), (min: 8.0, max: 12.0));
      expect(parseRepsRange('10'), (min: 10.0, max: null));
      expect(parseRepsRange('12-8'), (min: 12.0, max: null));
      expect((formatRepsRange(8, 12), formatRepsRange(10, null), repsRangeLabel(5, 5), repsRangeLabel(8, 12)), ('8-12', '10', '5', '8–12'));
      expect(const StrengthSet(kg: 50, reps: 8).toMap().containsKey('repsMax'), isFalse);
      expect(StrengthSet.fromMap(const StrengthSet(reps: 8, repsMax: 12).toMap()), const StrengthSet(reps: 8, repsMax: 12));
    });

    final exercise = DraftExercise(key: 'e', exerciseId: 'x', sets: [
      draft(SetType.warmup, reps: 8),
      draft(SetType.normal, reps: 8, max: 12),
      draft(SetType.normal, reps: 8, max: 12),
    ]);

    test('sube el peso solo si todas las series efectivas llegaron al tope', () {
      const warm = StrengthSet(type: SetType.warmup, kg: 20, reps: 8);
      expect(progressionKg(exercise, [warm, const StrengthSet(kg: 50, reps: 12), const StrengthSet(kg: 50, reps: 12)]), 52.5);
      expect(progressionKg(exercise, [warm, const StrengthSet(kg: 50, reps: 12), const StrengthSet(kg: 50, reps: 10)]), isNull);
      expect(progressionKg(exercise, [warm, const StrengthSet(kg: 50, reps: 12), null]), isNull);
      expect(progressionKg(exercise, [warm, const StrengthSet(kg: 50, reps: 12), const StrengthSet(kg: 50, reps: 12)], step: 5), 55);
    });

    test('con progresión sugiere el peso nuevo y el mínimo del rango', () {
      final s = exercise.sets[1];
      expect(suggestion(s, const StrengthSet(kg: 50, reps: 12), progressKg: 52.5), (kg: 52.5, reps: 8.0));
      expect(suggestion(exercise.sets[0], const StrengthSet(kg: 20, reps: 8), progressKg: 52.5), (kg: 20.0, reps: 8.0));
      final done = toggleDone(s, const StrengthSet(kg: 50, reps: 12), progressKg: 52.5)!;
      expect((done.kg, done.reps), ('52,5', '8'));
    });

    test('el paso depende del ejercicio', () {
      expect(progressionStep(const Exercise(id: 's', name: 's', equipment: 'barbell', primary: ['quadriceps'])), 5);
      expect(progressionStep(const Exercise(id: 'b', name: 'b', equipment: 'barbell', primary: ['chest'])), 2.5);
      expect(progressionStep(const Exercise(id: 'd', name: 'd', equipment: 'dumbbell', primary: ['shoulders'])), 2);
    });

    test('el rango viaja de la rutina a la sesión y se conserva al actualizar la rutina', () {
      const routine = Routine(id: 'r', name: 'Torso A', exercises: [
        RoutineExercise(exerciseId: 'x', sets: [StrengthSet(type: SetType.warmup, reps: 8), StrengthSet(reps: 8, repsMax: 12)]),
      ]);
      final active = workoutFromRoutine(routine, 0);
      expect(active.exercises.first.sets.map((s) => s.targetRepsMax), [null, 12]);
      expect(DraftSet.fromJson(active.exercises.first.sets[1].toJson()).targetRepsMax, 12);
      const done = Workout(id: 'w', routineId: 'r', name: 'Torso A', date: '2026-10-28', startedAt: 0, finishedAt: 0, exercises: [
        WorkoutExercise(exerciseId: 'x', name: 'x', sets: [StrengthSet(type: SetType.warmup, kg: 20, reps: 8), StrengthSet(kg: 55, reps: 11)]),
      ]);
      expect(routineExercisesFrom(done, routine).first.sets, const [
        StrengthSet(type: SetType.warmup, kg: 20, reps: 8),
        StrengthSet(kg: 55, reps: 8, repsMax: 12),
      ]);
    });
  });
}
