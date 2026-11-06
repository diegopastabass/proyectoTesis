import 'dart:math' as math;

import '../common/numbers.dart';
import 'models.dart';

/// Puntaje 0–100 de un macro respecto de su rango: 100 dentro del rango; fuera
/// de él cae linealmente según la desviación relativa al límite más cercano.
double macroScore(double value, Range range) {
  final min = range.min;
  final max = range.max;
  if (value >= min && value <= max) return 100;
  if (value < min) return min <= 0 ? 100 : math.max(0, 100 * (1 - (min - value) / min));
  return max <= 0 ? 0 : math.max(0, 100 * (1 - (value - max) / max));
}

Map<MacroKey, double> normalizedWeights(Map<MacroKey, double> weights) {
  final sum = MacroKey.values.fold<double>(0, (s, k) => s + math.max(0, weights[k] ?? 0));
  return {
    for (final k in MacroKey.values) k: sum > 0 ? math.max(0, weights[k] ?? 0) / sum : 1 / MacroKey.values.length,
  };
}

class DailyScore {
  const DailyScore({required this.total, required this.perMacro});

  final int total;
  final Map<MacroKey, double> perMacro;
}

DailyScore dailyScore(Macros totals, Goals goals) {
  final w = normalizedWeights(goals.weights);
  final perMacro = <MacroKey, double>{};
  var total = 0.0;
  for (final k in MacroKey.values) {
    perMacro[k] = macroScore(totals[k], goals.range(k));
    total += w[k]! * perMacro[k]!;
  }
  return DailyScore(total: jsRound(total), perMacro: perMacro);
}

enum ScoreLevel { good, mid, low }

ScoreLevel scoreLevel(num score) {
  if (score >= 85) return ScoreLevel.good;
  if (score >= 60) return ScoreLevel.mid;
  return ScoreLevel.low;
}

const defaultGoals = Goals(
  ranges: {
    MacroKey.kcal: Range(2200, 2600),
    MacroKey.protein: Range(120, 160),
    MacroKey.carbs: Range(220, 320),
    MacroKey.fat: Range(60, 90),
    MacroKey.fiber: Range(25, 40),
  },
  weights: {MacroKey.kcal: 40, MacroKey.protein: 25, MacroKey.carbs: 20, MacroKey.fat: 15, MacroKey.fiber: 10},
);

/// Objetivos guardados, completados con los valores por defecto.
Goals goalsFromMap(Object? data) {
  if (data is! Map) return defaultGoals;
  final ranges = data['ranges'] is Map ? data['ranges'] as Map : const {};
  final weights = data['weights'] is Map ? data['weights'] as Map : const {};
  return Goals(
    ranges: {for (final k in MacroKey.values) k: Range.fromMap(ranges[k.name], defaultGoals.range(k))},
    weights: {for (final k in MacroKey.values) k: (weights[k.name] as num?)?.toDouble() ?? defaultGoals.weights[k]!},
  );
}
