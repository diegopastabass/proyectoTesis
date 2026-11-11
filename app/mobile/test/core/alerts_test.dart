import 'package:asistente_deportivo/core/activity/calendar.dart';
import 'package:asistente_deportivo/core/activity/reminders.dart';
import 'package:asistente_deportivo/core/cardio/activity.dart';
import 'package:asistente_deportivo/core/common/date.dart';
import 'package:asistente_deportivo/core/strength/models.dart';
import 'package:asistente_deportivo/core/suggestions/alerts.dart';
import 'package:asistente_deportivo/core/suggestions/examples.dart';
import 'package:asistente_deportivo/core/suggestions/profile.dart';
import 'package:asistente_deportivo/core/suggestions/reason.dart';
import 'package:asistente_deportivo/core/suggestions/weekly_plan.dart';
import 'package:asistente_deportivo/core/training/load.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lunes 9 de noviembre de 2026, 10:00.
final now = DateTime(2026, 11, 9, 10);

int ms(DateTime d) => d.millisecondsSinceEpoch;

Workout lift(DateTime start, {int minutes = 60, String name = 'Pierna A'}) => Workout(
      id: 'w${ms(start)}',
      routineId: null,
      name: name,
      date: toDateKey(start),
      startedAt: ms(start),
      finishedAt: ms(start) + minutes * 60000,
      exercises: const [],
      rpe: 7,
    );

CardioActivity ride(DateTime start, {int minutes = 60, String title = 'Ruta en bici'}) => CardioActivity(
      id: 'c${ms(start)}',
      discipline: Discipline.cycling,
      title: title,
      startedAt: ms(start),
      finishedAt: ms(start) + minutes * 60000,
      stats: CardioStats(durationS: minutes * 60.0, movingS: minutes * 60.0),
      updatedAt: 0,
      rpe: 5,
    );

WeeklyPlan planWith(List<PlannedSession> sessions) => WeeklyPlan(level: Level.intermediate, orientation: Orientation.balanced, sessions: sessions, why: const []);

PlannedSession strengthOn(int weekday) => PlannedSession(kind: SessionKind.strength, weekday: weekday, title: 'Pierna A', minutes: 60, rpe: 7, legHeavy: true);

PlannedSession cardioOn(int weekday, CardioIntensity i) =>
    PlannedSession(kind: SessionKind.cardio, weekday: weekday, title: 'Ciclismo largo', minutes: 120, rpe: i.rpe, discipline: Discipline.cycling, intensity: i);

AlertContext withPlan(AlertContext base, WeeklyPlan? plan, {DateTime? at, double threshold = defaultRatioThreshold, List<Workout>? workouts}) => AlertContext(
      now: at ?? base.now,
      workouts: workouts ?? base.workouts,
      cardio: base.cardio,
      plan: plan,
      days: base.days,
      dailyExpenditure: base.dailyExpenditure,
      ratioThreshold: threshold,
    );

