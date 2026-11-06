/// Carga de entrenamiento: cuánto pesa cada sesión y cómo se acumula en el tiempo,
/// separada en fuerza y resistencia (cardio).
///
/// - **Carga de una sesión** (Foster et al., 2001): esfuerzo percibido (RPE de la
///   escala CR-10) × minutos. Se mide en unidades arbitrarias (UA) y sirve igual
///   para fuerza y para cardio, así las dos disciplinas se pueden comparar.
/// - **Carga aguda (ATL) y crónica (CTL)**: medias móviles exponenciales de la carga
///   diaria con constantes de 7 y 42 días (modelo de Banister, como el PMC de
///   TrainingPeaks). TSB = CTL − ATL: negativo = acumulando fatiga.
/// - **Razón ATL/CTL**: cuánto se entrenó la última semana frente a lo habitual.
///   Las zonas siguen a Gabbett (2016): 0,8–1,3 es lo habitual y sobre 1,5 el
///   riesgo de lesión sube. Es una señal de apoyo, no un diagnóstico.
library;

import 'dart:math' as math;

import '../cardio/activity.dart';
import '../common/date.dart';
import '../strength/models.dart';

/// Etiquetas de la escala CR-10 de Foster (índice = valor).
const rpeLabels = [
  'Reposo',
  'Muy, muy suave',
  'Suave',
  'Moderado',
  'Algo duro',
  'Duro',
  'Duro',
  'Muy duro',
  'Muy duro',
  'Casi máximo',
  'Máximo',
];

String rpeLabel(int rpe) => rpeLabels[rpe.clamp(0, 10)];

enum LoadKind { strength, cardio }

/// Esfuerzo típico de una sesión de fuerza cuando no se indicó (las sesiones de
/// pesas suelen quedar entre 5 y 7 en la CR-10).
const defaultStrengthRpe = 6;

/// Tope de duración de una sesión de fuerza: una sesión olvidada abierta no debe
/// sumar una carga imposible.
const maxStrengthMinutes = 180;

class SessionLoad {
  const SessionLoad({required this.date, required this.kind, required this.minutes, required this.rpe, required this.estimated});

  /// Día local (YYYY-MM-DD).
  final String date;
  final LoadKind kind;
  final double minutes;
  final int rpe;

  /// true si el RPE no lo indicó el usuario: se estimó (menos confiable).
  final bool estimated;

  /// Carga de la sesión en UA (RPE × minutos).
  double get load => rpe * minutes;
}

SessionLoad strengthSessionLoad(Workout w) {
  final minutes = math.min(maxStrengthMinutes, math.max(0, (w.finishedAt - w.startedAt) / 60000)).toDouble();
  return SessionLoad(date: w.date, kind: LoadKind.strength, minutes: minutes, rpe: w.rpe ?? defaultStrengthRpe, estimated: w.rpe == null);
}

/// RPE aproximado de una ruta sin RPE: a partir del MET de su velocidad media
/// (≈ 3 trote suave en bici, 5 trote, 7 carrera rápida). En trekking, subir más de
/// 300 m por hora suma un punto, porque el desnivel cansa más que la distancia.
int estimateCardioRpe(Discipline d, CardioStats s) {
  final met = metFor(d, s.avgSpeedMs * 3.6);
  var rpe = (met / 2 + 1).round();
  if (d == Discipline.trekking && s.ascentRateMh >= 300) rpe++;
  return rpe.clamp(2, 8);
}

/// En cardio cuenta el tiempo total sin pausas manuales (incluye detenciones breves,
/// como semáforos o descansos en un cerro, que también son parte de la sesión).
SessionLoad cardioSessionLoad(CardioActivity a) => SessionLoad(
      date: a.date,
      kind: LoadKind.cardio,
      minutes: a.stats.durationS / 60,
      rpe: a.rpe ?? estimateCardioRpe(a.discipline, a.stats),
      estimated: a.rpe == null,
    );

/// Constantes de tiempo (días) de la carga aguda y la crónica.
const atlDays = 7;
const ctlDays = 42;

