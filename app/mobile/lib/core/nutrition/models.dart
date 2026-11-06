/// Modelo del módulo de nutrición. Mismos campos que los documentos de Firestore
/// de la versión web, para que ambas apps compartan los datos.
library;

enum MacroKey { kcal, protein, carbs, fat, fiber }

class Macros {
  const Macros({this.kcal = 0, this.protein = 0, this.carbs = 0, this.fat = 0, this.fiber = 0});

  /// Construye cada macro con `f`.
  factory Macros.generate(double Function(MacroKey k) f) =>
      Macros(kcal: f(MacroKey.kcal), protein: f(MacroKey.protein), carbs: f(MacroKey.carbs), fat: f(MacroKey.fat), fiber: f(MacroKey.fiber));

  /// Completa con ceros los datos guardados antes de existir la fibra (o parciales).
  factory Macros.fromMap(Object? data) {
    final m = data is Map ? data : const {};
    double v(String k) => (m[k] as num?)?.toDouble() ?? 0;
    return Macros(kcal: v('kcal'), protein: v('protein'), carbs: v('carbs'), fat: v('fat'), fiber: v('fiber'));
  }

  static const zero = Macros();

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  double operator [](MacroKey k) => switch (k) {
        MacroKey.kcal => kcal,
        MacroKey.protein => protein,
        MacroKey.carbs => carbs,
        MacroKey.fat => fat,
        MacroKey.fiber => fiber,
      };

  Map<String, double> toMap() => {for (final k in MacroKey.values) k.name: this[k]};

  @override
  bool operator ==(Object other) => other is Macros && MacroKey.values.every((k) => other[k] == this[k]);

  @override
  int get hashCode => Object.hashAll(MacroKey.values.map((k) => this[k]));

  @override
  String toString() => 'Macros(${toMap()})';
}

class Portion {
  const Portion({required this.name, required this.grams});

  factory Portion.fromMap(Map<String, dynamic> m) =>
      Portion(name: m['name'] as String? ?? '', grams: (m['grams'] as num?)?.toDouble() ?? 0);

  /// Nombre de la porción: "unidad", "mediano", "taza", "rebanada"...
  final String name;
  final double grams;

  Map<String, dynamic> toMap() => {'name': name, 'grams': grams};
}

enum FoodSourceType { usda, off, chileTable, user, manual }

const _sourceCodes = {
  FoodSourceType.usda: 'USDA',
  FoodSourceType.off: 'OFF',
  FoodSourceType.chileTable: 'CHILE_TABLE',
  FoodSourceType.user: 'USER',
  FoodSourceType.manual: 'MANUAL',
};

class FoodSource {
  const FoodSource({required this.type, this.ref, this.license});

  factory FoodSource.fromMap(Object? data) {
    if (data is! Map) return userSource;
    final code = data['type'] as String?;
    final type = _sourceCodes.entries.where((e) => e.value == code).map((e) => e.key).firstOrNull ?? FoodSourceType.user;
    return FoodSource(type: type, ref: data['ref'] as String?, license: data['license'] as String?);
  }

  static const userSource = FoodSource(type: FoodSourceType.user);

  final FoodSourceType type;
  final String? ref;
  final String? license;

  Map<String, dynamic> toMap() => {'type': _sourceCodes[type], 'ref': ref, 'license': license};
}

class Food {
  const Food({
    required this.id,
    required this.name,
    this.aliases = const [],
    this.brand,
    this.barcode,
    required this.per100g,
    this.portions = const [],
    this.density,
    this.source = FoodSource.userSource,
    this.verified = false,
    required this.createdBy,
    this.fiberMissing = false,
  });

  final String id;
  final String name;
  final List<String> aliases;
  final String? brand;

  /// GTIN normalizado (ver core/nutrition/barcode).
  final String? barcode;
  final Macros per100g;
  final List<Portion> portions;

  /// Gramos por mililitro, para convertir ml → g. Por defecto 1.
  final double? density;
  final FoodSource source;
  final bool verified;
  final String createdBy;

  /// true si el documento guardado aún no tiene el campo de fibra (datos anteriores).
  final bool fiberMissing;

  Food copyWith({String? id, FoodInput? input, bool? fiberMissing}) => Food(
        id: id ?? this.id,
        name: input?.name ?? name,
        aliases: input?.aliases ?? aliases,
        brand: input != null ? input.brand : brand,
        barcode: input != null ? input.barcode : barcode,
        per100g: input?.per100g ?? per100g,
        portions: input?.portions ?? portions,
        density: input != null ? input.density : density,
        source: source,
        verified: verified,
        createdBy: createdBy,
        fiberMissing: fiberMissing ?? this.fiberMissing,
      );
}

