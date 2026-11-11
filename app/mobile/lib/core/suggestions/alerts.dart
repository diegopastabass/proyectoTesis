/// Alertas de fatiga cruzada e interferencia (CU-05, R03, RNF-03).
///
/// Reglas de la Tabla de definiciones operativas (cap. 3) y de los requisitos
/// específicos del motor de fatiga (cap. 6):
///
/// | Alerta | Se dispara cuando |
/// |---|---|
/// | Fatiga cruzada | La razón ATL/CTL total supera el umbral (1,3 por defecto, configurable), hay al menos 28 días de historial y el plan tiene una sesión de la otra disciplina en las próximas 24 horas |
/// | Aumento brusco | La razón supera el umbral, pero no hay una sesión de la otra disciplina cerca (o no hay plan) |
/// | Poca separación | Una sesión de fuerza y una de cardio con menos de 6 horas entre el fin de una y el inicio de la otra |
/// | Patrón repetido | Poca separación en dos o más días seguidos de la última semana: sugerir reorganizar |
/// | Comer poco | La ingesta promedio de los últimos 7 días está más de un 20 % bajo el gasto estimado. También se suma como razón a la de fatiga cruzada |
///
/// Si la mayoría de las sesiones de la última semana tienen el esfuerzo (RPE)
/// estimado, las alertas de carga bajan un nivel y lo dicen (RNF-03: confianza).
/// Son señales de apoyo y no diagnósticos: el usuario decide.
library;

import '../activity/calendar.dart';
import '../activity/reminders.dart';
import '../cardio/activity.dart';
import '../common/date.dart';
import '../common/numbers.dart';
import '../strength/models.dart';
import '../training/load.dart';
import 'reason.dart';
import 'weekly_plan.dart';

enum AlertKind { crossFatigue, loadSpike, shortGap, repeatedShortGaps, lowEnergy }

enum Severity { info, warning, important }

/// Separación mínima recomendada entre una sesión de fuerza y una de cardio.
const minGapHours = 6;

/// Días hacia atrás en que se revisa la separación entre sesiones.
const gapLookbackDays = 7;

/// Una sesión de poca separación se avisa sola solo si es reciente (hasta 3 días).
const recentGapDays = 3;

/// Déficit desde el cual se menciona que se está comiendo poco (20 % bajo el gasto).
const lowEnergyShare = 0.2;

/// Días con registros que se piden en la última semana para hablar de déficit.
const minIntakeDays = 4;

class FatigueAlert {
  const FatigueAlert({
    required this.id,
    required this.kind,
    required this.severity,
    required this.title,
    required this.text,
    required this.why,
    this.suggestion,
    this.session,
    this.sessionDate,
  });

  /// Estable mientras la situación sea la misma: sirve para no repetir una alerta respondida.
  final String id;
  final AlertKind kind;
  final Severity severity;
  final String title;
  final String text;
  final List<Reason> why;

  /// Qué hacer, en una frase. null si la alerta es solo informativa.
  final String? suggestion;

  /// Sesión planificada a la que se refiere (fatiga cruzada).
  final PlannedSession? session;
  final String? sessionDate;

  /// Texto corto para la notificación.
  String get notificationBody => suggestion == null ? text : '$title. $suggestion';

  @override
  String toString() => 'FatigueAlert(${kind.name}, ${severity.name}, $title)';
}

class AlertContext {
  const AlertContext({
    required this.now,
    this.workouts = const [],
    this.cardio = const [],
    this.plan,
    this.days = const [],
    this.dailyExpenditure,
    this.ratioThreshold = defaultRatioThreshold,
  });

  final DateTime now;

  /// Sesiones de fuerza y rutas de cardio registradas.
  final List<Workout> workouts;
  final List<CardioActivity> cardio;

  /// Plan semanal aceptado (para saber qué viene en las próximas 24 horas).
  final WeeklyPlan? plan;

  /// Resumen del diario por día (calorías ingeridas).
  final List<LoggedDay> days;

  /// Gasto diario estimado (con los registros o con la fórmula); null si no se sabe.
  final int? dailyExpenditure;

  /// Razón ATL/CTL desde la que se avisa.
  final double ratioThreshold;
}

String _ratio(double r) => r.toStringAsFixed(2).replaceAll('.', ',');

String _clock(DateTime d) => '${d.hour}:${d.minute.toString().padLeft(2, '0')}';

String _gap(Duration d) {
  final m = d.inMinutes < 0 ? 0 : d.inMinutes;
  if (m < 60) return '$m min';
  return m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60} min';
}

const _weekdayLong = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

