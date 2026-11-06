import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../core/training/load.dart';
import 'widgets.dart';

/// Color de un valor de la escala: verde (suave) → amarillo → rojo (máximo).
Color rpeColor(AppColors c, int rpe) => rpe <= 3 ? c.success : (rpe <= 6 ? c.warning : c.danger);

/// Escala de esfuerzo percibido 1–10: un toque elige el valor.
class RpePicker extends StatelessWidget {
  const RpePicker({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final v = value;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        for (var i = 1; i <= 10; i++) ...[
          if (i > 1) const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              button: true,
              selected: v == i,
              label: 'Esfuerzo $i: ${rpeLabel(i)}',
              excludeSemantics: true,
              child: Pressable(
                scale: 0.9,
                child: GestureDetector(
                  onTap: () {
                    if (v != i) HapticFeedback.selectionClick();
                    onChanged(i);
                  },
                  child: AnimatedContainer(
                    duration: Motion.standardDuration,
                    curve: Motion.standard,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: v == i ? rpeColor(c, i) : c.surface2.withValues(alpha: 0.7),
                      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      '$i',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: v == i ? c.onPrimary : c.fg, fontFeatures: tabular),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Text('Muy suave', style: TextStyle(fontSize: 11, color: c.faint)),
        Expanded(
          child: Text(
            v == null ? '' : '$v · ${rpeLabel(v)}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: v == null ? c.faint : rpeColor(c, v)),
          ),
        ),
        Text('Máximo', style: TextStyle(fontSize: 11, color: c.faint)),
      ]),
    ]);
  }
}

/// Pregunta el esfuerzo de una sesión en una hoja breve. Devuelve null si se cierra
/// sin responder; `(rpe: null)` si se elige continuar sin indicarlo.
Future<({int? rpe})?> askSessionRpe(BuildContext context, {required String title, int? initial, bool allowSkip = true}) {
  final c = context.colors;
  return showModalBottomSheet<({int? rpe})>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: c.fgStrong)),
        const SizedBox(height: 4),
        Text(
          'Piensa en la sesión completa: 1 es casi sin esfuerzo y 10 es lo más duro que puedes hacer. Con esto se calcula tu carga de entrenamiento.',
          style: TextStyle(fontSize: 13, color: c.muted, height: 1.35),
        ),
        const SizedBox(height: 16),
        RpePicker(value: initial, onChanged: (v) => Navigator.pop(ctx, (rpe: v))),
        if (allowSkip) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(ctx, (rpe: null)), child: const Text('Guardar sin indicar')),
        ],
      ]),
    ),
  );
}

/// "420 UA" (unidades arbitrarias de carga).
String formatLoad(double load) => '${load.round()} UA';
