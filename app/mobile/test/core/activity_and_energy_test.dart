import 'package:asistente_deportivo/core/activity/calendar.dart';
import 'package:asistente_deportivo/core/activity/streak.dart';
import 'package:asistente_deportivo/core/body/energy.dart';
import 'package:asistente_deportivo/core/body/progress.dart';
import 'package:asistente_deportivo/core/common/date.dart';
import 'package:asistente_deportivo/core/nutrition/copy.dart';
import 'package:asistente_deportivo/core/nutrition/models.dart';
import 'package:asistente_deportivo/core/nutrition/score.dart';
import 'package:asistente_deportivo/core/strength/models.dart';
import 'package:flutter_test/flutter_test.dart';

const today = '2026-10-28'; // miércoles

/// Días seguidos de `from` a `to` (inclusive).
List<String> range(String from, String to) => [for (var d = from; d.compareTo(to) <= 0; d = addDays(d, 1)) d];

DiaryEntry entry(String refId, double grams, MealSlot meal, {EntryKind kind = EntryKind.food, double? servings, Macros macros = const Macros(kcal: 1)}) =>
    DiaryEntry(id: 'e-$refId-${meal.name}', createdAt: 0, kind: kind, refId: refId, name: 'Guardado', grams: grams, servings: servings, macros: macros, meal: meal, rawInput: 'texto');

/// Conjunto como texto ordenado: los registros (records) comparan los conjuntos por identidad.
String sorted(Iterable<Object> items) => (items.map((e) => e is Enum ? e.name : '$e').toList()..sort()).join(',');

Workout workoutOn(String date, {String? finishedOn}) {
  final start = DateTime.parse('${date}T18:00:00').millisecondsSinceEpoch;
  return Workout(
    id: 'w-$date',
    routineId: null,
    name: 'Libre',
    date: date,
    startedAt: start,
    finishedAt: finishedOn == null ? start + 3600000 : DateTime.parse('${finishedOn}T19:00:00').millisecondsSinceEpoch,
    exercises: const [],
  );
}

