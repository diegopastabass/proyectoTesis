import 'macros.dart';
import 'models.dart';

class RecipeTotals {
  const RecipeTotals({required this.totalGrams, required this.totals, required this.perServing, required this.missing});

  final double totalGrams;
  final Macros totals;
  final Macros perServing;

  /// foodIds que no existen en el catálogo.
  final List<String> missing;
}

RecipeTotals computeRecipe(List<RecipeIngredient> ingredients, double servings, Map<String, Food> foods) {
  final missing = <String>[];
  final parts = <Macros>[];
  var totalGrams = 0.0;
  for (final ing in ingredients) {
    final food = foods[ing.foodId];
    if (food == null) {
      missing.add(ing.foodId);
      continue;
    }
    totalGrams += ing.grams;
    parts.add(macrosForGrams(food.per100g, ing.grams));
  }
  final totals = roundMacros(sumMacros(parts));
  final perServing = roundMacros(scaleMacros(totals, servings > 0 ? 1 / servings : 0));
  return RecipeTotals(totalGrams: totalGrams, totals: totals, perServing: perServing, missing: missing);
}

/// Recalcula los macros de una receta desde sus ingredientes actuales, de modo que
/// reflejen cambios en el catálogo. Si falta algún ingrediente conserva lo guardado.
Recipe refreshRecipe(Recipe recipe, Map<String, Food> foods) {
  final t = computeRecipe(recipe.ingredients, recipe.servings, foods);
  if (t.missing.isNotEmpty) return recipe;
  return recipe.copyWith(totalGrams: t.totalGrams, totals: t.totals, perServing: t.perServing);
}
