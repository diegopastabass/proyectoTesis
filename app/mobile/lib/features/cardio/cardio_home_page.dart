import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/cardio_providers.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/cardio/activity.dart';
import '../../core/cardio/geo.dart';
import '../../platform/capability.dart';
import '../../platform/platform_providers.dart';
import '../../ui/format.dart';
import '../../ui/widgets.dart';
import 'cardio_widgets.dart';

/// Inicio de cardio: elegir disciplina y un botón grande para empezar a grabar.
/// Mientras está abierta, el GPS ya busca señal para que "Iniciar" sea inmediato.
class CardioHomePage extends ConsumerStatefulWidget {
  const CardioHomePage({super.key});

  @override
  ConsumerState<CardioHomePage> createState() => _CardioHomePageState();
}

class _CardioHomePageState extends ConsumerState<CardioHomePage> {
  late Discipline _discipline = Discipline.from(ref.read(localStoreProvider).cardioDiscipline);
  bool _starting = false;

  void _pick(Discipline d) {
    setState(() => _discipline = d);
    ref.read(localStoreProvider).setCardioDiscipline(d.name);
  }

  Future<void> _start() async {
    if (ref.read(recordingProvider) != null) {
      context.go('/cardio/grabar');
      return;
    }
    setState(() => _starting = true);
    HapticFeedback.mediumImpact();
    final status = await ref.read(recordingProvider.notifier).start(_discipline);
    if (!mounted) return;
    setState(() => _starting = false);
    if (status.usable) {
      context.go('/cardio/grabar');
    } else {
      showToast(context, 'Sin permiso de ubicación no se puede grabar la ruta. Actívalo en Ajustes de iOS.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = ref.watch(locationStatusProvider).value;
    final fix = ref.watch(gpsWarmupProvider).value;
    final recording = ref.watch(recordingProvider);
    final recent = ref.watch(cardioActivitiesProvider).value ?? const [];

    final (gpsText, gpsColor) = switch (status) {
      CapabilityStatus.granted when fix == null => ('Buscando señal GPS…', c.warning),
      CapabilityStatus.granted => ('GPS listo · ±${fix!.accuracy?.round() ?? '?'} m', fix.accuracy != null && fix.accuracy! <= 20 ? c.success : c.warning),
      CapabilityStatus.notDetermined => ('Se pedirá permiso de ubicación al iniciar', c.muted),
      CapabilityStatus.denied => ('Ubicación desactivada', c.danger),
      CapabilityStatus.unsupported || CapabilityStatus.notImplemented => ('El GPS funciona en el iPhone', c.muted),
      null => ('Revisando el GPS…', c.muted),
    };

    return PageBody(
      children: [
        if (recording != null)
          AppCard(
            borderColor: c.primary.withValues(alpha: 0.5),
            padding: const EdgeInsets.all(12),
            onTap: () => context.go(recording.tracking ? '/cardio/grabar' : '/cardio/guardar'),
            child: Row(
              children: [
                GradientIcon(disciplineIcon(recording.recording.discipline)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recording.tracking ? 'Grabando' : 'Actividad sin guardar', style: TextStyle(fontSize: 12, color: c.muted)),
                      Text(
                        '${recording.recording.discipline.label} · ${formatKm(recording.recording.metrics.distanceM)}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: c.faint),
              ],
            ),
          ),
        RouteMap(segments: const [], current: fix == null ? null : LatLng(fix.latitude, fix.longitude), follow: true, height: 220),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gps_fixed, size: 14, color: gpsColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(gpsText, style: TextStyle(fontSize: 12, color: gpsColor)),
            ),
            if (status == CapabilityStatus.denied) TextButton(onPressed: () => launchUrl(Uri.parse('app-settings:')), child: const Text('Ajustes')),
          ],
        ),
        Center(
          child: DisciplinePicker(value: recording?.recording.discipline ?? _discipline, onChanged: recording == null ? _pick : (_) {}),
        ),
        Center(
          child: Semantics(
            container: true,
            button: true,
            label: recording != null ? 'Volver a la grabación' : 'Iniciar ${_discipline.label.toLowerCase()}',
            excludeSemantics: true,
            // La sombra va por fuera: dentro del Material se recortaría a su rectángulo y se vería un recuadro.
            child: Pressable(
              scale: 0.93,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: c.primary.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 2)],
                ),
                // Material circular propio: recorta el degradado y el efecto del toque al círculo, y evita que el
                // Ink se pinte en el Material del marco (se vería bajo otras pantallas).
                child: Material(
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  color: Colors.transparent,
                  child: Ink(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(gradient: c.gradient),
                    child: InkWell(
                      onTap: _starting ? null : _start,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(recording != null ? Icons.fiber_manual_record : Icons.play_arrow_rounded, size: 52, color: c.onPrimary),
                          Text(
                            recording != null ? 'CONTINUAR' : 'INICIAR',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: c.onPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (recent.isNotEmpty) ...[
          SectionTitle(
            'Últimas actividades',
            trailing: TextButton(onPressed: () => context.go('/cardio/historial'), child: const Text('Ver todo')),
          ),
          for (final a in recent.take(2)) ActivityTile(activity: a),
        ],
      ],
    );
  }
}

/// Fila del historial: miniatura de la ruta, título, fecha y métricas principales.
class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.activity});

  final CardioActivity activity;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = activity;
    final route = decodePolyline(a.preview);
    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => context.push('/cardio/historial/${a.id}'),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: c.bgHard, borderRadius: BorderRadius.circular(12)),
            child: CustomPaint(painter: RoutePainter([route], strokeWidth: 2.5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(disciplineIcon(a.discipline), size: 15, color: c.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong),
                      ),
                    ),
                    Icon(
                      a.syncState == SyncState.synced ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
                      size: 15,
                      color: a.syncState == SyncState.synced ? c.faint : c.warning,
                      semanticLabel: a.syncState == SyncState.synced ? 'Respaldada' : 'Pendiente de respaldo',
                    ),
                  ],
                ),
                Text(capitalize(weekdayDate(a.date)), style: TextStyle(fontSize: 11, color: c.faint)),
                const SizedBox(height: 4),
                Text(
                  headlineMetrics(a.discipline, a.stats).map((m) => m.value).join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.fg, fontFeatures: tabular),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
