/// Lo que muestra la sección de fatiga cruzada, calculado una vez: de dónde viene
/// la carga, la razón ATL/CTL día a día y las sesiones de la última semana. Y el
/// resumen de datos que se le entrega al asistente para que lo explique.
///
/// El asistente **solo explica**: las cifras, las zonas y las alertas salen del
/// motor (`load.dart`, `suggestions/alerts.dart`), que es lo que define la tesis.
library;

import '../cardio/activity.dart';
import '../common/date.dart';
import '../common/numbers.dart';
import '../strength/models.dart';
import '../suggestions/alerts.dart';
import '../suggestions/weekly_plan.dart';
import 'load.dart';

/// Una sesión de la última semana con su carga.
class LoadedSession {
  const LoadedSession({required this.load, required this.title, required this.route, required this.startedAt});

  final SessionLoad load;
  final String title;

  /// Pantalla de la sesión.
  final String route;
  final int startedAt;
}

/// Carga de una disciplina en la última semana.
class DisciplineLoad {
  const DisciplineLoad({required this.state, required this.week, required this.share});

  final LoadState state;

  /// Carga de los últimos 7 días (UA).
  final double week;

  /// Parte de la carga total de la semana (0 a 1).
  final double share;
}

class FatigueView {
  const FatigueView({required this.series, required this.strength, required this.cardio, required this.ratios, required this.sessions});

  final LoadSeries series;
  final DisciplineLoad strength;
  final DisciplineLoad cardio;

  /// Razón ATL/CTL total de cada día (null mientras no hay carga crónica).
  final List<(String, double?)> ratios;

  /// Sesiones de los últimos 7 días, de la más reciente a la más antigua.
  final List<LoadedSession> sessions;

  /// Más de la mitad de las sesiones de la semana con el esfuerzo estimado.
  bool get mostlyEstimated => sessions.isNotEmpty && sessions.where((s) => s.load.estimated).length * 2 > sessions.length;
}

FatigueView fatigueView({required List<Workout> workouts, required List<CardioActivity> activities, required String today}) {
  final series = trainingLoad(workouts: workouts, activities: activities, to: today);
  final week = series.days.length <= 7 ? series.days : series.days.sublist(series.days.length - 7);
  final strengthWeek = week.fold<double>(0, (a, d) => a + d.strengthLoad);
  final cardioWeek = week.fold<double>(0, (a, d) => a + d.cardioLoad);
  final total = strengthWeek + cardioWeek;
  final last = series.last;
  final from = addDays(today, -6);
  final sessions = <LoadedSession>[
    for (final w in workouts)
      if (w.date.compareTo(from) >= 0 && w.date.compareTo(today) <= 0)
        LoadedSession(load: strengthSessionLoad(w), title: w.name, route: '/fuerza/historial/${w.id}', startedAt: w.startedAt),
    for (final a in activities)
      if (a.date.compareTo(from) >= 0 && a.date.compareTo(today) <= 0)
        LoadedSession(load: cardioSessionLoad(a), title: a.title.isEmpty ? a.discipline.label : a.title, route: '/cardio/historial/${a.id}', startedAt: a.startedAt),
  ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  return FatigueView(
    series: series,
    strength: DisciplineLoad(state: last?.strength ?? const LoadState(), week: strengthWeek, share: total == 0 ? 0 : strengthWeek / total),
    cardio: DisciplineLoad(state: last?.cardio ?? const LoadState(), week: cardioWeek, share: total == 0 ? 0 : cardioWeek / total),
    ratios: [for (final d in series.days) (d.date, d.total.ratio)],
    sessions: sessions,
  );
}

double _r(double v) => round2(v);

/// Datos para que el asistente explique la semana. Solo cifras del motor y
/// tipos de sesión: nada que identifique a la persona.
Map<String, dynamic> fatigueBrief({
  required FatigueView view,
  required String today,
  required double threshold,
  List<FatigueAlert> alerts = const [],
  WeeklyPlan? plan,
  int? deficitPct,
}) {
  final last = view.series.last;
  final ratio = last?.total.ratio;
  final recent = view.series.days.length <= 14 ? view.series.days : view.series.days.sublist(view.series.days.length - 14);
  final weekday = fromDateKey(today).weekday;
  return {
    'hoy': today,
    'diasDeHistorial': view.series.historyDays,
    'historialSuficiente': view.series.reliable,
    'umbralDeAviso': threshold,
    'razonAgudaCronica': ratio == null ? null : _r(ratio),
    'zona': ratio == null
        ? null
        : switch (ratioZone(ratio)) {
            RatioZone.low => 'bajo lo habitual (< 0,8)',
            RatioZone.normal => 'habitual (0,8 a 1,3)',
            RatioZone.high => 'aumento brusco (1,3 a 1,5)',
            RatioZone.veryHigh => 'aumento muy brusco (> 1,5)',
          },
    'cargaTotal': {'aguda': _r(last?.total.atl ?? 0), 'cronica': _r(last?.total.ctl ?? 0)},
    'fuerza': {'aguda': _r(view.strength.state.atl), 'cronica': _r(view.strength.state.ctl), 'cargaSemana': view.strength.week.round(), 'parteDeLaSemana': _r(view.strength.share)},
    'cardio': {'aguda': _r(view.cardio.state.atl), 'cronica': _r(view.cardio.state.ctl), 'cargaSemana': view.cardio.week.round(), 'parteDeLaSemana': _r(view.cardio.share)},
    'cargaPorDia': [for (final d in recent) {'fecha': d.date, 'fuerza': d.strengthLoad.round(), 'cardio': d.cardioLoad.round()}],
    'sesionesSemana': [
      for (final s in view.sessions)
        {
          'fecha': s.load.date,
          'tipo': s.load.kind == LoadKind.strength ? 'fuerza' : 'cardio',
          'minutos': s.load.minutes.round(),
          'rpe': s.load.rpe,
          'rpeEstimado': s.load.estimated,
          'carga': s.load.load.round(),
        },
    ],
    'proximasSesionesPlan': plan == null
        ? <Map<String, dynamic>>[]
        : [
            for (var k = 0; k < 3; k++)
              for (final s in plan.on((weekday - 1 + k) % 7 + 1))
                {'cuando': k == 0 ? 'hoy' : (k == 1 ? 'mañana' : 'pasado mañana'), 'tipo': s.kind == SessionKind.strength ? 'fuerza' : 'cardio', 'sesion': s.title, 'minutos': s.minutes},
          ],
    'alertasDelMotor': [for (final a in alerts) {'titulo': a.title, 'sugerencia': a.suggestion}],
    'deficitCaloricoPct': deficitPct,
  };
}
