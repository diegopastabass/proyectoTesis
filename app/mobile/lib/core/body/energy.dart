/// Gasto calórico estimado y sugerencia de objetivos diarios.
///
/// Dos estimaciones del gasto diario total:
/// - Fórmula: Mifflin-St Jeor × factor de actividad. Es la ecuación que más veces
///   queda dentro de ±10 % del gasto medido (Frankenfield et al., 2005), pero el
///   error individual puede ser grande.
/// - Con tus registros: ingesta promedio menos el cambio de peso convertido en
///   calorías. Necesita algunas semanas de registro constante, pero se ajusta a
///   la persona.
library;

import 'dart:math' as math;

import '../activity/calendar.dart';
import '../common/date.dart';
import '../common/numbers.dart';
import '../nutrition/models.dart';
import 'progress.dart';

enum Sex { male, female }

/// Actividad total de una semana normal, entrenamientos incluidos.
enum ActivityLevel {
  sedentary(1.2),
  light(1.375),
  moderate(1.55),
  high(1.725),
  veryHigh(1.9);

  const ActivityLevel(this.factor);

  final double factor;
}

/// Datos corporales para estimar el gasto (campo `body` del perfil).
class BodyProfile {
  const BodyProfile({this.heightCm, this.birthDate, this.sex, this.activity = ActivityLevel.moderate});

  factory BodyProfile.fromMap(Object? data) {
    if (data is! Map) return const BodyProfile();
    final birth = data['birthDate'] as String?;
    return BodyProfile(
      heightCm: (data['heightCm'] as num?)?.toDouble(),
      birthDate: isDateKey(birth) ? birth : null,
      sex: Sex.values.where((s) => s.name == data['sex']).firstOrNull,
      activity: ActivityLevel.values.where((a) => a.name == data['activity']).firstOrNull ?? ActivityLevel.moderate,
    );
  }

  final double? heightCm;

  /// YYYY-MM-DD.
  final String? birthDate;
  final Sex? sex;
  final ActivityLevel activity;

  bool get complete => heightCm != null && birthDate != null && sex != null;

  Map<String, dynamic> toMap() => {'heightCm': heightCm, 'birthDate': birthDate, 'sex': sex?.name, 'activity': activity.name};
}

/// Años cumplidos en `today`.
int ageOn(String birthDate, String today) {
  final b = fromDateKey(birthDate);
  final t = fromDateKey(today);
  final hadBirthday = t.month > b.month || (t.month == b.month && t.day >= b.day);
  return t.year - b.year - (hadBirthday ? 0 : 1);
}

/// Gasto en reposo (kcal/día) según Mifflin-St Jeor (1990).
double mifflinStJeor({required double kg, required double heightCm, required int age, required Sex sex}) =>
    10 * kg + 6.25 * heightCm - 5 * age + (sex == Sex.male ? 5 : -161);

class FormulaEnergy {
  const FormulaEnergy({required this.bmr, required this.tdee});

  /// Gasto en reposo.
  final int bmr;

  /// Gasto diario total.
  final int tdee;
}

/// Gasto por fórmula; null si faltan datos del perfil o el peso.
FormulaEnergy? formulaEnergy(BodyProfile p, double? kg, String today) {
  if (!p.complete || kg == null || kg <= 0) return null;
  final bmr = mifflinStJeor(kg: kg, heightCm: p.heightCm!, age: ageOn(p.birthDate!, today), sex: p.sex!);
  return FormulaEnergy(bmr: jsRound(bmr), tdee: _round10(bmr * p.activity.factor));
}

/// kcal por kg de cambio de peso corporal (aproximación habitual de 7700 kcal/kg).
const kcalPerKg = 7700.0;

/// Ventana de días para estimar el gasto con los registros.
const observedWindowDays = 28;

/// Días registrados que se piden como mínimo dentro de la ventana.
const minObservedDays = 14;

/// Días mínimos entre el primer y el último peso de la ventana.
const minWeightSpanDays = 14;

class ObservedEnergy {
  const ObservedEnergy({required this.tdee, required this.avgIntake, required this.days, required this.ratePerWeek});

  final int tdee;
  final int avgIntake;

  /// Días registrados que se usaron.
  final int days;

  /// Tendencia del peso (kg por semana).
  final double ratePerWeek;
}

/// Qué falta para estimar el gasto con los registros.
class ObservedProgress {
  const ObservedProgress({required this.loggedDays, required this.weighIns, required this.weightSpanDays});

