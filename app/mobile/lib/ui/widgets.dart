/// Piezas de interfaz reutilizables, con patrones de iOS: tarjetas agrupadas,
/// respuesta inmediata al tocar y movimiento con resortes (ver `Motion`).
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';

/// Se achica al presionar (en el mismo instante del toque, no al soltar) y vuelve
/// con un resorte. La animación parte siempre del valor actual: se puede volver a
/// presionar a mitad de camino sin saltos. No maneja el toque; solo lo acompaña.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.scale = 0.97, this.enabled = true});

  final Widget child;
  final double scale;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final _c = AnimationController.unbounded(vsync: this, value: 1);

  void _to(double target, SpringDescription spring) => _c.animateWith(SpringSimulation(spring, _c.value, target, _c.velocity));

  void _down(PointerDownEvent _) {
    if (!widget.enabled || Motion.reduced(context)) return;
    _to(widget.scale, Motion.spring(response: 0.15));
  }

  // Al soltar, un leve rebote: el dedo le dio impulso.
  void _up(PointerEvent _) => _to(1, Motion.spring(damping: 0.7, response: 0.3));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: _down,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) => Transform.scale(scale: _c.value, child: child),
          child: widget.child,
        ),
      );
}

/// Aparece subiendo y aclarándose la primera vez que se muestra. `index` escalona
/// la entrada; con "Reducir movimiento" solo se funde.
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.child, this.index = 0, this.offset = 14});

  final Widget child;
  final int index;
  final double offset;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Motion.standardDuration);
  late final _t = CurvedAnimation(parent: _c, curve: Motion.standard);

  @override
  void initState() {
    super.initState();
    // Escalón corto y con tope: la pantalla completa aparece en menos de medio segundo.
    final delay = Duration(milliseconds: 35 * widget.index.clamp(0, 8));
    if (delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _t.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Opacity(
        opacity: Curves.easeOut.transform(_c.value),
        child: reduced ? child : Transform.translate(offset: Offset(0, widget.offset * (1 - _t.value)), child: child),
      ),
      child: widget.child,
    );
  }
}

/// Tarjeta sobre el fondo agrupado: esquinas continuas y, si se puede tocar, se
/// achica al presionar.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = EdgeInsets.zero, this.onTap, this.borderColor});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Borde de color para destacar (por ejemplo, la sesión en curso).
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(20),
      side: borderColor == null ? BorderSide.none : BorderSide(color: borderColor!, width: 1.5),
    );
    final card = Material(
      color: c.card,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? Padding(padding: padding, child: child) : InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
    return onTap == null ? card : Pressable(child: card);
  }
}

/// Encabezado dentro de una tarjeta ("Historial", "Tus avances"…).
class CardHeader extends StatelessWidget {
  const CardHeader(this.text, {super.key, this.trailing, this.icon});

  final String text;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
      child: Row(children: [
        if (icon != null) ...[Icon(icon, size: 17, color: c.primary), const SizedBox(width: 8)],
        Expanded(child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: c.fgStrong))),
        ?trailing,
      ]),
    );
  }
}

/// Lista agrupada de iOS: filas en una tarjeta con separadores finos con sangría.
class CardList extends StatelessWidget {
  const CardList({super.key, required this.children, this.header});

  final List<Widget> children;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ?header,
        for (var i = 0; i < children.length; i++) ...[if (i > 0 || header != null) const Divider(indent: 14), children[i]],
      ]),
    );
  }
}

/// Título de sección (como "Destacados" en la app Salud).
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2),
      child: Row(children: [
        Expanded(child: Text(text, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: context.colors.fgStrong))),
        ?trailing,
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(children: [
        Container(
          width: 56,
          height: 56,
          decoration: ShapeDecoration(color: c.primarySoft, shape: smoothShape(16)),
          child: Icon(icon, color: c.primary, size: 28),
        ),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: c.fgStrong)),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(message!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.muted, height: 1.4)),
        ],
      ]),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.text = 'Cargando…'});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          const CupertinoActivityIndicator(radius: 11),
          const SizedBox(height: 10),
          Text(text, style: TextStyle(fontSize: 13, color: context.colors.muted)),
        ]),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.error, {super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: ShapeDecoration(color: c.danger.withValues(alpha: 0.12), shape: smoothShape(16)),
      child: Row(children: [
        Icon(Icons.error_outline, size: 18, color: c.danger),
        const SizedBox(width: 10),
        Expanded(child: Text(errorMessage(error), style: TextStyle(fontSize: 13, color: c.danger))),
      ]),
    );
  }
}

