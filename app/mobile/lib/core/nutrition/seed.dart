import 'models.dart';

/// Alimentos de la semilla (assets/data/foods.seed.json) listos para guardar.
List<Food> seedFoodsFromJson(Map<String, dynamic> json, String createdBy) {
  final source = FoodSource.fromMap(json['source']);
  return [
    for (final f in (json['foods'] as List).cast<Map<String, dynamic>>())
      Food(
        id: f['id'] as String,
        name: f['name'] as String,
        aliases: (f['aliases'] as List? ?? const []).cast<String>(),
        per100g: Macros.fromMap(f['per100g']),
        portions: [for (final p in (f['portions'] as List? ?? const [])) Portion.fromMap((p as Map).cast<String, dynamic>())],
        density: (f['density'] as num?)?.toDouble(),
        source: source,
        createdBy: createdBy,
      ),
  ];
}

class SeedPlan {
  const SeedPlan({required this.missing, required this.fiberPatches});

  /// Alimentos de la semilla que aún no existen en el catálogo.
  final List<Food> missing;

  /// Alimentos de la semilla creados por este usuario que aún no tienen fibra.
  final List<Food> fiberPatches;

  int get pending => missing.length + fiberPatches.length;
}

SeedPlan seedPlan(List<Food> existing, List<Food> seed, String uid) {
  final byId = {for (final f in existing) f.id: f};
  return SeedPlan(
    missing: seed.where((f) => !byId.containsKey(f.id)).toList(),
    fiberPatches: seed.where((f) {
      final current = byId[f.id];
      return current != null && current.createdBy == uid && current.fiberMissing && f.per100g.fiber > 0;
    }).toList(),
  );
}