/// Días de historial necesarios para que la carga crónica (y la razón) sean
/// confiables: antes, la CTL todavía va subiendo y la razón sale inflada.
const minHistoryDays = 28;

/// Razón ATL/CTL desde la que se considera alta por defecto (configurable en las alertas).
const defaultRatioThreshold = 1.3;

double _k(int days) => 1 - math.exp(-1 / days);

class LoadState {
  const LoadState({this.atl = 0, this.ctl = 0});

  final double atl;
  final double ctl;

  /// Balance (forma): negativo = más fatiga reciente que lo habitual.
  double get tsb => ctl - atl;

  /// null si aún no hay carga crónica.
  double? get ratio => ctl < 1 ? null : atl / ctl;

  LoadState next(double load) => LoadState(atl: atl + (load - atl) * _k(atlDays), ctl: ctl + (load - ctl) * _k(ctlDays));
}

/// Zonas de la razón ATL/CTL (Gabbett, 2016): bajo 0,8 se está entrenando menos que
/// lo habitual; 0,8–1,3 es lo esperable; 1,3–1,5 es un aumento brusco; sobre 1,5, muy brusco.
enum RatioZone { low, normal, high, veryHigh }

RatioZone ratioZone(double ratio) {
  if (ratio > 1.5) return RatioZone.veryHigh;
  if (ratio > 1.3) return RatioZone.high;
  if (ratio < 0.8) return RatioZone.low;
  return RatioZone.normal;
}

class LoadDay {
  const LoadDay({required this.date, required this.strengthLoad, required this.cardioLoad, required this.strength, required this.cardio, required this.total});

  final String date;

  /// Carga de las sesiones de ese día (UA).
  final double strengthLoad;
  final double cardioLoad;

  /// Estado al final del día, por disciplina y en conjunto.
  final LoadState strength;
  final LoadState cardio;
  final LoadState total;

  double get load => strengthLoad + cardioLoad;
}

class LoadSeries {
  const LoadSeries({required this.days, required this.firstSession});

  /// Un día por fecha, en orden, hasta el día pedido (incluido).
  final List<LoadDay> days;

  /// Fecha de la primera sesión registrada (null si no hay ninguna).
  final String? firstSession;

  LoadDay? get last => days.lastOrNull;

  /// Días entre la primera sesión y el último día de la serie.
  int get historyDays => firstSession == null || days.isEmpty ? 0 : daysBetween(firstSession!, days.last.date) + 1;

  bool get reliable => historyDays >= minHistoryDays;
}

/// Carga diaria y su acumulación desde la primera sesión hasta `to`.
/// Las sesiones posteriores a `to` se ignoran.
LoadSeries loadSeries(Iterable<SessionLoad> sessions, {required String to}) {
  final byDay = <String, (double, double)>{};
  String? first;
  for (final s in sessions) {
    if (s.date.compareTo(to) > 0) continue;
    final (st, ca) = byDay[s.date] ?? (0.0, 0.0);
    byDay[s.date] = s.kind == LoadKind.strength ? (st + s.load, ca) : (st, ca + s.load);
    if (first == null || s.date.compareTo(first) < 0) first = s.date;
  }
  if (first == null) return const LoadSeries(days: [], firstSession: null);

  final days = <LoadDay>[];
  var strength = const LoadState();
  var cardio = const LoadState();
  var total = const LoadState();
  for (var d = first; d.compareTo(to) <= 0; d = addDays(d, 1)) {
    final (st, ca) = byDay[d] ?? (0.0, 0.0);
    strength = strength.next(st);
    cardio = cardio.next(ca);
    total = total.next(st + ca);
    days.add(LoadDay(date: d, strengthLoad: st, cardioLoad: ca, strength: strength, cardio: cardio, total: total));
  }
  return LoadSeries(days: days, firstSession: first);
}

/// Atajo: carga de los entrenamientos de fuerza y las rutas de cardio hasta `to`.
LoadSeries trainingLoad({required Iterable<Workout> workouts, required Iterable<CardioActivity> activities, required String to}) => loadSeries([
      for (final w in workouts) strengthSessionLoad(w),
      for (final a in activities) cardioSessionLoad(a),
    ], to: to);
