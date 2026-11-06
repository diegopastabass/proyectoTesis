import '../common/date.dart';

/// Lunes de la semana de `date` (semanas de lunes a domingo).
String weekStart(String date) {
  final weekday = fromDateKey(date).weekday; // 1 = lunes … 7 = domingo
  return addDays(date, -(weekday - 1));
}

class HeatDay {
  const HeatDay({required this.date, required this.count, required this.future});

  final String date;
  final int count;

  /// Día posterior a `today`: se dibuja vacío.
  final bool future;

  @override
  bool operator ==(Object other) => other is HeatDay && other.date == date && other.count == count && other.future == future;

  @override
  int get hashCode => Object.hash(date, count, future);
}

/// Cuántas sesiones hubo cada día.
Map<String, int> countByDate(Iterable<String> dates) {
  final map = <String, int>{};
  for (final d in dates) {
    map[d] = (map[d] ?? 0) + 1;
  }
  return map;
}

/// Columnas de un mapa de calor tipo calendario: `weeks` semanas (lunes a
/// domingo) que terminan en la semana de `today`.
List<List<HeatDay>> heatmapWeeks(Map<String, int> counts, String today, int weeks) {
  final firstMonday = addDays(weekStart(today), -7 * (weeks - 1));
  return List.generate(
    weeks,
    (w) => List.generate(7, (d) {
      final date = addDays(firstMonday, w * 7 + d);
      return HeatDay(date: date, count: counts[date] ?? 0, future: date.compareTo(today) > 0);
    }),
  );
}

/// Semanas seguidas con al menos un entrenamiento. La semana actual cuenta si ya
/// tiene uno; si aún no, la racha se mide hasta la semana pasada (no se corta).
int weeklyStreak(Iterable<String> dates, String today) {
  final weeks = dates.map(weekStart).toSet();
  var cursor = weekStart(today);
  if (!weeks.contains(cursor)) cursor = addDays(cursor, -7);
  var streak = 0;
  while (weeks.contains(cursor)) {
    streak++;
    cursor = addDays(cursor, -7);
  }
  return streak;
}

/// Días distintos con entrenamiento entre `from` y `to` (inclusive).
int trainedDaysBetween(Iterable<String> dates, String from, String to) =>
    dates.where((d) => d.compareTo(from) >= 0 && d.compareTo(to) <= 0).toSet().length;
