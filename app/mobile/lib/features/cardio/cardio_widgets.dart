import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../../app/cardio_providers.dart';
import '../../app/theme.dart';
import '../../core/cardio/activity.dart';
import '../../core/cardio/geo.dart';
import '../../core/common/numbers.dart';
import '../../ui/widgets.dart';

/// Verde de las rutas (mapa, miniaturas e imagen para historias).
const routeGreen = Color(0xFF7ED957);

IconData disciplineIcon(Discipline d) => switch (d) {
  Discipline.running => Icons.directions_run,
  Discipline.cycling => Icons.directions_bike,
  Discipline.trekking => Icons.hiking,
};

String formatKm(double meters) => '${formatNumber(meters / 1000, maxFractionDigits: 2)} km';

/// "1:02:15" o "32:10".
String formatClockDuration(double seconds) {
  final s = seconds.round();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
}

/// "5:33 /km"; "–" sin distancia.
String formatPace(double secondsPerKm) {
  if (secondsPerKm <= 0 || secondsPerKm > 3600) return '–';
  final s = secondsPerKm.round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')} /km';
}

String formatSpeed(double ms) => '${formatNumber(ms * 3.6, maxFractionDigits: 1)} km/h';

String formatMeters(double m) => '${formatNumber(jsRound(m))} m';

class Metric {
  const Metric(this.label, this.value, {this.icon});

  final String label;
  final String value;
  final IconData? icon;
}

/// Métricas de una actividad guardada, en el orden que importa para cada disciplina.
List<Metric> activityMetrics(Discipline d, CardioStats s, {int? kcal}) {
  final calories = kcal == null ? null : Metric('Calorías', '$kcal kcal', icon: Icons.local_fire_department_outlined);
  return switch (d) {
    Discipline.running => [
      Metric('Distancia', formatKm(s.distanceM), icon: Icons.straighten),
      Metric('Ritmo medio', formatPace(s.paceSPerKm), icon: Icons.speed),
      Metric('Tiempo en movimiento', formatClockDuration(s.movingS), icon: Icons.timer_outlined),
      Metric('Desnivel positivo', formatMeters(s.gainM), icon: Icons.trending_up),
      Metric('Tiempo total', formatClockDuration(s.durationS), icon: Icons.schedule),
      ?calories,
    ],
    Discipline.cycling => [
      Metric('Distancia', formatKm(s.distanceM), icon: Icons.straighten),
      Metric('Velocidad media', formatSpeed(s.avgSpeedMs), icon: Icons.speed),
      Metric('Tiempo en movimiento', formatClockDuration(s.movingS), icon: Icons.timer_outlined),
      Metric('Desnivel positivo', formatMeters(s.gainM), icon: Icons.trending_up),
      Metric('Velocidad máxima', formatSpeed(s.maxSpeedMs), icon: Icons.bolt),
      ?calories,
    ],
    Discipline.trekking => [
      Metric('Distancia', formatKm(s.distanceM), icon: Icons.straighten),
      Metric('Tiempo total', formatClockDuration(s.durationS), icon: Icons.schedule),
      Metric('Desnivel positivo', formatMeters(s.gainM), icon: Icons.trending_up),
      Metric('Desnivel negativo', formatMeters(s.lossM), icon: Icons.trending_down),
      Metric('Altura máxima', s.maxAltM == null ? '–' : formatMeters(s.maxAltM!), icon: Icons.terrain),
      Metric('Ascenso por hora', '${formatNumber(jsRound(s.ascentRateMh))} m/h', icon: Icons.north_east),
      Metric('Tiempo en movimiento', formatClockDuration(s.movingS), icon: Icons.timer_outlined),
      ?calories,
    ],
  };
}

/// Las tres que van en la imagen para historias.
List<Metric> headlineMetrics(Discipline d, CardioStats s) => switch (d) {
  Discipline.running => [
    Metric('Distancia', formatKm(s.distanceM)),
    Metric('Ritmo', formatPace(s.paceSPerKm)),
    Metric('Tiempo', formatClockDuration(s.movingS)),
  ],
  Discipline.cycling => [
    Metric('Distancia', formatKm(s.distanceM)),
    Metric('Vel. media', formatSpeed(s.avgSpeedMs)),
    Metric('Desnivel', formatMeters(s.gainM)),
  ],
  Discipline.trekking => [
    Metric('Distancia', formatKm(s.distanceM)),
    Metric('Desnivel', formatMeters(s.gainM)),
    Metric('Tiempo', formatClockDuration(s.durationS)),
  ],
};