  final int loggedDays;
  final int weighIns;
  final int weightSpanDays;
}

List<LoggedDay> _windowDays(Iterable<LoggedDay> days, String today) {
  final from = addDays(today, -observedWindowDays);
  // Hoy queda fuera: el día aún no termina.
  final inWindow = days.where((d) => d.entries > 0 && d.kcal > 0 && d.date.compareTo(from) >= 0 && d.date.compareTo(today) < 0).toList();
  if (inWindow.isEmpty) return inWindow;
  // Días anotados a medias (bajo la mitad de la mediana) sesgarían la ingesta hacia abajo.
  final sorted = inWindow.map((d) => d.kcal).toList()..sort();
  final median = sorted[sorted.length ~/ 2];
  return inWindow.where((d) => d.kcal >= median / 2).toList();
}

List<WeightEntry> _windowWeights(List<WeightEntry> weights, String today) {
  final from = addDays(today, -observedWindowDays);
  return sortByDate(weights.where((w) => w.date.compareTo(from) >= 0 && w.date.compareTo(today) <= 0));
}

ObservedProgress observedProgress(Iterable<LoggedDay> days, List<WeightEntry> weights, String today) {
  final w = _windowWeights(weights, today);
  return ObservedProgress(
    loggedDays: _windowDays(days, today).length,
    weighIns: w.length,
    weightSpanDays: w.length < 2 ? 0 : daysBetween(w.first.date, w.last.date),
  );
}

/// Gasto real estimado con las últimas 4 semanas; null si aún faltan datos.
ObservedEnergy? observedEnergy(Iterable<LoggedDay> days, List<WeightEntry> weights, String today) {
  final logged = _windowDays(days, today);
  final w = _windowWeights(weights, today);
  if (logged.length < minObservedDays || w.length < 3 || daysBetween(w.first.date, w.last.date) < minWeightSpanDays) return null;
  final slope = trendPerDay(w);
  if (slope == null) return null;
  final avg = logged.fold<double>(0, (s, d) => s + d.kcal) / logged.length;
  final tdee = avg - slope * kcalPerKg;
  // Un resultado fuera de rango indica registros incompletos, no un gasto real.
  if (tdee < 1200 || tdee > 6000) return null;
  return ObservedEnergy(tdee: _round10(tdee), avgIntake: jsRound(avg), days: logged.length, ratePerWeek: round2(slope * 7));
}

/// Ajuste sobre el gasto según la meta corporal.
const goalFactor = {GoalType.lose: 0.85, GoalType.maintain: 1.0, GoalType.gain: 1.10};

/// Proteína (g/kg): 1,6–2,2 en general; 2,2–2,8 en déficit para conservar masa
/// muscular (ISSN 2017: 1,4–2,0 g/kg y 2,3–3,1 g/kg en déficit en personas entrenadas).
Range proteinPerKg(GoalType goal) => goal == GoalType.lose ? const Range(2.2, 2.8) : const Range(1.6, 2.2);

/// Grasa: 20–30 % de las calorías.
const fatShare = Range(0.20, 0.30);

/// Fibra: 14 g cada 1000 kcal.
const fiberPer1000Kcal = 14.0;

/// Objetivos diarios sugeridos. Los pesos del puntaje se conservan de `current`.
Goals suggestGoals({required int tdee, required double kg, required GoalType goal, required Goals current}) {
  final target = tdee * goalFactor[goal]!;
  final protein = proteinPerKg(goal);
  final pMid = kg * (protein.min + protein.max) / 2;
  final fMid = target * (fatShare.min + fatShare.max) / 2 / 9;
  final cMid = math.max(0.0, (target - pMid * 4 - fMid * 9) / 4);
  final fiberMin = math.max(25.0, target / 1000 * fiberPer1000Kcal);
  return Goals(
    ranges: {
      MacroKey.kcal: Range(_round10(target * 0.95).toDouble(), _round10(target * 1.05).toDouble()),
      MacroKey.protein: Range(_round5(kg * protein.min), _round5(kg * protein.max)),
      MacroKey.carbs: Range(_round5(cMid * 0.85), _round5(cMid * 1.15)),
      MacroKey.fat: Range(_round5(target * fatShare.min / 9), _round5(target * fatShare.max / 9)),
      MacroKey.fiber: Range(_round5(fiberMin), _round5(fiberMin + 15)),
    },
    weights: current.weights,
  );
}

int _round10(double v) => jsRound(v / 10) * 10;

double _round5(double v) => (jsRound(v / 5) * 5).toDouble();
