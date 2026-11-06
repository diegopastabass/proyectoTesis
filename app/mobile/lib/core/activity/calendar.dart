/// Actividad por día: qué se registró en cada módulo. Alimenta el calendario de
/// actividad y la racha de uso.
library;

import '../cardio/activity.dart';
import '../common/date.dart';
import '../strength/models.dart';

enum ActivityKind { nutrition, strength, cardio }

/// Resumen del diario de un día (documento `users/{uid}/days/{fecha}`). Se
/// actualiza en la misma escritura que agrega o borra registros.
class LoggedDay {
  const LoggedDay({required this.date, required this.entries, required this.kcal, this.onTime = true});

  factory LoggedDay.fromMap(String date, Map<String, dynamic> m) => LoggedDay(
        date: date,
        entries: (m['entries'] as num?)?.toInt() ?? 0,
        kcal: (m['kcal'] as num?)?.toDouble() ?? 0,
        onTime: m['onTime'] == true,
      );

  final String date;

  /// Cantidad de registros del diario.
  final int entries;

  /// Suma de calorías de los registros (para estimar el gasto real).
  final double kcal;

  /// true si algo se registró a tiempo (ver [loggedOnTime]).
  final bool onTime;

  @override
  bool operator ==(Object other) =>
      other is LoggedDay && other.date == date && other.entries == entries && other.kcal == kcal && other.onTime == onTime;

  @override
  int get hashCode => Object.hash(date, entries, kcal, onTime);
}

/// Días de atraso con que un registro todavía suma a la racha.
const lateGraceDays = 1;

/// Un registro del día `date` hecho el día `loggedOn` cuenta para la racha si se
/// hizo ese mismo día o el siguiente (anotar el almuerzo de ayer, sí; rellenar la
/// semana pasada, no).
bool loggedOnTime(String date, String loggedOn) => daysBetween(date, loggedOn) <= lateGraceDays;

class DayActivity {
  const DayActivity({
    required this.date,
    this.entries = 0,
    this.kcal = 0,
    this.workouts = 0,
    this.cardio = 0,
    this.kinds = const {},
    this.onTime = const {},
  });

  final String date;
  final int entries;
  final double kcal;
  final int workouts;

  /// Actividades de cardio (rutas).
  final int cardio;

  /// Módulos con registros ese día.
  final Set<ActivityKind> kinds;

  /// Módulos registrados a tiempo: solo estos suman a la racha.
  final Set<ActivityKind> onTime;

  bool has(ActivityKind k) => kinds.contains(k);

  /// El día suma a la racha.
  bool get counts => onTime.isNotEmpty;

  /// Hubo registros, pero todos llegaron tarde.
  bool get late => kinds.isNotEmpty && onTime.isEmpty;
}

/// Une el índice del diario, los entrenamientos y las rutas de cardio en un mapa fecha → actividad.
Map<String, DayActivity> buildActivity({required Iterable<LoggedDay> days, required Iterable<Workout> workouts, Iterable<CardioActivity> cardio = const []}) {
  final entries = <String, int>{};
  final kcal = <String, double>{};
  final kinds = <String, Set<ActivityKind>>{};
  final onTime = <String, Set<ActivityKind>>{};
  final workoutCount = <String, int>{};
  final cardioCount = <String, int>{};

  for (final d in days) {
    if (d.entries <= 0) continue;
    entries[d.date] = d.entries;
    kcal[d.date] = d.kcal;
    kinds.putIfAbsent(d.date, () => {}).add(ActivityKind.nutrition);
    if (d.onTime) onTime.putIfAbsent(d.date, () => {}).add(ActivityKind.nutrition);
  }
  for (final w in workouts) {
    if (!isDateKey(w.date)) continue;
    workoutCount[w.date] = (workoutCount[w.date] ?? 0) + 1;
    kinds.putIfAbsent(w.date, () => {}).add(ActivityKind.strength);
    if (loggedOnTime(w.date, toDateKey(DateTime.fromMillisecondsSinceEpoch(w.finishedAt)))) {
      onTime.putIfAbsent(w.date, () => {}).add(ActivityKind.strength);
    }
  }
  for (final a in cardio) {
    cardioCount[a.date] = (cardioCount[a.date] ?? 0) + 1;
    kinds.putIfAbsent(a.date, () => {}).add(ActivityKind.cardio);
    if (loggedOnTime(a.date, toDateKey(DateTime.fromMillisecondsSinceEpoch(a.finishedAt)))) {
      onTime.putIfAbsent(a.date, () => {}).add(ActivityKind.cardio);
    }
  }
  return {
    for (final date in kinds.keys)
      date: DayActivity(
        date: date,
        entries: entries[date] ?? 0,
        kcal: kcal[date] ?? 0,
        workouts: workoutCount[date] ?? 0,
        cardio: cardioCount[date] ?? 0,
        kinds: kinds[date]!,
        onTime: onTime[date] ?? const {},
      ),
  };
}

/// Primer día del mes de `date`.
String monthStart(String date) => '${date.substring(0, 7)}-01';

/// Primer día del mes siguiente (o anterior, con `delta` negativo).
String addMonths(String date, int delta) {
  final d = fromDateKey(date);
  return toDateKey(DateTime(d.year, d.month + delta, 1));
}

/// Semanas (lunes a domingo) del mes de `date`; null en los días de otros meses.
List<List<String?>> monthWeeks(String date) {
  final first = monthStart(date);
  final next = addMonths(first, 1);
  var cursor = addDays(first, -(fromDateKey(first).weekday - 1));
  final weeks = <List<String?>>[];
  while (cursor.compareTo(next) < 0) {
    weeks.add([
      for (var i = 0; i < 7; i++)
        () {
          final d = addDays(cursor, i);
          return d.compareTo(first) >= 0 && d.compareTo(next) < 0 ? d : null;
        }(),
    ]);
    cursor = addDays(cursor, 7);
  }
  return weeks;
}