/// Grilla de métricas (2 columnas).
class MetricGrid extends StatelessWidget {
  const MetricGrid(this.metrics, {super.key});

  final List<Metric> metrics;

  @override
  Widget build(BuildContext context) => TileGrid(
    children: [for (final m in metrics) StatTile(icon: m.icon ?? Icons.insights, label: m.label, value: m.value)],
  );
}

/// Selector de disciplina (se puede cambiar en cualquier momento).
class DisciplinePicker extends StatelessWidget {
  const DisciplinePicker({super.key, required this.value, required this.onChanged, this.compact = false});

  final Discipline value;
  final ValueChanged<Discipline> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) => AppSegmented<Discipline>(
    value: value,
    segments: {
      for (final d in Discipline.values)
        d: compact
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(disciplineIcon(d), semanticLabel: d.label),
              )
            : Row(mainAxisSize: MainAxisSize.min, children: [Icon(disciplineIcon(d)), const SizedBox(width: 6), Text(d.label)]),
    },
    onChanged: (d) {
      if (d != value) HapticFeedback.selectionClick();
      onChanged(d);
    },
  );
}

/// Dibuja la ruta escalada al espacio disponible, sin mapa (miniaturas e imagen exportada).
class RoutePainter extends CustomPainter {
  RoutePainter(this.segments, {this.color = routeGreen, this.strokeWidth = 3, this.shadow = false});

  final List<List<LatLng>> segments;
  final Color color;
  final double strokeWidth;

  /// Sombra oscura para que la línea se vea sobre fotos claras.
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = GeoBounds.of(segments.expand((s) => s));
    if (bounds == null) return;
    // Proyección equirectangular corregida por la latitud: la forma no se deforma.
    final k = math.cos((bounds.north + bounds.south) / 2 * math.pi / 180);
    final w = math.max((bounds.east - bounds.west) * k, 1e-9);
    final h = math.max(bounds.north - bounds.south, 1e-9);
    final pad = strokeWidth * 2;
    final scale = math.min((size.width - 2 * pad) / w, (size.height - 2 * pad) / h);
    final dx = (size.width - w * scale) / 2;
    final dy = (size.height - h * scale) / 2;
    Offset at(LatLng p) => Offset(dx + (p.lng - bounds.west) * k * scale, dy + (bounds.north - p.lat) * scale);

