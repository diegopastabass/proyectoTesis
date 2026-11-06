/// Piezas compartidas por las pantallas de diseño (comunidad, IA, carga, cuenta).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/sim_providers.dart';
import '../app/theme.dart';
import '../data/simulated/sim_data.dart';
import '../features/cardio/cardio_widgets.dart';
import 'widgets.dart';

/// Colores de los avatares de las personas de ejemplo.
Color avatarColor(AppColors c, int tone) => [c.primary, c.protein, c.fiber, c.kcal, c.fat][tone % 5];

class SimAvatar extends StatelessWidget {
  const SimAvatar(this.user, {super.key, this.radius = 20});

  final SimUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = avatarColor(context.colors, user.tone);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.18),
      child: Text(user.initials, style: TextStyle(fontSize: radius * 0.72, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Imagen de ejemplo: las pantallas de diseño no incluyen fotos reales de personas ni de comida.
class SimPhoto extends StatelessWidget {
  const SimPhoto({super.key, this.icon = Icons.restaurant, this.tone = 0, this.height = 170, this.width = double.infinity, this.radius = 14});

  final IconData icon;
  final int tone;
  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final palettes = [
      [c.kcal, c.carbs],
      [c.primary, c.fat],
      [c.fiber, c.primary],
      [c.protein, c.kcal],
    ];
    final p = palettes[tone % palettes.length];
    return SizedBox(
      height: height,
      width: width,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          gradient: LinearGradient(colors: [p[0].withValues(alpha: 0.75), p[1].withValues(alpha: 0.5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          shape: smoothShape(radius),
        ),
        child: Center(child: Icon(icon, size: math.min(height, width).isFinite ? math.min(height, width) * 0.34 : 96, color: Colors.white.withValues(alpha: 0.9))),
      ),
    );
  }
}

/// Miniatura de una ruta publicada: el inicio y el final se ocultan (RNF de privacidad).
class SimRoutePreview extends StatelessWidget {
  const SimRoutePreview({super.key, required this.seed, this.height = 170, this.hideEnds = true});

  final int seed;
  final double height;
  final bool hideEnds;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final route = simRoute(seed);
    return Container(
      height: height,
      decoration: ShapeDecoration(color: c.bgHard, shape: smoothShape(14)),
      padding: const EdgeInsets.all(14),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: RoutePainter([hideEnds ? route.sublist(9, route.length - 9) : route], strokeWidth: 3))),
        if (hideEnds)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: ShapeDecoration(color: c.card, shape: const StadiumBorder()),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.visibility_off_outlined, size: 12, color: c.muted),
                const SizedBox(width: 4),
                Text('Inicio y final ocultos', style: TextStyle(fontSize: 11, color: c.muted)),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Mensaje destacado dentro de una pantalla (aviso, ayuda o resultado).
class InfoNote extends StatelessWidget {
  const InfoNote({super.key, required this.text, this.icon = Icons.info_outline, this.color, this.title, this.trailing});

  final String text;
  final String? title;
  final IconData icon;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = color ?? c.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(color: tint.withValues(alpha: 0.12), shape: smoothShape(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: tint),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) ...[
              Text(title!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
              const SizedBox(height: 2),
            ],
            Text(text, style: TextStyle(fontSize: 13, height: 1.35, color: c.fg)),
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}

/// Barra fija abajo con las acciones principales de un flujo.
class BottomActions extends StatelessWidget {
  const BottomActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GlassBar(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 8), children[i]],
            ]),
          ),
        ),
      );
}

/// Fila "etiqueta → valor" de los resúmenes.
class StatRow extends StatelessWidget {
  const StatRow(this.stats, {super.key});

  final List<SimStat> stats;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      for (final s in stats)
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: c.fgStrong, fontFeatures: tabular)),
            Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.muted)),
          ]),
        ),
    ]);
  }
}

