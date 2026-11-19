/// Respuestas del asistente de IA (Gemini) ya ordenadas, sin depender de Flutter
/// ni de la API. El modelo responde JSON con un esquema fijo (`prompts.dart`) y
/// aquí se lee de forma tolerante: un campo raro o faltante no rompe la pantalla.
library;

import '../nutrition/models.dart';

double? _num(Object? v) {
  final n = v is num ? v.toDouble() : (v is String ? double.tryParse(v.replaceFirst(',', '.')) : null);
  return n != null && n.isFinite && n >= 0 ? n : null;
}

String _text(Object? v) => v is String ? v.trim() : '';

List<Map<String, dynamic>> _list(Object? v) => [
  for (final e in v is List ? v : const [])
    if (e is Map) e.cast<String, dynamic>(),
];

/// Confianza 0–100 (el modelo a veces responde 0–1).
double _confidence(Object? v) {
  final n = _num(v) ?? 0;
  return (n <= 1 ? n * 100 : n).clamp(0, 100).toDouble();
}

/// Bajo esta confianza el usuario debe revisar el alimento antes de guardar
/// (requisito del módulo de nutrición: validación manual bajo 70 %).
const minAiConfidence = 70.0;

/// Un alimento que el asistente vio en la foto o leyó en el texto.
class AiFood {
  const AiFood({required this.name, required this.grams, required this.confidence, required this.macros});

  factory AiFood.fromJson(Map<String, dynamic> j) => AiFood(
    name: _text(j['nombre']),
    grams: _num(j['gramos']) ?? 0,
    confidence: _confidence(j['confianza']),
    macros: Macros(
      kcal: _num(j['kcal']) ?? 0,
      protein: _num(j['proteina']) ?? 0,
      carbs: _num(j['carbohidratos']) ?? 0,
      fat: _num(j['grasa']) ?? 0,
      fiber: _num(j['fibra']) ?? 0,
    ),
  );

  /// Nombre en español de Chile ("arroz blanco cocido").
  final String name;
  final double grams;

  /// 0–100.
  final double confidence;

  /// Lo que estima el modelo para esos gramos (se usa solo si el alimento no está en el catálogo).
  final Macros macros;
}

class AiMeal {
  const AiMeal({required this.items, this.note});

  factory AiMeal.fromJson(Map<String, dynamic> j) => AiMeal(
    items: [for (final f in _list(j['alimentos'])) AiFood.fromJson(f)]..removeWhere((f) => f.name.isEmpty || f.grams <= 0),
    note: switch (_text(j['nota'])) {
      '' => null,
      final s => s,
    },
  );

  final List<AiFood> items;

  /// Aviso del modelo ("la foto no muestra comida", "no se ve la porción completa").
  final String? note;
}

/// Lo que dice la tabla nutricional de un envase.
class NutritionLabel {
  const NutritionLabel({this.name, this.brand, this.servingGrams, this.per100g});

  factory NutritionLabel.fromJson(Map<String, dynamic> j) {
    Macros? read(Object? m) {
      if (m is! Map) return null;
      final kcal = _num(m['kcal']);
      if (kcal == null) return null;
      return Macros(
        kcal: kcal,
        protein: _num(m['proteina']) ?? 0,
        carbs: _num(m['carbohidratos']) ?? 0,
        fat: _num(m['grasa']) ?? 0,
        fiber: _num(m['fibra']) ?? 0,
      );
    }

    final serving = _num(j['gramosPorcion']);
    var per100 = read(j['por100g']);
    final perServing = read(j['porPorcion']);
    // Si la etiqueta solo trae la porción, se lleva a 100 g.
    if (per100 == null && perServing != null && serving != null && serving > 0) {
      per100 = Macros.generate((k) => perServing[k] * 100 / serving);
    }
    return NutritionLabel(
      name: switch (_text(j['nombre'])) {
        '' => null,
        final s => s,
      },
      brand: switch (_text(j['marca'])) {
        '' => null,
        final s => s,
      },
      servingGrams: serving != null && serving > 0 ? serving : null,
      per100g: per100,
    );
  }

  final String? name;
  final String? brand;
  final double? servingGrams;

  /// null si no se pudo leer la tabla.
  final Macros? per100g;

  bool get readable => per100g != null;
}

/// Una serie contada con palabras.
class AiSet {
  const AiSet({required this.reps, this.weight, this.warmup = false});

  factory AiSet.fromJson(Map<String, dynamic> j) => AiSet(reps: _num(j['repeticiones']) ?? 0, weight: _num(j['peso']), warmup: j['calentamiento'] == true);

  final double reps;

  /// En la unidad del ejercicio (kg o lb); null = sin peso (peso corporal).
  final double? weight;
  final bool warmup;
}

/// Un ejercicio contado con palabras ("sentadilla 4x8 con 80").
class AiExercise {
  const AiExercise({required this.written, required this.name, required this.nameEn, required this.sets, this.pounds = false});

  factory AiExercise.fromJson(Map<String, dynamic> j) => AiExercise(
    written: _text(j['escrito']),
    name: _text(j['nombre']),
    nameEn: _text(j['nombreIngles']),
    sets: [for (final s in _list(j['series'])) AiSet.fromJson(s)]..removeWhere((s) => s.reps <= 0),
    pounds: _text(j['unidad']).toLowerCase() == 'lb',
  );

  /// Como lo escribió el usuario.
  final String written;

  /// Nombre en español.
  final String name;

  /// Nombre habitual en inglés (el catálogo viene de free-exercise-db, en inglés).
  final String nameEn;
  final List<AiSet> sets;
  final bool pounds;
}

List<AiExercise> parseStrength(Map<String, dynamic> j) =>
    [for (final e in _list(j['ejercicios'])) AiExercise.fromJson(e)]..removeWhere((e) => e.sets.isEmpty || (e.name.isEmpty && e.nameEn.isEmpty));

/// Pasos traducidos, en el mismo orden.
List<String> parseSteps(Map<String, dynamic> j) => [
  for (final s in j['pasos'] as List? ?? const [])
    if (s is String && s.trim().isNotEmpty) s.trim(),
];

/// Explicación de la fatiga cruzada escrita por el asistente a partir de las
/// cifras del motor (no calcula nada por su cuenta).
class FatigueSummary {
  const FatigueSummary({required this.headline, required this.summary, this.points = const [], this.suggestion});

  factory FatigueSummary.fromJson(Map<String, dynamic> j) => FatigueSummary(
        headline: _text(j['titular']),
        summary: _text(j['resumen']),
        points: [for (final p in j['claves'] as List? ?? const []) if (p is String && p.trim().isNotEmpty) p.trim()].take(3).toList(),
        suggestion: switch (_text(j['sugerencia'])) { '' => null, final s => s },
      );

  final String headline;
  final String summary;

  /// Hasta tres puntos clave.
  final List<String> points;
  final String? suggestion;

  bool get isEmpty => headline.isEmpty && summary.isEmpty;

  Map<String, dynamic> toJson() => {'titular': headline, 'resumen': summary, 'claves': points, 'sugerencia': ?suggestion};
}
