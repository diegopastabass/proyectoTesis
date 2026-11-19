/// CU-05: carga y fatiga cruzada. Las cifras son las del motor
/// (`core/training/load.dart`), las alertas salen de `core/suggestions/alerts.dart`
/// y el asistente de IA solo las explica con palabras (`fatigueBrief`).
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/cardio_providers.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/ai/ai_models.dart';
import '../../core/common/date.dart';
import '../../core/suggestions/alerts.dart';
import '../../core/suggestions/examples.dart';
import '../../core/suggestions/reason.dart';
import '../../core/training/fatigue_view.dart';
import '../../core/training/load.dart';
import '../../data/ai/ai_service.dart';
import '../../ui/format.dart';
import '../../ui/sim_widgets.dart';
import '../../ui/widgets.dart';

(String, String, Color) _zoneText(RatioZone z, AppColors c) => switch (z) {
      RatioZone.low => ('Por debajo de lo habitual', 'Esta semana cargaste menos que de costumbre. Tienes margen para subir.', c.fiber),
      RatioZone.normal => ('Dentro de lo habitual', 'Tu carga de la semana es parecida a lo que vienes haciendo.', c.success),
      RatioZone.high => ('Aumento brusco', 'Esta semana subiste bastante tu carga. Conviene cuidar la recuperación.', c.warning),
      RatioZone.veryHigh => ('Aumento muy brusco', 'Tu carga subió mucho en poco tiempo. Es buen momento para bajar la intensidad.', c.danger),
    };

