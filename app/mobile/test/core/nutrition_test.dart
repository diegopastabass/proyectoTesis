// Port de las pruebas de src/core/__tests__ de la versión web: la lógica de
// Dart debe dar los mismos resultados que la de TypeScript.
import 'dart:convert';
import 'dart:io';

import 'package:asistente_deportivo/core/nutrition/barcode.dart';
import 'package:asistente_deportivo/core/nutrition/macros.dart';
import 'package:asistente_deportivo/core/nutrition/matcher.dart';
import 'package:asistente_deportivo/core/nutrition/models.dart';
import 'package:asistente_deportivo/core/nutrition/open_food_facts.dart';
import 'package:asistente_deportivo/core/nutrition/recipe.dart';
import 'package:asistente_deportivo/core/nutrition/resolve.dart';
import 'package:asistente_deportivo/core/nutrition/rule_parser.dart';
import 'package:asistente_deportivo/core/nutrition/score.dart';
import 'package:asistente_deportivo/core/nutrition/seed.dart';
import 'package:asistente_deportivo/core/nutrition/units.dart';
import 'package:flutter_test/flutter_test.dart';

final foods = seedFoodsFromJson(jsonDecode(File('assets/data/foods.seed.json').readAsStringSync()) as Map<String, dynamic>, 'test');
final foodsById = {for (final f in foods) f.id: f};

Recipe makeRecipe() {
  const ingredients = [
    RecipeIngredient(foodId: 'pechuga-pollo-cocida', grams: 400),
    RecipeIngredient(foodId: 'arroz-blanco-cocido', grams: 400),
    RecipeIngredient(foodId: 'aceite-oliva', grams: 20),
  ];
  final t = computeRecipe(ingredients, 4, foodsById);
  return Recipe(
    id: 'r1',
    ownerId: 'test',
    name: 'Pollo al limón con arroz',
    aliases: const ['pollo al limon'],
    servings: 4,
    ingredients: ingredients,
    totalGrams: t.totalGrams,
    totals: t.totals,
    perServing: t.perServing,
  );
}

ResolveContext context([List<Recipe> recipes = const []]) => ResolveContext.build(foods, recipes);

