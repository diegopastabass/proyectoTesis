import '../common/numbers.dart';
import 'macros.dart';
import 'models.dart';
import 'quantity.dart';

/// Copia registros de otro día ("el mismo almuerzo de ayer").
///
/// Conserva alimento, cantidad y comida, pero recalcula los macros con el
/// catálogo actual: si el alimento se corrigió después, la copia queda bien.
/// Si el alimento o la receta ya no existen, se usan los macros guardados.
List<NewDiaryEntry> copyEntries(Iterable<DiaryEntry> source, {required Map<String, Food> foods, required Map<String, Recipe> recipes}) => [
      for (final e in source) _copy(e, foods, recipes),
    ];

NewDiaryEntry _copy(DiaryEntry e, Map<String, Food> foods, Map<String, Recipe> recipes) {
  var name = e.name;
  var grams = e.grams;
  var servings = e.servings;
  var macros = e.macros;
  switch (e.kind) {
    case EntryKind.food:
      if (foods[e.refId] case final food?) {
        name = food.name;
        macros = macrosForGrams(food.per100g, grams);
      }
    case EntryKind.recipe:
      if (recipes[e.refId] case final recipe?) {
        name = recipe.name;
        // Las recetas se registran por porciones; si no hay, por peso.
        if (servings != null && recipe.servings > 0) {
          grams = round1(recipe.totalGrams / recipe.servings * servings);
          macros = roundMacros(scaleMacros(recipe.perServing, servings));
        } else {
          final amount = recipeAmountForGrams(recipe, grams);
          servings = amount.servings;
          macros = amount.macros;
        }
      }
  }
  return NewDiaryEntry(kind: e.kind, refId: e.refId, name: name, grams: grams, servings: servings, macros: macros, meal: e.meal);
}

/// Comidas de `source` que todavía no tienen registros en `target`, en el orden del día.
List<MealSlot> mealsToRepeat(Iterable<DiaryEntry> source, Iterable<DiaryEntry> target) {
  final taken = target.map((e) => e.meal).toSet();
  final available = source.map((e) => e.meal).toSet();
  return [for (final m in MealSlot.values) if (available.contains(m) && !taken.contains(m)) m];
}