String _dayName(String date, String today) {
  final diff = daysBetween(date, today);
  if (diff == 0) return 'hoy';
  if (diff == 1) return 'ayer';
  return 'el ${_weekdayLong[fromDateKey(date).weekday - 1]}';
}

// ---------------------------------------------------------------------------
// Carga: fatiga cruzada y aumento brusco
// ---------------------------------------------------------------------------

/// Próxima sesión del plan de la disciplina `kind` en las próximas 24 horas: lo
/// que queda de hoy (si aún no se registró una de ese tipo) y mañana.
({PlannedSession session, String date})? _upcoming(AlertContext c, SessionKind kind, {required bool trainedTodayOfKind}) {
  final plan = c.plan;
  if (plan == null) return null;
  final today = toDateKey(c.now);
  final candidates = <({PlannedSession session, String date})>[
    if (!trainedTodayOfKind)
      for (final s in plan.on(c.now.weekday))
        if (s.kind == kind) (session: s, date: today),
    for (final s in plan.on(c.now.weekday % 7 + 1))
      if (s.kind == kind) (session: s, date: addDays(today, 1)),
  ];
  return candidates.firstOrNull;
}

String _suggestionFor(PlannedSession s) => switch (s.kind) {
      SessionKind.strength => 'Baja un 10 a 20 % el peso o una serie por ejercicio en ${s.title}, o muévela un día.',
      SessionKind.cardio => switch (s.intensity) {
          CardioIntensity.intervals => 'Cambia los intervalos por una sesión suave, o muévelos un día.',
          CardioIntensity.long => 'Acorta la sesión larga un 20 a 30 % y mantén un ritmo cómodo.',
          _ => 'Mantén la intensidad cómoda: puedes conversar mientras entrenas.',
        },
    };

String _sessionName(PlannedSession s) => s.kind == SessionKind.strength ? 'fuerza (${s.title})' : s.title.toLowerCase();

List<FatigueAlert> _loadAlerts(AlertContext c, Reason? energy) {
  final today = toDateKey(c.now);
  final sessions = [
    for (final w in c.workouts) strengthSessionLoad(w),
    for (final a in c.cardio) cardioSessionLoad(a),
  ];
  final series = loadSeries(sessions, to: today);
  final last = series.last;
  final ratio = last?.total.ratio;
  if (last == null || ratio == null || !series.reliable || ratio <= c.ratioThreshold) return const [];

  // De dónde viene la fatiga: la disciplina con más carga aguda.
  final fromCardio = last.cardio.atl > last.strength.atl;
  final source = fromCardio ? 'el cardio' : 'la fuerza';
  final opposite = fromCardio ? SessionKind.strength : SessionKind.cardio;
  final trainedToday = fromCardio ? c.workouts.any((w) => w.date == today) : c.cardio.any((a) => a.date == today);

  final week = sessions.where((s) => daysBetween(s.date, today) < 7).toList();
  final estimated = week.isNotEmpty && week.where((s) => s.estimated).length * 2 > week.length;

  final why = <Reason>[
    Reason(
      'Tu carga de los últimos 7 días es ${_ratio(ratio)} veces la de tus últimas 6 semanas (el aviso parte en ${_ratio(c.ratioThreshold)}), sobre todo por $source.',
      source: 'gabbett2016training',
    ),
    const Reason('La carga de cada sesión es el esfuerzo percibido por los minutos, igual para fuerza y cardio.', source: Sources.sessionRpe),
    if (estimated) const Reason('Varias sesiones de la semana no tienen el esfuerzo anotado y se estimó: tómalo con más cautela.', source: Sources.design),
    ?energy,
    const Reason('Es una señal de apoyo y no un diagnóstico: el uso de esta razón todavía se discute.', source: 'impellizzeri2020acute'),
  ];

  final next = _upcoming(c, opposite, trainedTodayOfKind: trainedToday);
  if (next != null) {
    final when = next.date == today ? 'hoy' : 'mañana';
    return [
      FatigueAlert(
        id: 'fatiga-${next.date}-${next.session.kind.name}',
        kind: AlertKind.crossFatigue,
        severity: estimated ? Severity.warning : Severity.important,
        title: 'Vienes con harta carga y $when toca ${_sessionName(next.session)}',
        text: 'Subiste tu carga más rápido de lo habitual y viene una sesión de la otra disciplina. Sumarlas puede frenar tu recuperación.',
        why: [
          ...why.take(1),
          Reason('Tu plan tiene ${_sessionName(next.session)} $when: combinar disciplinas con fatiga acumulada aumenta la interferencia.', source: Sources.concurrent),
          ...why.skip(1),
        ],
        suggestion: _suggestionFor(next.session),
        session: next.session,
        sessionDate: next.date,
      ),
    ];
  }
  return [
    FatigueAlert(
      id: 'carga-$today',
      kind: AlertKind.loadSpike,
      severity: estimated ? Severity.info : Severity.warning,
      title: 'Subiste bastante tu carga esta semana',
      text: 'Entrenaste más de lo que vienes acostumbrado. No es malo en sí, pero conviene cuidar la recuperación.',
      why: why,
      suggestion: 'Deja tu próxima sesión exigente para cuando te sientas recuperado y duerme bien estos días.',
    ),
  ];
}

