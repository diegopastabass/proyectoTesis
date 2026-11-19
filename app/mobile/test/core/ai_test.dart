import 'dart:convert';
import 'dart:typed_data';

import 'package:asistente_deportivo/core/ai/ai_models.dart';
import 'package:asistente_deportivo/core/ai/estimate.dart';
import 'package:asistente_deportivo/core/ai/prompts.dart';
import 'package:asistente_deportivo/core/ai/strength_import.dart';
import 'package:asistente_deportivo/core/common/units.dart';
import 'package:asistente_deportivo/core/nutrition/models.dart';
import 'package:asistente_deportivo/core/nutrition/resolve.dart';
import 'package:asistente_deportivo/core/strength/catalog.dart';
import 'package:asistente_deportivo/core/strength/models.dart';
import 'package:asistente_deportivo/core/strength/session.dart';
import 'package:asistente_deportivo/data/ai/ai_service.dart';
import 'package:asistente_deportivo/data/ai/gemini_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final ctx = ResolveContext.build(const [
  Food(id: 'arroz', name: 'Arroz blanco cocido', aliases: ['arroz'], per100g: Macros(kcal: 130, protein: 2.7, carbs: 28, fat: 0.3), createdBy: 'x'),
  Food(id: 'pollo', name: 'Pechuga de pollo', aliases: ['pollo'], per100g: Macros(kcal: 165, protein: 31, carbs: 0, fat: 3.6), createdBy: 'x'),
], const []);

AiFood food(String name, double grams, double confidence, {double kcal = 100}) =>
    AiFood(name: name, grams: grams, confidence: confidence, macros: Macros(kcal: kcal, protein: 5, carbs: 10, fat: 2));

/// Respuesta de la API con el JSON del modelo como texto.
String apiResponse(Object data) => jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': jsonEncode(data)},
            ],
          },
          'finishReason': 'STOP',
        },
      ],
    });

