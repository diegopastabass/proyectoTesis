import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/nutrition/models.dart';
import '../../core/nutrition/seed.dart';
import '../../core/strength/catalog.dart';
import '../../core/strength/models.dart';

/// Datos que vienen dentro de la app (assets/data), compartidos con la versión web.
class CatalogAssets {
  CatalogAssets([AssetBundle? bundle]) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<Map<String, dynamic>> _json(String path) async => jsonDecode(await _bundle.loadString(path)) as Map<String, dynamic>;

  /// Semilla de alimentos (valores aproximados, marcados como no verificados).
  Future<List<Food>> seedFoods(String createdBy) async => seedFoodsFromJson(await _json('assets/data/foods.seed.json'), createdBy);

  /// Catálogo de free-exercise-db (~870 ejercicios) con nombres en español.
  Future<List<Exercise>> exercises() async {
    final raw = await _json('assets/data/exercises.json');
    final es = await _json('assets/data/exercises_es.json');
    return buildExercises((raw['exercises'] as List).cast<Map<String, dynamic>>(), es);
  }
}