String errorMessage(Object e) {
  final text = e.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}

/// Muestra datos asíncronos con estados de carga y error uniformes, con fundido entre ellos.
class AsyncView<T> extends StatelessWidget {
  const AsyncView(this.value, {super.key, required this.builder, this.loadingText = 'Cargando…'});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final String loadingText;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: Motion.medium,
        child: switch (value) {
          AsyncData(:final value) => KeyedSubtree(key: const ValueKey('data'), child: builder(value)),
          AsyncError(:final error) => KeyedSubtree(key: const ValueKey('error'), child: ErrorView(error)),
          _ => KeyedSubtree(key: const ValueKey('loading'), child: LoadingView(text: loadingText)),
        },
      );
}

/// Desplazamiento inicial de [PageBody], solo para el modo de capturas (ver main.dart).
double? captureScrollOffset;

/// Contenido desplazable de una sección, con márgenes, ancho máximo y rebote de iOS.
/// Deja espacio para las barras translúcidas (el contenido pasa por debajo) y los
/// bloques aparecen escalonados la primera vez.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.gap = 16, this.bottomPadding = 24});

  final List<Widget> children;
  final double gap;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    // Bordes seguros y barras flotantes (Scaffold los entrega como padding).
    final inset = MediaQuery.paddingOf(context);
    return ListView(
      controller: captureScrollOffset == null ? null : ScrollController(initialScrollOffset: captureScrollOffset!),
      padding: EdgeInsets.fromLTRB(16 + inset.left, 12 + inset.top, 16 + inset.right, bottomPadding + inset.bottom),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) SizedBox(height: gap),
                  Entrance(index: i, child: children[i]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Fila superior de una pantalla de detalle: volver (chevrón de iOS), título y acciones.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.onBack, this.actions = const []});

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      if (onBack != null)
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          tooltip: 'Volver',
          style: IconButton.styleFrom(foregroundColor: c.primary),
        ),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: c.fgStrong)),
          if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 13, color: c.muted)),
        ]),
      ),
      ...actions,
    ]);
  }
}

/// Indicador pequeño: ícono, etiqueta y valor destacado. Si el valor cambia, se
/// reemplaza deslizándose.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icon, required this.label, required this.value, this.caption, this.trailing, this.tooltip, this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Widget? trailing;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tile = AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 15, color: c.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted))),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Flexible(
            child: AnimatedSwitcher(
              duration: Motion.medium,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(a), child: child),
              ),
              child: Text(
                value,
                key: ValueKey(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: c.fgStrong, fontFeatures: tabular),
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ]),
        if (caption != null) Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.faint)),
      ]),
    );
    return tooltip == null ? tile : Tooltip(message: tooltip!, child: tile);
  }
}

/// Grilla de indicadores de 2 o 3 columnas; las tarjetas de una fila miden lo mismo.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children, this.columns = 2});

  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      rows.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var j = 0; j < columns; j++) ...[
            if (j > 0) const SizedBox(width: 10),
            Expanded(child: i + j < children.length ? children[i + j] : const SizedBox()),
          ],
        ]),
      ));
    }
    return Column(children: [for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 10), rows[i]]]);
  }
}

