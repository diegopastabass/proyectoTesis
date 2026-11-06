import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/strength/session.dart';
import '../../ui/format.dart';

/// Cronómetro que se actualiza cada segundo desde `startedAt` (ms).
class ElapsedText extends StatefulWidget {
  const ElapsedText(this.startedAt, {super.key, this.style});

  final int startedAt;
  final TextStyle? style;

  @override
  State<ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<ElapsedText> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    // `late` con inicializador sería perezoso: el reloj no arrancaría hasta el dispose.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(widget.startedAt));
    return Text(formatElapsed(elapsed), style: (widget.style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]));
  }
}

/// Cuenta regresiva del descanso; "Listo" al terminar.
class _RestLeft extends StatefulWidget {
  const _RestLeft(this.rest, {required this.style});

  final RestTimer rest;
  final TextStyle style;

  @override
  State<_RestLeft> createState() => _RestLeftState();
}

class _RestLeftState extends State<_RestLeft> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    // `late` con inicializador sería perezoso: el reloj no arrancaría hasta el dispose.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.rest.remaining(DateTime.now().millisecondsSinceEpoch);
    return Text(
      left == 0 ? 'Descanso listo' : 'Descanso ${formatElapsed(Duration(seconds: left))}',
      style: widget.style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}

/// Acceso rápido a la sesión en curso desde cualquier pantalla del módulo.
class ActiveWorkoutPill extends ConsumerWidget {
  const ActiveWorkoutPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeWorkoutProvider);
    if (active == null) return const SizedBox.shrink();
    final c = context.colors;
    final style = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.onPrimary);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.push('/fuerza/entrenar'),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: c.gradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 4))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.timer_outlined, size: 18, color: c.onPrimary),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(active.name, overflow: TextOverflow.ellipsis, style: style),
            ),
            const SizedBox(width: 8),
            if (active.rest case final rest?) _RestLeft(rest, style: style) else ElapsedText(active.startedAt, style: style),
            Icon(Icons.chevron_right, size: 18, color: c.onPrimary),
          ]),
        ),
      ),
    );
  }
}