void main() {
  group('lectura de las respuestas', () {
    test('comida: confianza 0–1 o 0–100 y alimentos sin gramos fuera', () {
      final meal = AiMeal.fromJson({
        'alimentos': [
          {'nombre': 'arroz', 'gramos': 180, 'confianza': 0.9, 'kcal': 234, 'proteina': 4, 'carbohidratos': 51, 'grasa': 0.5},
          {'nombre': 'pollo', 'gramos': '130', 'confianza': 85, 'kcal': 215, 'proteina': 40, 'carbohidratos': 0, 'grasa': 4.7},
          {'nombre': 'nada', 'gramos': 0, 'confianza': 50, 'kcal': 0},
        ],
        'nota': '',
      });
      expect(meal.items.map((f) => f.name), ['arroz', 'pollo']);
      expect(meal.items.first.confidence, 90);
      expect(meal.items[1].grams, 130);
      expect(meal.note, isNull);
    });

    test('etiqueta: si solo trae la porción, se lleva a 100 g', () {
      final l = NutritionLabel.fromJson({
        'nombre': 'Barra',
        'gramosPorcion': 40,
        'porPorcion': {'kcal': 160, 'proteina': 8, 'carbohidratos': 20, 'grasa': 4},
      });
      expect(l.readable, isTrue);
      expect(l.per100g!.kcal, 400);
      expect(l.per100g!.protein, 20);
      expect(NutritionLabel.fromJson(const {}).readable, isFalse);
    });

    test('fuerza: series, libras y calentamientos', () {
      final e = parseStrength({
        'ejercicios': [
          {
            'escrito': 'press',
            'nombre': 'Press de banca',
            'nombreIngles': 'Bench Press',
            'unidad': 'lb',
            'series': [
              {'repeticiones': 10, 'peso': 95, 'calentamiento': true},
              {'repeticiones': 8, 'peso': 135},
              {'repeticiones': 0},
            ],
          },
          {'escrito': 'vacío', 'nombre': 'x', 'nombreIngles': 'y', 'series': []},
        ],
      });
      expect(e, hasLength(1));
      expect(e.single.pounds, isTrue);
      expect(e.single.sets.map((s) => (s.reps, s.weight, s.warmup)), [(10.0, 95.0, true), (8.0, 135.0, false)]);
      expect(parseSteps({'pasos': [' Uno ', '', 'Dos']}), ['Uno', 'Dos']);
    });
  });

  group('cruce con el catálogo', () {
    test('si el alimento está en el catálogo, los macros salen del catálogo', () {
      final e = estimateFromAi(food('arroz blanco cocido', 200, 90, kcal: 999), ctx);
      expect((e.source, e.name, e.macros.kcal), (EstimateSource.catalog, 'Arroz blanco cocido', 260));
      expect(e.toEntry(MealSlot.almuerzo, via: 'IA: foto').refId, 'arroz');
    });

    test('si no está, se usan los del modelo y se recalculan al cambiar los gramos', () {
      final e = estimateFromAi(food('porotos con riendas', 300, 72, kcal: 390), ctx);
      expect((e.source, e.name, e.macros.kcal), (EstimateSource.model, 'Porotos con riendas', 390));
      expect(e.withGrams(150, ctx).macros.kcal, 195);
      expect(e.toEntry(MealSlot.almuerzo, via: 'IA: texto').refId, 'ia:porotos con riendas');
    });

    test('bajo 70 % de confianza hay que revisarlo antes de guardar', () {
      final e = estimateFromAi(food('aceite de oliva', 10, 45), ctx);
      expect(e.needsReview, isTrue);
      expect(e.copyWith(confirmed: true).needsReview, isFalse);
      expect(e.withGrams(15, ctx).needsReview, isFalse, reason: 'cambiar los gramos cuenta como revisarlo');
      expect(estimateFromAi(food('arroz', 100, 80), ctx).needsReview, isFalse);
    });

    test('lo que las reglas entienden no va al asistente', () {
      final split = splitByRules('200 g de arroz\nun plato de porotos con riendas', ctx);
      expect(split.resolved.single.name, 'Arroz blanco cocido');
      expect(split.resolved.single.source, EstimateSource.rules);
      expect(split.pending, ['un plato de porotos con riendas']);
      expect(totalOf(split.resolved).kcal, 260);
    });
  });

  group('sesión contada', () {
    final index = ExerciseIndex(const [
      Exercise(id: 'Barbell_Squat', name: 'Sentadilla con barra', nameEn: 'Barbell Squat', primary: ['quadriceps']),
      Exercise(id: 'Romanian_Deadlift', name: 'Peso muerto rumano', nameEn: 'Romanian Deadlift', primary: ['hamstrings']),
    ]);
    const parsed = [
      AiExercise(written: 'sentadilla', name: 'Sentadilla', nameEn: 'Barbell Squat', sets: [AiSet(reps: 8, weight: 80), AiSet(reps: 8, weight: 80)]),
      AiExercise(written: 'rumano', name: 'Peso muerto rumano', nameEn: 'Romanian Deadlift', sets: [AiSet(reps: 10, weight: 135)], pounds: true),
      AiExercise(written: 'granjero', name: 'Caminata del granjero', nameEn: 'Farmers Walk', sets: [AiSet(reps: 1, weight: 24)]),
    ];

    test('reconoce lo que está en el catálogo y deja lo demás para elegir', () {
      final m = matchExercises(parsed, index);
      expect(m.map((i) => i.exercise?.id), ['Barbell_Squat', 'Romanian_Deadlift', null]);
      expect(m[1].unit, WeightUnit.lb);
      expect(setLabel(parsed[1].sets.single, WeightUnit.lb), '135 lb × 10');
      expect(setLabel(const AiSet(reps: 12), WeightUnit.kg), '12 reps');
    });

    test('se abre como entrenamiento con todo marcado, en su unidad', () {
      final m = matchExercises(parsed, index);
      final w = workoutFromImport(m, now: 10000000);
      expect(w.exercises.map((e) => e.exerciseId), ['Barbell_Squat', 'Romanian_Deadlift'], reason: 'lo no reconocido no entra');
      expect(w.exercises[1].unit, WeightUnit.lb);
      expect(w.exercises.first.sets.every((s) => s.done), isTrue);
      expect(w.exercises.first.sets.first.kg, '80');
      expect(10000000 - w.startedAt, 10 * 60000, reason: 'mínimo 10 minutos para la carga');
      final saved = finishWorkout(w, 10000000, (id) => id);
      expect(saved.exercises[1].sets.single.kg, closeTo(61.2, 0.1));
      expect(saved.exercises.first.sets.first.type, SetType.normal);
    });
  });

  group('cliente de Gemini', () {
    test('envía la imagen, el esquema y la clave como pide la API', () async {
      late http.Request sent;
      final client = MockClient((req) async {
        sent = req;
        return http.Response(apiResponse({'alimentos': [], 'nota': 'No se ve comida'}), 200);
      });
      final ai = GeminiAiService(apiKey: 'clave', bundleId: 'cl.app', client: client);
      final meal = await ai.mealFromPhoto(Uint8List.fromList([1, 2, 3]));
      expect(meal.note, 'No se ve comida');
      expect(sent.url.toString(), 'https://generativelanguage.googleapis.com/v1beta/models/$defaultGeminiModel:generateContent');
      expect(sent.headers['x-goog-api-key'], 'clave');
      expect(sent.headers['X-Ios-Bundle-Identifier'], 'cl.app');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      final parts = (body['contents'] as List).single['parts'] as List;
      expect((parts.first as Map)['inlineData'], {'mimeType': 'image/jpeg', 'data': base64Encode([1, 2, 3])});
      expect(body['generationConfig']['responseMimeType'], 'application/json');
      expect(body['generationConfig']['responseJsonSchema'], mealSchema);
      expect(body['systemInstruction']['parts'].single['text'], contains('español de Chile'));
    });

    test('errores de cuota, clave y bloqueo', () async {
      Future<Object?> fail(int status, String body) async {
        final ai = GeminiAiService(apiKey: 'k', client: MockClient((_) async => http.Response(body, status)));
        try {
          await ai.mealFromText('pan');
          return null;
        } on AiException catch (e) {
          return e.kind;
        }
      }

      expect(await fail(429, '{"error":{"message":"Resource exhausted"}}'), AiErrorKind.quota);
      expect(await fail(400, '{"error":{"message":"API key not valid"}}'), AiErrorKind.notConfigured);
      expect(await fail(503, 'down'), AiErrorKind.server);
      expect(await fail(200, jsonEncode({'promptFeedback': {'blockReason': 'SAFETY'}})), AiErrorKind.blocked);
      expect(await fail(200, jsonEncode({'candidates': [{'content': {'parts': [{'text': 'no es json'}]}}]})), AiErrorKind.invalidResponse);
      expect(() => GeminiAiService(apiKey: '').mealFromText('x'), throwsA(isA<AiException>()));
    });

    test('si el modelo no acepta el nivel de razonamiento, reintenta sin él', () async {
      final bodies = <Map<String, dynamic>>[];
      final client = MockClient((req) async {
        final b = jsonDecode(req.body) as Map<String, dynamic>;
        bodies.add(b);
        if ((b['generationConfig'] as Map).containsKey('thinkingConfig')) {
          return http.Response('{"error":{"message":"Thinking level is not supported for this model."}}', 400);
        }
        return http.Response(apiResponse({'pasos': ['Paso uno']}), 200);
      });
      final steps = await GeminiAiService(apiKey: 'k', client: client).translateSteps('Squat', ['Step one']);
      expect(steps, ['Paso uno']);
      expect(bodies, hasLength(2));
    });

    test('ignora las partes de razonamiento al leer la respuesta', () {
      final body = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'pensando…', 'thought': true},
                {'text': '{"pasos": ["A"]}'},
              ],
            },
          },
        ],
      });
      expect(GeminiAiService.parseResponse(body), {'pasos': ['A']});
    });
  });
}
