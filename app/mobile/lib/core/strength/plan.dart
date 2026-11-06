/// Plan de entrenamiento: qué días se entrena y, si se sigue un programa, en qué
/// orden se hacen sus rutinas. Se guarda en el perfil (`users/{uid}.trainingPlan`)
/// para que los recordatorios y la pantalla de Fuerza coincidan en cada dispositivo.
library;

import 'models.dart';

class TrainingPlan {
  const TrainingPlan({this.weekdays = const {}, this.programId, this.routineIds = const [], this.startDate});

  factory TrainingPlan.fromMap(Object? data) {
    if (data is! Map) return const TrainingPlan();
    return TrainingPlan(
      weekdays: {for (final d in data['weekdays'] as List? ?? const []) if (d is num && d >= 1 && d <= 7) d.toInt()},
      programId: data['programId'] as String?,
      routineIds: [for (final id in data['routineIds'] as List? ?? const []) if (id is String) id],
      startDate: data['startDate'] as String?,
    );
  }

  /// Días de entrenamiento: 1 = lunes … 7 = domingo.
  final Set<int> weekdays;

  /// Programa sugerido que se está siguiendo (null = rutinas propias).
  final String? programId;

  /// Rutinas del programa en el orden en que se rotan.
  final List<String> routineIds;

  /// Desde cuándo se sigue el programa (YYYY-MM-DD).
  final String? startDate;

  bool get hasProgram => programId != null && routineIds.isNotEmpty;

  TrainingPlan copyWith({Set<int>? weekdays}) =>
      TrainingPlan(weekdays: weekdays ?? this.weekdays, programId: programId, routineIds: routineIds, startDate: startDate);

  /// Deja de seguir el programa; conserva los días.
  TrainingPlan withoutProgram() => TrainingPlan(weekdays: weekdays);

  Map<String, dynamic> toMap() =>
      {'weekdays': (weekdays.toList()..sort()), 'programId': programId, 'routineIds': routineIds, 'startDate': startDate};
}

/// Rutina que toca: la siguiente a la última del programa que se hizo desde que
/// empezó. Sin sesiones del programa, la primera. null si no hay programa.
String? nextRoutineId(TrainingPlan plan, List<Workout> workouts) {
  if (!plan.hasProgram) return null;
  final start = plan.startDate;
  // `workouts` viene de la más reciente a la más antigua.
  for (final w in workouts) {
    if (start != null && w.date.compareTo(start) < 0) break;
    final i = plan.routineIds.indexOf(w.routineId ?? '');
    if (i >= 0) return plan.routineIds[(i + 1) % plan.routineIds.length];
  }
  return plan.routineIds.first;
}

/// Días sugeridos según cuántos se entrena, repartidos para descansar entre sesiones.
Set<int> defaultWeekdays(int days) => switch (days) {
      <= 1 => {3},
      2 => {1, 4},
      3 => {1, 3, 5},
      4 => {1, 2, 4, 5},
      5 => {1, 2, 3, 5, 6},
      _ => {1, 2, 3, 4, 5, 6},
    };
