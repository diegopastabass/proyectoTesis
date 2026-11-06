import 'package:asistente_deportivo/core/body/progress.dart';
import 'package:asistente_deportivo/core/strength/calendar.dart';
import 'package:asistente_deportivo/core/strength/catalog.dart';
import 'package:asistente_deportivo/core/strength/insights.dart';
import 'package:asistente_deportivo/core/strength/models.dart';
import 'package:asistente_deportivo/core/strength/session.dart';
import 'package:asistente_deportivo/core/strength/stats.dart';
import 'package:flutter_test/flutter_test.dart';

StrengthSet s(double? kg, double reps, [SetType type = SetType.normal]) => StrengthSet(type: type, kg: kg, reps: reps);

var _n = 0;

Workout workout(String date, Map<String, List<StrengthSet>> exercises, {String? routineId = 'pecho', String name = 'Rutina de pecho'}) {
  final startedAt = DateTime.parse('${date}T18:00:00').millisecondsSinceEpoch;
  return Workout(
    id: 'w${++_n}',
    routineId: routineId,
    name: name,
    date: date,
    startedAt: startedAt,
    finishedAt: startedAt + 60 * 60000,
    exercises: [for (final e in exercises.entries) WorkoutExercise(exerciseId: e.key, name: e.key, sets: e.value)],
  );
}

