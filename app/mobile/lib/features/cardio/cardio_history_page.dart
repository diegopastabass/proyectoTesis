import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/cardio_providers.dart';
import '../../app/theme.dart';
import '../../core/cardio/activity.dart';
import '../../core/common/date.dart';
import '../../core/strength/calendar.dart' show weekStart;
import '../../ui/widgets.dart';
import 'cardio_home_page.dart';
import 'cardio_widgets.dart';

/// Actividades guardadas, con el resumen de la semana.
class CardioHistoryPage extends ConsumerWidget {
  const CardioHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return AsyncView(
      ref.watch(cardioActivitiesProvider),
      builder: (list) {
        final monday = weekStart(todayKey());
        final week = list.where((a) => a.date.compareTo(monday) >= 0).toList();
        final pending = list.where((a) => a.syncState == SyncState.pending).length;
        return RefreshIndicator.adaptive(
          onRefresh: () => ref.read(cardioActivitiesProvider.notifier).sync(),
          child: PageBody(
            children: [
              TileGrid(
                columns: 3,
                children: [
                  StatTile(icon: Icons.event_available, label: 'Esta semana', value: '${week.length}', caption: week.length == 1 ? 'actividad' : 'actividades'),
                  StatTile(icon: Icons.straighten, label: 'Distancia', value: formatKm(week.fold(0, (s, a) => s + a.stats.distanceM))),
                  StatTile(icon: Icons.trending_up, label: 'Desnivel', value: formatMeters(week.fold(0, (s, a) => s + a.stats.gainM))),
                ],
              ),
              if (pending > 0)
                Row(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 16, color: c.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$pending ${pending == 1 ? 'actividad pendiente' : 'actividades pendientes'} de respaldo: se suben al tener internet.',
                        style: TextStyle(fontSize: 12, color: c.muted),
                      ),
                    ),
                  ],
                ),
              if (list.isEmpty)
                const AppCard(
                  child: EmptyState(
                    icon: Icons.route,
                    title: 'Aún no grabas rutas',
                    message: 'Toca Iniciar en Grabar: la app registra distancia, ritmo y desnivel con el GPS del teléfono.',
                  ),
                ),
              for (final a in list) ActivityTile(activity: a),
            ],
          ),
        );
      },
    );
  }
}
