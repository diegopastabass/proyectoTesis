import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/nutrition/open_food_facts.dart';
import '../../core/strength/catalog.dart';
import '../repositories.dart';

/// Open Food Facts (datos ODbL) e instrucciones de free-exercise-db, por HTTP.
class HttpLookupRepository implements LookupRepository {
  HttpLookupRepository([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  static const _fields = 'code,product_name,product_name_es,generic_name,brands,nutriments,serving_quantity';
  static const _timeout = Duration(seconds: 8);

  /// La API pide identificar la app; en la web se usaba X-User-Agent porque el
  /// navegador no deja cambiar User-Agent.
  static const _userAgent = 'AsistenteDeportivo/0.1 (proyecto de titulo; iOS)';

  @override
  Future<OffDraft?> lookupBarcode(String code) async {
    final uri = Uri.parse('https://world.openfoodfacts.org/api/v2/product/${Uri.encodeComponent(code)}.json?fields=$_fields');
    http.Response res;
    try {
      res = await _client.get(uri, headers: {'User-Agent': _userAgent}).timeout(_timeout);
    } on Exception {
      throw const LookupException('No se pudo contactar a Open Food Facts. Revisa tu conexión.');
    }
    // Bajo carga o al superar el límite (~15 lecturas por minuto), la API responde HTML.
    if (!(res.headers['content-type'] ?? '').contains('json')) {
      throw const LookupException('Open Food Facts no está disponible ahora. Intenta en un minuto.');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final product = data['product'];
    if (data['status'] != 1 || product is! Map<String, dynamic>) return null;
    return mapOffProduct(code, product);
  }

  @override
  Future<List<String>> exerciseInstructions(String exerciseId) async {
    final res = await _client.get(Uri.parse(exerciseSourceUrl(exerciseId))).timeout(_timeout);
    if (res.statusCode != 200) throw LookupException('Error ${res.statusCode}');
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (data['instructions'] as List? ?? const []).cast<String>();
  }
}

class LookupException implements Exception {
  const LookupException(this.message);

  final String message;

  @override
  String toString() => message;
}