/// Fila de opciones exclusivas (filtros, períodos, métricas) en cápsulas; la
/// elegida se rellena con un resorte.
class ChoicePills<T> extends StatelessWidget {
  const ChoicePills({super.key, required this.options, required this.selected, required this.onSelected, required this.label, this.scrollable = false});

  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final String Function(T) label;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final chips = [
      for (final o in options)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Semantics(
            button: true,
            selected: o == selected,
            child: Pressable(
              scale: 0.94,
              child: GestureDetector(
                onTap: () {
                  if (o != selected) HapticFeedback.selectionClick();
                  onSelected(o);
                },
                child: AnimatedContainer(
                  duration: Motion.standardDuration,
                  curve: Motion.standard,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: ShapeDecoration(color: o == selected ? c.primary : c.surface2.withValues(alpha: 0.7), shape: const StadiumBorder()),
                  child: AnimatedDefaultTextStyle(
                    duration: Motion.fast,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -0.1, color: o == selected ? c.onPrimary : c.fg),
                    child: Text(label(o)),
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
    return scrollable
        ? SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), child: Row(children: chips))
        : Wrap(runSpacing: 8, children: chips);
  }
}

/// Control segmentado de iOS: el indicador se desliza a la opción elegida.
class AppSegmented<T extends Object> extends StatelessWidget {
  const AppSegmented({super.key, required this.value, required this.segments, required this.onChanged});

  /// null = ninguna elegida.
  final T? value;

  /// Opción → contenido (texto, ícono o ambos).
  final Map<T, Widget> segments;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CupertinoSlidingSegmentedControl<T>(
      groupValue: value,
      backgroundColor: c.surface2.withValues(alpha: 0.8),
      thumbColor: c.card,
      padding: const EdgeInsets.all(3),
      onValueChanged: (v) {
        if (v != null && onChanged != null) onChanged!(v);
      },
      children: {
        for (final e in segments.entries)
          e.key: DefaultTextStyle.merge(
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: e.key == value ? c.fgStrong : c.muted),
            child: IconTheme.merge(
              data: IconThemeData(size: 18, color: e.key == value ? c.primary : c.muted),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), child: e.value),
            ),
          ),
      },
    );
  }
}

/// Ícono sobre un cuadrado de esquinas continuas con el degradado de la app.
class GradientIcon extends StatelessWidget {
  const GradientIcon(this.icon, {super.key, this.size = 40});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(gradient: c.gradient, shape: smoothShape(size * 0.28)),
      child: Icon(icon, color: c.onPrimary, size: size * 0.5),
    );
  }
}

/// Campo numérico que acepta coma decimal.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.onSubmitted,
    this.hint,
    this.label,
    this.decimal = true,
    this.allowRange = false,
    this.textAlign = TextAlign.start,
    this.width,
    this.error = false,
    this.dense = false,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? hint;
  final String? label;
  final bool decimal;

  /// Acepta un rango de enteros ("8-12").
  final bool allowRange;
  final TextAlign textAlign;
  final double? width;
  final bool error;
  final bool dense;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final field = TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      focusNode: focusNode,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      textAlign: textAlign,
      // `signed` muestra la tecla "-" en el teclado numérico de iOS.
      keyboardType: TextInputType.numberWithOptions(decimal: decimal, signed: allowRange),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(allowRange ? r'[0-9-]' : decimal ? r'[0-9.,]' : r'[0-9]'))],
      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      decoration: InputDecoration(
        hintText: hint,
        labelText: label,
        contentPadding: dense ? const EdgeInsets.symmetric(horizontal: 6, vertical: 9) : null,
        enabledBorder: error ? OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.danger, width: 1.5)) : null,
      ),
    );
    return width == null ? field : SizedBox(width: width, child: field);
  }
}

/// Aviso breve flotante, como cápsula sobre la barra inferior.
void showToast(BuildContext context, String message, {bool error = false}) {
  final c = context.colors;
  if (error) HapticFeedback.heavyImpact();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle, size: 20, color: error ? c.onPrimary : c.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: TextStyle(color: error ? c.onPrimary : c.fgStrong))),
      ]),
      backgroundColor: error ? c.danger : c.surface2,
      duration: const Duration(seconds: 3),
    ));
}

/// Diálogo de confirmación (alerta nativa en iOS); devuelve true si el usuario acepta.
Future<bool> confirm(BuildContext context, String message, {String accept = 'Aceptar', bool destructive = false}) async {
  final c = context.colors;
  final ok = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) {
      final cupertino = Theme.of(context).platform == TargetPlatform.iOS;
      Widget action(String text, bool value, {bool primary = false}) => cupertino
          ? CupertinoDialogAction(
              isDefaultAction: primary && !destructive,
              isDestructiveAction: primary && destructive,
              onPressed: () => Navigator.pop(context, value),
              child: Text(text),
            )
          : TextButton(
              onPressed: () => Navigator.pop(context, value),
              child: Text(text, style: TextStyle(color: !primary ? c.muted : (destructive ? c.danger : c.primary), fontWeight: FontWeight.w600)),
            );
      return AlertDialog.adaptive(content: Text(message), actions: [action('Cancelar', false), action(accept, true, primary: true)]);
    },
  );
  return ok ?? false;
}