String _ratioText(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

/// Carga y fatiga cruzada: estado, explicación del asistente, alertas, de dónde
/// viene la carga, evolución de la razón y sesiones de la semana.
class TrainingLoadPage extends ConsumerWidget {
  const TrainingLoadPage({super.key, this.showShortHistory = false});

  /// Fuerza el curso alterno "faltan datos" (lo usa el modo de capturas).
  final bool showShortHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final today = todayKey();
    final workouts = ref.watch(workoutsProvider).value ?? const [];
    final activities = ref.watch(cardioActivitiesProvider).value ?? const [];
    final view = fatigueView(workouts: workouts, activities: activities, today: today);
    final series = view.series;
    final last = series.last;
    final ratio = last?.total.ratio;
    final reliable = series.reliable && !showShortHistory;
    final week = series.days.length <= 7 ? series.days : series.days.sublist(series.days.length - 7);
    final zone = ratio == null ? null : ratioZone(ratio);
    final alerts = ref.watch(fatigueAlertsProvider).value ?? const <FatigueAlert>[];
    final threshold = ref.watch(fatigueThresholdProvider);
    final trend = series.days.length <= 42 ? series.days : series.days.sublist(series.days.length - 42);

    // Déficit de la semana (para la explicación), con la misma regla de las alertas.
    final tdee = ref.watch(dailyExpenditureProvider);
    final intake = recentIntake(ref.watch(loggedDaysProvider).value ?? const [], today);
    final deficit = tdee == null || intake == null || intake.days < minIntakeDays ? null : ((1 - intake.avg / tdee) * 100).round();
    final brief = fatigueBrief(
      view: view,
      today: today,
      threshold: threshold,
      alerts: alerts,
      plan: ref.watch(weeklyPlanProvider).value,
      deficitPct: deficit != null && deficit > 0 ? deficit : null,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Carga y fatiga cruzada')),
      body: PageBody(children: [
        if (!reliable)
          InfoNote(
            icon: Icons.hourglass_bottom,
            color: c.fiber,
            title: 'Faltan datos para estimar tu fatiga',
            text: 'Necesitamos unas 4 semanas de registros. Llevas ${showShortHistory ? 9 : series.historyDays} días. Mientras tanto puedes ver tu carga semanal.',
          )
        else if (zone != null)
          () {
            final (title, text, color) = _zoneText(zone, c);
            return AppCard(
              padding: const EdgeInsets.all(16),
              borderColor: color.withValues(alpha: 0.6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(Icons.speed, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: c.fgStrong))),
                  Text(_ratioText(ratio!), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color, fontFeatures: tabular)),
                ]),
                const SizedBox(height: 6),
                Text(text, style: TextStyle(fontSize: 14, height: 1.35, color: c.fg)),
                const SizedBox(height: 6),
                Text('Carga de los últimos 7 días frente a tus últimas 6 semanas. Es una señal de apoyo, no un diagnóstico.', style: TextStyle(fontSize: 11, color: c.faint)),
              ]),
            );
          }(),
        if (series.days.isNotEmpty) _AiFatigueCard(brief: brief),
        for (final a in alerts) AlertCard(alert: a),
        TileGrid(columns: 3, children: [
          StatTile(icon: Icons.fitness_center, label: 'Fuerza', value: '${view.strength.week.round()}', caption: 'UA en 7 días'),
          StatTile(icon: Icons.directions_run, label: 'Cardio', value: '${view.cardio.week.round()}', caption: 'UA en 7 días'),
          StatTile(icon: Icons.bolt, label: 'Total', value: '${(view.strength.week + view.cardio.week).round()}', caption: 'UA en 7 días'),
        ]),
        if (reliable) _SourcesCard(view: view),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Carga de esta semana', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong)),
            const SizedBox(height: 12),
            _WeekBars(days: week),
            const SizedBox(height: 10),
            Row(children: [LegendDot(c.primary, 'Fuerza'), const SizedBox(width: 14), LegendDot(c.kcal, 'Cardio')]),
          ]),
        ),
        if (reliable && trend.length > 2)
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Tu razón aguda/crónica', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong)),
              const SizedBox(height: 2),
              Text('La banda verde es lo habitual (0,8 a 1,3); la línea punteada, tu umbral de aviso.', style: TextStyle(fontSize: 12, color: c.muted)),
              const SizedBox(height: 12),
              // Antes de 28 días de historial la razón sale inflada (la crónica aún se forma): no se dibuja.
              _RatioChart(
                points: [
                  for (final d in trend) series.firstSession != null && daysBetween(series.firstSession!, d.date) + 1 >= minHistoryDays ? d.total.ratio : null,
                ],
                threshold: threshold,
              ),
            ]),
          ),
        if (trend.length > 2)
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Tu carga en el tiempo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong)),
              const SizedBox(height: 2),
              Text(trend.length >= 14 ? 'Últimas ${(trend.length / 7).round()} semanas' : 'Últimos ${trend.length} días', style: TextStyle(fontSize: 12, color: c.muted)),
              const SizedBox(height: 12),
              SparkLine(height: 110, series: [
                ([for (final d in trend) d.total.atl], c.kcal),
                ([for (final d in trend) d.total.ctl], c.primary),
              ]),
              const SizedBox(height: 10),
              Row(children: [LegendDot(c.kcal, 'Fatiga reciente'), const SizedBox(width: 14), LegendDot(c.primary, 'Lo habitual')]),
            ]),
          ),
        _SessionsCard(view: view),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Avisar desde', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong)),
            const SizedBox(height: 2),
            Text('Cuántas veces tu carga de la semana puede superar a lo habitual antes de avisarte.', style: TextStyle(fontSize: 12, color: c.muted)),
            const SizedBox(height: 10),
            ChoicePills<double>(
              options: const [1.2, 1.3, 1.4, 1.5],
              selected: threshold,
              label: (v) => '${v.toStringAsFixed(1).replaceAll('.', ',')}${v == defaultRatioThreshold ? ' (sugerido)' : ''}',
              onSelected: (v) => ref.read(fatigueThresholdProvider.notifier).set(v),
            ),
            const SizedBox(height: 8),
            Text('1,3 es el límite de lo habitual según Gabbett (2016); el valor se ajustará con las pruebas del prototipo.', style: TextStyle(fontSize: 11, color: c.faint)),
          ]),
        ),
      ]),
    );
  }
}

