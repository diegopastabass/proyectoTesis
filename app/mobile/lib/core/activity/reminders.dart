/// Recordatorios locales: registrar comidas, entrenar y no perder la racha.
///
/// Las notificaciones locales no pueden revisar los datos al momento de sonar,
/// así que se programan los próximos días por adelantado y se vuelven a calcular
/// cada vez que cambia algo (al registrar una comida se quita el aviso de esa
/// comida de hoy) y al volver a abrir la app.
library;

import '../common/date.dart';
import '../nutrition/models.dart';

enum ReminderKind { meal, training, streak }

/// Hora del día en minutos desde medianoche.
String formatClock(int minutes) => '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

const defaultMealTimes = {
  MealSlot.desayuno: 10 * 60,
  MealSlot.almuerzo: 15 * 60,
  MealSlot.once: 18 * 60 + 30,
  MealSlot.cena: 21 * 60 + 30,
  MealSlot.snack: 17 * 60,
};

/// Preferencias de recordatorios (viven en el dispositivo).
class ReminderSettings {
  const ReminderSettings({
    this.meals = const {},
    this.training = false,
    this.trainingAt = 18 * 60,
    this.streak = false,
    this.streakAt = 21 * 60,
  });

  factory ReminderSettings.fromJson(Map<String, dynamic> j) => ReminderSettings(
        meals: {
          for (final e in (j['meals'] as Map? ?? const {}).entries)
            if (MealSlot.values.where((m) => m.name == e.key).firstOrNull case final slot? when e.value is num) slot: (e.value as num).toInt(),
        },
        training: j['training'] == true,
        trainingAt: (j['trainingAt'] as num?)?.toInt() ?? 18 * 60,
        streak: j['streak'] == true,
        streakAt: (j['streakAt'] as num?)?.toInt() ?? 21 * 60,
      );

  /// Comidas con recordatorio y su hora.
  final Map<MealSlot, int> meals;
  final bool training;
  final int trainingAt;
  final bool streak;
  final int streakAt;

  bool get any => meals.isNotEmpty || training || streak;

  /// Lo que se activa con un toque: almuerzo y cena, entrenamiento y racha.
  static const suggested = ReminderSettings(
    meals: {MealSlot.almuerzo: 15 * 60, MealSlot.cena: 21 * 60 + 30},
    training: true,
    streak: true,
  );

  ReminderSettings copyWith({Map<MealSlot, int>? meals, bool? training, int? trainingAt, bool? streak, int? streakAt}) => ReminderSettings(
        meals: meals ?? this.meals,
        training: training ?? this.training,
        trainingAt: trainingAt ?? this.trainingAt,
        streak: streak ?? this.streak,
        streakAt: streakAt ?? this.streakAt,
      );

  ReminderSettings withMeal(MealSlot slot, int? minutes) =>
      copyWith(meals: {for (final e in meals.entries) if (e.key != slot) e.key: e.value, slot: ?minutes});

  Map<String, dynamic> toJson() => {
        'meals': {for (final e in meals.entries) e.key.name: e.value},
        'training': training,
        'trainingAt': trainingAt,
        'streak': streak,
        'streakAt': streakAt,
      };
}

/// Estado actual con que se decide qué avisos siguen teniendo sentido.
class ReminderContext {
  const ReminderContext({
    required this.now,
    this.mealsLoggedToday = const {},
    this.trainedToday = false,
    this.trainingWeekdays = const {},
    this.nextRoutine,
    this.streak = 0,
    this.activeToday = false,
    this.restWeekdays = const {},
  });

  final DateTime now;
  final Set<MealSlot> mealsLoggedToday;
  final bool trainedToday;

  /// 1 = lunes … 7 = domingo.
  final Set<int> trainingWeekdays;

  /// Rutina que toca, si se sigue un programa.
  final String? nextRoutine;
  final int streak;
  final bool activeToday;

  /// Días de descanso de la racha: sin avisos de comidas ni de racha.
  final Set<int> restWeekdays;
}

class PlannedReminder {
  const PlannedReminder({required this.kind, required this.at, required this.title, required this.body, required this.route});

  final ReminderKind kind;

  /// Hora local.
  final DateTime at;
  final String title;
  final String body;

  /// Pantalla que abre al tocarla.
  final String route;

  @override
  String toString() => 'PlannedReminder(${kind.name}, $at, $title)';
}

/// Días programados por adelantado (iOS permite hasta 64 avisos pendientes).
const reminderDaysAhead = 7;

const _mealArticle = {
  MealSlot.desayuno: 'el desayuno',
  MealSlot.almuerzo: 'el almuerzo',
  MealSlot.once: 'la once',
  MealSlot.cena: 'la cena',
  MealSlot.snack: 'el snack',
};

/// Avisos de los próximos días, en orden.
List<PlannedReminder> planReminders(ReminderSettings s, ReminderContext c, {int days = reminderDaysAhead}) {
  final out = <PlannedReminder>[];
  final today = toDateKey(c.now);
  for (var i = 0; i < days; i++) {
    final date = addDays(today, i);
    final isToday = i == 0;
    final day = fromDateKey(date);
    DateTime at(int minutes) => DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
    final rest = c.restWeekdays.contains(day.weekday);

    for (final slot in MealSlot.values) {
      final minutes = s.meals[slot];
      if (rest || minutes == null || (isToday && c.mealsLoggedToday.contains(slot))) continue;
      final keepsStreak = isToday && c.streak > 0 && !c.activeToday;
      out.add(PlannedReminder(
        kind: ReminderKind.meal,
        at: at(minutes),
        title: '¿Ya registraste ${_mealArticle[slot]}?',
        body: keepsStreak ? 'Anótalo y sumas el día ${c.streak + 1} de tu racha.' : 'Anótalo ahora y mantén tus macros al día.',
        route: '/registrar?d=$date&m=${slot.name}',
      ));
    }

    if (s.training && c.trainingWeekdays.contains(day.weekday) && !(isToday && c.trainedToday)) {
      out.add(PlannedReminder(
        kind: ReminderKind.training,
        at: at(s.trainingAt),
        title: 'Hoy toca entrenar',
        body: isToday && c.nextRoutine != null ? 'Te toca ${c.nextRoutine}. ¡A darle!' : 'Tu sesión de fuerza te espera.',
        route: '/fuerza',
      ));
    }

    // Sin racha no hay nada que perder; hoy no avisa si ya sumó. Un día de descanso no la corta.
    if (s.streak && !rest && c.streak > 0 && !(isToday && c.activeToday)) {
      out.add(PlannedReminder(
        kind: ReminderKind.streak,
        at: at(s.streakAt),
        title: isToday ? 'Tu racha de ${c.streak} ${c.streak == 1 ? 'día' : 'días'} está en riesgo' : 'Mantén tu racha',
        body: 'Registra una comida o un entrenamiento antes de medianoche.',
        route: '/actividad',
      ));
    }
  }
  return [for (final r in out) if (r.at.isAfter(c.now)) r]..sort((a, b) => a.at.compareTo(b.at));
}
