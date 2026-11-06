import '../common/numbers.dart';
import 'macros.dart';
import 'models.dart';
import 'rule_parser.dart';
import 'units.dart';

class Amount {
  const Amount({required this.grams, this.servings, required this.macros, required this.assumed, required this.label});

  static const zero = Amount(grams: 0, macros: Macros.zero, assumed: false, label: '');

  final double grams;
  final double? servings;
  final Macros macros;

  /// true cuando la cantidad o la porción se supusieron.
  final bool assumed;

  /// Descripción legible, p. ej. "3 × unidad (50 g)".
  final String label;
}

const _fallbackGrams = 100.0;
const _defaultPortions = ['unidad', 'mediano', 'porcion'];

Portion? _findPortion(Food food, String name) => food.portions.where((p) => samePortionName(p.name, name)).firstOrNull;

Portion? _defaultPortion(Food food) {
  for (final n in _defaultPortions) {
    final p = _findPortion(food, n);
    if (p != null) return p;
  }
  return food.portions.firstOrNull;
}

String _fmt(double n) => n == n.truncateToDouble() ? plain(n) : plain(round1(n));

/// Convierte la cantidad escrita a gramos usando las porciones del alimento.
Amount foodAmount(ParsedItem item, Food food) {
  final density = food.density ?? 1;
  final q = item.quantity ?? 1;
  var assumed = item.quantity == null;
  double grams;
  String label;
  final unit = item.unit;

  if (unit == Unit.g) {
    grams = q;
    label = '${_fmt(q)} g';
  } else if (unit == Unit.ml) {
    grams = q * density;
    label = '${_fmt(q)} ml';
  } else {
    Portion? portion;
    if (item.size != null) portion = _findPortion(food, item.size!.label);
    if (portion == null && unit != null && unit != Unit.unidad) portion = _findPortion(food, unit.name);
    if (portion == null && (unit == null || unit == Unit.unidad || item.size != null)) portion = _defaultPortion(food);

    if (portion != null) {
      grams = q * portion.grams;
      label = '${_fmt(q)} × ${portion.name} (${_fmt(portion.grams)} g)';
      if (item.size != null && !samePortionName(portion.name, item.size!.label)) assumed = true;
    } else if (unit != null && genericMl[unit] != null) {
      grams = q * genericMl[unit]! * density;
      label = '${_fmt(q)} × ${unit.label} (${plain(genericMl[unit]!)} ml)';
      assumed = true;
    } else if (unit != null && genericG[unit] != null) {
      grams = q * genericG[unit]!;
      label = '${_fmt(q)} × ${unit.label} (${plain(genericG[unit]!)} g)';
      assumed = true;
    } else {
      grams = _fallbackGrams;
      label = '${plain(_fallbackGrams)} g (supuesto)';
      assumed = true;
    }
  }

  grams = round1(grams);
  return Amount(grams: grams, macros: macrosForGrams(food.per100g, grams), assumed: assumed, label: label);
}

/// Cantidad de una receta: por porciones ("2 porciones") o por peso ("300 g").
Amount recipeAmount(ParsedItem item, Recipe recipe) {
  if ((item.unit == Unit.g || item.unit == Unit.ml) && item.quantity != null) {
    return recipeAmountForGrams(recipe, item.quantity!);
  }
  final servings = item.quantity ?? 1;
  final gramsPerServing = recipe.servings > 0 ? recipe.totalGrams / recipe.servings : 0.0;
  return Amount(
    grams: round1(gramsPerServing * servings),
    servings: servings,
    macros: roundMacros(scaleMacros(recipe.perServing, servings)),
    assumed: item.quantity == null,
    label: '${_fmt(servings)} ${servings == 1 ? 'porción' : 'porciones'}',
  );
}

Amount recipeAmountForGrams(Recipe recipe, double grams) {
  final ratio = recipe.totalGrams > 0 ? grams / recipe.totalGrams : 0.0;
  return Amount(
    grams: round1(grams),
    servings: round1(ratio * recipe.servings),
    macros: roundMacros(scaleMacros(recipe.totals, ratio)),
    assumed: false,
    label: '${_fmt(grams)} g',
  );
}
