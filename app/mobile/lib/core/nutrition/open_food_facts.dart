import '../common/numbers.dart';
import 'models.dart';

/// Borrador de alimento armado desde un producto de Open Food Facts; el usuario lo revisa.
class OffDraft {
  const OffDraft({required this.barcode, required this.name, this.brand, this.per100g, this.servingGrams, required this.url});

  final String barcode;
  final String name;
  final String? brand;

  /// null cuando el producto no trae información nutricional.
  final Macros? per100g;

  /// Gramos de una porción según la etiqueta.
  final double? servingGrams;
  final String url;
}

const _kjPerKcal = 4.184;

double? _num(Object? v) {
  final n = v is String ? double.tryParse(v.replaceFirst(',', '.')) : (v is num ? v.toDouble() : null);
  return n != null && n.isFinite && n >= 0 ? n : null;
}

String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

/// Convierte la respuesta `product` de la API v2 en un borrador.
OffDraft mapOffProduct(String code, Map<String, dynamic> product) {
  final n = product['nutriments'] is Map ? product['nutriments'] as Map : const {};
  final kj = _num(n['energy-kj_100g']) ?? _num(n['energy_100g']);
  final kcal = _num(n['energy-kcal_100g']) ?? (kj != null ? kj / _kjPerKcal : null);
  final protein = _num(n['proteins_100g']);
  final carbs = _num(n['carbohydrates_100g']);
  final fat = _num(n['fat_100g']);
  final hasNutrition = [kcal, protein, carbs, fat].any((v) => v != null);

  return OffDraft(
    barcode: code,
    name: _text(product['product_name_es']) ?? _text(product['product_name']) ?? _text(product['generic_name']) ?? '',
    brand: _text(product['brands'])?.split(',').first.trim(),
    per100g: hasNutrition
        ? Macros(
            kcal: jsRound(kcal ?? 0).toDouble(),
            protein: round1(protein ?? 0),
            carbs: round1(carbs ?? 0),
            fat: round1(fat ?? 0),
            fiber: round1(_num(n['fiber_100g']) ?? 0),
          )
        : null,
    servingGrams: _num(product['serving_quantity']),
    url: 'https://world.openfoodfacts.org/product/$code',
  );
}
