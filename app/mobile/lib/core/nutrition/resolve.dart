import '../common/numbers.dart';
import 'macros.dart';
import 'matcher.dart';
import 'models.dart';
import 'quantity.dart';
import 'rule_parser.dart';

/// Desde esta confianza el ítem se acepta sin revisión.
const acceptConfidence = 0.85;

/// Bajo esta confianza se considera que el alimento no está en el catálogo.
const missingConfidence = 0.6;

/// Si el segundo candidato está así de cerca del primero, se pide revisión.
const _ambiguityMargin = 0.03;

enum ItemStatus { ok, review, missing }

class ResolvedItem {
  const ResolvedItem({
    required this.key,
    required this.parsed,
    required this.match,
    required this.alternatives,
    required this.grams,
    required this.servings,
    required this.macros,
    required this.assumed,
    required this.label,
    required this.status,
  });

  final String key;
  final ParsedItem parsed;
  final Candidate? match;
  final List<Candidate> alternatives;
  final double grams;
  final double? servings;
  final Macros macros;
  final bool assumed;
  final String label;
  final ItemStatus status;

  ResolvedItem withAmount(Amount a, {required ItemStatus status}) => ResolvedItem(
        key: key,
        parsed: parsed,
        match: match,
        alternatives: alternatives,
        grams: a.grams,
        servings: a.servings,
        macros: a.macros,
        assumed: a.assumed,
        label: a.label,
        status: status,
      );

  ResolvedItem withStatus(ItemStatus s) => withAmount(
        Amount(grams: grams, servings: servings, macros: macros, assumed: assumed, label: label),
        status: s,
      );
}

/// Catálogo con el que se resuelven las listas.
class ResolveContext {
  ResolveContext({required this.matcher, required this.foods, required this.recipes});

  factory ResolveContext.build(List<Food> foods, List<Recipe> recipes) => ResolveContext(
        matcher: Matcher(buildCatalog(foods, recipes)),
        foods: {for (final f in foods) f.id: f},
        recipes: {for (final r in recipes) r.id: r},
      );

  final Matcher matcher;
  final Map<String, Food> foods;
  final Map<String, Recipe> recipes;

  /// Copia con un alimento extra (recién creado, aún no llega del servidor).
  ResolveContext withFood(Food food) => ResolveContext(matcher: matcher, foods: {...foods, food.id: food}, recipes: recipes);
}

Amount? _amountFor(ParsedItem parsed, Candidate match, ResolveContext ctx) {
  if (match.kind == EntryKind.food) {
    final food = ctx.foods[match.id];
    return food != null ? foodAmount(parsed, food) : null;
  }
  final recipe = ctx.recipes[match.id];
  return recipe != null ? recipeAmount(parsed, recipe) : null;
}

ItemStatus _statusFor(Candidate? match, List<Candidate> alternatives, bool assumed, bool forced) {
  if (match == null) return ItemStatus.missing;
  if (forced) return ItemStatus.ok;
  final second = alternatives.where((c) => c.id != match.id || c.kind != match.kind).firstOrNull;
  final ambiguous = match.confidence < 1 && second != null && match.confidence - second.confidence <= _ambiguityMargin;
  if (match.confidence < acceptConfidence || ambiguous || assumed) return ItemStatus.review;
  return ItemStatus.ok;
}

/// Resuelve un ítem. `forced` = candidato elegido por el usuario.
ResolvedItem resolveItem(ParsedItem parsed, ResolveContext ctx, String key, {Candidate? forced}) {
  final alternatives = ctx.matcher.search(parsed.query, limit: 6);
  final best = forced ?? alternatives.firstOrNull;
  final match = best != null && (forced != null || best.confidence >= missingConfidence) ? best : null;
  final amount = (match != null ? _amountFor(parsed, match, ctx) : null) ?? Amount.zero;
  return ResolvedItem(
    key: key,
    parsed: parsed,
    match: match,
    alternatives: alternatives,
    grams: amount.grams,
    servings: amount.servings,
    macros: amount.macros,
    assumed: amount.assumed,
    label: amount.label,
    status: _statusFor(match, alternatives, amount.assumed, forced != null),
  );
}

List<ResolvedItem> resolveText(String text, ResolveContext ctx) {
  final parsed = parseText(text);
  return [for (var i = 0; i < parsed.length; i++) resolveItem(parsed[i], ctx, '$i-${parsed[i].raw}')];
}

/// Recalcula un ítem cuando el usuario corrige los gramos a mano.
ResolvedItem withGrams(ResolvedItem item, double grams, ResolveContext ctx) {
  final match = item.match;
  if (match == null || grams < 0) return item;
  if (match.kind == EntryKind.food) {
    final food = ctx.foods[match.id];
    if (food == null) return item;
    return item.withAmount(
      Amount(grams: grams, macros: macrosForGrams(food.per100g, grams), assumed: false, label: '${plain(grams)} g'),
      status: ItemStatus.ok,
    );
  }
  final recipe = ctx.recipes[match.id];
  if (recipe == null) return item;
  return item.withAmount(recipeAmountForGrams(recipe, grams), status: ItemStatus.ok);
}
