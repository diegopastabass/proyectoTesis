/// Fechas locales como claves `YYYY-MM-DD`, igual que en la versión web
/// (los documentos de Firestore usan estas claves como id).
library;

String _two(int n) => n.toString().padLeft(2, '0');

/// Fecha local en formato YYYY-MM-DD.
String toDateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

String todayKey([DateTime? now]) => toDateKey(now ?? DateTime.now());

DateTime fromDateKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String addDays(String key, int days) {
  final d = fromDateKey(key);
  return toDateKey(DateTime(d.year, d.month, d.day + days));
}

final _dateKeyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

bool isDateKey(String? s) => s != null && _dateKeyPattern.hasMatch(s);

/// Número de día absoluto (independiente de la zona horaria y del horario de verano).
int dayIndex(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}

/// Días entre dos claves (`to - from`).
int daysBetween(String from, String to) => dayIndex(to) - dayIndex(from);
