import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/common/date.dart';
import '../../core/nutrition/copy.dart';
import '../../core/nutrition/macros.dart';
import '../../core/nutrition/models.dart';
import '../../core/nutrition/score.dart';
import '../../core/common/numbers.dart';
import '../../ui/format.dart';
import '../../ui/macros.dart';
import '../../ui/widgets.dart';
import '../activity/steps_card.dart';

/// Diario del día: puntaje, macros contra objetivos y comidas registradas.
class DiaryPage extends ConsumerStatefulWidget {
  const DiaryPage({super.key, this.initialDate});

  final String? initialDate;

  @override
  ConsumerState<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends ConsumerState<DiaryPage> {
  late String _date = isDateKey(widget.initialDate) ? widget.initialDate! : todayKey();

  @override
  void didUpdateWidget(DiaryPage old) {
    super.didUpdateWidget(old);
    if (widget.initialDate != old.initialDate && isDateKey(widget.initialDate)) _date = widget.initialDate!;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final goals = ref.watch(goalsProvider).value ?? defaultGoals;
    final entries = ref.watch(dayEntriesProvider(_date));
    final list = entries.value;
    final totals = sumMacros((list ?? const <DiaryEntry>[]).map((e) => e.macros));
    final score = dailyScore(totals, goals);
    final isEmpty = list != null && list.isEmpty;
    final previous = addDays(_date, -1);
    final previousList = ref.watch(dayEntriesProvider(previous)).value;
    final repeat = list != null && previousList != null ? mealsToRepeat(previousList, list) : const <MealSlot>[];

    return PageBody(children: [
      Row(children: [
        Expanded(child: Align(alignment: Alignment.centerLeft, child: DateNav(date: _date, onChanged: (d) => setState(() => _date = d)))),
        IconButton(
          tooltip: 'Copiar de otro día',
          onPressed: () => showSheet<void>(context, title: 'Copiar comidas', builder: (_) => CopyMealsSheet(target: _date)),
          icon: const Icon(Icons.content_copy),
        ),
        IconButton.filled(
          tooltip: 'Registrar comida',
          onPressed: () => context.go('/registrar?d=$_date'),
          icon: const Icon(Icons.playlist_add),
        ),
      ]),
      AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          ScoreRing(score: score.total, empty: isEmpty),
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
      StepsCard(date: _date),
      if (entries is AsyncError) ErrorView(entries.error!),
      if (list == null && entries is! AsyncError) const LoadingView(),
      if (repeat.isNotEmpty)
        _RepeatCard(
          title: _date == todayKey() ? 'Repetir de ayer' : 'Repetir del ${weekdayDate(previous)}',
          meals: repeat,
          source: previousList!,
          onCopy: (slots) => _copy(previousList.where((e) => slots.contains(e.meal)).toList()),
        ),
      if (isEmpty)
        const AppCard(
          child: EmptyState(
            icon: Icons.restaurant_menu,
            title: 'Sin registros este día',
            message: 'Toca el botón de registrar para pegar una lista como "Arroz 100g, Huevos x3".',
          ),
        ),
      if (list != null)
        for (final slot in MealSlot.values)
          if (list.any((e) => e.meal == slot))
            _MealCard(
              slot: slot,
              items: list.where((e) => e.meal == slot).toList(),
              onDelete: (e) => runGuarded(context, () => ref.read(nutritionActionsProvider).deleteEntry(_date, e)),
            ),
      if (list != null && list.isNotEmpty)
        Text('Total del día: ${formatMacro(MacroKey.kcal, totals.kcal)} kcal', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.faint)),
    ]);
  }

  Future<void> _copy(List<DiaryEntry> source) async {
    var n = 0;
    await runGuarded(context, () async => n = await ref.read(nutritionActionsProvider).repeatEntries(_date, source));
    if (mounted && n > 0) showToast(context, copiedText(n));
  }
}

String copiedText(int n) => '$n ${n == 1 ? 'registro copiado' : 'registros copiados'}';

/// Texto corto con los primeros nombres: "Avena, Leche y 2 más".
String _preview(List<DiaryEntry> items) {
  final names = items.map((e) => e.name).toList();
  return '${names.take(2).join(', ')}${names.length > 2 ? ' y ${names.length - 2} más' : ''}';
}

/// Comidas del día anterior que hoy aún no tienen registros, para repetirlas con un toque.
class _RepeatCard extends StatelessWidget {
  const _RepeatCard({required this.title, required this.meals, required this.source, required this.onCopy});

