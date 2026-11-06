import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/common/date.dart';
import '../core/common/numbers.dart';
import 'format.dart';

class TrendPoint<T> {
  const TrendPoint({required this.date, required this.value, required this.data});

  final String date;
  final double value;
  final T data;
}

class ChartReference {
  const ChartReference(this.value, this.label);

  final double value;
  final String label;
}

String _defaultFormat(num n) => formatNumber(n, maxFractionDigits: 1);

/// Marcas "redondas" del eje: pasos de 1, 2, 2,5 o 5 × 10ⁿ.
List<double> _niceTicks(double lo, double hi, [int approx = 4]) {
  final raw = (hi - lo) / approx;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final step = [1, 2, 2.5, 5, 10].map((m) => m * mag).firstWhere((s) => s >= raw, orElse: () => 10 * mag);
  final out = <double>[];
  for (var v = (lo / step).floor() * step; v <= (hi / step).ceil() * step + step * 1e-6; v += step) {
    out.add((v * 1000).round() / 1000);
  }
  return out;
}

/// Gráfica de línea en el tiempo. Tocar o arrastrar muestra el detalle del punto
/// más cercano; tocar de nuevo el mismo punto llama a [onSelect].
class TrendChart<T> extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.points,
    required this.unit,
    required this.label,
    this.format = _defaultFormat,
    this.axisFormat,
    this.reference,
    this.minPad = 0.5,
    this.compareLabel = 'vs. registro anterior',
    this.detail,
    this.onSelect,
  });

  final List<TrendPoint<T>> points;
  final String unit;

  /// Para el resumen accesible: "peso", "volumen"…
  final String label;
  final String Function(num) format;
  final String Function(num)? axisFormat;
  final ChartReference? reference;
  final double minPad;
  final String compareLabel;
  final String? Function(T data)? detail;
  final void Function(T data)? onSelect;

  @override
  State<TrendChart<T>> createState() => _TrendChartState<T>();
}

class _Geometry {
  _Geometry({required this.xs, required this.ys, required this.ticks, required this.sy, required this.xTicks, required this.left});

  final List<double> xs;
  final List<double> ys;
  final List<double> ticks;
  final double Function(double) sy;
  final List<(double, String)> xTicks;
  final double left;
}

class _TrendChartState<T> extends State<TrendChart<T>> with SingleTickerProviderStateMixin {
  static const _height = 220.0;
  static const _top = 18.0;
  static const _right = 18.0;
  static const _bottom = 26.0;

  int? _active;
  late final AnimationController _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();

  @override
  void didUpdateWidget(TrendChart<T> old) {
    super.didUpdateWidget(old);
    if (old.points.length != widget.points.length || old.points.firstOrNull?.date != widget.points.firstOrNull?.date) {
      _active = null;
      _draw.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  _Geometry _geometry(double width) {
    final data = widget.points;
    final axisFormat = widget.axisFormat ?? widget.format;
    final days = data.map((p) => dayIndex(p.date).toDouble()).toList();
    final values = [...data.map((p) => p.value), if (widget.reference != null) widget.reference!.value];
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final pad = math.max(widget.minPad, (hi - lo) * 0.15);
    final ticks = _niceTicks(math.max(0, lo - pad), hi + pad);
    final yMin = ticks.first;
    final yMax = ticks.last;
    // El margen izquierdo se ajusta al largo de las etiquetas del eje.
    final left = 14 + ticks.map((t) => axisFormat(t).length).reduce(math.max) * 6.0;
    var xMin = days.reduce(math.min);
    var xMax = days.reduce(math.max);
    if (xMin == xMax) {
      xMin -= 3;
      xMax += 3;
    }
    final innerW = width - left - _right;
    const innerH = _height - _top - _bottom;
    double sx(double day) => left + ((day - xMin) / (xMax - xMin)) * innerW;
    double sy(double v) => _top + (1 - (v - yMin) / (yMax - yMin)) * innerH;
    final xTickCount = math.max(2, math.min(4, (innerW / 90).floor()));
    final xTicks = [
      for (var i = 0; i < xTickCount; i++)
        () {
          final day = xMin + ((xMax - xMin) * i) / (xTickCount - 1);
          final date = DateTime.fromMillisecondsSinceEpoch(day.round() * Duration.millisecondsPerDay, isUtc: true);
          return (sx(day), shortDate(toDateKey(DateTime(date.year, date.month, date.day))));
        }(),
    ];
    return _Geometry(xs: days.map(sx).toList(), ys: data.map((p) => sy(p.value)).toList(), ticks: ticks, sy: sy, xTicks: xTicks, left: left);
  }

  int _nearest(_Geometry g, double x) {
    var best = 0;
    for (var i = 0; i < g.xs.length; i++) {
      if ((g.xs[i] - x).abs() < (g.xs[best] - x).abs()) best = i;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final data = widget.points;
    if (data.isEmpty) return const SizedBox(height: _height);
    final summary =
        'Gráfica de ${widget.label}: ${data.length} registros, de ${widget.format(data.first.value)} ${widget.unit} a ${widget.format(data.last.value)} ${widget.unit}.';

    return LayoutBuilder(builder: (context, box) {
      final width = math.max(240.0, box.maxWidth);
      final g = _geometry(width);
      final active = _active != null && _active! < data.length ? _active : null;

      return Semantics(
        label: summary,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final i = _nearest(g, d.localPosition.dx);
            if (i == active && widget.onSelect != null) {
              widget.onSelect!(data[i].data);
            } else {
              setState(() => _active = i);
            }
          },
          onHorizontalDragStart: (d) => setState(() => _active = _nearest(g, d.localPosition.dx)),
          onHorizontalDragUpdate: (d) => setState(() => _active = _nearest(g, d.localPosition.dx)),
          child: Stack(clipBehavior: Clip.none, children: [
            AnimatedBuilder(
              animation: _draw,
              builder: (context, _) => CustomPaint(
                size: Size(width, _height),
                painter: _ChartPainter(
                  geometry: g,
                  colors: c,
                  width: width,
                  progress: Curves.easeInOutCubic.transform(_draw.value),
                  active: active,
                  reference: widget.reference,
                  axisFormat: widget.axisFormat ?? widget.format,
                  lastLabel: '${widget.format(data.last.value)} ${widget.unit}',
                ),
              ),
            ),
            if (active != null) _tooltip(context, g, width, active),
          ]),
        ),
      );
    });
  }

  Widget _tooltip(BuildContext context, _Geometry g, double width, int i) {
    final c = context.colors;
    final p = widget.points[i];
    final prev = i > 0 ? widget.points[i - 1] : null;
    final delta = prev == null ? null : round1(p.value - prev.value);
    final extra = widget.detail?.call(p.data);
    const w = 168.0;
    final left = (g.xs[i] - w / 2).clamp(0.0, width - w);
    return Positioned(
      left: left,
      top: 0,
      width: w,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(capitalize(weekdayDateYear(p.date)), style: TextStyle(fontSize: 11, color: c.muted)),
            Text('${widget.format(p.value)} ${widget.unit}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong, fontFeatures: const [FontFeature.tabularFigures()])),
            if (extra != null) Text(extra, style: TextStyle(fontSize: 11, color: c.muted)),
            if (delta != null && delta != 0)
              Text('${delta > 0 ? '+' : '−'}${widget.format(delta.abs())} ${widget.unit} ${widget.compareLabel}',
                  style: TextStyle(fontSize: 11, color: c.muted)),
            if (widget.onSelect != null) Text('Toca de nuevo para abrir', style: TextStyle(fontSize: 10, color: c.faint)),
          ]),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.geometry,
    required this.colors,
    required this.width,
    required this.progress,
    required this.active,
    required this.reference,
    required this.axisFormat,
    required this.lastLabel,
  });

