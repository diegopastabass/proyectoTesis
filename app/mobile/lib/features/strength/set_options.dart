import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/strength/models.dart';
import '../../core/strength/session.dart';
import '../../ui/format.dart';
import '../../ui/widgets.dart';

Color setTypeColor(AppColors c, SetType t) => switch (t) {
      SetType.warmup => c.warning,
      SetType.failure => c.danger,
      SetType.drop => c.primary2,
      SetType.normal => c.fgStrong,
    };

String setTypeName(SetType t) => switch (t) {
      SetType.normal => 'Serie efectiva',
      SetType.warmup => 'Calentamiento',
      SetType.failure => 'Al fallo',
      SetType.drop => 'Drop set',
    };

String _setTypeHelp(SetType t) => switch (t) {
      SetType.normal => 'Cuenta para el volumen y las series de la semana.',
      SetType.warmup => 'No cuenta como serie efectiva ni suma volumen.',
      SetType.failure => 'Hasta no poder hacer otra repetición con buena técnica.',
      SetType.drop => 'Bajas el peso y sigues sin descansar. Es parte de la serie anterior.',
    };

/// Lo elegido en la hoja de opciones de una serie.
sealed class SetOption {
  const SetOption();
}

class ChangeSetType extends SetOption {
  const ChangeSetType(this.type);

  final SetType type;
}

class AddDropSet extends SetOption {
  const AddDropSet();
}

class RemoveSet extends SetOption {
  const RemoveSet();
}

/// `children` se arma con el contexto de la hoja: `Navigator.pop` con el de la
/// pantalla cerraría la pantalla en vez de la hoja.
Future<T?> compactSheet<T>(BuildContext context, {required String title, required List<Widget> Function(BuildContext sheet) children}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (context) {
      final c = context.colors;
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: c.fgStrong)),
          ),
          ...children(context),
        ]),
      );
    },
  );
}

/// Opciones de una serie (tipo, drop set, quitar) en un solo lugar, para no
/// llenar cada fila de botones. `canDrop`: hay una serie antes a la cual bajarle el peso.
Future<SetOption?> showSetOptions(BuildContext context, {required String label, required SetType type, required bool canDrop}) {
  final c = context.colors;
  return compactSheet<SetOption>(context, title: type == SetType.drop ? 'Drop set' : 'Serie $label', children: (context) => [
    for (final t in SetType.values)
      if (t != SetType.drop || canDrop)
        ListTile(
          leading: SizedBox(
            width: 28,
            child: Center(
              child: Text(
                switch (t) {
                  SetType.warmup => 'C',
                  SetType.failure => 'F',
                  SetType.drop => 'D',
                  SetType.normal => '1',
                },
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: setTypeColor(c, t)),
              ),
            ),
          ),
          title: Text(setTypeName(t)),
          subtitle: Text(_setTypeHelp(t), style: TextStyle(fontSize: 12, color: c.muted)),
          trailing: t == type ? Icon(Icons.check, color: c.primary) : null,
          selected: t == type,
          onTap: () => Navigator.pop(context, ChangeSetType(t)),
        ),
    const Divider(height: 16),
    if (type != SetType.warmup)
      ListTile(
        leading: Icon(Icons.south_rounded, color: c.primary2),
        title: const Text('Agregar drop set'),
        subtitle: Text('Una bajada de peso (~20 %) justo después, sin descanso.', style: TextStyle(fontSize: 12, color: c.muted)),
        onTap: () => Navigator.pop(context, const AddDropSet()),
      ),
    ListTile(
      leading: Icon(Icons.delete_outline, color: c.danger),
      title: Text('Quitar serie', style: TextStyle(color: c.danger)),
      onTap: () => Navigator.pop(context, const RemoveSet()),
    ),
  ]);
}

const _restChoices = [0, 30, 45, 60, 90, 120, 150, 180, 240, 300];

/// Elegir el descanso entre series de un ejercicio. null si se cierra sin elegir.
Future<int?> pickRest(BuildContext context, {required int current}) {
  final c = context.colors;
  return compactSheet<int>(context, title: 'Descanso entre series', children: (context) => [
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        'Al marcar una serie empieza la cuenta regresiva y te avisamos al terminar. Entre una serie y su drop set no hay descanso.',
        style: TextStyle(fontSize: 12, color: c.muted, height: 1.3),
      ),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in {..._restChoices, current}.toList()..sort())
          ChoiceChip(
            label: Text(formatRest(s)),
            selected: s == current,
            onSelected: (_) => Navigator.pop(context, s),
          ),
      ]),
    ),
    const SizedBox(height: 12),
  ]);
}

