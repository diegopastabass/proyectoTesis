/// Estadísticas de los pasos leídos desde Apple Salud (lógica pura).
///
/// - Meta diaria configurable (8.000 por defecto): entre 7.000 y 8.000 pasos
///   diarios se asocian a menor mortalidad en adultos (Paluch et al., 2022,
///   metaanálisis en Lancet Public Health; aún no está en la bibliografía de la tesis).
/// - Distancia estimada con el largo del paso: 41,5 % de la estatura en hombres y
///   41,3 % en mujeres (regla habitual de los podómetros); sin estatura, 0,75 m.
/// - Energía estimada del caminar sobre el reposo: ~0,5 kcal por kg y km
///   (costo neto de caminar a ritmo normal). Son aproximaciones, no mediciones.
library;

import 'dart:math' as math;

import '../body/energy.dart';
import '../common/date.dart';
import 'models.dart';

const defaultStepsGoal = 8000;

/// Metas para elegir.
const stepsGoalChoices = [6000, 7000, 8000, 10000, 12000];

class StepsStats {
  const StepsStats({
    required this.total,
    required this.average,
    required this.best,
    required this.goalDays,
    required this.countedDays,
    required this.streak,
    this.previousAverage,
  });

  /// Pasos del periodo.
  final int total;

  /// Promedio por día (sin contar hoy, que todavía no termina, salvo que sea el único día).
  final int average;

  /// Día con más pasos (null si no hay datos).
  final DailySteps? best;

  /// Días que llegaron a la meta.
  final int goalDays;

  /// Días que entran en el promedio.
  final int countedDays;

  /// Días seguidos cumpliendo la meta hasta hoy (hoy cuenta solo si ya la cumplió).
  final int streak;

  /// Promedio del periodo anterior del mismo largo (null si no hay datos).
  final int? previousAverage;

  /// Cambio porcentual frente al periodo anterior.
  int? get change => previousAverage == null || previousAverage == 0 ? null : ((average / previousAverage! - 1) * 100).round();
}

/// Días completos (`days` incluye el periodo actual; `previous`, el anterior).
StepsStats stepsStats(List<DailySteps> days, {required int goal, required String today, List<DailySteps> previous = const []}) {
  final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
  final total = sorted.fold<int>(0, (a, d) => a + d.steps);
  final complete = sorted.where((d) => d.date.compareTo(today) < 0).toList();
  final counted = complete.isEmpty ? sorted : complete;
  final average = counted.isEmpty ? 0 : (counted.fold<int>(0, (a, d) => a + d.steps) / counted.length).round();
  final best = sorted.isEmpty ? null : sorted.reduce((a, b) => b.steps > a.steps ? b : a);

  // Racha: desde hoy (si ya cumplió) o desde ayer hacia atrás.
  final byDate = {for (final d in sorted) d.date: d.steps};
  var streak = 0;
  var day = (byDate[today] ?? 0) >= goal ? today : addDays(today, -1);
  while ((byDate[day] ?? 0) >= goal) {
    streak++;
    day = addDays(day, -1);
  }

  final prev = previous.where((d) => d.date.compareTo(today) < 0).toList();
  return StepsStats(
    total: total,
    average: average,
    best: best == null || best.steps == 0 ? null : best,
    goalDays: sorted.where((d) => d.steps >= goal).length,
    countedDays: counted.length,
    streak: streak,
    previousAverage: prev.isEmpty ? null : (prev.fold<int>(0, (a, d) => a + d.steps) / prev.length).round(),
  );
}

/// Largo del paso en metros según la estatura y el sexo.
double strideMeters(BodyProfile body) {
  final h = body.heightCm;
  if (h == null) return 0.75;
  return h / 100 * (body.sex == Sex.female ? 0.413 : 0.415);
}

/// Distancia aproximada (km).
double stepsKm(int steps, BodyProfile body) => steps * strideMeters(body) / 1000;

/// Energía aproximada del caminar sobre el reposo (kcal). null sin peso.
int? stepsKcal(int steps, BodyProfile body, double? weightKg) {
  if (weightKg == null || weightKg <= 0) return null;
  return (0.5 * weightKg * stepsKm(steps, body)).round();
}

/// Parte de la meta cumplida (0 a 1, tope 1).
double goalProgress(int steps, int goal) => goal <= 0 ? 0 : math.min(1, steps / goal);

/// Días del periodo que termina en `to`: `length` días hacia atrás.
({String from, String to}) periodRange(String to, int length) => (from: addDays(to, -(length - 1)), to: to);