  final String title;
  final List<MealSlot> meals;
  final List<DiaryEntry> source;
  final void Function(Set<MealSlot> meals) onCopy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CardList(
      header: CardHeader(
        title,
        icon: Icons.replay,
        trailing: meals.length > 1
            ? TextButton(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => onCopy(meals.toSet()),
                child: const Text('Copiar todo'),
              )
            : null,
      ),
      children: [
        for (final slot in meals)
          () {
            final items = source.where((e) => e.meal == slot).toList();
            final kcal = sumMacros(items.map((e) => e.macros)).kcal;
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
              child: Row(children: [
                Icon(mealMeta[slot]!.icon, size: 18, color: c.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${mealMeta[slot]!.label} · ${formatMacro(MacroKey.kcal, kcal)} kcal',
                        style: TextStyle(fontSize: 14, color: c.fgStrong, fontFeatures: tabular)),
                    Text(_preview(items), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.faint)),
                  ]),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => onCopy({slot}),
                  child: Text('Copiar', semanticsLabel: 'Copiar ${mealMeta[slot]!.label.toLowerCase()}'),
                ),
              ]),
            );
          }(),
      ],
    );
  }
}

/// Copia comidas de cualquier día al día `target`, eligiendo cuáles.
class CopyMealsSheet extends ConsumerStatefulWidget {
  const CopyMealsSheet({super.key, required this.target});

  final String target;

  @override
  ConsumerState<CopyMealsSheet> createState() => _CopyMealsSheetState();
}

class _CopyMealsSheetState extends ConsumerState<CopyMealsSheet> {
  late String _source = addDays(widget.target, -1);

  /// Comidas desmarcadas (por defecto se copian todas).
  final _skipped = <MealSlot>{};
  bool _saving = false;

  Future<void> _copy(List<DiaryEntry> entries) async {
    setState(() => _saving = true);
    var n = 0;
    final ok = await runGuarded(context, () async => n = await ref.read(nutritionActionsProvider).repeatEntries(widget.target, entries));
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      showToast(context, copiedText(n));
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final entries = ref.watch(dayEntriesProvider(_source));
    final list = entries.value;
    final meals = [for (final m in MealSlot.values) if (list?.any((e) => e.meal == m) ?? false) m];
    final selected = [for (final e in list ?? const <DiaryEntry>[]) if (!_skipped.contains(e.meal)) e];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Text('Desde', style: TextStyle(fontSize: 12, color: c.muted)),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: DateNav(date: _source, onChanged: (d) => setState(() {
                    _source = d;
                    _skipped.clear();
                  })),
            ),
          ),
        ]),
      ),
      Expanded(
        child: PageBody(gap: 12, children: [
          if (entries is AsyncError) ErrorView(entries.error!),
          if (list == null && entries is! AsyncError) const LoadingView(),
          if (list != null && list.isEmpty)
            const AppCard(child: EmptyState(icon: Icons.event_busy, title: 'Sin registros ese día', message: 'Elige otro día con las flechas.')),
          for (final slot in meals)
            CardList(
              header: CardHeader(
                mealMeta[slot]!.label,
                icon: mealMeta[slot]!.icon,
                trailing: Checkbox(
                  value: !_skipped.contains(slot),
                  semanticLabel: 'Copiar ${mealMeta[slot]!.label.toLowerCase()}',
                  onChanged: (v) => setState(() => v == true ? _skipped.remove(slot) : _skipped.add(slot)),
                ),
              ),
              children: [
                for (final e in list!.where((e) => e.meal == slot))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(children: [
                      Expanded(child: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.fg))),
                      Text('${e.grams.round()} g', style: TextStyle(fontSize: 12, color: c.faint, fontFeatures: tabular)),
                    ]),
                  ),
              ],
            ),
        ]),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: selected.isEmpty || _saving ? null : () => _copy(selected),
            icon: const Icon(Icons.content_copy, size: 18),
            label: Text(selected.isEmpty ? 'Nada que copiar' : 'Copiar ${selected.length} a ${widget.target == todayKey() ? 'hoy' : weekdayDate(widget.target)}'),
          ),
        ),
      ),
    ]);
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.slot, required this.items, required this.onDelete});

  final MealSlot slot;
  final List<DiaryEntry> items;
  final void Function(DiaryEntry) onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meta = mealMeta[slot]!;
    return CardList(
      header: CardHeader(meta.label, icon: meta.icon, trailing: MacroInline(sumMacros(items.map((i) => i.macros)), fontSize: 11)),
      children: [
        for (final e in items)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(children: [
              if (e.kind == EntryKind.recipe) ...[Icon(Icons.menu_book_outlined, size: 14, color: c.primary), const SizedBox(width: 6)],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.fg)),
                    const SizedBox(height: 2),
                    Wrap(spacing: 8, children: [
                      Text('${e.servings != null ? '${plain(e.servings!)} porc. · ' : ''}${e.grams.round()} g',
                          style: TextStyle(fontSize: 12, color: c.faint, fontFeatures: tabular)),
                      MacroInline(e.macros),
                    ]),
                  ]),
                ),
              ),
              IconButton(
                tooltip: 'Eliminar ${e.name}',
                onPressed: () => onDelete(e),
                icon: Icon(Icons.delete_outline, size: 20, color: c.danger),
              ),
            ]),
          ),
      ],
    );
  }
}
