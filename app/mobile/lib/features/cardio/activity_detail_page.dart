import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/cardio_providers.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/cardio/activity.dart';
import '../../core/cardio/track.dart' as tr show Split;
import '../../core/common/numbers.dart';
import '../../core/training/load.dart';
import '../../ui/format.dart';
import '../../ui/rpe.dart';
import '../../ui/widgets.dart';
import 'cardio_widgets.dart';

/// Detalle de una actividad: mapa, métricas de su disciplina, parciales y perfil de altura.
class ActivityDetailPage extends ConsumerWidget {
  const ActivityDetailPage({super.key, required this.id});

  final String id;

  Future<void> _edit(BuildContext context, WidgetRef ref, CardioActivity a) async {
    final title = TextEditingController(text: a.title);
    final description = TextEditingController(text: a.description);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar actividad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Título'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Descripción'),
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final newTitle = title.text.trim().isEmpty ? a.title : title.text.trim();
      await runGuarded(context, () => ref.read(cardioActivitiesProvider.notifier).edit(a.copyWith(title: newTitle, description: description.text.trim())));
    }
    title.dispose();
    description.dispose();
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, CardioActivity a) async {
    if (!await confirm(context, '¿Eliminar "${a.title}"? También se borra el respaldo.', accept: 'Eliminar', destructive: true)) return;
    if (!context.mounted) return;
    final ok = await runGuarded(context, () => ref.read(cardioActivitiesProvider.notifier).remove(a.id), success: 'Actividad eliminada');
    if (ok && context.mounted) context.go('/cardio/historial');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return AsyncView(
      ref.watch(cardioActivitiesProvider),
      builder: (list) {
        final a = list.where((x) => x.id == id).firstOrNull;
        if (a == null) return const LoadingView(text: 'Actividad no encontrada.');
        final track = ref.watch(cardioTrackProvider(id)).value;
        final kg = ref.watch(weightsProvider).value?.lastOrNull?.kg;
        final splits = track == null ? const <tr.Split>[] : splitsOf(track);
        final profile = track == null ? const <(double, double)>[] : elevationProfile(track);
        final start = DateTime.fromMillisecondsSinceEpoch(a.startedAt);
        final load = cardioSessionLoad(a);

        return PageBody(
          gap: 12,
          children: [
            PageHeader(
              title: a.title,
              subtitle: '${capitalize(weekdayDateYear(a.date))} · ${start.hour}:${start.minute.toString().padLeft(2, '0')}',
              onBack: () => context.canPop() ? context.pop() : context.go('/cardio/historial'),
              actions: [
                IconButton(tooltip: 'Compartir imagen', onPressed: () => context.push('/cardio/historial/$id/exportar'), icon: const Icon(Icons.ios_share)),
                PopupMenuButton<String>(
                  tooltip: 'Opciones',
                  onSelected: (v) => v == 'edit' ? _edit(context, ref, a) : _delete(context, ref, a),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar título y descripción')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar', style: TextStyle(color: c.danger)),
                    ),
                  ],
                ),
              ],
            ),
            Center(
              child: DisciplinePicker(
                value: a.discipline,
                onChanged: (d) => runGuarded(context, () => ref.read(cardioActivitiesProvider.notifier).edit(a.copyWith(discipline: d))),
              ),
            ),
            if (a.description.isNotEmpty) Text(a.description, style: TextStyle(fontSize: 14, color: c.fg, height: 1.4)),
            RouteMap(
              segments: track == null
                  ? const []
                  : [
                      for (final s in track.segments) [for (final p in s) p.latLng],
                    ],
            ),
            MetricGrid(activityMetrics(a.discipline, a.stats, kcal: estimateKcal(a.discipline, a.stats, kg))),
            if (kg == null) Text('Registra tu peso en Nutrición › Progreso para estimar las calorías.', style: TextStyle(fontSize: 11, color: c.faint)),
            TileGrid(children: [
              StatTile(
                icon: Icons.speed,
                label: 'Esfuerzo',
                value: a.rpe == null ? 'Indicar' : '${a.rpe}/10',
                caption: a.rpe == null ? 'Estimado: ${load.rpe}/10' : rpeLabel(a.rpe!),
                onTap: () async {
                  final answer = await askSessionRpe(context, title: '¿Qué tan dura fue?', initial: a.rpe, allowSkip: false);
                  final rpe = answer?.rpe;
                  if (rpe == null || rpe == a.rpe || !context.mounted) return;
                  await runGuarded(context, () => ref.read(cardioActivitiesProvider.notifier).edit(a.copyWith(rpe: rpe)));
                },
              ),
              StatTile(
                icon: Icons.bolt,
                label: 'Carga',
                value: formatLoad(load.load),
                caption: load.estimated ? 'Estimada por la velocidad' : 'Esfuerzo × minutos',
                tooltip: 'Carga de la sesión: esfuerzo percibido (1–10) × minutos. Sirve para comparar fuerza y cardio.',
              ),
            ]),
            if (profile.length > 1)
              CardList(
                header: const CardHeader('Perfil de altura', icon: Icons.terrain),
                children: [Padding(padding: const EdgeInsets.all(12), child: ElevationChart(profile))],
              ),
            if (splits.isNotEmpty)
              CardList(
                header: CardHeader(
                  'Parciales por kilómetro',
                  icon: Icons.flag_outlined,
                  trailing: Text(a.discipline == Discipline.cycling ? 'km/h' : 'ritmo', style: TextStyle(fontSize: 11, color: c.faint)),
                ),
                children: [
                  for (final s in splits)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            child: Text(
                              s.distanceM < 1000 ? formatNumber(s.distanceM / 1000, maxFractionDigits: 2) : '${s.index}',
                              style: TextStyle(fontSize: 13, color: c.muted, fontFeatures: tabular),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              a.discipline == Discipline.cycling ? formatSpeed(s.movingS > 0 ? s.distanceM / s.movingS : 0) : formatPace(s.paceSPerKm),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.fgStrong, fontFeatures: tabular),
                            ),
                          ),
                          Text(
                            '${s.gainM >= 0.5 ? '+' : ''}${formatNumber(jsRound(s.gainM))} m',
                            style: TextStyle(fontSize: 12, color: c.muted, fontFeatures: tabular),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            FilledButton.icon(
              onPressed: () => context.push('/cardio/historial/$id/exportar'),
              icon: const Icon(Icons.ios_share),
              label: const Text('Compartir imagen para historias'),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  a.syncState == SyncState.synced ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
                  size: 14,
                  color: a.syncState == SyncState.synced ? c.success : c.warning,
                ),
                const SizedBox(width: 6),
                Text(
                  a.syncState == SyncState.synced ? 'Respaldada en tu cuenta' : 'Guardada en el teléfono; se respalda al tener internet',
                  style: TextStyle(fontSize: 11, color: c.muted),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
