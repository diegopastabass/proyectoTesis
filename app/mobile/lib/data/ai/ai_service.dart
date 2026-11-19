/// Asistente de IA: comida con foto o con palabras, tabla nutricional, sesión de
/// fuerza con palabras e instrucciones de ejercicios en español.
///
/// Tres implementaciones: Gemini (con clave de API), demostración (respuestas de
/// ejemplo, sin red) y apagado (sin clave con Firebase real: las pantallas ofrecen
/// el registro manual). Las pantallas solo conocen esta interfaz.
library;

import 'dart:typed_data';

import '../../core/ai/ai_models.dart';

enum AiMode {
  /// Gemini con la clave de `env/gemini.json`.
  gemini,

  /// Respuestas de ejemplo (modo demostración sin clave, pruebas y capturas).
  demo,

  /// Sin asistente.
  off,
}

enum AiErrorKind { notConfigured, quota, network, blocked, invalidResponse, server }

class AiException implements Exception {
  const AiException(this.kind, [this.detail]);

  final AiErrorKind kind;
  final String? detail;

  /// Mensaje para el usuario.
  String get message => switch (kind) {
    AiErrorKind.notConfigured => 'El asistente no está configurado: falta la clave de la API de Gemini o no es válida.',
    AiErrorKind.quota => 'Se acabaron las consultas gratuitas al asistente por ahora (se renuevan cada día). Puedes registrar a mano.',
    AiErrorKind.network => 'No hay conexión con el asistente. Revisa tu internet o registra a mano.',
    AiErrorKind.blocked => 'El asistente no pudo procesar esta foto o texto. Prueba con otra o registra a mano.',
    AiErrorKind.invalidResponse => 'El asistente respondió algo que no pudimos leer. Prueba otra vez.',
    AiErrorKind.server => 'El asistente no está disponible en este momento. Prueba en unos minutos.',
  };

  @override
  String toString() => 'AiException(${kind.name}${detail == null ? '' : ': $detail'})';
}

abstract interface class AiService {
  AiMode get mode;

  /// Nombre del modelo, para mostrarlo en Ajustes.
  String get model;

  /// CU-07: alimentos de la foto de un plato (JPEG).
  Future<AiMeal> mealFromPhoto(Uint8List jpeg);

  /// CU-16: alimentos de lo que la lista por reglas no entendió.
  Future<AiMeal> mealFromText(String text);

  /// Tabla nutricional de la foto de un envase.
  Future<NutritionLabel> labelFromPhoto(Uint8List jpeg);

  /// CU-02: ejercicios, series, peso y repeticiones de una sesión contada.
  Future<List<AiExercise>> strengthFromText(String text);

  /// Pasos de las instrucciones de un ejercicio, en español.
  Future<List<String>> translateSteps(String exercise, List<String> steps);

  /// Explicación de la fatiga cruzada a partir de los datos del motor (`fatigueBrief`).
  Future<FatigueSummary> fatigueSummary(Map<String, dynamic> brief);
}

/// Sin asistente: cada función avisa que falta configurarlo.
class OffAiService implements AiService {
  const OffAiService();

  @override
  AiMode get mode => AiMode.off;

  @override
  String get model => '';

  Never _off() => throw const AiException(AiErrorKind.notConfigured);

  @override
  Future<AiMeal> mealFromPhoto(Uint8List jpeg) async => _off();

  @override
  Future<AiMeal> mealFromText(String text) async => _off();

  @override
  Future<NutritionLabel> labelFromPhoto(Uint8List jpeg) async => _off();

  @override
  Future<List<AiExercise>> strengthFromText(String text) async => _off();

  @override
  Future<List<String>> translateSteps(String exercise, List<String> steps) async => _off();

  @override
  Future<FatigueSummary> fatigueSummary(Map<String, dynamic> brief) async => _off();
}