/// Campos que el usuario edita en el formulario de alimento.
class FoodInput {
  const FoodInput({
    required this.name,
    this.aliases = const [],
    this.brand,
    this.barcode,
    required this.per100g,
    this.portions = const [],
    this.density,
  });

  final String name;
  final List<String> aliases;
  final String? brand;
  final String? barcode;
  final Macros per100g;
  final List<Portion> portions;
  final double? density;

  Map<String, dynamic> toMap() => {
        'name': name,
        'aliases': aliases,
        'brand': brand,
        'barcode': barcode,
        'per100g': per100g.toMap(),
        'portions': portions.map((p) => p.toMap()).toList(),
        'density': density,
      };
}

class RecipeIngredient {
  const RecipeIngredient({required this.foodId, required this.grams});

  factory RecipeIngredient.fromMap(Map<String, dynamic> m) =>
      RecipeIngredient(foodId: m['foodId'] as String? ?? '', grams: (m['grams'] as num?)?.toDouble() ?? 0);

  final String foodId;
  final double grams;

  Map<String, dynamic> toMap() => {'foodId': foodId, 'grams': grams};
}

class Recipe {
  const Recipe({
    required this.id,
    required this.ownerId,
    required this.name,
    this.aliases = const [],
    required this.servings,
    required this.ingredients,
    required this.totalGrams,
    required this.totals,
    required this.perServing,
  });

  final String id;
  final String ownerId;
  final String name;
  final List<String> aliases;
  final double servings;
  final List<RecipeIngredient> ingredients;
  final double totalGrams;
  final Macros totals;
  final Macros perServing;

  Recipe copyWith({String? id, double? totalGrams, Macros? totals, Macros? perServing}) => Recipe(
        id: id ?? this.id,
        ownerId: ownerId,
        name: name,
        aliases: aliases,
        servings: servings,
        ingredients: ingredients,
        totalGrams: totalGrams ?? this.totalGrams,
        totals: totals ?? this.totals,
        perServing: perServing ?? this.perServing,
      );

  /// Campos guardados (sin id).
  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'name': name,
        'aliases': aliases,
        'servings': servings,
        'ingredients': ingredients.map((i) => i.toMap()).toList(),
        'totalGrams': totalGrams,
        'totals': totals.toMap(),
        'perServing': perServing.toMap(),
      };
}

class Range {
  const Range(this.min, this.max);

  factory Range.fromMap(Object? data, Range fallback) {
    if (data is! Map) return fallback;
    return Range((data['min'] as num?)?.toDouble() ?? fallback.min, (data['max'] as num?)?.toDouble() ?? fallback.max);
  }

  final double min;
  final double max;

  Map<String, double> toMap() => {'min': min, 'max': max};

  @override
  bool operator ==(Object other) => other is Range && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);
}

class Goals {
  const Goals({required this.ranges, required this.weights});

  final Map<MacroKey, Range> ranges;

  /// Pesos relativos; se normalizan al calcular el puntaje.
  final Map<MacroKey, double> weights;

  Range range(MacroKey k) => ranges[k]!;

  Map<String, dynamic> toMap() => {
        'ranges': {for (final k in MacroKey.values) k.name: range(k).toMap()},
        'weights': {for (final k in MacroKey.values) k.name: weights[k]},
      };
}

enum MealSlot { desayuno, almuerzo, once, cena, snack }

enum EntryKind { food, recipe }

class NewDiaryEntry {
  const NewDiaryEntry({
    required this.kind,
    required this.refId,
    required this.name,
    required this.grams,
    this.servings,
    required this.macros,
    required this.meal,
    this.rawInput,
  });

  final EntryKind kind;
  final String refId;
  final String name;
  final double grams;
  final double? servings;
  final Macros macros;
  final MealSlot meal;
  final String? rawInput;

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'refId': refId,
        'name': name,
        'grams': grams,
        'servings': servings,
        'macros': macros.toMap(),
        'meal': meal.name,
        'rawInput': rawInput,
      };
}

class DiaryEntry extends NewDiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.createdAt,
    required super.kind,
    required super.refId,
    required super.name,
    required super.grams,
    super.servings,
    required super.macros,
    required super.meal,
    super.rawInput,
  });

  final String id;

  /// Milisegundos desde epoch.
  final int createdAt;
}
