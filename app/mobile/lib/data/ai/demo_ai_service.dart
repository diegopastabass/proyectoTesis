/// Asistente de ejemplo: el modo demostración sin clave, las pruebas automáticas
/// y las capturas del documento. Responde siempre lo mismo, tras una pausa breve,
/// con el mismo formato que Gemini.
library;

import 'dart:typed_data';

import '../../core/ai/ai_models.dart';
import 'ai_service.dart';

class DemoAiService implements AiService {
  const DemoAiService({this.delay = const Duration(milliseconds: 900)});

  final Duration delay;

  @override
  AiMode get mode => AiMode.demo;

  @override
  String get model => 'ejemplo';

  static Map<String, dynamic> _food(String name, double grams, double confidence, double kcal, double p, double c, double f) => {
    'nombre': name,
    'gramos': grams,
    'confianza': confidence,
    'kcal': kcal,
    'proteina': p,
    'carbohidratos': c,
    'grasa': f,
  };

  @override
  Future<AiMeal> mealFromPhoto(Uint8List jpeg) async {
    await Future<void>.delayed(delay);
    return AiMeal.fromJson({
      'alimentos': [
        _food('arroz blanco cocido', 180, 90, 234, 4.3, 51, 0.5),
        _food('pechuga de pollo a la plancha', 130, 85, 215, 40, 0, 4.7),
        _food('tomate', 90, 88, 18, 0.8, 3.5, 0.2),
        _food('aceite de oliva', 10, 45, 88, 0, 0, 10),
      ],
    });
  }

  @override
  Future<AiMeal> mealFromText(String text) async {
    await Future<void>.delayed(delay);
    return AiMeal.fromJson({
      'alimentos': [_food('porotos con riendas', 300, 72, 390, 20, 60, 6), _food('ensalada surtida', 120, 55, 30, 1.5, 6, 0.3)],
    });
  }

  @override
  Future<NutritionLabel> labelFromPhoto(Uint8List jpeg) async {
    await Future<void>.delayed(delay);
    return NutritionLabel.fromJson({
      'nombre': 'Yogur proteico natural',
      'marca': 'Ejemplo',
      'gramosPorcion': 150,
      'por100g': {'kcal': 62, 'proteina': 10, 'carbohidratos': 4.2, 'grasa': 0.4, 'fibra': 0},
    });
  }

  @override
  Future<List<AiExercise>> strengthFromText(String text) async {
    await Future<void>.delayed(delay);
    return parseStrength({
      'ejercicios': [
        {
          'escrito': 'Sentadilla',
          'nombre': 'Sentadilla con barra',
          'nombreIngles': 'Barbell Squat',
          'unidad': 'kg',
          'series': [
            for (var i = 0; i < 4; i++) {'repeticiones': 8, 'peso': 80},
          ],
        },
        {
          'escrito': 'peso muerto rumano',
          'nombre': 'Peso muerto rumano',
          'nombreIngles': 'Romanian Deadlift',
          'unidad': 'kg',
          'series': [
            for (var i = 0; i < 3; i++) {'repeticiones': 10, 'peso': 60},
          ],
        },
        {
          'escrito': 'wall balls',
          'nombre': 'Lanzamiento de balón al muro',
          'nombreIngles': 'Wall Ball Shot',
          'unidad': 'kg',
          'series': [
            for (var i = 0; i < 3; i++) {'repeticiones': 20, 'peso': 6},
          ],
        },
      ],
    });
  }

  /// Un ejemplo que usa las cifras reales del resumen, para que se vea creíble.
  @override
  Future<FatigueSummary> fatigueSummary(Map<String, dynamic> brief) async {
    await Future<void>.delayed(delay);
    final reliable = brief['historialSuficiente'] == true;
    final ratio = brief['razonAgudaCronica'];
    final cardioShare = ((brief['cardio'] as Map?)?['parteDeLaSemana'] as num? ?? 0) * 100;
    return FatigueSummary(
      headline: reliable ? 'Tu carga está ${ratio is num && ratio > 1.3 ? 'subiendo rápido' : 'dentro de lo habitual'}' : 'Todavía estamos conociendo tu carga',
      summary: reliable
          ? 'Esta semana tu carga es ${ratio is num ? ratio.toStringAsFixed(2).replaceAll('.', ',') : '—'} veces la de las últimas seis semanas. '
              'El ${cardioShare.round()} % vino del cardio.'
          : 'Llevas ${brief['diasDeHistorial']} días registrados: con menos de 4 semanas la comparación todavía no es confiable, así que miramos tu carga de la semana.',
      points: const ['Ejemplo del modo demostración: con Gemini, este resumen se escribe con tus datos.'],
      suggestion: 'Mantén las sesiones suaves suaves y anota el esfuerzo al terminar cada entrenamiento.',
    );
  }

  @override
  Future<List<String>> translateSteps(String exercise, List<String> steps) async {
    await Future<void>.delayed(delay);
    return [for (var i = 0; i < steps.length; i++) 'Paso ${i + 1} (ejemplo traducido): ${steps[i]}'];
  }
}
