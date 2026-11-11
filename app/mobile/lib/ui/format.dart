/// Textos de fechas y cantidades en español de Chile (sin depender de datos de locale).
library;

import 'package:flutter/material.dart';

import '../core/common/date.dart';
import '../core/common/numbers.dart';
import '../core/common/units.dart';
import '../core/nutrition/models.dart';
import '../core/strength/insights.dart';
import '../core/strength/models.dart';

const _weekdaysShort = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _weekdaysLong = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _monthsShort = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];
const _monthsLong = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "27 oct"
String shortDate(String key) {
  final d = fromDateKey(key);
  return '${d.day} ${_monthsShort[d.month - 1]}';
}

/// "lun, 27 oct"
String weekdayDate(String key) {
  final d = fromDateKey(key);
  return '${_weekdaysShort[d.weekday - 1]}, ${d.day} ${_monthsShort[d.month - 1]}';
}

/// "lun, 27 oct 2026"
String weekdayDateYear(String key) => '${weekdayDate(key)} ${fromDateKey(key).year}';

/// "lunes, 27 de octubre"
String longDate(String key) {
  final d = fromDateKey(key);
  return '${_weekdaysLong[d.weekday - 1]}, ${d.day} de ${_monthsLong[d.month - 1]}';
}

/// "octubre de 2026"
String monthYear(String key) {
  final d = fromDateKey(key);
  return '${_monthsLong[d.month - 1]} de ${d.year}';
}

String monthShort(String key) => _monthsShort[fromDateKey(key).month - 1];

/// "lun 27"
String weekdayDay(String key) {
  final d = fromDateKey(key);
  return '${_weekdaysShort[d.weekday - 1]} ${d.day}';
}

/// Fecha del selector de días: "Hoy · lun, 27 oct".
String dateLabel(String key, String today) => key == today ? 'Hoy · ${weekdayDate(key)}' : weekdayDate(key);

/// "hoy", "ayer", "hace 3 días"…
String relativeDay(String date) => date == todayKey() ? 'hoy' : sinceText(date, todayKey());

String formatKgValue(num n) => formatNumber(n, maxFractionDigits: 1);

/// Número de un peso guardado en kg, mostrado en `unit`: "61,25" en kg (discos de
/// 1,25) o "45" en lb (con un decimal, que basta para las libras).
String formatWeightValue(num kg, [WeightUnit unit = WeightUnit.kg]) =>
    unit == WeightUnit.kg ? formatKg(kg) : formatNumber(fromKg(kg.toDouble(), unit), maxFractionDigits: 1);

/// "45 lb", "20 kg".
String formatWeight(num kg, [WeightUnit unit = WeightUnit.kg]) => '${formatWeightValue(kg, unit)} ${unit.symbol}';

/// Volumen (guardado en kg) en la unidad pedida: "12.500 kg".
String formatVolume(num kg, [WeightUnit unit = WeightUnit.kg]) =>
    '${formatNumber(jsRound(fromKg(kg.toDouble(), unit)), maxFractionDigits: 0)} ${unit.symbol}';

String formatDuration(int min) {
  if (min < 60) return '$min min';
  final h = min ~/ 60;
  final m = min % 60;
  return m > 0 ? '$h h $m min' : '$h h';
}

/// "55 kg × 5", "45 lb × 10" o "12 reps".
String formatSet({double? kg, double? reps, WeightUnit unit = WeightUnit.kg}) {
  if (reps == null) return '—';
  return kg != null && kg > 0 ? '${formatWeight(kg, unit)} × ${plain(reps)}' : '${plain(reps)} reps';
}

/// Descanso: "1:30", "45 s" o "Sin descanso".
String formatRest(int seconds) {
  if (seconds <= 0) return 'Sin descanso';
  if (seconds < 60) return '$seconds s';
  return formatElapsed(Duration(seconds: seconds));
}

/// Cronómetro mm:ss (o h:mm:ss).
String formatElapsed(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = h > 0 ? m.toString().padLeft(2, '0') : '$m';
  return '${h > 0 ? '$h:' : ''}$mm:${s.toString().padLeft(2, '0')}';
}

/// Etiqueta de cada serie: "C" calentamiento, "F" al fallo, "D" drop y el número de serie efectiva.
List<String> setLabels(List<SetType> types) {
  var n = 0;
  final out = <String>[];
  for (final t in types) {
    if (t == SetType.warmup || t == SetType.drop) {
      out.add(t == SetType.warmup ? 'C' : 'D');
      continue;
    }
    n++;
    out.add(t == SetType.failure ? 'F' : '$n');
  }
  return out;
}

class MacroMeta {
  const MacroMeta(this.label, this.short, this.unit);

  final String label;
  final String short;
  final String unit;
}

const macroMeta = {
  MacroKey.kcal: MacroMeta('Calorías', 'kcal', 'kcal'),
  MacroKey.protein: MacroMeta('Proteína', 'P', 'g'),
  MacroKey.carbs: MacroMeta('Carbohidratos', 'C', 'g'),
  MacroKey.fat: MacroMeta('Grasa', 'G', 'g'),
  MacroKey.fiber: MacroMeta('Fibra', 'Fib', 'g'),
};

String formatMacro(MacroKey k, double v) => k == MacroKey.kcal ? '${jsRound(v)}' : formatNumber(v, maxFractionDigits: 1);

class MealMeta {
  const MealMeta(this.label, this.icon);

  final String label;
  final IconData icon;
}

const mealMeta = {
  MealSlot.desayuno: MealMeta('Desayuno', Icons.coffee_outlined),
  MealSlot.almuerzo: MealMeta('Almuerzo', Icons.soup_kitchen_outlined),
  MealSlot.once: MealMeta('Once', Icons.bakery_dining_outlined),
  MealSlot.cena: MealMeta('Cena', Icons.nightlight_outlined),
  MealSlot.snack: MealMeta('Snack', Icons.apple),
};

/// Comida sugerida según la hora local.
MealSlot mealForNow([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 11) return MealSlot.desayuno;
  if (h < 16) return MealSlot.almuerzo;
  if (h < 20) return MealSlot.once;
  return MealSlot.cena;
}
