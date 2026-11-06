import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/common/numbers.dart';
import '../../core/nutrition/models.dart';
import '../../core/nutrition/score.dart';
import '../../ui/format.dart';
import '../../ui/widgets.dart';

/// Rango diario de cada macro y su peso en el puntaje.
class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      ref.watch(goalsProvider),
      builder: (goals) => _GoalsEditor(key: ValueKey(goals.toMap().toString()), goals: goals),
    );
  }
}

class _Draft {
  _Draft(Range r, this.weight)
      : min = TextEditingController(text: plain(r.min)),
        max = TextEditingController(text: plain(r.max));

  final TextEditingController min;
  final TextEditingController max;
  double weight;
}

class _GoalsEditor extends ConsumerStatefulWidget {
  const _GoalsEditor({super.key, required this.goals});

  final Goals goals;

  @override
  ConsumerState<_GoalsEditor> createState() => _GoalsEditorState();
}

class _GoalsEditorState extends ConsumerState<_GoalsEditor> {
  late final Map<MacroKey, _Draft> _draft = _toDraft(widget.goals);
  bool _saving = false;

  Map<MacroKey, _Draft> _toDraft(Goals g) => {for (final k in MacroKey.values) k: _Draft(g.range(k), g.weights[k]!)};

  @override
  void dispose() {
    for (final d in _draft.values) {
      d.min.dispose();
      d.max.dispose();
    }
    super.dispose();
  }

  void _reset() => setState(() {
        for (final k in MacroKey.values) {
          _draft[k]!.min.text = plain(defaultGoals.range(k).min);
          _draft[k]!.max.text = plain(defaultGoals.range(k).max);
          _draft[k]!.weight = defaultGoals.weights[k]!;
        }
      });

  bool _invalid(MacroKey k) {
    final min = parseNum(_draft[k]!.min.text);
    final max = parseNum(_draft[k]!.max.text);
    return !(min != null && max != null && min >= 0 && max >= min);
  }

  Future<void> _save() async {
    final goals = Goals(
      ranges: {for (final k in MacroKey.values) k: Range(parseNum(_draft[k]!.min.text)!, parseNum(_draft[k]!.max.text)!)},
      weights: {for (final k in MacroKey.values) k: _draft[k]!.weight},
    );
    setState(() => _saving = true);
    await runGuarded(context, () => ref.read(nutritionActionsProvider).saveGoals(goals), success: 'Objetivos guardados');
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final weights = normalizedWeights({for (final k in MacroKey.values) k: _draft[k]!.weight});
    final hasErrors = MacroKey.values.any(_invalid);

    return PageBody(gap: 12, children: [
      SectionTitle(
        'Objetivos diarios',
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(tooltip: 'Calcular desde mi perfil', onPressed: () => context.push('/perfil'), icon: const Icon(Icons.calculate_outlined)),
          IconButton(tooltip: 'Restaurar valores por defecto', onPressed: _reset, icon: const Icon(Icons.restart_alt)),
          FilledButton(onPressed: hasErrors || _saving ? null : _save, child: const Text('Guardar')),
        ]),
      ),
      CardList(children: [
        for (final k in MacroKey.values)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(children: [
              Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: c.macro(k), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text('${macroMeta[k]!.label}  ', style: TextStyle(fontSize: 14, color: c.fg))),
                Text(macroMeta[k]!.unit, style: TextStyle(fontSize: 12, color: c.faint)),
                const SizedBox(width: 8),
                NumberField(controller: _draft[k]!.min, width: 76, dense: true, textAlign: TextAlign.right, error: _invalid(k), onChanged: (_) => setState(() {})),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('–', style: TextStyle(color: c.faint))),
                NumberField(controller: _draft[k]!.max, width: 76, dense: true, textAlign: TextAlign.right, error: _invalid(k), onChanged: (_) => setState(() {})),
              ]),
              Row(children: [
                SizedBox(width: 110, child: Text('Peso en puntaje', style: TextStyle(fontSize: 12, color: c.muted))),
                Expanded(
                  child: Slider(
                    value: _draft[k]!.weight.clamp(0, 100),
                    max: 100,
                    divisions: 20,
                    label: '${_draft[k]!.weight.round()}',
                    onChanged: (v) => setState(() => _draft[k]!.weight = v),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text('${(weights[k]! * 100).round()}%', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: c.fg, fontFeatures: tabular)),
                ),
              ]),
            ]),
          ),
      ]),
      Text(
        'Cada macro suma 100 puntos si queda dentro de su rango y baja en proporción a cuánto se aleja del límite más cercano. '
        'El puntaje del día es el promedio ponderado con estos pesos (se normalizan para sumar 100%).',
        style: TextStyle(fontSize: 12, color: c.faint, height: 1.5),
      ),
    ]);
  }
}
