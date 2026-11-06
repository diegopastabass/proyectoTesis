import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/cardio_providers.dart';
import '../../app/theme.dart';
import '../../core/cardio/activity.dart';
import '../../core/cardio/geo.dart';
import '../../ui/format.dart';
import '../../ui/widgets.dart';
import 'cardio_widgets.dart';

/// Tamaño lógico de la imagen; se exporta ×3 (1080 × 1920, formato de historias).
const _storySize = Size(360, 640);

/// Imagen para historias de Instagram: la ruta en verde y las métricas principales,
/// con fondo transparente (para pegar sobre una foto) u oscuro.
class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  final _boundary = GlobalKey();
  bool _transparent = true;
  bool _busy = false;

  Future<void> _share(CardioActivity a) async {
    if (kIsWeb) {
      showToast(context, 'Compartir la imagen funciona en el iPhone.');
      return;
    }
    setState(() => _busy = true);
    // El iPad necesita saber desde dónde abrir el menú para compartir.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    await runGuarded(context, () async {
      final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1080 / _storySize.width);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('${(await getTemporaryDirectory()).path}/nutriapp-${a.id}.png');
      await file.writeAsBytes(png!.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          sharePositionOrigin: origin,
        ),
      );
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = ref.watch(cardioActivitiesProvider).value?.where((x) => x.id == widget.id).firstOrNull;
    final track = ref.watch(cardioTrackProvider(widget.id)).value;
    if (a == null) return const LoadingView();
    final segments = track == null
        ? [decodePolyline(a.preview)]
        : [
            for (final s in track.segments)
              if (s.isNotEmpty) simplifyTo([for (final p in s) p.latLng], 600),
          ];

    return PageBody(
      gap: 12,
      children: [
        PageHeader(title: 'Imagen para historias', subtitle: a.title, onBack: () => context.canPop() ? context.pop() : context.go('/cardio/historial/${a.id}')),
        Center(
          child: AppSegmented<bool>(
            value: _transparent,
            segments: const {
              true: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.layers_clear_outlined), SizedBox(width: 6), Text('Transparente')]),
              false: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.dark_mode_outlined), SizedBox(width: 6), Text('Fondo oscuro')]),
            },
            onChanged: (v) => setState(() => _transparent = v),
          ),
        ),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 460,
              child: AspectRatio(
                aspectRatio: _storySize.width / _storySize.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Damero para mostrar qué parte es transparente (no sale en la imagen).
                    if (_transparent) CustomPaint(painter: _Checkerboard(c.surface2, c.bgHard)),
                    FittedBox(
                      child: RepaintBoundary(
                        key: _boundary,
                        child: StoryCard(activity: a, segments: segments, transparent: _transparent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _busy ? null : () => _share(a),
          icon: const Icon(Icons.ios_share),
          label: const Text('Compartir'),
        ),
        Text(
          'Se abre el menú para compartir de iOS: elige Instagram para ponerla en una historia o "Guardar imagen" para dejarla en Fotos. '
          'Con fondo transparente, la ruta y los datos quedan sobre tu foto.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: c.faint, height: 1.4),
        ),
      ],
    );
  }
}

/// La imagen exportada (360 × 640 lógicos).
class StoryCard extends StatelessWidget {
  const StoryCard({super.key, required this.activity, required this.segments, required this.transparent});

  final CardioActivity activity;
  final List<List<LatLng>> segments;
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    const shadows = [Shadow(color: Color(0x99000000), blurRadius: 8)];
    final metrics = headlineMetrics(a.discipline, a.stats);
    return Container(
      width: _storySize.width,
      height: _storySize.height,
      decoration: transparent
          ? null
          : const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1D2021), Color(0xFF282828)]),
            ),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: CustomPaint(
                painter: RoutePainter(segments, strokeWidth: 6, shadow: transparent),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${a.discipline.label.toUpperCase()} · ${capitalize(longDate(a.date))}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1, color: Colors.white70, shadows: shadows),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final m in metrics)
                  Expanded(
                    child: Padding(
                      // Separación entre columnas: los valores largos se achican antes de tocarse.
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: Column(
                        children: [
                          Text(
                            m.label.toUpperCase(),
                            style: const TextStyle(fontSize: 11, letterSpacing: 0.8, color: Colors.white70, shadows: shadows),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            child: Text(
                              m.value,
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, shadows: shadows, fontFeatures: tabular),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/branding/logo.png', width: 26, height: 26),
              const SizedBox(width: 8),
              const Text(
                'NutriApp',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, shadows: shadows),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _Checkerboard extends CustomPainter {
  _Checkerboard(this.a, this.b);

  final Color a;
  final Color b;

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 14.0;
    final pa = Paint()..color = a;
    final pb = Paint()..color = b;
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), ((x + y) / cell).round().isEven ? pa : pb);
      }
    }
  }

  @override
  bool shouldRepaint(_Checkerboard old) => old.a != a || old.b != b;
}