/// Firma corta de los datos (FNV-1a de 32 bits), para reutilizar el resumen mientras no cambien.
String _signature(String s) {
  var h = 0x811c9dc5;
  for (final unit in utf8.encode(s)) {
    h = ((h ^ unit) * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16);
}

/// Explicación de la semana escrita por el asistente con las cifras del motor.
class _AiFatigueCard extends ConsumerStatefulWidget {
  const _AiFatigueCard({required this.brief});

  final Map<String, dynamic> brief;

  @override
  ConsumerState<_AiFatigueCard> createState() => _AiFatigueCardState();
}

class _AiFatigueCardState extends ConsumerState<_AiFatigueCard> {
  FatigueSummary? _summary;
  Object? _error;
  bool _loading = false;
  String? _shownFor;

  String get _sig => _signature(jsonEncode(widget.brief));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrAsk());
  }

  @override
  void didUpdateWidget(_AiFatigueCard old) {
    super.didUpdateWidget(old);
    // Llegó un dato nuevo (otra sesión, otra alerta): se vuelve a explicar.
    if (_shownFor != null && _shownFor != _sig && !_loading) WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrAsk());
  }

  void _loadOrAsk() {
    if (!mounted) return;
    final sig = _sig;
    final raw = ref.read(localStoreProvider).fatigueSummary;
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        if (j['firma'] == sig) {
          setState(() {
            _summary = FatigueSummary.fromJson((j['resumen'] as Map).cast<String, dynamic>());
            _shownFor = sig;
          });
          return;
        }
      } on Object {
        // Guardado con otro formato: se pide de nuevo.
      }
    }
    if (ref.read(aiServiceProvider).mode != AiMode.off) _ask();
  }

  Future<void> _ask() async {
    final ai = ref.read(aiServiceProvider);
    final sig = _sig;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await ai.fatigueSummary(widget.brief);
      if (ai.mode == AiMode.gemini) {
        await ref.read(localStoreProvider).setFatigueSummary(jsonEncode({'firma': sig, 'resumen': summary.toJson()}));
      }
      if (mounted) {
        setState(() {
          _summary = summary;
          _shownFor = sig;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ai = ref.watch(aiServiceProvider);
    if (ai.mode == AiMode.off) return const SizedBox.shrink();
    final s = _summary;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const GradientIcon(Icons.auto_awesome, size: 30),
          const SizedBox(width: 10),
          Expanded(child: Text('Lo que dice el asistente', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong))),
          IconButton(tooltip: 'Volver a explicar', onPressed: _loading ? null : _ask, icon: Icon(Icons.refresh, size: 20, color: c.muted)),
        ]),
        const SizedBox(height: 8),
        if (_loading && s == null)
          Row(children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: c.primary)),
            const SizedBox(width: 10),
            Expanded(child: Text('Leyendo tu semana…', style: TextStyle(fontSize: 13, color: c.muted))),
          ])
        else if (_error != null && s == null)
          Text(_error is AiException ? (_error! as AiException).message : 'No se pudo preparar la explicación.', style: TextStyle(fontSize: 13, color: c.danger))
        else if (s != null) ...[
          if (s.headline.isNotEmpty) Text(s.headline, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.25, color: c.fgStrong)),
          if (s.summary.isNotEmpty) ...[const SizedBox(height: 4), Text(s.summary, style: TextStyle(fontSize: 14, height: 1.4, color: c.fg))],
          for (final p in s.points)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 6, color: c.primary)),
                const SizedBox(width: 8),
                Expanded(child: Text(p, style: TextStyle(fontSize: 13, height: 1.35, color: c.fg))),
              ]),
            ),
          if (s.suggestion != null)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(12)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.tips_and_updates_outlined, size: 18, color: c.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(s.suggestion!, style: TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w600, color: c.fgStrong))),
              ]),
            ),
        ],
        const SizedBox(height: 8),
        Text(
          ai.mode == AiMode.demo
              ? 'Modo demostración: texto de ejemplo con tus cifras.'
              : 'Escrito por Gemini con las cifras de esta pantalla (sin tus datos personales). Las cifras y las alertas son las del motor de la app; es apoyo, no un diagnóstico.',
          style: TextStyle(fontSize: 11, color: c.faint, height: 1.35),
        ),
      ]),
    );
  }
}

/// De dónde viene la carga: aguda y crónica de cada disciplina.
class _SourcesCard extends StatelessWidget {
  const _SourcesCard({required this.view});

