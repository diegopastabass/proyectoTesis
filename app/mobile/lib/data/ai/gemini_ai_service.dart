/// Asistente con la API de Gemini (Google AI Studio), por HTTP.
///
/// `POST https://generativelanguage.googleapis.com/v1beta/models/{modelo}:generateContent`
/// con salida estructurada (`responseMimeType: application/json` y
/// `responseJsonSchema`). La clave viene de `env/gemini.json` (no se versiona).
///
/// En el prototipo la clave queda dentro de la app, como cualquier valor de
/// `--dart-define`: sirve para pruebas personales. Para entregarla a otras
/// personas, la llamada debe pasar por Firebase AI Logic o por el backend del MVP
/// (la tesis pide que la clave viva solo en el servidor); esta clase es la única
/// pieza que cambia. Se envía el identificador de la app de iOS para poder
/// restringir la clave a esta app en la consola de Google Cloud.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/ai/ai_models.dart';
import '../../core/ai/prompts.dart';
import 'ai_service.dart';

/// Flash-Lite estable más reciente (noviembre de 2026). Se cambia con GEMINI_MODEL.
const defaultGeminiModel = 'gemini-3.5-flash-lite';

class GeminiAiService implements AiService {
  GeminiAiService({required this.apiKey, this.model = defaultGeminiModel, this.bundleId, http.Client? client, this.timeout = const Duration(seconds: 40)})
    : _client = client ?? http.Client();

  final String apiKey;
  @override
  final String model;

  /// Identificador de la app de iOS (encabezado X-Ios-Bundle-Identifier).
  final String? bundleId;
  final http.Client _client;
  final Duration timeout;

  /// Si el modelo no acepta el nivel de razonamiento, se deja de enviar.
  bool _thinking = true;

  @override
  AiMode get mode => AiMode.gemini;

  Uri get _uri => Uri.https('generativelanguage.googleapis.com', '/v1beta/models/$model:generateContent');

  /// Cuerpo de la solicitud (público para las pruebas).
  @visibleForTesting
  Map<String, dynamic> body(AiTask task, {Uint8List? jpeg}) => {
    'systemInstruction': {
      'parts': [
        {'text': task.system},
      ],
    },
    'contents': [
      {
        'role': 'user',
        'parts': [
          if (jpeg != null)
            {
              'inlineData': {'mimeType': 'image/jpeg', 'data': base64Encode(jpeg)},
            },
          {'text': task.prompt},
        ],
      },
    ],
    'generationConfig': {
      'responseMimeType': 'application/json',
      'responseJsonSchema': task.schema,
      // Son tareas de extracción: con razonamiento mínimo responde más rápido y gasta menos.
      if (_thinking) 'thinkingConfig': {'thinkingLevel': 'MINIMAL'},
    },
  };

  Future<Map<String, dynamic>> _run(AiTask task, {Uint8List? jpeg}) async {
    if (apiKey.isEmpty) throw const AiException(AiErrorKind.notConfigured);
    http.Response res;
    try {
      res = await _client
          .post(
            _uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
              if (bundleId != null && bundleId!.isNotEmpty) 'X-Ios-Bundle-Identifier': bundleId!,
            },
            body: jsonEncode(body(task, jpeg: jpeg)),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AiException(AiErrorKind.network, 'tiempo de espera');
    } on SocketException catch (e) {
      throw AiException(AiErrorKind.network, e.message);
    } on http.ClientException catch (e) {
      throw AiException(AiErrorKind.network, e.message);
    }

    if (res.statusCode != 200) {
      final message = _errorMessage(res.body);
      // Algunos modelos no aceptan el nivel de razonamiento: se reintenta sin él.
      if (res.statusCode == 400 && _thinking && message.toLowerCase().contains('think')) {
        _thinking = false;
        return _run(task, jpeg: jpeg);
      }
      throw AiException(switch (res.statusCode) {
        400 when message.toLowerCase().contains('api key') => AiErrorKind.notConfigured,
        401 || 403 => AiErrorKind.notConfigured,
        429 => AiErrorKind.quota,
        >= 500 => AiErrorKind.server,
        _ => AiErrorKind.invalidResponse,
      }, '${res.statusCode}: $message');
    }
    return parseResponse(res.body);
  }

  static String _errorMessage(String body) {
    try {
      final j = jsonDecode(body);
      final error = (j is Map) ? j['error'] : null;
      final message = (error is Map) ? error['message'] : null;
      return message is String ? message : body;
    } on FormatException {
      return body;
    }
  }

  /// Saca el JSON de la respuesta (`candidates[0].content.parts[*].text`).
  @visibleForTesting
  static Map<String, dynamic> parseResponse(String body) {
    final Object? j;
    try {
      j = jsonDecode(body);
    } on FormatException {
      throw const AiException(AiErrorKind.invalidResponse, 'respuesta no es JSON');
    }
    if (j is! Map) throw const AiException(AiErrorKind.invalidResponse);
    final blocked = (j['promptFeedback'] as Map?)?['blockReason'];
    if (blocked != null) throw AiException(AiErrorKind.blocked, '$blocked');
    final candidate = (j['candidates'] as List?)?.firstOrNull;
    if (candidate is! Map) throw const AiException(AiErrorKind.invalidResponse, 'sin candidatos');
    final reason = candidate['finishReason'];
    if (reason == 'SAFETY' || reason == 'PROHIBITED_CONTENT' || reason == 'IMAGE_SAFETY') throw AiException(AiErrorKind.blocked, '$reason');
    final parts = (candidate['content'] as Map?)?['parts'] as List? ?? const [];
    // Las partes de "pensamiento" (thought: true) no son la respuesta.
    final text = parts.whereType<Map>().where((p) => p['thought'] != true).map((p) => p['text']).whereType<String>().join();
    try {
      final data = jsonDecode(text);
      if (data is Map<String, dynamic>) return data;
    } on FormatException {
      // Respuesta cortada (MAX_TOKENS) o texto libre.
    }
    throw AiException(AiErrorKind.invalidResponse, 'texto: ${text.length > 120 ? text.substring(0, 120) : text}');
  }

  @override
  Future<AiMeal> mealFromPhoto(Uint8List jpeg) async => AiMeal.fromJson(await _run(mealFromPhotoTask(), jpeg: jpeg));

  @override
  Future<AiMeal> mealFromText(String text) async => AiMeal.fromJson(await _run(mealFromTextTask(text)));

  @override
  Future<NutritionLabel> labelFromPhoto(Uint8List jpeg) async => NutritionLabel.fromJson(await _run(labelTask(), jpeg: jpeg));

  @override
  Future<List<AiExercise>> strengthFromText(String text) async => parseStrength(await _run(strengthTask(text)));

  @override
  Future<FatigueSummary> fatigueSummary(Map<String, dynamic> brief) async {
    final out = FatigueSummary.fromJson(await _run(fatigueSummaryTask(jsonEncode(brief))));
    if (out.isEmpty) throw const AiException(AiErrorKind.invalidResponse, 'resumen vacío');
    return out;
  }

  @override
  Future<List<String>> translateSteps(String exercise, List<String> steps) async {
    if (steps.isEmpty) return const [];
    final out = parseSteps(await _run(translateStepsTask(exercise, steps)));
    if (out.isEmpty) throw const AiException(AiErrorKind.invalidResponse, 'sin pasos');
    return out;
  }
}
