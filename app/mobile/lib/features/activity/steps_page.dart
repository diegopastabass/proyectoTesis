/// Detalle de los pasos (se abre al tocar la tarjeta de pasos del Diario):
/// el día elegido con su meta y su distribución por hora, la evolución en 7, 30
/// o 90 días, promedios, mejor día, racha de la meta y estimaciones de distancia
/// y energía. Los datos vienen de Apple Salud.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/activity/steps.dart';
import '../../core/body/energy.dart';
import '../../core/common/date.dart';
import '../../core/common/numbers.dart';
import '../../platform/platform_providers.dart';
import '../../ui/format.dart';
import '../../ui/widgets.dart';

String _n(num v) => formatNumber(v, maxFractionDigits: 0);

class StepsPage extends ConsumerStatefulWidget {
  const StepsPage({super.key, this.initialDate});

  final String? initialDate;

  @override
  ConsumerState<StepsPage> createState() => _StepsPageState();
}

class _StepsPageState extends ConsumerState<StepsPage> {
  late String _day = widget.initialDate ?? todayKey();
  int _length = 7;

  void _refresh() {
    final today = todayKey();
    ref.invalidate(periodStepsProvider((today, _length)));
    ref.invalidate(hourlyStepsProvider(_day));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = todayKey();
    final status = ref.watch(healthStatusProvider).value;
    final goal = ref.watch(stepsGoalProvider);

    if (status != null && !status.usable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pasos')),
        body: const PageBody(children: [
          AppCard(child: EmptyState(icon: Icons.directions_walk, title: 'Conecta Apple Salud', message: 'Desde la tarjeta de pasos del Diario puedes dar el permiso para leerlos.')),
        ]),
      );
    }

    final period = ref.watch(periodStepsProvider((today, _length)));
    return Scaffold(
      appBar: AppBar(title: const Text('Pasos'), actions: [
        IconButton(tooltip: 'Actualizar pasos', onPressed: _refresh, icon: const Icon(Icons.refresh)),
      ]),
      body: AsyncView(
        period,
        loadingText: 'Leyendo Apple Salud…',
        builder: (all) {
          final range = periodRange(today, _length);
          final current = [for (final d in all) if (d.date.compareTo(range.from) >= 0) d];
          final previous = [for (final d in all) if (d.date.compareTo(range.from) < 0) d];
          final byDate = {for (final d in all) d.date: d.steps};
          final stats = stepsStats(current, goal: goal, today: today, previous: previous);
          final steps = byDate[_day] ?? 0;
          final body = ref.watch(bodyProfileProvider).value ?? const BodyProfile();
          final weight = ref.watch(weightsProvider).value?.lastOrNull?.kg;
          final km = stepsKm(steps, body);
          final kcal = stepsKcal(steps, body, weight);
          final allZero = current.every((d) => d.steps == 0);

          return PageBody(children: [
            _DayHeader(day: _day, today: today, steps: steps, goal: goal, km: km, kcal: kcal),
            _HourlyCard(day: _day),
            AppSegmented<int>(
              value: _length,
              segments: const {7: Text('7 días'), 30: Text('30 días'), 90: Text('90 días')},
              onChanged: (v) => setState(() => _length = v),
            ),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Últimos $_length días', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong)),
                Text('Toca un día para verlo arriba. La línea es tu meta.', style: TextStyle(fontSize: 11, color: c.faint)),
                const SizedBox(height: 12),
                _PeriodBars(days: [for (var i = _length - 1; i >= 0; i--) addDays(today, -i)], byDate: byDate, goal: goal, selected: _day, onSelect: (d) => setState(() => _day = d)),
              ]),
            ),
            TileGrid(children: [
              StatTile(
                icon: Icons.show_chart,
                label: 'Promedio diario',
                value: _n(stats.average),
                caption: switch (stats.change) {
                  null => 'sin periodo anterior',
                  final ch => '${ch > 0 ? '+' : ch < 0 ? '−' : ''}${ch.abs()} % vs. los $_length días anteriores',
                },
              ),
              StatTile(icon: Icons.functions, label: 'Total', value: _n(stats.total), caption: '≈ ${formatNumber(stepsKm(stats.total, body), maxFractionDigits: 1)} km'),
              StatTile(
                icon: Icons.emoji_events_outlined,
                label: 'Mejor día',
                value: stats.best == null ? '—' : _n(stats.best!.steps),
                caption: stats.best == null ? null : capitalize(weekdayDate(stats.best!.date)),
              ),
              StatTile(icon: Icons.flag_outlined, label: 'Días con la meta', value: '${stats.goalDays} de ${current.length}', caption: stats.streak > 0 ? 'Racha: ${stats.streak} ${stats.streak == 1 ? 'día' : 'días'}' : null),
            ]),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Meta diaria', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong)),
                const SizedBox(height: 8),
                ChoicePills<int>(scrollable: true, options: stepsGoalChoices, selected: goal, label: _n, onSelected: (g) => ref.read(stepsGoalProvider.notifier).set(g)),
                const SizedBox(height: 8),
                Text('Entre 7.000 y 8.000 pasos al día se asocian a mejor salud en adultos (Paluch et al., 2022).', style: TextStyle(fontSize: 11, color: c.faint, height: 1.35)),
              ]),
            ),
            if (allZero)
              Text(
                '¿Ves 0 pasos? Revisa en la app Salud › tu perfil › Apps › Asistente que esté permitido leer "Pasos".',
                style: TextStyle(fontSize: 11, color: c.warning, height: 1.4),
              ),
            Text(
              'Pasos de Apple Salud (iPhone y reloj, sin duplicar). La distancia usa el largo de tu paso según tu estatura'
              '${body.heightCm == null ? ' (sin estatura en tu perfil se usan 0,75 m)' : ''}, y la energía, unas 0,5 kcal por kg y km caminado sobre el reposo: son aproximaciones.',
              style: TextStyle(fontSize: 11, color: c.faint, height: 1.4),
            ),
          ]);
        },
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.today, required this.steps, required this.goal, required this.km, required this.kcal});

  final String day;
  final String today;
  final int steps;
  final int goal;
  final double km;
  final int? kcal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final progress = goalProgress(steps, goal);
    final reached = steps >= goal;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(capitalize(dateLabel(day, today)), style: TextStyle(fontSize: 12, color: c.muted)),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_n(steps), style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1, color: c.fgStrong, fontFeatures: tabular)),
          const SizedBox(width: 6),
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('pasos', style: TextStyle(fontSize: 14, color: c.muted))),
          const Spacer(),
          if (reached) Padding(padding: const EdgeInsets.only(bottom: 8), child: Icon(Icons.check_circle, color: c.success)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: c.surface2, color: reached ? c.success : c.primary),
        ),
        const SizedBox(height: 6),
        Text(
          reached ? 'Meta de ${_n(goal)} cumplida' : '${(progress * 100).round()} % de tu meta de ${_n(goal)} · faltan ${_n(goal - steps)}',
          style: TextStyle(fontSize: 12, color: c.muted),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.straighten, size: 16, color: c.primary),
          const SizedBox(width: 4),
          Text('≈ ${formatNumber(km, maxFractionDigits: 1)} km', style: TextStyle(fontSize: 13, color: c.fg)),
          if (kcal != null) ...[
            const SizedBox(width: 16),
            Icon(Icons.local_fire_department_outlined, size: 16, color: c.kcal),
            const SizedBox(width: 4),
            Text('≈ $kcal kcal caminando', style: TextStyle(fontSize: 13, color: c.fg)),
          ],
        ]),
      ]),
    );
  }
}