  final FatigueView view;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget row(String name, IconData icon, Color color, DisciplineLoad d) {
      final r = d.state.ratio;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong))),
            Text('${(d.share * 100).round()} % de la semana', style: TextStyle(fontSize: 12, color: c.muted)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: d.share, minHeight: 6, backgroundColor: c.surface2, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            'Reciente ${d.state.atl.round()} · habitual ${d.state.ctl.round()} UA por día${r == null ? '' : ' · razón ${_ratioText(r)}'}',
            style: TextStyle(fontSize: 12, color: c.faint, fontFeatures: tabular),
          ),
        ]),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('De dónde viene la carga', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong)),
        row('Fuerza', Icons.fitness_center, c.primary, view.strength),
        row('Cardio', Icons.directions_run, c.kcal, view.cardio),
      ]),
    );
  }
}

/// Razón aguda/crónica día a día, con la banda de lo habitual y el umbral.
class _RatioChart extends StatelessWidget {
  const _RatioChart({required this.points, required this.threshold});

  final List<double?> points;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Razón aguda/crónica de los últimos ${points.length} días',
      child: SizedBox(
        height: 130,
        width: double.infinity,
        child: CustomPaint(painter: _RatioPainter(points, threshold, line: c.primary, band: c.success, limit: c.warning, grid: c.border, text: c.faint)),
      ),
    );
  }
}

class _RatioPainter extends CustomPainter {
  _RatioPainter(this.points, this.threshold, {required this.line, required this.band, required this.limit, required this.grid, required this.text});

  final List<double?> points;
  final double threshold;
  final Color line;
  final Color band;
  final Color limit;
  final Color grid;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    const minY = 0.4;
    final values = points.whereType<double>();
    // Escala entre 0,4 y 1,8–2,2: lo que pase de 2,2 queda en el borde (la banda habitual siempre se ve).
    final maxY = math.min(2.2, math.max(1.8, values.isEmpty ? 0 : values.reduce(math.max) + 0.1));
    double y(double v) => size.height - (v.clamp(minY, maxY) - minY) / (maxY - minY) * size.height;

    canvas.drawRect(Rect.fromLTRB(0, y(1.3), size.width, y(0.8)), Paint()..color = band.withValues(alpha: 0.12));
    for (final v in [0.8, 1.3]) {
      canvas.drawLine(Offset(0, y(v)), Offset(size.width, y(v)), Paint()..color = grid);
      final tp = TextPainter(text: TextSpan(text: _ratioText(v), style: TextStyle(fontSize: 9, color: text)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(2, y(v) - tp.height - 1));
    }
    // Umbral de aviso, punteado.
    final dash = Paint()
      ..color = limit
      ..strokeWidth = 1.2;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, y(threshold)), Offset(math.min(size.width, x + 4), y(threshold)), dash);
    }

    if (points.length < 2) return;
    final stroke = Paint()
      ..color = line
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    var started = false;
    final step = size.width / (points.length - 1);
    for (var i = 0; i < points.length; i++) {
      final v = points[i];
      if (v == null) {
        started = false;
        continue;
      }
      final p = Offset(i * step, y(v));
      started ? path.lineTo(p.dx, p.dy) : path.moveTo(p.dx, p.dy);
      started = true;
    }
    canvas.drawPath(path, stroke);
    final lastValue = points.last;
    if (lastValue != null) canvas.drawCircle(Offset(size.width, y(lastValue)), 4, Paint()..color = line);
  }

  @override
  bool shouldRepaint(_RatioPainter old) => old.points != points || old.threshold != threshold || old.line != line;
}

/// Sesiones de los últimos 7 días con su carga; las de RPE estimado, marcadas.
class _SessionsCard extends StatelessWidget {
  const _SessionsCard({required this.view});