void main() {
  group('splitItems', () {
    test('separa por líneas, punto y coma y comas no decimales', () {
      expect(splitItems('Arroz 100g\n1 Tomate mediano; Huevos x3, Atún 150g'), ['Arroz 100g', '1 Tomate mediano', 'Huevos x3', 'Atún 150g']);
    });

    test('no corta la coma decimal y quita viñetas', () {
      expect(splitItems('- pollo 1,5 kg\n2) palta\n• avena'), ['pollo 1,5 kg', 'palta', 'avena']);
    });
  });

  group('parseLine', () {
    final cases = <String, (String, double?, Unit?, PortionSize?)>{
      'Arroz 100g': ('arroz', 100, Unit.g, null),
      '1 Tomate mediano': ('tomate', 1, null, PortionSize.mediano),
      'Huevos x3': ('huevos', 3, null, null),
      '3x huevos': ('huevos', 3, null, null),
      'Atún 150g': ('atun', 150, Unit.g, null),
      '2 tazas de leche': ('leche', 2, Unit.taza, null),
      '200ml de leche': ('leche', 200, Unit.ml, null),
      'pollo 1,5 kg': ('pollo', 1500, Unit.g, null),
      'medio plátano': ('platano', 0.5, null, null),
      '1/2 palta': ('palta', 0.5, null, null),
      '1 1/2 taza de avena': ('avena', 1.5, Unit.taza, null),
      '3 rebanadas de pan de molde': ('pan de molde', 3, Unit.rebanada, null),
      'Pollo al limón 2 porciones': ('pollo al limon', 2, Unit.porcion, null),
      'un huevo': ('huevo', 1, null, null),
      'torta tres leches': ('torta tres leches', null, null, null),
      'un poco de aceite': ('aceite', null, null, null),
      'arroz 150': ('arroz', 150, Unit.g, null),
      'café': ('cafe', null, null, null),
      'taza de leche': ('leche', 1, Unit.taza, null),
      'un par de huevos': ('huevos', 2, null, null),
      '2 cdas de mantequilla de maní': ('mantequilla de mani', 2, Unit.cda, null),
      '1 scoop proteína': ('proteina', 1, Unit.scoop, null),
    };
    cases.forEach((raw, expected) {
      test(raw, () {
        final p = parseLine(raw)!;
        expect((p.query, p.quantity, p.unit, p.size), expected);
      });
    });

    test('devuelve null si solo hay cantidad', () => expect(parseLine('100 g'), isNull));
  });

  test('parseText procesa la lista de ejemplo de la tesis', () {
    expect(parseText('Arroz 100g\n1 Tomate mediano\nHuevos x3\nAtún 150g').map((i) => i.query), ['arroz', 'tomate', 'huevos', 'atun']);
  });

  group('macros', () {
    const oats = Macros(kcal: 379, protein: 13.2, carbs: 67.7, fat: 6.5, fiber: 10.1);

    test('completa con 0 los datos guardados antes de existir la fibra', () {
      expect(Macros.fromMap({'kcal': 100, 'protein': 5, 'carbs': 10, 'fat': 2}), const Macros(kcal: 100, protein: 5, carbs: 10, fat: 2));
      expect(Macros.fromMap(null), Macros.zero);
    });

    test('escala la fibra con los gramos y redondea a 1 decimal', () {
      expect(macrosForGrams(oats, 40), const Macros(kcal: 152, protein: 5.3, carbs: 27.1, fat: 2.6, fiber: 4));
    });

    test('suma la fibra de varios alimentos', () {
      expect(sumMacros([oats, const Macros(fiber: 2.5)]).fiber, closeTo(12.6, 1e-5));
    });

    test('estimateKcal usa los factores de Atwater', () => expect(estimateKcal(10, 20, 5), 165));
  });

  group('puntaje', () {
    const range = Range(100, 200);

    test('da 100 dentro del rango, incluidos los bordes', () {
      expect([macroScore(100, range), macroScore(150, range), macroScore(200, range)], [100, 100, 100]);
    });

    test('cae linealmente fuera del rango', () {
      expect([macroScore(90, range), macroScore(300, range), macroScore(0, range), macroScore(500, range)], [90, 50, 0, 0]);
    });

    test('tolera rangos con mínimo o máximo cero', () {
      expect(macroScore(0, const Range(0, 50)), 100);
      expect(macroScore(10, const Range(0, 0)), 0);
    });

    test('pondera con pesos normalizados', () {
      final w = normalizedWeights({MacroKey.kcal: 2, MacroKey.protein: 1, MacroKey.carbs: 1, MacroKey.fat: 0, MacroKey.fiber: 0});
      expect(w, {MacroKey.kcal: 0.5, MacroKey.protein: 0.25, MacroKey.carbs: 0.25, MacroKey.fat: 0, MacroKey.fiber: 0});
    });

    test('reparte en partes iguales si todos los pesos son cero', () {
      expect(normalizedWeights({for (final k in MacroKey.values) k: 0})[MacroKey.kcal], 0.2);
    });

    test('da 100 con todo dentro del rango y menos con desvíos', () {
      const inside = Macros(kcal: 2400, protein: 140, carbs: 250, fat: 70, fiber: 30);
      expect(dailyScore(inside, defaultGoals).total, 100);
      final s = dailyScore(const Macros(kcal: 2400, protein: 60, carbs: 250, fat: 70, fiber: 30), defaultGoals);
      expect(s.perMacro[MacroKey.protein], 50);
      expect(s.total, (100 - (25 / 110) * 50).round());
    });

    test('la fibra baja el puntaje cuando queda fuera de su rango', () {
      final s = dailyScore(const Macros(kcal: 2400, protein: 140, carbs: 250, fat: 70, fiber: 0), defaultGoals);
      expect(s.perMacro[MacroKey.fiber], 0);
      expect(s.total, (100 - (10 / 110) * 100).round());
    });
  });

  group('fibra en recetas', () {
    test('se calcula por cantidad igual que el resto de los macros', () {
      expect(resolveText('avena 50g', context()).first.macros.fiber, closeTo(5.1, 0.05));
    });

    test('las recetas suman la fibra de sus ingredientes', () {
      final t = computeRecipe(const [RecipeIngredient(foodId: 'avena-hojuelas', grams: 100), RecipeIngredient(foodId: 'platano', grams: 100)], 2, foodsById);
      expect(t.totals.fiber, closeTo(12.7, 0.05));
      expect(t.perServing.fiber, closeTo(6.4, 0.05));
    });

    test('conserva lo guardado si falta un ingrediente en el catálogo', () {
      final old = makeRecipe();
      final r = Recipe(
        id: old.id,
        ownerId: old.ownerId,
        name: old.name,
        servings: old.servings,
        ingredients: const [RecipeIngredient(foodId: 'no-existe', grams: 100)],
        totalGrams: old.totalGrams,
        totals: old.totals,
        perServing: old.perServing,
      );
      expect(identical(refreshRecipe(r, foodsById), r), isTrue);
    });
  });

  group('phraseSimilarity', () {
    test('es 1 para frases iguales y menor para frases parciales', () {
      expect(phraseSimilarity('arroz', 'arroz'), 1);
      expect(phraseSimilarity('pan', 'pan marraqueta'), closeTo(0.667, 0.005));
      expect(phraseSimilarity('arros', 'arroz'), greaterThanOrEqualTo(0.8));
      expect(phraseSimilarity('sushi', 'arroz'), 0);
    });
  });

  group('Matcher', () {
    final m = context().matcher;

    test('encuentra por alias exacto y por plural', () {
      for (final (q, id) in [('arroz', 'arroz-blanco-cocido'), ('huevos', 'huevo-entero'), ('tomates', 'tomate')]) {
        final best = m.search(q).first;
        expect((best.id, best.confidence), (id, 1.0), reason: q);
      }
    });

    test('tolera errores de tipeo', () {
      expect(m.search('platno').first.id, 'platano');
      expect(m.search('marraquta').first.id, 'pan-marraqueta');
    });

    test('no inventa coincidencias para alimentos ausentes', () {
      final best = m.search('sushi').firstOrNull;
      expect(best == null || best.confidence < 0.6, isTrue);
    });
  });

  group('resolveText', () {
    test('resuelve la lista de ejemplo con gramos y macros', () {
      final items = resolveText('Arroz 100g\n1 Tomate mediano\nHuevos x3\nAtún 150g', context());
      expect(items.map((i) => (i.match?.id, i.grams, i.status)), [
        ('arroz-blanco-cocido', 100, ItemStatus.ok),
        ('tomate', 123, ItemStatus.ok),
        ('huevo-entero', 150, ItemStatus.ok),
        ('atun-lata-agua', 150, ItemStatus.ok),
      ]);
      expect(items[0].macros, const Macros(kcal: 130, protein: 2.7, carbs: 28.2, fat: 0.3, fiber: 0.4));
      expect(items[2].macros.protein, closeTo(18.9, 0.05));
    });

    test('marca como faltante lo que no está en el catálogo', () {
      final item = resolveText('sushi 200g', context()).first;
      expect(item.status, ItemStatus.missing);
      expect(item.match, isNull);
    });

    test('pide revisión cuando la cantidad se supone', () {
      final item = resolveText('un poco de aceite', context()).first;
      expect(item.match?.id, 'aceite-oliva');
      expect(item.status, ItemStatus.review);
      expect(item.assumed, isTrue);
    });

    test('usa porciones genéricas si el alimento no las define', () {
      expect(resolveText('2 tazas de lentejas', context()).first.grams, 396);
      expect(resolveText('1 vaso de cerveza', context()).first.grams, 300);
    });

    test('reconoce recetas por nombre y calcula por porción o por peso', () {
      final recipe = makeRecipe();
      final ctx = context([recipe]);
      final byServing = resolveText('pollo al limón 2 porciones', ctx).first;
      expect((byServing.match?.kind, byServing.match?.id), (EntryKind.recipe, 'r1'));
      expect(byServing.servings, 2);
      expect(byServing.macros.kcal, (recipe.perServing.kcal * 2).round());
      expect(resolveText('pollo al limon 205g', ctx).first.servings, 1);
    });

    test('recalcula al corregir gramos', () {
      final ctx = context();
      final edited = withGrams(resolveText('arroz', ctx).first, 200, ctx);
      expect(edited.macros.kcal, 260);
      expect(edited.status, ItemStatus.ok);
    });
  });

  group('códigos de barras', () {
    test('deja solo dígitos y completa UPC-A a 13', () {
      expect(normalizeBarcode(' 8410109 109832 '), '8410109109832');
      expect(normalizeBarcode('078742040370'), '0078742040370');
      expect(normalizeBarcode('20224042'), '20224042');
    });

    test('acepta EAN-13, UPC-A y EAN-8 con dígito verificador correcto', () {
      for (final code in ['8410109109832', '0078742040370', '078742040370', '20224042']) {
        expect(isValidGtin(code), isTrue, reason: code);
      }
    });

    test('rechaza dígito verificador incorrecto o largos inválidos', () {
      for (final code in ['8410109109833', '12345', 'abc']) {
        expect(isValidGtin(code), isFalse, reason: code);
      }
    });
  });

  group('Open Food Facts', () {
    test('toma kcal, macros y porción por 100 g', () {
      final d = mapOffProduct('8410109109832', {
        'product_name': '85% Cacao',
        'brands': 'Valor, Chocolates Valor',
        'serving_quantity': 20,
        'nutriments': {'energy-kcal_100g': 568, 'proteins_100g': 11, 'carbohydrates_100g': 19, 'fat_100g': 49, 'fiber_100g': '13,5'},
      });
      expect((d.name, d.brand, d.servingGrams), ('85% Cacao', 'Valor', 20));
      expect(d.per100g, const Macros(kcal: 568, protein: 11, carbs: 19, fat: 49, fiber: 13.5));
    });

    test('prefiere el nombre en español y convierte kJ a kcal', () {
      final d = mapOffProduct('1', {
        'product_name': 'Milk',
        'product_name_es': 'Leche',
        'nutriments': {'energy-kj_100g': 209.2},
      });
      expect(d.name, 'Leche');
      expect(d.per100g?.kcal, 50);
    });

    test('deja per100g en null si no hay información nutricional', () {
      expect(mapOffProduct('1', {'product_name': 'Agua'}).per100g, isNull);
    });
  });
}