void main() {
  group('copiar comidas', () {
    const arroz = Food(id: 'arroz', name: 'Arroz cocido', per100g: Macros(kcal: 200, protein: 10), createdBy: 'u');
    const guiso = Recipe(
      id: 'guiso',
      ownerId: 'u',
      name: 'Guiso',
      servings: 2,
      ingredients: [],
      totalGrams: 600,
      totals: Macros(kcal: 1000, protein: 60),
      perServing: Macros(kcal: 500, protein: 30),
    );

    test('recalcula los macros con el catálogo actual y conserva cantidad y comida', () {
      final [copy] = copyEntries([entry('arroz', 150, MealSlot.almuerzo)], foods: {'arroz': arroz}, recipes: const {});
      expect((copy.name, copy.grams, copy.meal, copy.macros.kcal, copy.macros.protein, copy.rawInput), ('Arroz cocido', 150, MealSlot.almuerzo, 300, 15, null));
    });

    test('si el alimento ya no existe usa los macros guardados', () {
      final [copy] = copyEntries([entry('borrado', 80, MealSlot.cena, macros: const Macros(kcal: 99))], foods: const {}, recipes: const {});
      expect((copy.name, copy.macros.kcal), ('Guardado', 99));
    });

    test('las recetas se copian por porciones', () {
      final [copy] = copyEntries([entry('guiso', 0, MealSlot.almuerzo, kind: EntryKind.recipe, servings: 1.5)], foods: const {}, recipes: {'guiso': guiso});
      expect((copy.grams, copy.servings, copy.macros.kcal), (450, 1.5, 750));
    });

    test('propone solo las comidas que el día destino aún no tiene', () {
      final yesterday = [entry('a', 1, MealSlot.desayuno), entry('b', 1, MealSlot.almuerzo), entry('c', 1, MealSlot.cena)];
      expect(mealsToRepeat(yesterday, [entry('d', 1, MealSlot.almuerzo)]), [MealSlot.desayuno, MealSlot.cena]);
      expect(mealsToRepeat(yesterday, yesterday), isEmpty);
    });
  });

  group('actividad por día', () {
    test('un registro cuenta si se hizo ese día o el siguiente', () {
      expect(loggedOnTime('2026-10-27', today), isTrue);
      expect(loggedOnTime(today, today), isTrue);
      expect(loggedOnTime('2026-10-26', today), isFalse);
    });

    test('une diario y entrenamientos, y separa lo registrado tarde', () {
      final activity = buildActivity(
        days: const [
          LoggedDay(date: '2026-10-27', entries: 3, kcal: 1500),
          LoggedDay(date: '2026-10-20', entries: 2, kcal: 900, onTime: false),
          LoggedDay(date: '2026-10-19', entries: 0, kcal: 0),
        ],
        workouts: [workoutOn('2026-10-27'), workoutOn('2026-10-22', finishedOn: '2026-10-25')],
      );
      expect(activity.keys.toSet(), {'2026-10-27', '2026-10-20', '2026-10-22'});
      final both = activity['2026-10-27']!;
      expect((both.entries, both.kcal, both.workouts, sorted(both.kinds), both.counts), (3, 1500.0, 1, 'nutrition,strength', true));
      expect((activity['2026-10-20']!.late, activity['2026-10-20']!.counts), (true, false));
      expect(activity['2026-10-22']!.late, isTrue);
    });

    test('arma las semanas del mes de lunes a domingo', () {
      final weeks = monthWeeks('2026-10-15');
      expect(weeks.length, 5);
      expect(weeks.first, [null, null, null, '2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04']);
      expect(weeks.last, ['2026-10-26', '2026-10-27', '2026-10-28', '2026-10-29', '2026-10-30', '2026-10-31', null]);
      expect((addMonths('2026-12-10', 1), addMonths('2026-01-31', -1)), ('2027-01-01', '2025-12-01'));
    });
  });

  group('racha', () {
    test('cuenta días seguidos y hoy no la corta mientras no termine', () {
      final s = computeStreak(range('2026-10-20', '2026-10-27'), today);
      expect((s.current, s.best, s.start, s.activeToday, sorted(s.protectedDays)), (8, 8, '2026-10-20', false, ''));
      expect(computeStreak(range('2026-10-20', today), today).activeToday, isTrue);
      expect(computeStreak(const [], today).current, 0);
    });

    test('el protector cubre una falta por semana; el día protegido no suma', () {
      final s = computeStreak([...range('2026-10-21', '2026-10-22'), ...range('2026-10-24', '2026-10-27')], today);
      expect((s.current, s.start, sorted(s.protectedDays)), (6, '2026-10-21', '2026-10-23'));
    });

    test('dos faltas en la misma semana cortan la racha', () {
      final s = computeStreak(['2026-10-19', ...range('2026-10-22', '2026-10-27')], today);
      expect((s.current, s.start, s.best, sorted(s.protectedDays)), (6, '2026-10-22', 6, ''));
    });

    test('una falta el domingo y otra el lunes usan el protector de cada semana', () {
      final s = computeStreak([...range('2026-10-20', '2026-10-24'), '2026-10-27'], today);
      expect((s.current, sorted(s.protectedDays)), (6, '2026-10-25,2026-10-26'));
    });

    test('si ayer faltó, el protector mantiene la racha y queda usado esta semana', () {
      final s = computeStreak(range('2026-10-20', '2026-10-26'), today);
      expect((s.current, sorted(s.protectedDays), s.protectorUsedInWeek(today)), (7, '2026-10-27', true));
      expect(computeStreak(range('2026-10-20', '2026-10-27'), today).protectorUsedInWeek(today), isFalse);
    });

    test('los días de descanso sin registro mantienen la racha sin sumar ni gastar el protector', () {
      const weekend = {6, 7};
      // Lunes 19 a viernes 23, descanso sábado 24 y domingo 25, lunes 26 y martes 27.
      final s = computeStreak([...range('2026-10-19', '2026-10-23'), ...range('2026-10-26', '2026-10-27')], today, restWeekdays: weekend);
      expect((s.current, s.start, sorted(s.restDays), sorted(s.protectedDays), s.protectorUsedInWeek(today)),
          (7, '2026-10-19', '2026-10-24,2026-10-25', '', false));
      // Sin días de descanso, dos faltas el mismo fin de semana la cortan.
      expect(computeStreak([...range('2026-10-19', '2026-10-23'), ...range('2026-10-26', '2026-10-27')], today).current, 2);
      // Registrar en un día de descanso suma igual; una falta entre semana sigue usando el protector.
      final t = computeStreak(['2026-10-22', '2026-10-24', ...range('2026-10-26', '2026-10-27')], today, restWeekdays: weekend);
      expect((t.current, sorted(t.restDays), sorted(t.protectedDays)), (4, '2026-10-25', '2026-10-23'));
      expect(computeStreak(const [], '2026-10-31', restWeekdays: weekend).restToday, isTrue);
      expect(weekdaysFrom([7, 6, 0, 'x', 8]), {6, 7});
    });

    test('recuerda la mejor racha aunque la actual sea más corta', () {
      final s = computeStreak([...range('2026-10-01', '2026-10-12'), ...range('2026-10-26', today)], today);
      expect((s.current, s.best), (3, 12));
    });

    test('hitos: 5, 7, 10, 30 y cada 30 días', () {
      expect([for (var d = 1; d <= 90; d++) if (isStreakMilestone(d)) d], [5, 7, 10, 30, 60, 90]);
      expect([nextStreakMilestone(0), nextStreakMilestone(5), nextStreakMilestone(10), nextStreakMilestone(45)], [5, 7, 30, 60]);
      expect([streakMilestoneTitle(5), streakMilestoneTitle(7), streakMilestoneTitle(30), streakMilestoneTitle(90)],
          ['¡5 días seguidos!', '¡Una semana seguida!', '¡Un mes seguido!', '¡3 meses seguidos!']);
    });

    test('celebra un hito recién alcanzado una sola vez por racha', () {
      final s = computeStreak(range('2026-10-24', today), today);
      expect((s.milestone, s.milestoneDate), (5, today));
      expect(milestoneToCelebrate(s, null, today), 5);
      expect(milestoneToCelebrate(s, const StreakCelebration(start: '2026-10-24', milestone: 5), today), isNull);
      expect(milestoneToCelebrate(s, const StreakCelebration(start: '2026-09-01', milestone: 30), today), 5);
      // El hito de 10 días se alcanzó hace semanas: no se celebra al abrir la app.
      expect(milestoneToCelebrate(computeStreak(range('2026-10-01', today), today), null, today), isNull);
    });
  });

  group('gasto calórico', () {
    test('Mifflin-St Jeor y edad', () {
      expect(mifflinStJeor(kg: 80, heightCm: 180, age: 30, sex: Sex.male), 1780);
      expect(mifflinStJeor(kg: 60, heightCm: 165, age: 25, sex: Sex.female), 1345.25);
      expect((ageOn('1990-10-29', today), ageOn('1990-10-28', today)), (35, 36));
    });

    test('la fórmula multiplica por la actividad y exige datos completos', () {
      const p = BodyProfile(heightCm: 180, birthDate: '1996-01-01', sex: Sex.male, activity: ActivityLevel.moderate);
      final e = formulaEnergy(p, 80, today)!;
      expect((e.bmr, e.tdee), (1780, 2760));
      expect(formulaEnergy(const BodyProfile(heightCm: 180, sex: Sex.male), 80, today), isNull);
      expect(formulaEnergy(p, null, today), isNull);
    });

    test('el perfil se guarda y se lee igual', () {
      const p = BodyProfile(heightCm: 172.5, birthDate: '1990-05-02', sex: Sex.female, activity: ActivityLevel.high);
      expect(BodyProfile.fromMap(p.toMap()).toMap(), p.toMap());
      expect(BodyProfile.fromMap(null).activity, ActivityLevel.moderate);
    });

    final steadyDays = [for (final d in range('2026-10-01', '2026-10-27')) LoggedDay(date: d, entries: 4, kcal: 2500)];
    final losing = [for (var i = 0; i <= 27; i += 3) WeightEntry(date: addDays('2026-10-01', i), kg: 80 - i * 0.5 / 7)];

    test('con los registros: ingesta promedio menos el cambio de peso', () {
      final e = observedEnergy(steadyDays, losing, today)!;
      expect((e.tdee, e.avgIntake, e.days, e.ratePerWeek), (3050, 2500, 27, -0.5));
    });

    test('ignora los días anotados a medias', () {
      final e = observedEnergy([...steadyDays.where((d) => d.date != '2026-10-15'), const LoggedDay(date: '2026-10-15', entries: 1, kcal: 400)], losing, today)!;
      expect((e.avgIntake, e.days), (2500, 26));
    });

    test('sin suficientes días o pesajes no estima', () {
      expect(observedEnergy(steadyDays.take(10), losing, today), isNull);
      expect(observedEnergy(steadyDays, losing.take(2).toList(), today), isNull);
      final p = observedProgress(steadyDays.take(10), losing.take(2).toList(), today);
      expect((p.loggedDays, p.weighIns, p.weightSpanDays), (10, 2, 3));
    });

    test('sugiere rangos a partir del gasto, el peso y la meta', () {
      final g = suggestGoals(tdee: 2500, kg: 80, goal: GoalType.maintain, current: defaultGoals);
      expect([for (final k in MacroKey.values) (g.range(k).min, g.range(k).max)], [(2380, 2630), (130, 175), (270, 365), (55, 85), (35, 50)]);
      expect(g.weights, defaultGoals.weights);
      final lose = suggestGoals(tdee: 2500, kg: 80, goal: GoalType.lose, current: defaultGoals);
      expect([lose.range(MacroKey.kcal).min, lose.range(MacroKey.kcal).max, lose.range(MacroKey.protein).min, lose.range(MacroKey.protein).max], [2020, 2230, 175, 225]);
    });
  });
}
