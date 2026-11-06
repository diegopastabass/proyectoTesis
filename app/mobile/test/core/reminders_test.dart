import 'package:asistente_deportivo/core/activity/reminders.dart';
import 'package:asistente_deportivo/core/nutrition/models.dart';
import 'package:asistente_deportivo/core/strength/models.dart';
import 'package:asistente_deportivo/core/strength/plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// Miércoles 28 de octubre de 2026, 12:00.
final noon = DateTime(2026, 10, 28, 12);

const all = ReminderSettings(
  meals: {MealSlot.desayuno: 600, MealSlot.almuerzo: 900, MealSlot.cena: 1290},
  training: true,
  trainingAt: 1080,
  streak: true,
  streakAt: 1260,
);

String describe(PlannedReminder r) => '${r.at.day} ${r.at.hour}:${r.at.minute} ${r.kind.name}';

Workout workout(String date, String? routineId) =>
    Workout(id: 'w-$date', routineId: routineId, name: 'x', date: date, startedAt: 0, finishedAt: 0, exercises: const []);

void main() {
  group('recordatorios', () {
    test('hoy solo programa lo que aún no pasó ni se registró', () {
      final today = planReminders(
        all,
        ReminderContext(now: noon, mealsLoggedToday: {MealSlot.almuerzo}, trainingWeekdays: {3}, streak: 4),
        days: 1,
      );
      expect(today.map(describe), ['28 18:0 training', '28 21:0 streak', '28 21:30 meal']);
      expect(today.last.route, '/registrar?d=2026-10-28&m=cena');
      expect(today.first.route, '/fuerza');
    });

    test('si ya entrenó o ya sumó a la racha, no avisa hoy', () {
      final today = planReminders(all, ReminderContext(now: noon, trainedToday: true, trainingWeekdays: {3}, streak: 4, activeToday: true), days: 1);
      expect(today.map((r) => r.kind), [ReminderKind.meal, ReminderKind.meal]);
    });

    test('el entrenamiento solo los días elegidos y nombra la rutina de hoy', () {
      final week = planReminders(
        const ReminderSettings(training: true),
        ReminderContext(now: noon, trainingWeekdays: {1, 3, 5}, nextRoutine: 'Torso A'),
      );
      expect(week.map((r) => r.at.day), [28, 30, 2]);
      expect(week.first.body, 'Te toca Torso A. ¡A darle!');
      expect(week[1].body, 'Tu sesión de fuerza te espera.');
    });

    test('la racha menciona los días y no avisa si no hay racha', () {
      final risk = planReminders(const ReminderSettings(streak: true), ReminderContext(now: noon, streak: 6), days: 2);
      expect(risk.map((r) => r.title), ['Tu racha de 6 días está en riesgo', 'Mantén tu racha']);
      expect(planReminders(const ReminderSettings(streak: true), ReminderContext(now: noon)), isEmpty);
    });

    test('los días de descanso de la racha no tienen avisos de comidas ni de racha', () {
      // Descanso el jueves 29: solo queda el entrenamiento de ese día.
      final week = planReminders(all, ReminderContext(now: noon, trainingWeekdays: {4}, streak: 4, restWeekdays: {4}), days: 2);
      expect(week.where((r) => r.at.day == 29).map((r) => r.kind), [ReminderKind.training]);
      expect(week.where((r) => r.at.day == 28).map((r) => r.kind).toSet(), {ReminderKind.meal, ReminderKind.streak});
    });

    test('el aviso de comida cuenta el día que se sumaría a la racha', () {
      final [lunch, ...] = planReminders(const ReminderSettings(meals: {MealSlot.almuerzo: 900}), ReminderContext(now: noon, streak: 6), days: 1);
      expect((lunch.title, lunch.body), ('¿Ya registraste el almuerzo?', 'Anótalo y sumas el día 7 de tu racha.'));
    });

    test('programa 7 días en orden y las preferencias se guardan y leen igual', () {
      final week = planReminders(all, ReminderContext(now: noon, trainingWeekdays: {1, 2, 3, 4, 5, 6, 7}, streak: 1));
      expect(week.length, lessThanOrEqualTo(64));
      expect(week.last.at.day, 3);
      expect([for (var i = 1; i < week.length; i++) !week[i].at.isBefore(week[i - 1].at)].every((x) => x), isTrue);
      expect(ReminderSettings.fromJson(all.toJson()).toJson(), all.toJson());
      expect(all.withMeal(MealSlot.desayuno, null).meals.keys, [MealSlot.almuerzo, MealSlot.cena]);
      expect(formatClock(1290), '21:30');
    });
  });

  group('plan de entrenamiento', () {
    const plan = TrainingPlan(weekdays: {1, 3, 5}, programId: 'fb3', routineIds: ['a', 'b'], startDate: '2026-10-01');

    test('toca la rutina siguiente a la última del programa', () {
      expect(nextRoutineId(plan, const []), 'a');
      expect(nextRoutineId(plan, [workout('2026-10-27', 'a')]), 'b');
      expect(nextRoutineId(plan, [workout('2026-10-27', null), workout('2026-10-26', 'b')]), 'a');
      // Lo anterior al inicio del programa no cuenta.
      expect(nextRoutineId(plan, [workout('2026-09-30', 'a')]), 'a');
      expect(nextRoutineId(const TrainingPlan(weekdays: {1}), const []), isNull);
    });

    test('se guarda y lee igual; sugiere días repartidos', () {
      expect(TrainingPlan.fromMap(plan.toMap()).toMap(), plan.toMap());
      expect(plan.withoutProgram().toMap(), {'weekdays': [1, 3, 5], 'programId': null, 'routineIds': const <String>[], 'startDate': null});
      expect([for (var d = 2; d <= 6; d++) defaultWeekdays(d).length], [2, 3, 4, 5, 6]);
    });
  });
}