/// Botón chico con el descanso del ejercicio ("⏱ 1:30").
class RestChip extends StatelessWidget {
  const RestChip({super.key, required this.seconds, required this.onTap});

  final int seconds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final off = seconds <= 0;
    return Semantics(
      button: true,
      label: off ? 'Sin descanso entre series. Toca para cambiarlo' : 'Descanso entre series: ${formatRest(seconds)}. Toca para cambiarlo',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(off ? Icons.timer_off_outlined : Icons.timer_outlined, size: 14, color: off ? c.faint : c.primary),
            const SizedBox(width: 4),
            Text(off ? 'Sin descanso' : 'Descanso ${formatRest(seconds)}', style: TextStyle(fontSize: 11, color: off ? c.faint : c.muted)),
          ]),
        ),
      ),
    );
  }
}

/// Cuenta regresiva del descanso, flotando sobre el entrenamiento. Al llegar a
/// cero vibra y llama a `onDone` (sin vibrar si ya había terminado al abrir la pantalla).
class RestBar extends StatefulWidget {
  const RestBar({super.key, required this.rest, required this.onAdjust, required this.onDone, this.onPause});

  final RestTimer rest;
  final ValueChanged<int> onAdjust;

  /// Pausa o sigue la cuenta (también se puede desde la pantalla bloqueada).
  final VoidCallback? onPause;

  /// Terminó o se saltó.
  final VoidCallback onDone;

  @override
  State<RestBar> createState() => _RestBarState();
}

class _RestBarState extends State<RestBar> {
  late final Timer _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    // Si terminó mientras la pantalla estaba cerrada, se quita sin vibrar.
    if (widget.rest.remaining(DateTime.now().millisecondsSinceEpoch) == 0) {
      _finished = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDone();
      });
    }
  }

  @override
  void didUpdateWidget(RestBar old) {
    super.didUpdateWidget(old);
    if (old.rest.endsAt != widget.rest.endsAt || old.rest.pausedLeft != widget.rest.pausedLeft) _finished = false;
  }

  void _tick() {
    if (!mounted || _finished) return;
    if (widget.rest.remaining(DateTime.now().millisecondsSinceEpoch) == 0) {
      _finished = true;
      HapticFeedback.heavyImpact();
      widget.onDone();
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now().millisecondsSinceEpoch;
    final left = widget.rest.remaining(now);
    final progress = widget.rest.progress(now);
    final paused = widget.rest.paused;
    final style = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.onPrimary);
    Widget adjust(int delta) => TextButton(
          style: TextButton.styleFrom(
            foregroundColor: c.onPrimary,
            backgroundColor: Colors.white24,
            minimumSize: const Size(48, 34),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () => widget.onAdjust(delta),
          child: Text(delta > 0 ? '+$delta' : '−${-delta}', style: style),
        );

    return Semantics(
      container: true,
      label: 'Descanso: quedan ${formatElapsed(Duration(seconds: left))}',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: c.gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 4))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(children: [
              Icon(Icons.timer_outlined, size: 20, color: c.onPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(paused ? 'Descanso en pausa' : 'Descanso', style: TextStyle(fontSize: 11, color: c.onPrimary.withValues(alpha: 0.8))),
                  Text(
                    formatElapsed(Duration(seconds: left)),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.onPrimary, fontFeatures: tabular, height: 1.1),
                  ),
                ]),
              ),
              if (widget.onPause != null) ...[
                IconButton(
                  tooltip: paused ? 'Seguir el descanso' : 'Pausar el descanso',
                  style: IconButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: c.onPrimary, minimumSize: const Size(34, 34)),
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onPause,
                  icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 20),
                ),
                const SizedBox(width: 6),
              ],
              adjust(-15),
              const SizedBox(width: 6),
              adjust(15),
              const SizedBox(width: 6),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: c.primary,
                  backgroundColor: c.onPrimary,
                  minimumSize: const Size(56, 34),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: widget.onDone,
                child: const Text('Saltar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          LinearProgressIndicator(value: progress, minHeight: 3, backgroundColor: Colors.white24, valueColor: AlwaysStoppedAnimation(c.onPrimary)),
        ]),
      ),
    );
  }
}