void main() {
  group('volumen y totales', () {
    test('suma kg × reps de las series efectivas, sin calentamiento', () {
      final w = workout('2026-10-20', {
        'banca': [s(30, 6, SetType.warmup), s(55, 5), s(55, 5, SetType.failure)],
        'fondos': [s(null, 12)],
      });
      expect(workoutVolume(w), 550);
      final t = workoutTotals(w);
      expect((t.volume, t.sets, t.reps, t.exercises, t.durationMin), (550, 3, 22, 2, 60));
    });

    test('estima el 1RM con Epley', () {
      expect(estimate1RM(100, 1), 100);
      expect(estimate1RM(100, 10), closeTo(133.33, 0.05));
      expect(estimate1RM(0, 10), 0);
    });
  });

  group('sesión anterior', () {
    final ws = [
      workout('2026-10-13', {'banca': [s(30, 6, SetType.warmup), s(52.5, 6), s(55, 5)]}),
      workout('2026-10-06', {'banca': [s(50, 6)]}),
    ];

    test('toma la sesión más reciente con el ejercicio', () {
      expect(lastSetsFor(ws, 'banca'), hasLength(3));
      expect(lastSetsFor(ws, 'banca', before: ws[0].startedAt), [s(50, 6)]);
      expect(lastSetsFor(ws, 'sentadilla'), isNull);
    });

    test('empareja calentamiento con calentamiento y efectivas con efectivas', () {
      final prev = lastSetsFor(ws, 'banca');
      const types = [SetType.warmup, SetType.normal, SetType.normal, SetType.failure];
      expect(matchPrevious(prev, types, 0), s(30, 6, SetType.warmup));
      expect(matchPrevious(prev, types, 1), s(52.5, 6));
      expect(matchPrevious(prev, types, 2), s(55, 5));
      expect(matchPrevious(prev, types, 3), isNull);
    });

    test('resume la historia de un ejercicio en orden', () {
      final h = exerciseHistory(ws, 'banca');
      expect(h.map((x) => x.maxKg), [50, 55]);
      expect((h[1].repsAtMax, h[1].sets, h[1].volume), (5, 2, 590));
    });
  });

  group('sesión en curso', () {
    const routine = Routine(id: 'pecho', name: 'Rutina de pecho', exercises: [
      RoutineExercise(exerciseId: 'banca', sets: [StrengthSet(kg: 60, reps: 8), StrengthSet(kg: 60, reps: 8)]),
    ]);

    test('parte desde la rutina con sus valores como sugerencia', () {
      final w = workoutFromRoutine(routine, 1000);
      final first = w.exercises[0].sets[0];
      expect(w.exercises[0].sets, hasLength(2));
      expect((first.kg, first.reps, first.targetKg, first.targetReps, first.done), ('', '', 60, 8, false));
    });

    test('al marcar una serie vacía usa la sesión anterior o la rutina; sin repeticiones no se marca', () {
      const empty = DraftSet(key: 'a');
      final a = toggleDone(empty, s(52.5, 6))!;
      expect((a.kg, a.reps, a.done), ('52,5', '6', true));
      expect(toggleDone(empty, null), isNull);
      final b = toggleDone(empty.copyWith(reps: '10'), null)!;
      expect((b.kg, b.reps, b.done), ('', '10', true));
      const fromRoutine = DraftSet(key: 'a', targetKg: 50, targetReps: 8);
      final c = toggleDone(fromRoutine, null)!;
      expect((c.kg, c.reps), ('50', '8'));
      final d = toggleDone(fromRoutine, s(55, 6))!;
      expect((d.kg, d.reps), ('55', '6'));
    });

    test('al terminar guarda solo series hechas y omite ejercicios vacíos', () {
      final w = workoutFromRoutine(routine, DateTime.parse('2026-10-20T18:00:00').millisecondsSinceEpoch);
      final sets = [...w.exercises[0].sets];
      sets[0] = sets[0].copyWith(kg: '62,5', reps: '8', done: true);
      final edited = w.copyWith(exercises: [
        w.exercises[0].withSets(sets),
        const DraftExercise(key: 'x', exerciseId: 'fondos', sets: []),
      ]);
      final saved = finishWorkout(edited, edited.startedAt + 1000, (id) => id.toUpperCase());
      expect(saved.date, '2026-10-20');
      expect(saved.exercises, [WorkoutExercise(exerciseId: 'banca', name: 'BANCA', sets: [s(62.5, 8)], restSec: defaultRestSec)]);
      expect(finishWorkout(emptyWorkout(0), 1, (id) => id).exercises, isEmpty);
    });

    test('se serializa para sobrevivir a un cierre de la app', () {
      final w = workoutFromRoutine(routine, 1000);
      final back = ActiveWorkout.fromJson(w.toJson());
      expect((back.routineId, back.name, back.startedAt, back.exercises.first.sets.first.targetKg), ('pecho', 'Rutina de pecho', 1000, 60));
    });
  });

  group('drop sets y descansos', () {
    DraftSet d(SetType type, {String kg = '', double? targetKg, double? targetReps}) =>
        DraftSet(key: newKey(), type: type, kg: kg, targetKg: targetKg, targetReps: targetReps);

    test('el drop va después de la serie y de sus drops, con ~20 % menos peso', () {
      final sets = [d(SetType.normal, kg: '60'), d(SetType.normal, targetKg: 60)];
      final one = insertDrop(sets, 0);
      expect(one.map((s) => s.type), [SetType.normal, SetType.drop, SetType.normal]);
      expect(one[1].targetKg, 47.5);
      final two = insertDrop(one, 0);
      expect(two.map((s) => s.type), [SetType.normal, SetType.drop, SetType.drop, SetType.normal]);
      expect(two[2].targetKg, 37.5);
      // Sin peso escrito ni de rutina, usa la sugerencia que se entrega.
      expect(insertDrop([d(SetType.normal)], 0, fromKg: 10)[1].targetKg, 8);
      expect(dropKg(null), isNull);
    });

    test('una serie nueva tras un drop es normal y copia la sugerencia de la serie principal', () {
      final sets = appendSet([d(SetType.failure, targetKg: 50, targetReps: 8), d(SetType.drop, targetKg: 40)]);
      expect((sets.last.type, sets.last.targetKg, sets.last.targetReps), (SetType.normal, 50, 8));
    });

    test('no hay descanso antes de un drop ni en ejercicios sin temporizador', () {
      final e = DraftExercise(key: 'e', exerciseId: 'banca', sets: [d(SetType.normal), d(SetType.drop), d(SetType.normal)], restSec: 120);
      expect([for (var i = 0; i < 3; i++) restAfter(e, i)], [null, 120, 120]);
      expect(restAfter(e.withRest(0), 2), isNull);
    });

    test('se ajusta el descanso en curso y termina si se resta todo', () {
      const rest = RestTimer(endsAt: 100000, seconds: 90);
      final more = adjustRest(rest, 15, 50000)!;
      expect((more.endsAt, more.seconds, more.remaining(50000)), (115000, 105, 65));
      expect(adjustRest(rest, -60, 50000), isNull);
    });

    test('los drops se emparejan con drops, no suman series y sí volumen', () {
      final prev = [s(60, 8), s(45, 6, SetType.drop), s(60, 7)];
      const types = [SetType.normal, SetType.drop, SetType.normal];
      expect([for (var i = 0; i < 3; i++) matchPrevious(prev, types, i)], prev);
      final totals = workoutTotals(workout('2026-10-20', {'banca': prev}));
      expect((totals.sets, totals.volume), (2, 60 * 8 + 45 * 6 + 60 * 7));
    });

    test('el descanso se guarda en la sesión, la rutina y al cerrar la app', () {
      const routine = Routine(id: 'r', name: 'R', exercises: [
        RoutineExercise(exerciseId: 'banca', sets: [StrengthSet(kg: 60, reps: 8)], restSec: 150),
        RoutineExercise(exerciseId: 'fondos', sets: [StrengthSet(reps: 10)]),
      ]);
      final w = workoutFromRoutine(routine, 1000).withRest(const RestTimer(endsAt: 5000, seconds: 150));
      expect(w.exercises.map((e) => e.restSec), [150, defaultRestSec]);
      final back = ActiveWorkout.fromJson(w.toJson());
      expect((back.exercises.first.restSec, back.rest?.endsAt, back.rest?.seconds), (150, 5000, 150));
      expect(ActiveWorkout.fromJson(w.withRest(null).toJson()).rest, isNull);

      final done = w.copyWith(exercises: [
        w.exercises.first.withSets([w.exercises.first.sets.first.copyWith(reps: '8', done: true)]),
      ]);
      final saved = Workout.fromNew('x', finishWorkout(done, 2000, (id) => id));
      expect(saved.exercises.single.restSec, 150);
      expect(routineExercisesFrom(saved, routine).single.restSec, 150);
      expect(restForNewExercise('banca', [saved]), 150);
      expect(restForNewExercise('remo', [saved]), defaultRestSec);
    });
  });

  group('calendario', () {
    test('las semanas parten el lunes', () {
      expect(weekStart('2026-10-22'), '2026-10-19');
      expect(weekStart('2026-10-25'), '2026-10-19');
      expect(weekStart('2026-10-19'), '2026-10-19');
    });

    test('arma columnas de 7 días que terminan en la semana actual', () {
      final grid = heatmapWeeks(countByDate(['2026-10-20', '2026-10-20', '2026-10-13']), '2026-10-22', 2);
      expect(grid, hasLength(2));
      expect(grid[0][0].date, '2026-10-12');
      expect(grid[1][1], const HeatDay(date: '2026-10-20', count: 2, future: false));
      expect((grid[1][6].date, grid[1][6].future), ('2026-10-25', true));
    });

    test('cuenta semanas seguidas sin cortar la racha si la semana actual aún no tiene entrenamiento', () {
      expect(weeklyStreak(['2026-10-06', '2026-10-13', '2026-10-21'], '2026-10-22'), 3);
      expect(weeklyStreak(['2026-10-06', '2026-10-13'], '2026-10-22'), 2);
      expect(weeklyStreak(['2026-09-01', '2026-10-13'], '2026-10-22'), 1);
      expect(weeklyStreak([], '2026-10-22'), 0);
    });
  });

  group('mensajes de motivación', () {
    test('celebra el primer entrenamiento', () {
      final w = workout('2026-10-20', {'banca': [s(50, 5)]});
      expect(workoutInsights(w, [w]).first.kind, InsightKind.first);
    });

    test('detecta récord, más series, más repeticiones y más volumen', () {
      final prev = workout('2026-10-13', {
        'banca': [s(52.5, 6)],
        'remo': [s(40, 10)],
        'curl': [s(12, 8)],
        'fondos': [s(null, 10)],
      });
      final cur = workout('2026-10-20', {
        'banca': [s(55, 5)],
        'remo': [s(40, 10), s(40, 10)],
        'curl': [s(12, 10)],
        'fondos': [s(null, 12)],
        'sentadilla': [s(80, 5)],
      });
      final texts = workoutInsights(cur, [prev, cur], limit: 20).map((i) => i.text).toList();
      expect(texts, contains('Nuevo récord en banca: 55 kg × 5.'));
      expect(texts, contains('Hoy hiciste 1 serie más de remo que la última vez (la semana pasada).'));
      expect(texts, contains('Más repeticiones en curl con 12 kg: 10 (antes 8).'));
      expect(texts, contains('Más repeticiones en fondos: 12 (antes 10).'));
      expect(texts, contains('Primera vez registrando sentadilla.'));
      expect(texts.any((t) => t.startsWith('Volumen total') && t.contains('Rutina de pecho')), isTrue);
      expect(texts, contains('Llevas 2 semanas seguidas entrenando.'));
    });

    test('compara solo con sesiones anteriores', () {
      final old = workout('2026-10-06', {'banca': [s(50, 5)]});
      final mid = workout('2026-10-13', {'banca': [s(60, 5)]});
      final later = workout('2026-10-20', {'banca': [s(70, 5)]});
      expect(workoutInsights(mid, [old, mid, later]).map((i) => i.text), contains('Nuevo récord en banca: 60 kg × 5.'));
    });

    test('describe cuánto pasó desde la última vez', () {
      expect(sinceText('2026-10-21', '2026-10-22'), 'ayer');
      expect(sinceText('2026-10-15', '2026-10-22'), 'la semana pasada');
      expect(sinceText('2026-10-10', '2026-10-22'), 'hace 12 días');
    });
  });

  group('catálogo', () {
    final list = buildExercises([
      {'id': 'Barbell_Squat', 'name': 'Barbell Squat', 'category': 'strength', 'equipment': 'barbell', 'primary': ['quadriceps'], 'secondary': [], 'images': 2},
      {'id': 'Barbell_Curl', 'name': 'Barbell Curl', 'category': 'strength', 'equipment': 'barbell', 'primary': ['biceps'], 'secondary': [], 'images': 2},
      {'id': 'Zercher_Squats', 'name': 'Zercher Squats', 'category': 'strength', 'equipment': 'barbell', 'primary': ['quadriceps'], 'secondary': [], 'images': 2},
    ], {
      'Barbell_Squat': {'name': 'Sentadilla con barra', 'aliases': ['squat']},
      'Barbell_Curl': {'name': 'Curl de bíceps con barra'},
    });
    final index = ExerciseIndex(list);

    test('encuentra por nombre en español, en inglés y con errores de tipeo', () {
      expect(index.search(query: 'sentadila').first.id, 'Barbell_Squat');
      expect(index.search(query: 'zercher').first.id, 'Zercher_Squats');
      expect(index.search(query: 'biceps').first.id, 'Barbell_Curl');
    });

    test('filtra por grupo muscular y muestra primero los traducidos', () {
      expect(index.search(group: 'piernas').map((e) => e.id), ['Barbell_Squat', 'Zercher_Squats']);
    });
  });

  group('progreso corporal', () {
    const entries = [WeightEntry(date: '2026-09-01', kg: 85), WeightEntry(date: '2026-09-15', kg: 84), WeightEntry(date: '2026-10-01', kg: 82)];
    const lose = BodyGoal(type: GoalType.lose, targetKg: 78, startDate: '2026-09-01');

    test('calcula la pendiente por mínimos cuadrados', () {
      expect(trendPerDay(const [WeightEntry(date: '2026-01-01', kg: 80), WeightEntry(date: '2026-01-08', kg: 79.3)]), closeTo(-0.1, 1e-5));
      expect(trendPerDay(const [WeightEntry(date: '2026-01-01', kg: 80)]), isNull);
    });

    test('mide cambio, faltante y porcentaje hacia la meta', () {
      final st = progressStats(entries, lose);
      expect((st.start?.kg, st.current?.kg, st.change, st.remaining, st.percent), (85, 82, -3, -4, 43));
    });

    test('estima ritmo semanal y fecha de llegada si va en la dirección correcta', () {
      final st = progressStats(entries, lose);
      expect(st.ratePerWeek, lessThan(0));
      expect(st.eta, isNotNull);
      expect(st.eta!.compareTo('2026-10-01'), greaterThan(0));
    });

    test('no estima llegada si la tendencia va en contra de la meta', () {
      final st = progressStats(entries, const BodyGoal(type: GoalType.gain, targetKg: 90, startDate: '2026-09-01'));
      expect(st.percent, 0);
      expect(st.eta, isNull);
    });

    test('usa el primer registro desde la fecha de inicio de la meta', () {
      expect(progressStats(entries, const BodyGoal(type: GoalType.lose, targetKg: 78, startDate: '2026-09-10')).start?.kg, 84);
    });

    test('para mantener no calcula porcentaje', () {
      expect(progressStats(entries, const BodyGoal(type: GoalType.maintain, targetKg: 82, startDate: '2026-09-01')).percent, isNull);
    });

    test('funciona sin registros', () {
      final st = progressStats(const [], lose);
      expect((st.start, st.current, st.change, st.eta), (null, null, null, null));
    });
  });
}
