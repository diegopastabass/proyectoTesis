import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/common/date.dart';
import '../core/nutrition/models.dart';
import '../core/nutrition/score.dart';
import 'format.dart';
import 'widgets.dart';

/// "520 kcal · P 30 · C 60 · G 12 · Fib 4" con el color de cada macro.
class MacroInline extends StatelessWidget {
  const MacroInline(this.macros, {super.key, this.fontSize = 12, this.bold = false});

  final Macros macros;
  final double fontSize;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spans = <InlineSpan>[];
    for (final k in MacroKey.values) {
      if (spans.isNotEmpty) spans.add(TextSpan(text: '  ', style: TextStyle(color: c.faint)));
      final value = formatMacro(k, macros[k]);
      spans.add(TextSpan(
        text: k == MacroKey.kcal ? '$value kcal' : '${macroMeta[k]!.short} $value',
        style: TextStyle(color: c.macro(k)),
      ));
    }
    return Text.rich(
      TextSpan(children: spans),
      style: TextStyle(fontSize: fontSize, fontFeatures: tabular, fontWeight: bold ? FontWeight.w600 : null),
    );
  }
}

/// Barra con la zona objetivo marcada y el consumo actual.
class MacroBar extends StatelessWidget {
  const MacroBar({super.key, required this.macro, required this.value, required this.range, required this.score});

  final MacroKey macro;
  final double value;
  final Range range;
  final double score;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meta = macroMeta[macro]!;
    final scale = math.max(math.max(range.max * 1.25, value), 1.0);
    double pct(double n) => math.min(1, n / scale);
    final inRange = value >= range.min && value <= range.max;
    final color = c.macro(macro);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(flex: 2, child: Text(meta.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted))),
        const SizedBox(width: 6),
        Flexible(
          flex: 3,
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: formatMacro(macro, value), style: TextStyle(fontWeight: FontWeight.w600, color: inRange ? c.fgStrong : color)),
                  TextSpan(text: ' / ${formatMacro(macro, range.min)}–${formatMacro(macro, range.max)} ${meta.unit}', style: TextStyle(color: c.faint)),
                ]),
                style: const TextStyle(fontSize: 12, fontFeatures: tabular),
              ),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 4),
      Semantics(
        label: '${meta.label}: ${formatMacro(macro, value)} de ${formatMacro(macro, range.min)} a ${formatMacro(macro, range.max)} ${meta.unit}',
        child: SizedBox(
          height: 8,
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            return Stack(children: [
              Container(decoration: BoxDecoration(color: c.bgHard, borderRadius: BorderRadius.circular(4))),
              Positioned(
                left: w * pct(range.min),
                width: math.max(0, w * (pct(range.max) - pct(range.min))),
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    border: Border.all(color: c.primary.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pct(value)),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => Container(
                  width: w * t,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ]);
          }),
        ),
      ),
    ]);
  }
}

/// Anillo con el puntaje del día (0–100).
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, this.size = 76, this.empty = false});

  final int score;
  final double size;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = empty
        ? c.faint
        : switch (scoreLevel(score)) {
            ScoreLevel.good => c.success,
            ScoreLevel.mid => c.warning,
            ScoreLevel.low => c.danger,
          };
    return Semantics(
      label: empty ? 'Sin puntaje' : 'Puntaje $score de 100',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: empty ? 0 : score.toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, shown, _) => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(progress: shown / 100, color: color, track: c.bgHard),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(empty ? '–' : '${shown.round()}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.fgStrong, fontFeatures: tabular)),
                Text('PUNTAJE', style: TextStyle(fontSize: 9, letterSpacing: 0.5, color: c.faint)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color, required this.track});

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(arc, 0, math.pi * 2, false, base);
    if (progress <= 0) return;
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color || old.track != track;
}

/// Selector de día: ‹ Hoy · lun, 27 oct › [ir a hoy]
class DateNav extends StatelessWidget {
  const DateNav({super.key, required this.date, required this.onChanged});

  final String date;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final today = todayKey();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: () => onChanged(addDays(date, -1)),
        icon: const Icon(Icons.chevron_left),
        tooltip: 'Día anterior',
      ),
      Flexible(
        child: Text(capitalize(dateLabel(date, today)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.colors.fgStrong)),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: () => onChanged(addDays(date, 1)),
        icon: const Icon(Icons.chevron_right),
        tooltip: 'Día siguiente',
      ),
      if (date != today)
        IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(today),
          icon: const Icon(Icons.today, size: 18),
          tooltip: 'Ir a hoy',
        ),
    ]);
  }
}
