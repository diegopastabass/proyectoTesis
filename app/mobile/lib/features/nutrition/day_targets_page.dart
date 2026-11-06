/// CU-18 (metas del día según el entrenamiento) y CU-20 (nota en una comida).
/// El avance del día es real; el ajuste de las metas es una regla de ejemplo, porque
/// el cálculo definitivo aún no está implementado.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/common/date.dart';
import '../../core/nutrition/macros.dart';
import '../../core/nutrition/models.dart';
import '../../core/nutrition/score.dart';
import '../../ui/format.dart';
import '../../ui/macros.dart';
import '../../ui/sim_widgets.dart';
import '../../ui/widgets.dart';

/// Ajuste de ejemplo: más calorías y carbohidratos cuando se entrena.
Goals _adjusted(Goals g, bool training) {
  final kcal = training ? 1.08 : 0.95;
  final carbs = training ? 1.15 : 0.85;
  Range scale(Range r, double f) => Range((r.min * f / 5).round() * 5.0, (r.max * f / 5).round() * 5.0);
  return Goals(
    ranges: {
      for (final k in MacroKey.values)
        k: switch (k) {
          MacroKey.kcal => scale(g.range(k), kcal),
          MacroKey.carbs => scale(g.range(k), carbs),
          _ => g.range(k),
        },
    },
    weights: g.weights,
  );
}

class DayTargetsPage extends ConsumerStatefulWidget {
  const DayTargetsPage({super.key, this.rest = false});

  /// Abre con la vista de un día de descanso.
  final bool rest;

  @override
  ConsumerState<DayTargetsPage> createState() => _DayTargetsPageState();
}

class _DayTargetsPageState extends ConsumerState<DayTargetsPage> {
  late bool _training = !widget.rest;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = ref.watch(goalsProvider).value ?? defaultGoals;
    final goals = _adjusted(base, _training);
    final totals = sumMacros((ref.watch(dayEntriesProvider(todayKey())).value ?? const <DiaryEntry>[]).map((e) => e.macros));
    final score = dailyScore(totals, goals);
    final kcalLeft = ((goals.range(MacroKey.kcal).min + goals.range(MacroKey.kcal).max) / 2 - totals.kcal).clamp(0, double.infinity).round();
    final proteinLeft = ((goals.range(MacroKey.protein).min + goals.range(MacroKey.protein).max) / 2 - totals.protein).clamp(0, double.infinity).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Metas de hoy')),
      body: PageBody(children: [
        AppSegmented<bool>(
          value: _training,
          segments: const {
            true: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.fitness_center), SizedBox(width: 6), Text('Con entrenamiento')]),
            false: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.bedtime_outlined), SizedBox(width: 6), Text('Descanso')]),
          },
          onChanged: (v) => setState(() => _training = v),
        ),
        InfoNote(
          icon: _training ? Icons.event_available : Icons.bedtime_outlined,
          title: _training ? 'Hoy: Fuerza de pierna, 19:00' : 'Hoy es tu día de descanso',
          text: _training ? 'Subimos tus calorías y carbohidratos para que llegues con energía y te recuperes bien.' : 'Bajamos un poco tus calorías y carbohidratos, y mantenemos la proteína.',
        ),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            ScoreRing(score: score.total, empty: totals.kcal == 0),
            const SizedBox(width: 16),
            Expanded(
              child: Column(children: [
                for (final k in MacroKey.values) ...[
                  if (k != MacroKey.kcal) const SizedBox(height: 10),
                  MacroBar(macro: k, value: totals[k], range: goals.range(k), score: score.perMacro[k]!),
                ],
              ]),
            ),
          ]),
        ),
        TileGrid(children: [
          StatTile(icon: Icons.local_fire_department_outlined, label: 'Te faltan', value: '$kcalLeft kcal'),
          StatTile(icon: Icons.egg_alt_outlined, label: 'Proteína pendiente', value: '$proteinLeft g'),
        ]),
        if (_training)
          CardList(header: const CardHeader('Cuándo te conviene comer', icon: Icons.schedule), children: [
            for (final (time, title, text) in const [
              ('17:30', 'Antes de entrenar', 'Una colación con carbohidratos, como pan con palta o un plátano.'),
              ('20:30', 'Después de entrenar', 'Una comida con proteína y carbohidratos, dentro de las 2 horas siguientes.'),
            ])
              ListTile(
                dense: true,
                leading: Text(time, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.primary, fontFeatures: tabular)),
                title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
                subtitle: Text(text, style: TextStyle(fontSize: 12, color: c.muted)),
              ),
          ]),
        Text('Son sugerencias y no una dieta. Ante una condición de salud, consulta a un profesional.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.faint)),
      ]),
    );
  }
}

/// Detalle de una comida del diario, con su nota de "cómo me sentí" (CU-20).
class MealDetailPage extends ConsumerWidget {
  const MealDetailPage({super.key, required this.slot, this.date, this.example = false});

  final MealSlot slot;
  final String? date;

  /// Deja un borrador de ejemplo en la nota (lo usa el modo de capturas).
  final bool example;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final day = isDateKey(date) ? date! : todayKey();
    final items = (ref.watch(dayEntriesProvider(day)).value ?? const <DiaryEntry>[]).where((e) => e.meal == slot).toList();
    final totals = sumMacros(items.map((e) => e.macros));
    final meta = mealMeta[slot]!;
    return Scaffold(
      appBar: AppBar(title: Text(meta.label)),
      body: PageBody(children: [
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              GradientIcon(meta.icon, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(capitalize(longDate(day)), style: TextStyle(fontSize: 13, color: c.muted)),
                  Text('${totals.kcal.round()} kcal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: c.fgStrong, fontFeatures: tabular)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            MacroInline(totals),
          ]),
        ),
        CardList(children: [
          for (final e in items)
            ListTile(
              dense: true,
              title: Text(e.name, style: TextStyle(fontSize: 14, color: c.fgStrong)),
              trailing: Text('${e.grams.round()} g', style: TextStyle(fontSize: 13, color: c.muted, fontFeatures: tabular)),
            ),
        ]),
        FeelingNoteCard(
          noteKey: 'comida-$day-${slot.name}',
          hint: 'Por ejemplo: me cayó pesada antes de entrenar.',
          initial: example ? 'Me cayó un poco pesada. La próxima vez como menos arroz antes de entrenar.' : null,
        ),
      ]),
    );
  }
}