  final FatigueView view;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sessions = view.sessions;
    return CardList(header: const CardHeader('Sesiones de la semana', icon: Icons.event_note_outlined), children: [
      if (sessions.isEmpty)
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text('Sin sesiones en los últimos 7 días.', style: TextStyle(fontSize: 13, color: c.muted)),
        ),
      for (final s in sessions)
        ListTile(
          dense: true,
          onTap: () => context.push(s.route),
          leading: Icon(s.load.kind == LoadKind.strength ? Icons.fitness_center : Icons.directions_run, size: 20, color: s.load.kind == LoadKind.strength ? c.primary : c.kcal),
          title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.fgStrong)),
          subtitle: Text(
            '${capitalize(relativeDay(s.load.date))} · ${s.load.minutes.round()} min · RPE ${s.load.rpe}${s.load.estimated ? ' estimado' : ''}',
            style: TextStyle(fontSize: 12, color: s.load.estimated ? c.warning : c.muted),
          ),
          trailing: Text('${s.load.load.round()} UA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.fgStrong, fontFeatures: tabular)),
        ),
      if (view.mostlyEstimated)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
          child: Text(
            'Varias sesiones tienen el esfuerzo estimado. Anotarlo al terminar (o desde el detalle de la sesión) hace el cálculo más confiable.',
            style: TextStyle(fontSize: 11, color: c.faint, height: 1.35),
          ),
        ),
    ]);
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days});

  final List<LoadDay> days;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final top = days.fold<double>(1, (a, d) => d.load > a ? d.load : a);
    const height = 96.0;
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (final d in days)
        Expanded(
          child: Column(children: [
            SizedBox(
              height: height,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (d.cardioLoad > 0) Container(width: 20, height: d.cardioLoad / top * height, decoration: BoxDecoration(color: c.kcal, borderRadius: BorderRadius.circular(4))),
                  if (d.cardioLoad > 0 && d.strengthLoad > 0) const SizedBox(height: 2),
                  if (d.strengthLoad > 0) Container(width: 20, height: d.strengthLoad / top * height - (d.cardioLoad > 0 ? 2 : 0), decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(4))),
                  if (d.load == 0) Container(width: 20, height: 3, decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(2))),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Text(capitalize(weekdayDay(d.date).split(' ').first).substring(0, 1), style: TextStyle(fontSize: 11, color: d.date == todayKey() ? c.primary : c.muted, fontWeight: FontWeight.w600)),
          ]),
        ),
    ]);
  }
}

(IconData, Color) _severityStyle(Severity s, AppColors c) => switch (s) {
      Severity.important => (Icons.notifications_active_outlined, c.danger),
      Severity.warning => (Icons.warning_amber_rounded, c.warning),
      Severity.info => (Icons.info_outline, c.fiber),
    };

IconData _kindIcon(AlertKind k) => switch (k) {
      AlertKind.crossFatigue || AlertKind.loadSpike => Icons.trending_up,
      AlertKind.shortGap || AlertKind.repeatedShortGaps => Icons.schedule,
      AlertKind.lowEnergy => Icons.restaurant,
    };

/// Tarjeta de una alerta (resumen de carga e inicio de Fuerza).
class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.alert});

  final FatigueAlert alert;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, color) = _severityStyle(alert.severity, c);
    return AppCard(
      padding: const EdgeInsets.all(12),
      borderColor: color.withValues(alpha: 0.6),
      onTap: () => context.push('/carga/alerta/${alert.id}'),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(alert.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
            if (alert.suggestion != null) Text(alert.suggestion!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
          ]),
        ),
        Icon(Icons.chevron_right, color: c.faint),
      ]),
    );
  }
}

/// Aviso de fatiga con su sugerencia: el atleta decide si la sigue.
///
/// Con `id` muestra esa alerta (si sigue vigente); sin `id`, una alerta de ejemplo
/// calculada por el motor con datos simulados (para conocerla y para las capturas).
class FatigueAlertPage extends ConsumerStatefulWidget {
  const FatigueAlertPage({super.key, this.id});

  final String? id;

  @override
  ConsumerState<FatigueAlertPage> createState() => _FatigueAlertPageState();
}

class _FatigueAlertPageState extends ConsumerState<FatigueAlertPage> {
  /// Lo que respondió en esta pantalla (null = sin responder).
  ResponseKind? _response;
  FatigueAlert? _shown;

  bool get _example => widget.id == null;

