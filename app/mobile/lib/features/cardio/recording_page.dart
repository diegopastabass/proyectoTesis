import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/cardio_providers.dart';
import '../../app/theme.dart';
import '../../core/cardio/activity.dart';
import '../../core/cardio/geo.dart';
import '../../ui/widgets.dart';
import 'cardio_widgets.dart';

/// Pantalla de grabación: tiempo grande, métricas de la disciplina y el mapa.
class RecordingPage extends ConsumerStatefulWidget {
  const RecordingPage({super.key});

  @override
  ConsumerState<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends ConsumerState<RecordingPage> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // El tiempo avanza aunque no lleguen puntos (detenido en un semáforo).
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    await ref.read(recordingProvider.notifier).stop();
    if (mounted) context.go('/cardio/guardar');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final snap = ref.watch(recordingProvider);
    if (snap == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/cardio');
      });
      return const Scaffold(body: LoadingView());
    }
    final r = snap.recording;
    final now = DateTime.now().millisecondsSinceEpoch;
    final stats = r.stats(now);
    final fix = snap.fix;
    final fresh = fix != null && now - fix.at.millisecondsSinceEpoch < 10000;
    final currentSpeed = fresh ? (fix.speed ?? 0) : 0.0;
    final paused = r.paused;
    final ctrl = ref.read(recordingProvider.notifier);

    final live = switch (r.discipline) {
      Discipline.running => [
        Metric('Distancia', formatKm(stats.distanceM)),
        Metric('Ritmo medio', formatPace(stats.paceSPerKm)),
        Metric('Ritmo actual', currentSpeed > 0.5 ? formatPace(1000 / currentSpeed) : '–'),
        Metric('Desnivel +', formatMeters(stats.gainM)),
      ],
      Discipline.cycling => [
        Metric('Distancia', formatKm(stats.distanceM)),
        Metric('Velocidad', formatSpeed(currentSpeed)),
        Metric('Vel. media', formatSpeed(stats.avgSpeedMs)),
        Metric('Desnivel +', formatMeters(stats.gainM)),
      ],
      Discipline.trekking => [
        Metric('Distancia', formatKm(stats.distanceM)),
        Metric('Desnivel +', formatMeters(stats.gainM)),
        Metric('Altura', fix?.altitude == null ? '–' : formatMeters(fix!.altitude!)),
        Metric('Ritmo medio', formatPace(stats.paceSPerKm)),
      ],
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(tooltip: 'Minimizar (sigue grabando)', onPressed: () => context.go('/cardio'), icon: const Icon(Icons.keyboard_arrow_down)),
                  Expanded(
                    child: Center(
                      child: DisciplinePicker(value: r.discipline, onChanged: ctrl.setDiscipline, compact: true),
                    ),
                  ),
                  Icon(Icons.gps_fixed, size: 16, color: !fresh ? c.danger : (fix.accuracy != null && fix.accuracy! <= 20 ? c.success : c.warning)),
                  const SizedBox(width: 4),
                  Text(!fresh ? 'Sin señal' : '±${fix.accuracy?.round() ?? '?'} m', style: TextStyle(fontSize: 11, color: c.muted)),
                ],
              ),
            ),
            // El aviso de pausa aparece y se va estirando el espacio, sin saltos.
            AnimatedSize(
              duration: Motion.standardDuration,
              curve: Motion.standard,
              child: paused
                  ? Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: ShapeDecoration(color: c.warning.withValues(alpha: 0.18), shape: const StadiumBorder()),
                      child: Text(
                        'EN PAUSA',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1, color: c.warning),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  Text(
                    'TIEMPO',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1, color: c.faint),
                  ),
                  Text(
                    formatClockDuration(stats.durationS),
                    style: TextStyle(fontSize: 56, fontWeight: FontWeight.w700, color: c.fgStrong, fontFeatures: tabular, height: 1.1),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  for (final m in live)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            m.value,
                            maxLines: 1,
                            style: TextStyle(fontSize: m.label == 'Distancia' ? 20 : 17, fontWeight: FontWeight.w700, color: c.fgStrong, fontFeatures: tabular),
                          ),
                          Text(m.label, style: TextStyle(fontSize: 11, color: c.muted)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: LayoutBuilder(
                  builder: (_, box) => RouteMap(
                    segments: [
                      for (final s in r.segments) [for (final p in s) p.latLng],
                    ],
                    current: fix == null ? null : LatLng(fix.latitude, fix.longitude),
                    follow: true,
                    height: box.maxHeight,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              // Pausar se transforma en Reanudar / Terminar con un resorte (interrumpible).
              child: AnimatedSwitcher(
                duration: Motion.standardDuration,
                switchInCurve: Motion.standard,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(a), child: child),
                ),
                child: paused
                    ? Row(
                        key: const ValueKey('paused'),
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                              onPressed: ctrl.resume,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Reanudar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56), foregroundColor: c.fgStrong),
                              onPressed: _finish,
                              icon: const Icon(Icons.stop),
                              label: const Text('Terminar'),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        key: const ValueKey('recording'),
                        child: Semantics(
                          container: true,
                          button: true,
                          label: 'Pausar',
                          excludeSemantics: true,
                          child: Pressable(
                            scale: 0.9,
                            child: Material(
                              type: MaterialType.transparency,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  ctrl.pause();
                                },
                                child: Ink(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    color: c.surface2,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: c.borderStrong),
                                  ),
                                  child: Icon(Icons.pause, size: 36, color: c.fgStrong),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            if (stats.distanceM == 0 && !paused)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Puedes bloquear el teléfono: la ruta se sigue grabando.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: c.faint),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