/// Fila seleccionable de una lista de opciones (motivos, disciplinas…).
class OptionTile extends StatelessWidget {
  const OptionTile({super.key, required this.title, required this.selected, required this.onTap, this.subtitle, this.icon});

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      onTap: onTap,
      dense: true,
      leading: icon == null ? null : Icon(icon, color: selected ? c.primary : c.muted),
      title: Text(title, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: c.fgStrong)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: TextStyle(fontSize: 12, color: c.muted)),
      trailing: Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, size: 22, color: selected ? c.primary : c.faint),
    );
  }
}

/// Escala de esfuerzo (1 a 10) en una fila de botones.
class RpePicker extends StatelessWidget {
  const RpePicker({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(builder: (context, box) {
      final size = (box.maxWidth - 4 * 8) / 5;
      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 1; i <= 10; i++)
          SizedBox(
            width: size,
            height: 38,
            child: Pressable(
              scale: 0.92,
              child: Material(
                color: value == i ? c.primary : c.surface2.withValues(alpha: 0.7),
                shape: smoothShape(10),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: Center(child: Text('$i', style: TextStyle(fontWeight: FontWeight.w600, color: value == i ? c.onPrimary : c.fg, fontFeatures: tabular))),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

/// Nota de "cómo me sentí" pegada a un registro (CU-20).
class FeelingNoteCard extends ConsumerStatefulWidget {
  const FeelingNoteCard({super.key, required this.noteKey, this.hint = 'Por ejemplo: me molestó un poco la rodilla al final.', this.initial});

  final String noteKey;
  final String hint;

  /// Texto de ejemplo para el borrador (lo usa el modo de capturas).
  final String? initial;

  @override
  ConsumerState<FeelingNoteCard> createState() => _FeelingNoteCardState();
}

class _FeelingNoteCardState extends ConsumerState<FeelingNoteCard> {
  late final _text = TextEditingController(text: ref.read(simProvider).notes[widget.noteKey] ?? widget.initial ?? '');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    final text = _text.text.trim();
    // Sin texto no se crea ninguna nota.
    if (text.isEmpty) return;
    ref.read(simProvider.notifier).setNote(widget.noteKey, text);
    showToast(context, 'Nota guardada');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final saved = ref.watch(simProvider).notes[widget.noteKey];
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.edit_note, size: 20, color: c.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('¿Cómo te sentiste?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong))),
          if (saved != null) Icon(Icons.check_circle, size: 18, color: c.success),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _text, minLines: 2, maxLines: 5, decoration: InputDecoration(hintText: widget.hint)),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _save, child: Text(saved == null ? 'Guardar nota' : 'Actualizar nota'))),
      ]),
    );
  }
}

/// Línea sencilla para series en el tiempo (potencia, carga…). Solo dibuja; sin ejes.
class SparkLine extends StatelessWidget {
  const SparkLine({super.key, required this.series, this.height = 90});

  /// Cada serie: valores y color.
  final List<(List<double>, Color)> series;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _SparkPainter(series, context.colors.border)));
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.series, this.grid);

  final List<(List<double>, Color)> series;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final all = series.expand((s) => s.$1).toList();
    if (all.isEmpty) return;
    final lo = all.reduce(math.min);
    final hi = all.reduce(math.max);
    final span = math.max(hi - lo, 1e-6);
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;
    for (var i = 0; i <= 2; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (final (values, color) in series) {
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final x = size.width * i / math.max(values.length - 1, 1);
        final y = size.height - (values[i] - lo) / span * size.height;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.series != series;
}

/// Leyenda de un gráfico: punto de color y nombre.
class LegendDot extends StatelessWidget {
  const LegendDot(this.color, this.label, {super.key});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: context.colors.muted)),
      ]);
}

/// Acceso a una función desde otra pantalla: ícono, texto y flecha.
class EntryCard extends StatelessWidget {
  const EntryCard({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap, this.badge});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(children: [
        GradientIcon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: c.muted)),
          ]),
        ),
        if (badge != null)
          Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: ShapeDecoration(color: c.warning.withValues(alpha: 0.18), shape: const StadiumBorder()),
            child: Text(badge!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.warning)),
          ),
        Icon(Icons.chevron_right, color: c.faint),
      ]),
    );
  }
}