    final path = Path();
    for (final seg in segments) {
      if (seg.isEmpty) continue;
      path.moveTo(at(seg.first).dx, at(seg.first).dy);
      for (final p in seg.skip(1)) {
        path.lineTo(at(p).dx, at(p).dy);
      }
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (shadow) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.black.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    canvas.drawPath(
      path,
      stroke
        ..strokeWidth = strokeWidth
        ..color = color,
    );
    // Inicio y fin.
    final first = segments.firstWhere((s) => s.isNotEmpty, orElse: () => const []);
    final last = segments.lastWhere((s) => s.isNotEmpty, orElse: () => const []);
    if (first.isNotEmpty) canvas.drawCircle(at(first.first), strokeWidth * 1.3, Paint()..color = color);
    if (last.isNotEmpty) {
      canvas.drawCircle(at(last.last), strokeWidth * 1.6, Paint()..color = Colors.white);
      canvas.drawCircle(at(last.last), strokeWidth * 1.1, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(RoutePainter old) => old.segments != segments || old.color != color || old.strokeWidth != strokeWidth;
}

/// Mapa con la ruta en verde. Sin teselas (o sin internet) se ve solo la línea.
class RouteMap extends ConsumerStatefulWidget {
  const RouteMap({super.key, required this.segments, this.current, this.follow = false, this.height = 260});

  final List<List<LatLng>> segments;

  /// Posición actual (punto azul).
  final LatLng? current;

  /// Centrar en la posición actual (durante la grabación).
  final bool follow;
  final double height;

  @override
  ConsumerState<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends ConsumerState<RouteMap> {
  final _controller = fm.MapController();
  bool _ready = false;

  @override
  void didUpdateWidget(RouteMap old) {
    super.didUpdateWidget(old);
    final p = widget.current;
    // Durante la grabación el mapa sigue a la posición sin perder el zoom elegido.
    if (widget.follow && _ready && p != null && p != old.current) {
      _controller.move(ll.LatLng(p.lat, p.lng), _controller.camera.zoom);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final segments = widget.segments;
    final current = widget.current;
    final follow = widget.follow;
    final height = widget.height;
    final tiles = ref.watch(mapTilesProvider);
    final points = [for (final s in segments) ...s, ?current];
    ll.LatLng conv(LatLng p) => ll.LatLng(p.lat, p.lng);

    if (points.isEmpty) {
      return Container(
        height: height,
        decoration: ShapeDecoration(color: c.card, shape: smoothShape(20)),
        alignment: Alignment.center,
        child: Text('Esperando señal del GPS…', style: TextStyle(fontSize: 12, color: c.muted)),
      );
    }
    if (!tiles) {
      return Container(
        height: height,
        decoration: ShapeDecoration(color: c.card, shape: smoothShape(20)),
        child: CustomPaint(painter: RoutePainter(segments, strokeWidth: 4), size: Size.infinite),
      );
    }

    final bounds = GeoBounds.of(points)!;
    final single = bounds.north - bounds.south < 1e-4 && bounds.east - bounds.west < 1e-4;
    const interaction = fm.InteractionOptions(flags: fm.InteractiveFlag.all & ~fm.InteractiveFlag.rotate);
    final options = follow || single
        ? fm.MapOptions(initialCenter: conv(current ?? points.last), initialZoom: 16, interactionOptions: interaction, onMapReady: () => _ready = true)
        : fm.MapOptions(
            initialCameraFit: fm.CameraFit.bounds(
              bounds: fm.LatLngBounds(ll.LatLng(bounds.south, bounds.west), ll.LatLng(bounds.north, bounds.east)),
              padding: const EdgeInsets.all(28),
            ),
            interactionOptions: interaction,
            onMapReady: () => _ready = true,
          );
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: height,
        child: fm.FlutterMap(
          mapController: _controller,
          options: options,
          children: [
            fm.TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'cl.asistentedeportivo.asistenteDeportivo'),
            fm.PolylineLayer(
              polylines: [
                for (final s in segments)
                  if (s.length > 1)
                    fm.Polyline(points: [for (final p in s) conv(p)], color: routeGreen, strokeWidth: 5, borderColor: Colors.black26, borderStrokeWidth: 1.5),
              ],
            ),
            if (current != null)
              fm.MarkerLayer(
                markers: [
                  fm.Marker(
                    point: conv(current),
                    width: 18,
                    height: 18,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
            const _MapAttribution(),
          ],
        ),
      ),
    );
  }
}

/// Crédito de OpenStreetMap (lo exige su licencia): pequeño y en la esquina,
/// para no tapar el mapa. Al tocarlo abre la página de derechos de autor.
class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.bottomRight,
        child: Semantics(
          link: true,
          label: 'Mapa de OpenStreetMap',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'), mode: LaunchMode.externalApplication),
            child: Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(4)),
              child: const Text('© OpenStreetMap', style: TextStyle(fontSize: 9, color: Colors.black87)),
            ),
          ),
        ),
      );
}

/// Perfil de altura (área bajo la curva).
class ElevationChart extends StatelessWidget {
  const ElevationChart(this.profile, {super.key, this.height = 120});

  final List<(double km, double alt)> profile;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (profile.length < 2) return const SizedBox.shrink();
    final alts = profile.map((p) => p.$2);
    final min = alts.reduce(math.min);
    final max = alts.reduce(math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(painter: _ElevationPainter(profile, c.success, c.border)),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('${formatNumber(jsRound(min))}–${formatNumber(jsRound(max))} m', style: TextStyle(fontSize: 11, color: c.muted)),
            const Spacer(),
            Text('${formatNumber(profile.last.$1, maxFractionDigits: 1)} km', style: TextStyle(fontSize: 11, color: c.muted)),
          ],
        ),
      ],
    );
  }
}

class _ElevationPainter extends CustomPainter {
  _ElevationPainter(this.profile, this.color, this.grid);

  final List<(double, double)> profile;
  final Color color;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final maxKm = math.max(profile.last.$1, 1e-6);
    final alts = profile.map((p) => p.$2);
    var lo = alts.reduce(math.min);
    var hi = alts.reduce(math.max);
    // Al menos 20 m de rango: una ruta plana no debe verse como una montaña.
    if (hi - lo < 20) {
      final mid = (hi + lo) / 2;
      lo = mid - 10;
      hi = mid + 10;
    }
    Offset at((double, double) p) => Offset(p.$1 / maxKm * size.width, size.height - (p.$2 - lo) / (hi - lo) * size.height);
    final line = Path()..moveTo(at(profile.first).dx, at(profile.first).dy);
    for (final p in profile.skip(1)) {
      line.lineTo(at(p).dx, at(p).dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), Paint()..color = grid);
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.2));
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ElevationPainter old) => old.profile != profile;
}
