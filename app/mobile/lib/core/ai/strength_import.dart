/// Sesión de fuerza contada con palabras (CU-02) → ejercicios del catálogo.
///
/// El modelo devuelve el nombre en español y en inglés; el cruce con el catálogo
/// (más de 800 ejercicios, en inglés con nombres en español) se hace aquí, sin
/// mandarle el catálogo al modelo. Lo que no se reconoce queda para elegirlo de
/// la lista, como dice la tesis.
library;

import '../common/numbers.dart';
import '../common/units.dart';
import '../nutrition/matcher.dart';
import '../strength/catalog.dart';
import '../strength/models.dart';
import '../strength/session.dart';
import 'ai_models.dart';

/// Similitud mínima entre lo que dijo el modelo y el nombre del ejercicio.
const exerciseAccept = 0.6;

class ImportedExercise {
  const ImportedExercise({required this.source, this.exercise, required this.confidence});

  final AiExercise source;

  /// Ejercicio del catálogo; null = falta elegirlo.
  final Exercise? exercise;
  final double confidence;

  bool get recognized => exercise != null;

  ImportedExercise pick(Exercise e) => ImportedExercise(source: source, exercise: e, confidence: 1);

  WeightUnit get unit => source.pounds ? WeightUnit.lb : WeightUnit.kg;
}

double _similarity(AiExercise e, Exercise x) {
  var best = 0.0;
  for (final q in [e.nameEn, e.name, e.written]) {
    if (q.isEmpty) continue;
    for (final t in [x.name, x.nameEn, ...x.aliases]) {
      final s = phraseSimilarity(q, t);
      if (s > best) best = s;
    }
  }
  return best;
}

/// Busca cada ejercicio en el catálogo (primero por el nombre en inglés, que es el del catálogo).
List<ImportedExercise> matchExercises(List<AiExercise> parsed, ExerciseIndex index) => [
  for (final e in parsed)
    () {
      Exercise? best;
      var score = 0.0;
      for (final q in {e.nameEn, e.name, e.written}..remove('')) {
        for (final x in index.search(query: q, limit: 5)) {
          final s = _similarity(e, x);
          if (s > score) {
            score = s;
            best = x;
          }
        }
      }
      return ImportedExercise(source: e, exercise: score >= exerciseAccept ? best : null, confidence: score);
    }(),
];

/// Texto de una serie para revisar: "80 kg × 8" o "12 reps".
String setLabel(AiSet s, WeightUnit unit) =>
    s.weight != null && s.weight! > 0 ? '${plainEs(s.weight!)} ${unit.symbol} × ${plain(s.reps)}' : '${plain(s.reps)} reps';

/// Sesión en curso con todo lo contado ya marcado como hecho: el usuario la revisa
/// en la pantalla de siempre y la guarda con "Terminar" (y su esfuerzo).
ActiveWorkout workoutFromImport(List<ImportedExercise> items, {required int now, String name = 'Sesión contada'}) {
  final sets = items.fold<int>(0, (n, i) => n + i.source.sets.length);
  // Duración aproximada para la carga: unos 2,5 minutos por serie con su descanso.
  final startedAt = now - (sets * 150000).clamp(10 * 60000, 150 * 60000);
  return ActiveWorkout(
    name: name,
    startedAt: startedAt,
    exercises: [
      for (final i in items)
        if (i.exercise != null)
          DraftExercise(
            key: newKey(),
            exerciseId: i.exercise!.id,
            unit: i.unit,
            sets: [
              for (final s in i.source.sets)
                DraftSet(
                  key: newKey(),
                  type: s.warmup ? SetType.warmup : SetType.normal,
                  kg: s.weight == null ? '' : plainEs(s.weight!),
                  reps: plain(s.reps),
                  done: true,
                ),
            ],
          ),
    ],
  );
}
