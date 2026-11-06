import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/strength/models.dart';
import '../../core/strength/stats.dart';
import '../../ui/format.dart';
import '../../ui/widgets.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return AsyncView(ref.watch(workoutsProvider), builder: (workouts) {
      final months = <String, List<Workout>>{};
      for (final w in workouts) {
        (months[w.date.substring(0, 7)] ??= []).add(w);
      }
      return PageBody(children: [
        const SectionTitle('Historial'),
        if (workouts.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.history,
              title: 'Aún no terminas ningún entrenamiento',
              message: 'Cuando termines uno, aparecerá aquí con su volumen total y tus avances.',
            ),
          ),
        for (final MapEntry(key: month, value: list) in months.entries)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                '${capitalize(monthYear('$month-01'))} · ${list.length} ${list.length == 1 ? 'entrenamiento' : 'entrenamientos'}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.muted),
              ),
            ),
            CardList(children: [
              for (final w in list)
                () {
                  final t = workoutTotals(w);
                  return InkWell(
                    onTap: () => context.push('/fuerza/historial/${w.id}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        SizedBox(width: 52, child: Text(weekdayDay(w.date), style: TextStyle(fontSize: 12, color: c.muted))),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(w.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.fg)),
                            Text('${t.exercises} ejercicios · ${t.sets} series · ${formatDuration(t.durationMin)}',
                                style: TextStyle(fontSize: 12, color: c.faint)),
                          ]),
                        ),
                        Text(formatVolume(t.volume), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong, fontFeatures: tabular)),
                        Icon(Icons.chevron_right, color: c.faint),
                      ]),
                    ),
                  );
                }(),
            ]),
          ]),
      ]);
    });
  }
}