void main() {
  group('fatiga cruzada', () {
    test('carga alta por el cardio y pierna mañana: alerta importante con sugerencia', () {
      final alerts = fatigueAlerts(exampleAlertContext(now));
      final a = alerts.first;
      expect(a.kind, AlertKind.crossFatigue);
      expect(a.severity, Severity.important);
      expect(a.id, 'fatiga-2026-11-10-strength');
      expect(a.title, 'Vienes con harta carga y mañana toca fuerza (Pierna A)');
      expect(a.suggestion, contains('Pierna A'));
      expect(a.why.first.text, contains('sobre todo por el cardio'));
      expect(a.why.map((r) => r.source), containsAll(['gabbett2016training', Sources.concurrent, Sources.sessionRpe, 'impellizzeri2020acute']));
      expect(a.notificationBody, startsWith(a.title));
    });

    test('bajo el umbral no avisa; el umbral es configurable', () {
      final base = exampleAlertContext(now);
      expect(fatigueAlerts(withPlan(base, base.plan, threshold: 2.5)).where((a) => a.kind == AlertKind.crossFatigue), isEmpty);
      expect(fatigueAlerts(withPlan(base, base.plan, threshold: 1.2)).first.kind, AlertKind.crossFatigue);
    });

    test('sin una sesión de la otra disciplina cerca: aumento brusco, menos grave', () {
      final base = exampleAlertContext(now);
      final noPlan = fatigueAlerts(withPlan(base, null)).first;
      expect((noPlan.kind, noPlan.severity, noPlan.id), (AlertKind.loadSpike, Severity.warning, 'carga-2026-11-09'));
      // La fatiga viene del cardio: más cardio mañana no es "la otra disciplina".
      final sameKind = fatigueAlerts(withPlan(base, planWith([cardioOn(2, CardioIntensity.long)]))).first;
      expect(sameKind.kind, AlertKind.loadSpike);
      // Pasado mañana queda fuera de las 24 horas.
      expect(fatigueAlerts(withPlan(base, planWith([strengthOn(3)]))).first.kind, AlertKind.loadSpike);
    });

    test('la sesión de hoy cuenta si aún no se hizo', () {
      final base = exampleAlertContext(now);
      final today = fatigueAlerts(withPlan(base, planWith([strengthOn(1), strengthOn(2)]))).first;
      expect(today.title, contains('hoy toca'));
      expect(today.sessionDate, '2026-11-09');
      // Si ya entrenó fuerza hoy, la siguiente es la de mañana.
      final done = withPlan(base, planWith([strengthOn(1), strengthOn(2)]), workouts: [...base.workouts, lift(DateTime(2026, 11, 9, 7))]);
      expect(fatigueAlerts(done).first.sessionDate, '2026-11-10');
    });

    test('sin 28 días de historial no avisa la carga', () {
      final base = exampleAlertContext(now);
      final short = AlertContext(
        now: now,
        cardio: [for (final c in base.cardio) if (DateTime.fromMillisecondsSinceEpoch(c.startedAt).isAfter(now.subtract(const Duration(days: 20)))) c],
        plan: base.plan,
      );
      expect(fatigueAlerts(short).where((a) => a.kind == AlertKind.crossFatigue || a.kind == AlertKind.loadSpike), isEmpty);
    });

    test('con el esfuerzo estimado en la mayoría de las sesiones baja un nivel y lo dice', () {
      final base = exampleAlertContext(now);
      final estimated = AlertContext(
        now: now,
        workouts: base.workouts,
        cardio: [for (final c in base.cardio) CardioActivity(id: c.id, discipline: c.discipline, title: c.title, startedAt: c.startedAt, finishedAt: c.finishedAt, stats: c.stats, updatedAt: 0)],
        plan: base.plan,
        ratioThreshold: 1.05,
      );
      final a = fatigueAlerts(estimated).first;
      expect(a.kind, AlertKind.crossFatigue);
      expect(a.severity, Severity.warning);
      expect(a.why.map((r) => r.text), contains(contains('se estimó')));
    });
  });

  group('separación entre sesiones', () {
    test('fuerza y cardio con menos de 6 horas', () {
      final c = AlertContext(now: now, workouts: [lift(DateTime(2026, 11, 8, 9))], cardio: [ride(DateTime(2026, 11, 8, 12))]);
      final a = fatigueAlerts(c).single;
      expect(a.kind, AlertKind.shortGap);
      expect(a.text, 'Ayer hiciste fuerza (Pierna A) (9:00) y Ruta en bici (12:00) con 2 h entre una y otra.');
      expect(a.why.single.source, Sources.concurrent);
    });

    test('con 6 horas o más, o hace más de 3 días, no avisa', () {
      expect(fatigueAlerts(AlertContext(now: now, workouts: [lift(DateTime(2026, 11, 8, 7))], cardio: [ride(DateTime(2026, 11, 8, 14))])), isEmpty);
      expect(fatigueAlerts(AlertContext(now: now, workouts: [lift(DateTime(2026, 11, 4, 9))], cardio: [ride(DateTime(2026, 11, 4, 11))])), isEmpty);
    });

    test('el cardio primero también cuenta, y que se superpongan', () {
      final a = fatigueAlerts(AlertContext(now: now, workouts: [lift(DateTime(2026, 11, 9, 8, 30))], cardio: [ride(DateTime(2026, 11, 9, 8))])).single;
      expect(a.text, startsWith('Hoy hiciste Ruta en bici (8:00) y fuerza (Pierna A) (8:30) con 0 min'));
    });

    test('dos días seguidos: sugiere reorganizar la semana', () {
      final c = AlertContext(
        now: now,
        workouts: [lift(DateTime(2026, 11, 6, 9)), lift(DateTime(2026, 11, 7, 9))],
        cardio: [ride(DateTime(2026, 11, 6, 11)), ride(DateTime(2026, 11, 7, 11))],
      );
      final a = fatigueAlerts(c).single;
      expect(a.kind, AlertKind.repeatedShortGaps);
      expect(a.suggestion, contains('Reorganiza'));
      expect(a.id, 'patron-2026-11-07');
    });
  });

  group('comer poco', () {
    List<LoggedDay> week(double kcal, int n) => [for (var i = 1; i <= n; i++) LoggedDay(date: addDays('2026-11-09', -i), entries: 3, kcal: kcal)];

    test('más de un 20 % bajo el gasto en la semana', () {
      final a = fatigueAlerts(AlertContext(now: now, days: week(1500, 6), dailyExpenditure: 2500)).single;
      expect(a.kind, AlertKind.lowEnergy);
      expect(a.severity, Severity.info);
      expect(a.text, contains('1500 kcal, un 40 % bajo tu gasto estimado (2500 kcal)'));
    });

    test('con pocos días anotados, sin gasto o con un déficit moderado no avisa', () {
      expect(fatigueAlerts(AlertContext(now: now, days: week(1500, 3), dailyExpenditure: 2500)), isEmpty);
      expect(fatigueAlerts(AlertContext(now: now, days: week(1500, 6))), isEmpty);
      expect(fatigueAlerts(AlertContext(now: now, days: week(2100, 6), dailyExpenditure: 2500)), isEmpty);
      expect(recentIntake(week(2000, 3), '2026-11-09'), (avg: 2000, days: 3));
    });

    test('con fatiga cruzada se suma como razón en vez de una alerta aparte', () {
      final base = exampleAlertContext(now);
      final c = AlertContext(now: now, workouts: base.workouts, cardio: base.cardio, plan: base.plan, days: week(1500, 6), dailyExpenditure: 2500);
      final alerts = fatigueAlerts(c);
      expect(alerts.map((a) => a.kind), isNot(contains(AlertKind.lowEnergy)));
      expect(alerts.first.why.map((r) => r.text), contains(contains('40 % menos de lo que gastas')));
    });
  });

  group('avisos', () {
    test('dos horas antes de la hora de entrenar, no antes de las 8:00', () {
      expect(fatigueNoticeTime('2026-11-10', 18 * 60), DateTime(2026, 11, 10, 16));
      expect(fatigueNoticeTime('2026-11-10', 9 * 60), DateTime(2026, 11, 10, 8));
      final alerts = fatigueAlerts(exampleAlertContext(now));
      final r = fatigueReminders(alerts, now: now, trainingAt: 18 * 60).single;
      expect((r.kind, r.at, r.route), (ReminderKind.fatigue, DateTime(2026, 11, 10, 16), '/carga/alerta/fatiga-2026-11-10-strength'));
      expect(fatigueReminders(alerts, now: DateTime(2026, 11, 10, 17), trainingAt: 18 * 60), isEmpty);
    });

    test('las alertas de fatiga vienen activadas y se guardan en las preferencias', () {
      expect(const ReminderSettings().fatigue, isTrue);
      expect(ReminderSettings.fromJson(const ReminderSettings(fatigue: false).toJson()).fatigue, isFalse);
      expect(ReminderSettings.fromJson(const {}).fatigue, isTrue);
    });

    test('la respuesta se guarda y se lee igual', () {
      const r = SuggestionResponse(id: 'x', kind: 'crossFatigue', response: ResponseKind.kept, date: '2026-11-09', title: 't');
      final back = SuggestionResponse.fromMap('x', r.toMap());
      expect((back.response, back.kind, back.date, back.title), (ResponseKind.kept, 'crossFatigue', '2026-11-09', 't'));
    });
  });
}
