/// Datos de ejemplo para mostrar el motor sin historial real (pantalla de ejemplo
/// de la alerta y capturas del documento). Son datos simulados con valores
/// conocidos, y también sirven para probar las reglas de las alertas.
library;

import '../cardio/activity.dart';
import '../common/date.dart';
import '../strength/models.dart';
import 'alerts.dart';
import 'profile.dart';
import 'weekly_plan.dart';

/// Seis semanas de ciclismo suave y fuerza dos veces por semana, y una última
/// semana con bastante más ciclismo; mañana el plan tiene pierna. La razón ATL/CTL
/// queda sobre 1,3 con la fatiga venida del cardio: la alerta de la tesis
/// ("fuerza máxima después de un entrenamiento de resistencia exigente").
AlertContext exampleAlertContext(DateTime now) {
  final today = toDateKey(now);
  int at(int daysAgo, int hour) {
    final d = fromDateKey(addDays(today, -daysAgo));
    return DateTime(d.year, d.month, d.day, hour).millisecondsSinceEpoch;
  }

  CardioActivity ride(int daysAgo, int minutes, int rpe) => CardioActivity(
        id: 'ej-bici-$daysAgo',
        discipline: Discipline.cycling,
        title: 'Ruta en bici',
        startedAt: at(daysAgo, 8),
        finishedAt: at(daysAgo, 8) + minutes * 60000,
        stats: CardioStats(durationS: minutes * 60.0, movingS: minutes * 60.0, distanceM: minutes * 450.0),
        updatedAt: 0,
        rpe: rpe,
      );

  Workout lift(int daysAgo) => Workout(
        id: 'ej-fuerza-$daysAgo',
        routineId: null,
        name: 'Cuerpo completo',
        date: addDays(today, -daysAgo),
        startedAt: at(daysAgo, 19),
        finishedAt: at(daysAgo, 19) + 60 * 60000,
        exercises: const [],
        rpe: 6,
      );

  final cardio = <CardioActivity>[
    for (var d = 42; d >= 8; d -= 2) ride(d, 60, 4),
    ride(6, 150, 6),
    ride(4, 90, 7),
    ride(2, 120, 6),
    ride(1, 90, 7),
  ];
  final workouts = <Workout>[
    for (var d = 41; d >= 1; d--)
      if (fromDateKey(addDays(today, -d)).weekday == DateTime.tuesday || fromDateKey(addDays(today, -d)).weekday == DateTime.friday) lift(d),
  ];
  final tomorrow = now.weekday % 7 + 1;
  final plan = WeeklyPlan(
    level: Level.intermediate,
    orientation: Orientation.balanced,
    programId: 'torso-pierna-4',
    sessions: [
      PlannedSession(kind: SessionKind.strength, weekday: tomorrow, title: 'Pierna A', minutes: 60, rpe: 7, routineIndex: 1, legHeavy: true),
    ],
    why: const [],
  );
  return AlertContext(now: now, workouts: workouts, cardio: cardio, plan: plan);
}
