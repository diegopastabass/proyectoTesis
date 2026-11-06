import '../common/numbers.dart';
import 'models.dart';

Macros roundMacros(Macros m) =>
    Macros.generate((k) => k == MacroKey.kcal ? jsRound(m[k]).toDouble() : round1(m[k]));

Macros scaleMacros(Macros m, double factor) => Macros.generate((k) => m[k] * factor);

/// Macros de `grams` gramos de un alimento con valores por 100 g.
Macros macrosForGrams(Macros per100g, double grams) => roundMacros(scaleMacros(per100g, grams / 100));

Macros sumMacros(Iterable<Macros> list) {
  final totals = {for (final k in MacroKey.values) k: 0.0};
  for (final m in list) {
    for (final k in MacroKey.values) {
      totals[k] = totals[k]! + m[k];
    }
  }
  return Macros.generate((k) => totals[k]!);
}

/// Estimación de Atwater: 4 kcal/g proteína y carbohidratos, 9 kcal/g grasa.
int estimateKcal(double protein, double carbs, double fat) => jsRound(protein * 4 + carbs * 4 + fat * 9);
