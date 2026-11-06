import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/common/numbers.dart';
import '../../core/nutrition/macros.dart';
import '../../core/nutrition/models.dart';
import '../../core/nutrition/recipe.dart';
import '../../ui/macros.dart';
import '../../ui/widgets.dart';
import 'food_form_page.dart';
import 'food_picker.dart';

class RecipeEditorPage extends ConsumerWidget {
  const RecipeEditorPage({super.key, required this.id});

  /// "nueva" para crear.
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(ref.watch(nutritionDataProvider), builder: (data) {
      final recipe = id == 'nueva' ? null : data.recipes.where((r) => r.id == id).firstOrNull;
      if (id != 'nueva' && recipe == null) return const LoadingView(text: 'Receta no encontrada.');
      return _RecipeEditor(key: ValueKey(recipe?.id ?? 'nueva'), recipe: recipe, data: data);
    });
  }
}

class _Row {
  _Row(this.foodId, String grams) : grams = TextEditingController(text: grams);

  final String foodId;
  final TextEditingController grams;
}

class _RecipeEditor extends ConsumerStatefulWidget {
  const _RecipeEditor({super.key, required this.recipe, required this.data});

  final Recipe? recipe;
  final NutritionData data;

  @override
  ConsumerState<_RecipeEditor> createState() => _RecipeEditorState();
}

class _RecipeEditorState extends ConsumerState<_RecipeEditor> {
  late final _name = TextEditingController(text: widget.recipe?.name ?? '');
  late final _aliases = TextEditingController(text: widget.recipe?.aliases.join(', ') ?? '');
  late final _servings = TextEditingController(text: plain(widget.recipe?.servings ?? 1));
  late final List<_Row> _rows = [for (final i in widget.recipe?.ingredients ?? const <RecipeIngredient>[]) _Row(i.foodId, plain(i.grams))];

  /// Alimentos creados aquí que aún no llegan al catálogo.
  final Map<String, Food> _created = {};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _aliases, _servings, ..._rows.map((r) => r.grams)]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addFood(String foodId) => setState(() => _rows.add(_Row(foodId, '100')));

  Future<void> _pick() async {
    final data = widget.data;
    final result = await showFoodPicker(context, matcher: data.foodMatcher, ctx: data.ctx, title: 'Agregar ingrediente');
    if (!mounted) return;
    switch (result) {
      case Picked(:final candidate):
        _addFood(candidate.id);
      case CreateRequested(:final name):
        final food = await openFoodForm(context, initialName: name);
        if (food != null && mounted) {
          _created[food.id] = food;
          _addFood(food.id);
        }
      case null:
        break;
    }
  }

  Future<void> _save(RecipeTotals totals, List<RecipeIngredient> ingredients, double servings) async {
    final uid = ref.read(sessionUserProvider)?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    final recipe = Recipe(
      id: widget.recipe?.id ?? '',
      ownerId: uid,
      name: _name.text.trim(),
      aliases: _aliases.text.split(',').map((a) => a.trim()).where((a) => a.isNotEmpty).toList(),
      servings: servings,
      ingredients: ingredients,
      totalGrams: totals.totalGrams,
      totals: totals.totals,
      perServing: totals.perServing,
    );
    final ok = await runGuarded(context, () => ref.read(nutritionActionsProvider).saveRecipe(recipe, id: widget.recipe?.id), success: 'Receta guardada');
    if (!mounted) return;
    if (ok) {
      context.go('/recetas');
    } else {
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final recipe = widget.recipe!;
    if (!await confirm(context, '¿Eliminar la receta "${recipe.name}"?', accept: 'Eliminar', destructive: true)) return;
    if (!mounted) return;
    final ok = await runGuarded(context, () => ref.read(nutritionActionsProvider).deleteRecipe(recipe.id), success: 'Receta eliminada');
    if (ok && mounted) context.go('/recetas');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final foods = {...widget.data.ctx.foods, ..._created};
    final ingredients = [for (final r in _rows) RecipeIngredient(foodId: r.foodId, grams: numOr(r.grams.text, 0).clamp(0, double.infinity).toDouble())];
    final servings = numOr(_servings.text, 0).clamp(0, double.infinity).toDouble();
    final totals = computeRecipe(ingredients, servings, foods);
    final valid = _name.text.trim().isNotEmpty && servings > 0 && ingredients.isNotEmpty && totals.missing.isEmpty && ingredients.every((i) => i.grams > 0);

    return PageBody(gap: 12, children: [
      PageHeader(
        title: widget.recipe != null ? 'Editar receta' : 'Nueva receta',
        onBack: () => context.go('/recetas'),
        actions: [
          if (widget.recipe != null)
            IconButton(tooltip: 'Eliminar receta', onPressed: _delete, icon: Icon(Icons.delete_outline, color: c.danger)),
          FilledButton(onPressed: valid && !_saving ? () => _save(totals, ingredients, servings) : null, child: const Text('Guardar')),
        ],
      ),
      AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _name,
                maxLength: 120,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Nombre (así la reconocerá la lista)', hintText: 'Pollo al limón con arroz', counterText: ''),
              ),
            ),
            const SizedBox(width: 8),
            NumberField(controller: _servings, label: 'Porciones', width: 96, onChanged: (_) => setState(() {})),
          ]),
          const SizedBox(height: 8),
          TextField(controller: _aliases, decoration: const InputDecoration(labelText: 'Alias, separados por coma', hintText: 'pollo al limon')),
        ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CardHeader('Ingredientes', trailing: IconButton(tooltip: 'Agregar ingrediente', onPressed: _pick, icon: Icon(Icons.add, color: c.primary))),
          if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Agrega ingredientes desde el catálogo.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.muted)),
            ),
          for (final row in _rows) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(foods[row.foodId]?.name ?? 'Alimento eliminado',
                        overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: foods[row.foodId] != null ? c.fg : c.danger)),
                    if (foods[row.foodId] case final food?) MacroInline(macrosForGrams(food.per100g, numOr(row.grams.text, 0)), fontSize: 11),
                  ]),
                ),
                NumberField(controller: row.grams, width: 70, dense: true, textAlign: TextAlign.right, onChanged: (_) => setState(() {})),
                const SizedBox(width: 4),
                Text('g', style: TextStyle(fontSize: 12, color: c.faint)),
                IconButton(
                  tooltip: 'Quitar ingrediente',
                  onPressed: () => setState(() {
                    _rows.remove(row);
                    row.grams.dispose();
                  }),
                  icon: Icon(Icons.delete_outline, color: c.danger, size: 20),
                ),
              ]),
            ),
          ],
          if (_rows.isNotEmpty) ...[
            const Divider(),
            Container(
              color: c.surface2.withValues(alpha: 0.5),
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Text('Total · ${plain(totals.totalGrams)} g', style: TextStyle(fontSize: 12, color: c.muted))),
                  MacroInline(totals.totals, fontSize: 11),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                    child: Text('Por porción · ${servings > 0 ? (totals.totalGrams / servings).round() : 0} g',
                        style: TextStyle(fontSize: 12, color: c.muted)),
                  ),
                  MacroInline(totals.perServing, fontSize: 11, bold: true),
                ]),
              ]),
            ),
          ],
        ]),
      ),
    ]);
  }
}