/// Pasos por hora del día elegido.
class _HourlyCard extends ConsumerWidget {
  const _HourlyCard({required this.day});

  final String day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Por hora', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong)),
        const SizedBox(height: 10),
        AsyncView(
          ref.watch(hourlyStepsProvider(day)),
          loadingText: 'Leyendo las horas…',
          builder: (hours) {
            final byHour = {for (final h in hours) h.hour: h.steps};
            final top = math.max(1, byHour.values.fold<int>(0, math.max));
            final active = hours.where((h) => h.steps >= 250).length;
            final peak = hours.isEmpty || top <= 1 ? null : hours.reduce((a, b) => b.steps > a.steps ? b : a);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                height: 80,
                child: Semantics(
                  label: 'Pasos por hora',
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    for (var h = 0; h < 24; h++)
                      Expanded(
                        child: Container(
                          height: 2 + 76 * (byHour[h] ?? 0) / top,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: peak?.hour == h ? c.primary : c.primary.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 4),
              Row(children: [
                for (final label in const ['0 h', '6 h', '12 h', '18 h', '24 h'])
                  Expanded(child: Text(label, textAlign: label == '0 h' ? TextAlign.start : (label == '24 h' ? TextAlign.end : TextAlign.center), style: TextStyle(fontSize: 10, color: c.faint))),
              ]),
              const SizedBox(height: 8),
              Text(
                peak == null
                    ? 'Sin pasos registrados por hora este día.'
                    : 'Más activo entre las ${peak.hour}:00 y las ${peak.hour + 1}:00 (${_n(peak.steps)} pasos). $active ${active == 1 ? 'hora' : 'horas'} con movimiento (250 pasos o más).',
                style: TextStyle(fontSize: 12, color: c.muted, height: 1.35),
              ),
            ]);
          },
        ),
      ]),
    );
  }
}

/// Barras de los días del periodo con la línea de la meta.
class _PeriodBars extends StatelessWidget {
  const _PeriodBars({required this.days, required this.byDate, required this.goal, required this.selected, required this.onSelect});

  final List<String> days;
  final Map<String, int> byDate;
  final int goal;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const height = 120.0;
    final top = math.max(goal, days.map((d) => byDate[d] ?? 0).fold<int>(0, math.max)).toDouble();
    final dense = days.length > 31;
    return Column(children: [
      SizedBox(
        height: height,
        child: Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: height * goal / top,
            child: Container(height: 1.5, color: c.success.withValues(alpha: 0.7)),
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final d in days)
              Expanded(
                child: Semantics(
                  button: true,
                  label: '${weekdayDate(d)}: ${_n(byDate[d] ?? 0)} pasos',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(d),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: math.max(2, height * (byDate[d] ?? 0) / top),
                        margin: EdgeInsets.symmetric(horizontal: dense ? 0.5 : 2),
                        decoration: BoxDecoration(
                          color: d == selected ? c.primary : ((byDate[d] ?? 0) >= goal ? c.success.withValues(alpha: 0.75) : c.primary.withValues(alpha: 0.35)),
                          borderRadius: BorderRadius.circular(dense ? 1 : 3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ]),
      ),
      const SizedBox(height: 4),
      Row(children: [
        Text(shortDate(days.first), style: TextStyle(fontSize: 10, color: c.faint)),
        const Spacer(),
        Text(shortDate(days.last), style: TextStyle(fontSize: 10, color: c.faint)),
      ]),
    ]);
  }
}
