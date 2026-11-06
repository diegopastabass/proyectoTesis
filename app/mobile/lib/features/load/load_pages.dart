/// CU-05: resumen de carga y alertas de fatiga. El cálculo es el real
/// (`core/training/load.dart`, con los datos registrados); las alertas y sus
/// sugerencias son reglas de ejemplo, porque el motor de alertas aún no existe.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/cardio_providers.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/common/date.dart';
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
    final risky = reliable && (zone == RatioZone.high || zone == RatioZone.veryHigh);
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
        if (risky)
          EntryCard(
            icon: Icons.notifications_active_outlined,
            title: 'Tienes una alerta de fatiga',
            subtitle: 'Mañana tienes un entrenamiento exigente',
            onTap: () => context.push('/carga/alerta'),
          ),
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
              Text('Últimas ${(trend.length / 7).round()} semanas', style: TextStyle(fontSize: 12, color: c.muted)),
              const SizedBox(height: 12),
              SparkLine(height: 110, series: [
                ([for (final d in trend) d.total.atl], c.kcal),
                ([for (final d in trend) d.total.ctl], c.primary),
              ]),
              const SizedBox(height: 10),
              Row(children: [LegendDot(c.kcal, 'Fatiga reciente'), const SizedBox(width: 14), LegendDot(c.primary, 'Lo habitual')]),
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

/// Aviso de fatiga con su sugerencia: el atleta decide si la sigue.
class FatigueAlertPage extends StatefulWidget {
  const FatigueAlertPage({super.key});

  @override
  State<FatigueAlertPage> createState() => _FatigueAlertPageState();
}

class _FatigueAlertPageState extends State<FatigueAlertPage> {
  /// null = sin responder.
  bool? _accepted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Alerta de fatiga')),
      bottomNavigationBar: _accepted != null
          ? BottomActions(children: [FilledButton(onPressed: () => context.pop(), child: const Text('Volver a mi resumen'))])
          : BottomActions(children: [
              FilledButton(onPressed: () => setState(() => _accepted = true), child: const Text('Seguir la sugerencia')),
              OutlinedButton(onPressed: () => setState(() => _accepted = false), child: const Text('Mantener mi plan')),
            ]),
      body: PageBody(children: [
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
                  Text('ahora', style: TextStyle(fontSize: 12, color: c.faint)),
                ]),
                const SizedBox(height: 2),
                Text('Vienes con harta carga y mañana toca pierna. Revisa la sugerencia antes de entrenar.', style: TextStyle(fontSize: 13, height: 1.3, color: c.fg)),
              ]),
            ),
          ]),
        ),
        const SectionTitle('Qué notamos'),
        CardList(children: [
          ListTile(
            leading: Icon(Icons.trending_up, color: c.warning),
            title: Text('Subiste tu carga esta semana', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
            subtitle: Text('La fatiga reciente viene sobre todo de tus últimas sesiones de fuerza.', style: TextStyle(fontSize: 13, color: c.muted)),
          ),
          ListTile(
            leading: Icon(Icons.schedule, color: c.warning),
            title: Text('Poco tiempo entre sesiones', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
            subtitle: Text('Dejaste menos de 6 horas entre tu sesión de fuerza y tu salida de cardio.', style: TextStyle(fontSize: 13, color: c.muted)),
          ),
        ]),
        const SectionTitle('Te sugerimos'),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const GradientIcon(Icons.tips_and_updates_outlined, size: 36),
              const SizedBox(width: 12),
              Expanded(child: Text('Bajar 10 % el peso en tu sesión de pierna de mañana', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.25, color: c.fgStrong))),
            ]),
            const SizedBox(height: 10),
            Text('O muévela al sábado, cuando tendrás dos días con menos carga.', style: TextStyle(fontSize: 13, height: 1.35, color: c.fg)),
          ]),
        ),
        if (_accepted == true) InfoNote(icon: Icons.check_circle, color: c.success, title: 'Actualizamos tu plan', text: 'La sesión de mañana queda con los pesos ajustados.'),
        if (_accepted == false) const InfoNote(title: 'Tu plan sigue igual', text: 'No cambiamos nada. Puedes revisar tu carga cuando quieras.'),
        Text('Es una señal de apoyo y no un diagnóstico médico.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.faint)),
      ]),
    );
  }
}
