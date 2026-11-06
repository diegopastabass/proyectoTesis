/// Meta corporal y tendencia del peso.
library;

import '../common/date.dart';
import '../common/numbers.dart';

enum GoalType { lose, maintain, gain }

class BodyGoal {
  const BodyGoal({required this.type, this.targetKg, required this.startDate});

  static BodyGoal? fromMap(Object? data) {
    if (data is! Map) return null;
    final type = GoalType.values.where((t) => t.name == data['type']).firstOrNull ?? GoalType.maintain;
    final start = data['startDate'] as String?;
    return BodyGoal(type: type, targetKg: (data['targetKg'] as num?)?.toDouble(), startDate: isDateKey(start) ? start! : todayKey());
  }

  final GoalType type;
  final double? targetKg;

  /// Desde esta fecha se mide el progreso (YYYY-MM-DD).
  final String startDate;

  Map<String, dynamic> toMap() => {'type': type.name, 'targetKg': targetKg, 'startDate': startDate};
}

class WeightEntry {
  const WeightEntry({required this.date, required this.kg});

  final String date;
  final double kg;
}

class ProgressStats {
  const ProgressStats({this.start, this.current, this.change, this.remaining, this.percent, this.ratePerWeek, this.eta});

  final WeightEntry? start;
  final WeightEntry? current;

  /// current - start, en kg.
  final double? change;

  /// target - current, en kg.
  final double? remaining;

  /// 0–100 hacia la meta (solo perder o ganar).
  final int? percent;

  /// Tendencia en kg por semana (regresión lineal de los últimos 28 días).
  final double? ratePerWeek;

  /// Fecha estimada para alcanzar la meta con la tendencia actual.
  final String? eta;
}

const _trendWindowDays = 28;

List<WeightEntry> sortByDate(Iterable<WeightEntry> entries) => [...entries]..sort((a, b) => a.date.compareTo(b.date));

/// Pendiente de mínimos cuadrados en kg/día; null con menos de 2 días distintos.
double? trendPerDay(List<WeightEntry> entries) {
  if (entries.length < 2) return null;
  final xs = entries.map((e) => dayIndex(e.date).toDouble()).toList();
  final n = xs.length;
  final mx = xs.reduce((a, b) => a + b) / n;
  final my = entries.fold<double>(0, (s, e) => s + e.kg) / n;
  var num = 0.0;
  var den = 0.0;
  for (var i = 0; i < n; i++) {
    num += (xs[i] - mx) * (entries[i].kg - my);
    den += (xs[i] - mx) * (xs[i] - mx);
  }
  return den == 0 ? null : num / den;
}

int _sign(double v) => v > 0 ? 1 : (v < 0 ? -1 : 0);

ProgressStats progressStats(List<WeightEntry> entries, BodyGoal? goal) {
  final sorted = sortByDate(entries);
  final current = sorted.lastOrNull;
  final WeightEntry? start = goal != null
      ? (sorted.where((e) => e.date.compareTo(goal.startDate) >= 0).firstOrNull ??
          sorted.where((e) => e.date.compareTo(goal.startDate) < 0).lastOrNull)
      : sorted.firstOrNull;

  final recent = current != null
      ? sorted.where((e) => e.date.compareTo(addDays(current.date, -_trendWindowDays)) >= 0).toList()
      : <WeightEntry>[];
  final slope = trendPerDay(recent);
  final ratePerWeek = slope == null ? null : round2(slope * 7);

  final target = goal?.targetKg;
  final change = start != null && current != null ? round1(current.kg - start.kg) : null;
  final remaining = target != null && current != null ? round1(target - current.kg) : null;

  double? percent;
  if (goal != null && goal.type != GoalType.maintain && target != null && start != null && current != null) {
    final total = target - start.kg;
    percent = total == 0 ? 100 : (((current.kg - start.kg) / total) * 100).clamp(0, 100).toDouble();
  }

  String? eta;
  if (remaining != null && slope != null && current != null && remaining.abs() >= 0.1 && _sign(slope) == _sign(remaining)) {
    final days = (remaining / slope).ceil();
    if (days > 0 && days < 365 * 3) eta = addDays(current.date, days);
  }

  return ProgressStats(
    start: start,
    current: current,
    change: change,
    remaining: remaining,
    percent: percent == null ? null : jsRound(percent),
    ratePerWeek: ratePerWeek,
    eta: eta,
  );
}
