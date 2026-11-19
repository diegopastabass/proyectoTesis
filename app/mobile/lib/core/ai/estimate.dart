/// Comida estimada (foto o palabras) lista para revisar y guardar.
///
/// Igual que en la lista por reglas, **los macros salen del catálogo** cuando el
/// alimento está en él: el modelo solo dice qué alimento es y cuántos gramos. Si
/// no está, se usan los macros que estimó el modelo y el alimento queda marcado
/// como estimado. Todo lo que tenga confianza bajo 70 % se debe revisar antes de
/// guardar (requisito del módulo de nutrición).
library;

import '../common/numbers.dart';
import '../nutrition/macros.dart';
import '../nutrition/matcher.dart';
import '../nutrition/models.dart';
import '../nutrition/quantity.dart';
import '../nutrition/resolve.dart';
import 'ai_models.dart';

/// De dónde salen los macros del alimento.
enum EstimateSource {
  /// Del catálogo (alimento o receta encontrados por nombre).
  catalog,

  /// Del modelo (no está en el catálogo).
  model,

  /// De la lista por reglas, sin pasar por el modelo.
  rules,
}

class EstimatedItem {
  const EstimatedItem({
    required this.name,
    required this.grams,
    required this.macros,
    required this.confidence,
    required this.source,
    this.match,
    this.per100g,
    this.confirmed = false,
  });

  /// Lo que se ve en la lista (el nombre del catálogo si se encontró).
  final String name;
  final double grams;
  final Macros macros;

  /// 0–100: la del modelo, o 100 si lo resolvieron las reglas sin dudas.
  final double confidence;
  final EstimateSource source;

  /// Alimento o receta del catálogo.
  final Candidate? match;

  /// Macros por 100 g para recalcular al cambiar los gramos (de un alimento del
  /// catálogo o derivados de la estimación del modelo).
  final Macros? per100g;

  /// El usuario ya lo revisó (o cambió los gramos).
  final bool confirmed;

  /// Falta revisarlo para poder guardar.
  bool get needsReview => !confirmed && confidence < minAiConfidence;

  EstimatedItem copyWith({double? grams, Macros? macros, bool? confirmed}) => EstimatedItem(
    name: name,
    grams: grams ?? this.grams,
    macros: macros ?? this.macros,
    confidence: confidence,
    source: source,
    match: match,
    per100g: per100g,
    confirmed: confirmed ?? this.confirmed,
  );

  /// Con otros gramos: se recalculan los macros y queda revisado.
  EstimatedItem withGrams(double grams, ResolveContext ctx) {
    if (grams <= 0) return this;
    final m = match;
    if (m != null && m.kind == EntryKind.recipe) {
      final recipe = ctx.recipes[m.id];
      if (recipe != null) return copyWith(grams: grams, macros: recipeAmountForGrams(recipe, grams).macros, confirmed: true);
    }
    final base = per100g;
    if (base == null) return copyWith(grams: grams, confirmed: true);
    return copyWith(grams: grams, macros: macrosForGrams(base, grams), confirmed: true);
  }

  /// Lo que se guarda en el diario.
  NewDiaryEntry toEntry(MealSlot meal, {required String via}) => NewDiaryEntry(
    kind: match?.kind ?? EntryKind.food,
    refId: match?.id ?? 'ia:${name.toLowerCase()}',
    name: name,
    grams: round1(grams),
    macros: roundMacros(macros),
    meal: meal,
    rawInput: via,
  );
}

/// Similitud desde la que un nombre del modelo se toma como el alimento del catálogo.
const _catalogAccept = acceptConfidence;

/// Cruza lo que vio el modelo con el catálogo.
EstimatedItem estimateFromAi(AiFood food, ResolveContext ctx) {
  final best = ctx.matcher.search(food.name, limit: 1).firstOrNull;
  if (best != null && best.confidence >= _catalogAccept) {
    if (best.kind == EntryKind.food) {
      final item = ctx.foods[best.id];
      if (item != null) {
        return EstimatedItem(
          name: item.name,
          grams: food.grams,
          macros: macrosForGrams(item.per100g, food.grams),
          confidence: food.confidence,
          source: EstimateSource.catalog,
          match: best,
          per100g: item.per100g,
        );
      }
    } else {
      final recipe = ctx.recipes[best.id];
      if (recipe != null) {
        return EstimatedItem(
          name: recipe.name,
          grams: food.grams,
          macros: recipeAmountForGrams(recipe, food.grams).macros,
          confidence: food.confidence,
          source: EstimateSource.catalog,
          match: best,
        );
      }
    }
  }
  return EstimatedItem(
    name: _capitalize(food.name),
    grams: food.grams,
    macros: food.macros,
    // Fuera del catálogo los macros son del modelo: se tratan con más cautela.
    confidence: food.confidence,
    source: EstimateSource.model,
    per100g: food.grams > 0 ? scaleMacros(food.macros, 100 / food.grams) : null,
  );
}

/// Una línea que la lista por reglas resolvió bien (no se manda al modelo).
EstimatedItem estimateFromRules(ResolvedItem item, ResolveContext ctx) {
  final m = item.match!;
  final food = m.kind == EntryKind.food ? ctx.foods[m.id] : null;
  return EstimatedItem(name: m.name, grams: item.grams, macros: item.macros, confidence: 100, source: EstimateSource.rules, match: m, per100g: food?.per100g);
}

/// Divide el texto: lo que las reglas resuelven con seguridad y lo que hay que preguntarle al modelo.
({List<EstimatedItem> resolved, List<String> pending}) splitByRules(String text, ResolveContext ctx) {
  final resolved = <EstimatedItem>[];
  final pending = <String>[];
  for (final item in resolveText(text, ctx)) {
    if (item.status == ItemStatus.ok && item.match != null && item.grams > 0) {
      resolved.add(estimateFromRules(item, ctx));
    } else {
      pending.add(item.parsed.raw);
    }
  }
  return (resolved: resolved, pending: pending);
}

Macros totalOf(Iterable<EstimatedItem> items) => roundMacros(Macros.generate((k) => items.fold(0.0, (a, e) => a + e.macros[k])));

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