  Future<void> _respond(FatigueAlert alert, ResponseKind r) async {
    if (!_example) {
      final ok = await runGuarded(context, () => ref.read(strengthActionsProvider).respondToAlert(alert, r));
      if (!ok) return;
    }
    if (mounted) setState(() => _response = r);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final alerts = ref.watch(fatigueAlertsProvider);
    // Tras responder, la alerta sale de la lista: se sigue mostrando la que se respondió.
    final alert = _shown ??= _example
        ? fatigueAlerts(exampleAlertContext(DateTime.now())).firstOrNull
        : alerts.value?.where((a) => a.id == widget.id).firstOrNull;

    if (alert == null) {
      if (!_example && !alerts.hasValue) return const Scaffold(body: LoadingView());
      return Scaffold(
        appBar: AppBar(title: const Text('Alerta de fatiga')),
        body: PageBody(children: [
          const AppCard(child: EmptyState(icon: Icons.check_circle_outline, title: 'Esta alerta ya no está vigente', message: 'La respondiste o cambiaron tus datos.')),
          FilledButton(onPressed: () => context.go('/carga'), child: const Text('Ver mi carga')),
        ]),
      );
    }

    final (icon, color) = _severityStyle(alert.severity, c);
    final hasPlanChoice = alert.session != null;
    return Scaffold(
      appBar: AppBar(title: Text(alert.kind == AlertKind.crossFatigue ? 'Alerta de fatiga' : 'Aviso')),
      bottomNavigationBar: _response != null
          ? BottomActions(children: [FilledButton(onPressed: () => context.canPop() ? context.pop() : context.go('/carga'), child: const Text('Volver a mi resumen'))])
          : BottomActions(children: [
              if (hasPlanChoice) ...[
                FilledButton(onPressed: () => _respond(alert, ResponseKind.followed), child: const Text('Seguir la sugerencia')),
                OutlinedButton(onPressed: () => _respond(alert, ResponseKind.kept), child: const Text('Mantener mi plan')),
              ] else
                FilledButton(onPressed: () => _respond(alert, ResponseKind.dismissed), child: const Text('Entendido')),
            ]),
      body: PageBody(children: [
        if (_example)
          const InfoNote(icon: Icons.science_outlined, title: 'Alerta de ejemplo', text: 'Calculada con datos simulados: seis semanas de ciclismo suave y una semana con mucho más, y pierna mañana.'),
        if (alert.kind == AlertKind.crossFatigue)
          // Cómo se ve el aviso que llega al teléfono.
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.asset('assets/branding/logo.png', width: 38, height: 38)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('NutriApp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.fgStrong))),
                    Text('aviso', style: TextStyle(fontSize: 12, color: c.faint)),
                  ]),
                  const SizedBox(height: 2),
                  Text(alert.notificationBody, style: TextStyle(fontSize: 13, height: 1.3, color: c.fg)),
                ]),
              ),
            ]),
          ),
        AppCard(
          padding: const EdgeInsets.all(14),
          borderColor: color.withValues(alpha: 0.6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(_kindIcon(alert.kind), color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(alert.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.25, color: c.fgStrong))),
            ]),
            const SizedBox(height: 8),
            Text(alert.text, style: TextStyle(fontSize: 13, height: 1.35, color: c.fg)),
          ]),
        ),
        if (alert.suggestion != null) ...[
          const SectionTitle('Te sugerimos'),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const GradientIcon(Icons.tips_and_updates_outlined, size: 36),
              const SizedBox(width: 12),
              Expanded(child: Text(alert.suggestion!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3, color: c.fgStrong))),
            ]),
          ),
        ],
        const SectionTitle('Qué notamos'),
        CardList(children: [
          for (final r in alert.why)
            ListTile(
              leading: Icon(icon, size: 20, color: color),
              title: Text(r.text, style: TextStyle(fontSize: 13, height: 1.35, color: c.fg)),
              subtitle: r.source == null ? null : Text(Sources.label(r.source!), style: TextStyle(fontSize: 10, color: c.faint)),
            ),
        ]),
        if (_response == ResponseKind.followed)
          InfoNote(icon: Icons.check_circle, color: c.success, title: 'Anotado', text: 'Cuando empieces esa sesión, ajusta la carga como te sugerimos. Tu plan semanal no cambia.'),
        if (_response == ResponseKind.kept) const InfoNote(title: 'Tu plan sigue igual', text: 'No cambiamos nada. Si llegas cansado, escucha a tu cuerpo.'),
        if (_response == ResponseKind.dismissed) const InfoNote(title: 'Listo', text: 'No te volveremos a mostrar este aviso.'),
        Text('Es una señal de apoyo y no un diagnóstico médico.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.faint)),
      ]),
    );
  }
}