  final _Geometry geometry;
  final AppColors colors;
  final double width;
  final double progress;
  final int? active;
  final ChartReference? reference;
  final String Function(num) axisFormat;
  final String lastLabel;

  /// Con pocos registros se marcan todos los puntos; con muchos, solo el activo y el último.
  static const _maxMarked = 24;

  void _text(Canvas canvas, String text, Offset at, {required Color color, double size = 10, TextAlign align = TextAlign.left, FontWeight? weight}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: weight, fontFeatures: const [FontFeature.tabularFigures()])),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.right || TextAlign.end => at.dx - tp.width,
      TextAlign.center => at.dx - tp.width / 2,
      _ => at.dx,
    };
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    const right = 18.0;
    final grid = Paint()
      ..color = colors.border
      ..strokeWidth = 1;
    for (final t in g.ticks) {
      final y = g.sy(t);
      canvas.drawLine(Offset(g.left, y), Offset(width - right, y), grid);
      _text(canvas, axisFormat(t), Offset(g.left - 8, y), color: colors.faint, align: TextAlign.right);
    }
    for (var i = 0; i < g.xTicks.length; i++) {
      final (x, label) = g.xTicks[i];
      final align = i == 0 ? TextAlign.left : (i == g.xTicks.length - 1 ? TextAlign.right : TextAlign.center);
      _text(canvas, label, Offset(x, size.height - 10), color: colors.faint, align: align);
    }

    final ref = reference;
    if (ref != null) {
      final y = g.sy(ref.value);
      canvas.drawLine(Offset(g.left, y), Offset(width - right, y), Paint()
        ..color = colors.muted
        ..strokeWidth = 1);
      _text(canvas, ref.label, Offset(width - right - 4, y - 9), color: colors.muted, align: TextAlign.right);
    }

    if (active != null) {
      canvas.drawLine(Offset(g.xs[active!], 18), Offset(g.xs[active!], size.height - 26), Paint()
        ..color = colors.borderStrong
        ..strokeWidth = 1);
    }

    final n = g.xs.length;
    if (n > 1) {
      final path = Path()..moveTo(g.xs[0], g.ys[0]);
      for (var i = 1; i < n; i++) {
        path.lineTo(g.xs[i], g.ys[i]);
      }
      // La línea se dibuja de izquierda a derecha al aparecer.
      final metrics = path.computeMetrics().toList();
      final total = metrics.fold<double>(0, (s, m) => s + m.length);
      var remaining = total * progress;
      final visible = Path();
      for (final m in metrics) {
        if (remaining <= 0) break;
        visible.addPath(m.extractPath(0, math.min(remaining, m.length)), Offset.zero);
        remaining -= m.length;
      }
      canvas.drawPath(
        visible,
        Paint()
          ..color = colors.chartLine
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final marked = n <= _maxMarked;
    for (var i = 0; i < n; i++) {
      final isLast = i == n - 1;
      if (!marked && !isLast && i != active) continue;
      if (progress < (n == 1 ? 0 : i / (n - 1)) * 0.9) continue;
      final center = Offset(g.xs[i], g.ys[i]);
      final r = i == active ? 6.0 : 4.5;
      canvas.drawCircle(center, r + 2, Paint()..color = colors.surface);
      canvas.drawCircle(center, r, Paint()..color = colors.chartLine);
    }

    if (active == null && progress >= 1) {
      final x = g.xs.last;
      _text(canvas, lastLabel, Offset(x, g.ys.last - 14),
          color: colors.fgStrong, size: 12, weight: FontWeight.w600, align: x > width - 60 ? TextAlign.right : TextAlign.center);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}