// ---------------------------------------------------------------------------
// Separación entre fuerza y cardio
// ---------------------------------------------------------------------------

class _Gap {
  const _Gap(this.first, this.second, this.firstName, this.secondName, this.date);

  /// Inicio y fin de la primera sesión y de la segunda (ms).
  final (int, int) first;
  final (int, int) second;
  final String firstName;
  final String secondName;

  /// Día de la segunda sesión.
  final String date;

  Duration get between => Duration(milliseconds: second.$1 - first.$2);
}

/// Pares fuerza–cardio con menos de 6 horas entre el fin de una y el inicio de la otra.
List<_Gap> _shortGaps(List<Workout> workouts, List<CardioActivity> cardio, DateTime now) {
  final from = now.millisecondsSinceEpoch - gapLookbackDays * Duration.millisecondsPerDay;
  final limit = minGapHours * Duration.millisecondsPerHour;
  final out = <_Gap>[];
  for (final w in workouts.where((w) => w.finishedAt >= from)) {
    for (final a in cardio.where((a) => a.finishedAt >= from)) {
      final strengthFirst = w.startedAt <= a.startedAt;
      final (first, second) = strengthFirst ? ((w.startedAt, w.finishedAt), (a.startedAt, a.finishedAt)) : ((a.startedAt, a.finishedAt), (w.startedAt, w.finishedAt));
      if (second.$1 - first.$2 >= limit) continue;
      final strengthName = 'fuerza (${w.name})';
      final cardioName = a.title.isEmpty ? a.discipline.label.toLowerCase() : a.title;
      out.add(_Gap(first, second, strengthFirst ? strengthName : cardioName, strengthFirst ? cardioName : strengthName,
          toDateKey(DateTime.fromMillisecondsSinceEpoch(second.$1))));
    }
  }
  out.sort((x, y) => x.second.$1.compareTo(y.second.$1));
  return out;
}

List<FatigueAlert> _gapAlerts(AlertContext c) {
  final today = toDateKey(c.now);
  final gaps = _shortGaps(c.workouts, c.cardio, c.now);
  if (gaps.isEmpty) return const [];
  const why6h = Reason('Se recomienda dejar al menos 6 horas entre fuerza y cardio (mejor 6 a 8) para que una no reste a la otra.', source: Sources.concurrent);

  final days = {for (final g in gaps) g.date}.toList()..sort();
  var consecutive = false;
  for (var i = 1; i < days.length; i++) {
    if (daysBetween(days[i - 1], days[i]) == 1) consecutive = true;
  }
  if (consecutive) {
    return [
      FatigueAlert(
        id: 'patron-${days.last}',
        kind: AlertKind.repeatedShortGaps,
        severity: Severity.warning,
        title: 'Fuerza y cardio pegados varios días',
        text: 'Esta semana juntaste fuerza y cardio con poco tiempo entre ellos en días seguidos (${days.map((d) => _dayName(d, today)).join(', ')}).',
        why: const [
          why6h,
          Reason('Repetirlo varios días seguidos suma la interferencia y deja poco espacio para recuperarse.', source: Sources.interference),
        ],
        suggestion: 'Reorganiza tu semana: fuerza y cardio en días distintos, o uno en la mañana y el otro en la tarde.',
      ),
    ];
  }
  final g = gaps.last;
  if (daysBetween(g.date, today) >= recentGapDays) return const [];
  final start1 = DateTime.fromMillisecondsSinceEpoch(g.first.$1);
  final start2 = DateTime.fromMillisecondsSinceEpoch(g.second.$1);
  return [
    FatigueAlert(
      id: 'separacion-${g.date}-${g.second.$1}',
      kind: AlertKind.shortGap,
      severity: Severity.warning,
      title: 'Poco tiempo entre fuerza y cardio',
      text: '${_capitalize(_dayName(g.date, today))} hiciste ${g.firstName} (${_clock(start1)}) y ${g.secondName} (${_clock(start2)}) '
          'con ${_gap(g.between)} entre una y otra.',
      why: const [why6h],
      suggestion: 'La próxima vez sepáralas al menos 6 horas o hazlas en días distintos; si van juntas, primero la que sea tu prioridad.',
    ),
  ];
}

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ---------------------------------------------------------------------------
// Energía: comer bastante menos de lo que se gasta
// ---------------------------------------------------------------------------

