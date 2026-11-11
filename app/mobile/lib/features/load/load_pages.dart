/// CU-05: resumen de carga y alertas de fatiga. La carga es la real
/// (`core/training/load.dart`) y las alertas salen del motor de sugerencias
/// (`core/suggestions/alerts.dart`) con los datos registrados y el plan semanal.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/cardio_providers.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/common/date.dart';
import '../../core/suggestions/alerts.dart';
import '../../core/suggestions/examples.dart';
import '../../core/suggestions/reason.dart';
import '../../core/training/load.dart';
import '../../ui/format.dart';
import '../../ui/sim_widgets.dart';
import '../../ui/widgets.dart';

(String, String, Color) _zoneText(RatioZone z, AppColors c) => switch (z) {
      RatioZone.low => ('Por debajo de lo habitual', 'Esta semana cargaste menos que de costumbre. Tienes margen para subir.', c.fiber),
      RatioZone.normal => ('Dentro de lo habitual', 'Tu carga de la semana es parecida a lo que vienes haciendo.', c.success),
      RatioZone.high => ('Aumento brusco', 'Esta semana subiste bastante tu carga. Conviene cuidar la recuperación.', c.warning),
      RatioZone.veryHigh => ('Aumento muy brusco', 'Tu carga subió mucho en poco tiempo. Es buen momento para bajar la intensidad.', c.danger),
    };

/// Resumen de carga: lo real de fuerza y cardio, sumado en la misma unidad.
class TrainingLoadPage extends ConsumerWidget {
  const TrainingLoadPage({super.key, this.showShortHistory = false});

  /// Fuerza el curso alterno "faltan datos" (lo usa el modo de capturas).
  final bool showShortHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final workouts = ref.watch(workoutsProvider).value ?? const [];
    final activities = ref.watch(cardioActivitiesProvider).value ?? const [];
    final series = trainingLoad(workouts: workouts, activities: activities, to: todayKey());
    final last = series.last;
    final ratio = last?.total.ratio;
    final reliable = series.reliable && !showShortHistory;
    final week = series.days.length <= 7 ? series.days : series.days.sublist(series.days.length - 7);
    final strength = week.fold<double>(0, (a, d) => a + d.strengthLoad);
    final cardio = week.fold<double>(0, (a, d) => a + d.cardioLoad);
    final zone = ratio == null ? null : ratioZone(ratio);
    final alerts = ref.watch(fatigueAlertsProvider).value ?? const <FatigueAlert>[];
    final threshold = ref.watch(fatigueThresholdProvider);
    final trend = series.days.length <= 42 ? series.days : series.days.sublist(series.days.length - 42);

    return Scaffold(
      appBar: AppBar(title: const Text('Carga de entrenamiento')),
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
                  Text(ratio!.toStringAsFixed(2).replaceAll('.', ','), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color, fontFeatures: tabular)),
                ]),
                const SizedBox(height: 6),
                Text(text, style: TextStyle(fontSize: 14, height: 1.35, color: c.fg)),
                const SizedBox(height: 6),
                Text('Carga de los últimos 7 días frente a tus últimas 6 semanas. Es una señal de apoyo, no un diagnóstico.', style: TextStyle(fontSize: 11, color: c.faint)),
              ]),
            );
          }(),
        for (final a in alerts) AlertCard(alert: a),
        TileGrid(columns: 3, children: [
          StatTile(icon: Icons.fitness_center, label: 'Fuerza', value: '${strength.round()}', caption: 'UA en 7 días'),
          StatTile(icon: Icons.directions_run, label: 'Cardio', value: '${cardio.round()}', caption: 'UA en 7 días'),
          StatTile(icon: Icons.bolt, label: 'Total', value: '${(strength + cardio).round()}', caption: 'UA en 7 días'),
        ]),
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