/// Ejecuta una acción mostrando su error como aviso. Devuelve true si terminó bien.
Future<bool> runGuarded(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) {
      HapticFeedback.lightImpact();
      showToast(context, success);
    }
    return true;
  } on Object catch (e) {
    if (context.mounted) showToast(context, errorMessage(e), error: true);
    return false;
  }
}

/// Hoja inferior a pantalla casi completa con título (como las hojas de iOS).
Future<T?> showSheet<T>(BuildContext context, {required String title, required Widget Function(BuildContext) builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Encima de la barra de secciones del shell.
    useRootNavigator: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.92,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
          child: Row(children: [
            Expanded(child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: context.colors.fgStrong))),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Cerrar',
              style: IconButton.styleFrom(backgroundColor: context.colors.surface2, foregroundColor: context.colors.muted),
            ),
          ]),
        ),
        Expanded(child: builder(context)),
      ]),
    ),
  );
}

/// Rueda de iOS en una hoja inferior, con "Listo". Devuelve null si se cierra sin elegir.
Future<DateTime?> _wheelSheet(BuildContext context, {required String title, required Widget Function(ValueChanged<DateTime>) picker, required DateTime initial}) {
  var value = initial;
  return showModalBottomSheet<DateTime>(
    context: context,
    useRootNavigator: true,
    builder: (sheet) {
      final c = sheet.colors;
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
            child: Row(children: [
              Expanded(child: Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: c.fgStrong))),
              TextButton(onPressed: () => Navigator.pop(sheet, value), child: const Text('Listo')),
            ]),
          ),
          SizedBox(
            height: 216,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Theme.of(sheet).brightness,
                textTheme: CupertinoTextThemeData(dateTimePickerTextStyle: TextStyle(fontSize: 21, color: c.fgStrong)),
              ),
              child: picker((v) => value = v),
            ),
          ),
        ]),
      );
    },
  );
}

/// Elegir una fecha con la rueda de iOS.
Future<DateTime?> pickDate(BuildContext context, {required DateTime initial, required DateTime first, required DateTime last, String title = 'Fecha'}) {
  final start = initial.isBefore(first) ? first : (initial.isAfter(last) ? last : initial);
  return _wheelSheet(
    context,
    title: title,
    initial: start,
    picker: (onChanged) => CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      dateOrder: DatePickerDateOrder.dmy,
      initialDateTime: start,
      minimumDate: first,
      maximumDate: last,
      onDateTimeChanged: onChanged,
    ),
  );
}

/// Elegir una hora (minutos desde medianoche) con la rueda de iOS.
Future<int?> pickTime(BuildContext context, {required int minutes, String title = 'Hora'}) async {
  final now = DateTime.now();
  final initial = DateTime(now.year, now.month, now.day, minutes ~/ 60, (minutes % 60) ~/ 5 * 5);
  final picked = await _wheelSheet(
    context,
    title: title,
    initial: initial,
    picker: (onChanged) => CupertinoDatePicker(
      mode: CupertinoDatePickerMode.time,
      use24hFormat: true,
      minuteInterval: 5,
      initialDateTime: initial,
      onDateTimeChanged: onChanged,
    ),
  );
  return picked == null ? null : picked.hour * 60 + picked.minute;
}

/// Barra flotante translúcida (material de iOS): desenfoca lo que pasa por debajo.
class GlassBar extends StatelessWidget {
  const GlassBar({super.key, required this.child, this.top = false});

  final Widget child;

  /// Barra superior (la línea fina va abajo) o inferior (va arriba).
  final bool top;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final edge = BorderSide(color: c.border.withValues(alpha: 0.5), width: 0.5);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(color: c.canvas.withValues(alpha: 0.78), border: top ? Border(bottom: edge) : Border(top: edge)),
          child: child,
        ),
      ),
    );
  }
}

const tabular = [FontFeature.tabularFigures()];
