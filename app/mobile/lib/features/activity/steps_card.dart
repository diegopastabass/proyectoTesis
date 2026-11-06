import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/activity/models.dart';
import '../../core/common/date.dart';
import '../../core/common/numbers.dart';
import '../../platform/capability.dart';
import '../../platform/platform_providers.dart';
import '../../ui/widgets.dart';

const _weekdayInitials = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

/// Pasos del día (y de la semana) leídos desde Apple Salud.
/// No se muestra donde Apple Salud no existe (web, Android por ahora).
class StepsCard extends ConsumerWidget {
  const StepsCard({super.key, required this.date});

  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(healthStatusProvider).value;
    if (status == null || status == CapabilityStatus.unsupported || status == CapabilityStatus.notImplemented) {
      return const SizedBox.shrink();
    }
    final c = context.colors;
    final header = Row(children: [
      Icon(Icons.directions_walk, size: 18, color: c.primary),
      const SizedBox(width: 8),
      Expanded(child: Text('Pasos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong))),
      Text('Apple Salud', style: TextStyle(fontSize: 11, color: c.faint)),
      if (status.usable)
        IconButton(
          tooltip: 'Actualizar pasos',
          visualDensity: VisualDensity.compact,
          onPressed: () => ref.invalidate(weekStepsProvider(date)),
          icon: Icon(Icons.refresh, size: 18, color: c.muted),
        ),
    ]);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        if (!status.usable) ...[
          const SizedBox(height: 4),
          Text('Conecta Apple Salud para ver los pasos que registran tu iPhone y tu reloj.',
              style: TextStyle(fontSize: 12, color: c.muted, height: 1.4)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => runGuarded(context, () async {
                final result = await connectHealth(ref);
                if (result == CapabilityStatus.denied) throw Exception('No se pudo abrir el permiso de Apple Salud.');
              }),
              icon: const Icon(Icons.favorite_border, size: 18),
              label: const Text('Conectar Apple Salud'),
            ),
          ),
        ] else
          AsyncView(
            ref.watch(weekStepsProvider(date)),
            loadingText: 'Leyendo Apple Salud…',
            builder: (week) => _StepsWeek(date: date, week: week),
          ),
      ]),
    );
  }
}

class _StepsWeek extends StatelessWidget {
  const _StepsWeek({required this.date, required this.week});

  final String date;
  final List<DailySteps> week;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final byDate = {for (final d in week) d.date: d.steps};
    final days = [for (var i = 6; i >= 0; i--) addDays(date, -i)];
    final today = byDate[date] ?? 0;
    final maxSteps = math.max(1, days.map((d) => byDate[d] ?? 0).reduce(math.max));
    final allZero = days.every((d) => (byDate[d] ?? 0) == 0);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(formatNumber(today, maxFractionDigits: 0),
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: c.fgStrong, fontFeatures: tabular)),
          Text(date == todayKey() ? 'pasos hoy' : 'pasos ese día', style: TextStyle(fontSize: 11, color: c.faint)),
        ]),
        const SizedBox(width: 16),
        Expanded(
          child: Semantics(
            label: 'Pasos de los últimos 7 días',
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final d in days)
                Expanded(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      height: 4 + 36 * (byDate[d] ?? 0) / maxSteps,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: d == date ? c.primary : c.primary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_weekdayInitials[fromDateKey(d).weekday - 1],
                        style: TextStyle(fontSize: 10, color: d == date ? c.primary : c.faint)),
                  ]),
                ),
            ]),
          ),
        ),
      ]),
      if (allZero) ...[
        const SizedBox(height: 8),
        // HealthKit no avisa si se negó el permiso: solo devuelve 0.
        Text(
          '¿Ves 0 pasos? Revisa en la app Salud › tu perfil › Apps › Asistente que esté permitido leer "Pasos".',
          style: TextStyle(fontSize: 11, color: c.warning, height: 1.4),
        ),
      ],
    ]);
  }
}