/// Ingesta promedio de los últimos 7 días (sin hoy, que aún no termina) y cuántos
/// días se usaron. Los días anotados a medias (bajo la mitad de la mediana) no cuentan.
({int avg, int days})? recentIntake(List<LoggedDay> days, String today) {
  final from = addDays(today, -7);
  final week = days.where((d) => d.entries > 0 && d.kcal > 0 && d.date.compareTo(from) >= 0 && d.date.compareTo(today) < 0).toList();
  if (week.isEmpty) return null;
  final sorted = week.map((d) => d.kcal).toList()..sort();
  final median = sorted[sorted.length ~/ 2];
  final used = week.where((d) => d.kcal >= median / 2).toList();
  return (avg: jsRound(used.fold<double>(0, (a, d) => a + d.kcal) / used.length), days: used.length);
}

({int avg, int tdee, int pct})? _deficit(AlertContext c) {
  final tdee = c.dailyExpenditure;
  if (tdee == null || tdee <= 0) return null;
  final intake = recentIntake(c.days, toDateKey(c.now));
  if (intake == null || intake.days < minIntakeDays) return null;
  final share = 1 - intake.avg / tdee;
  if (share <= lowEnergyShare) return null;
  return (avg: intake.avg, tdee: tdee, pct: jsRound(share * 100));
}

/// Todas las alertas vigentes, de la más importante a la menos.
List<FatigueAlert> fatigueAlerts(AlertContext c) {
  final deficit = _deficit(c);
  final energyReason = deficit == null
      ? null
      : Reason('Además, esta semana comiste en promedio un ${deficit.pct} % menos de lo que gastas: un déficit grande puede retrasar tu recuperación.',
          source: Sources.design);
  final load = _loadAlerts(c, energyReason);
  final out = <FatigueAlert>[
    ...load,
    ..._gapAlerts(c),
    if (deficit != null && load.isEmpty)
      FatigueAlert(
        id: 'energia-${toDateKey(c.now)}',
        kind: AlertKind.lowEnergy,
        severity: Severity.info,
        title: 'Estás comiendo bastante menos de lo que gastas',
        text: 'En los últimos 7 días comiste en promedio ${formatKcal(deficit.avg)}, un ${deficit.pct} % bajo tu gasto estimado (${formatKcal(deficit.tdee)}).',
        why: [
          const Reason('Un déficit grande y sostenido puede retrasar la recuperación entre entrenamientos y frenar la ganancia de fuerza.', source: Sources.design),
          const Reason('El gasto se estima con tus registros de comida y peso o, si aún no alcanzan, con la ecuación de Mifflin-St Jeor.', source: Sources.mifflin),
        ],
        suggestion: 'Si no buscas bajar de peso rápido, suma una colación o una porción más en los días de entrenamiento.',
      ),
  ];
  out.sort((a, b) => b.severity.index.compareTo(a.severity.index));
  return out;
}

String formatKcal(int kcal) => '${formatNumber(kcal, maxFractionDigits: 0)} kcal';

/// Hora del aviso de una alerta de fatiga cruzada: dos horas antes de la hora de
/// entrenar (de los recordatorios), y no antes de las 8:00, el día de la sesión.
DateTime fatigueNoticeTime(String sessionDate, int trainingAt) {
  final minutes = trainingAt - 120 < 8 * 60 ? 8 * 60 : trainingAt - 120;
  final d = fromDateKey(sessionDate);
  return DateTime(d.year, d.month, d.day, minutes ~/ 60, minutes % 60);
}

/// Avisos locales de las alertas de fatiga cruzada sin responder (las demás se
/// ven en la app). Solo los que aún no pasan.
List<PlannedReminder> fatigueReminders(List<FatigueAlert> alerts, {required DateTime now, required int trainingAt}) => [
      for (final a in alerts)
        if (a.kind == AlertKind.crossFatigue && a.sessionDate != null)
          if (fatigueNoticeTime(a.sessionDate!, trainingAt) case final at when at.isAfter(now))
            PlannedReminder(kind: ReminderKind.fatigue, at: at, title: 'Alerta de fatiga', body: a.notificationBody, route: '/carga/alerta/${a.id}'),
    ];
