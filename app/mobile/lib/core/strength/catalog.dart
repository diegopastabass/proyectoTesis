/// Catálogo de ejercicios (free-exercise-db + nombres en español) y su buscador.
library;

import '../common/fuzzy.dart';
import '../common/normalize.dart';
import 'models.dart';

/// Mismo commit con el que se generó assets/data/exercises.json.
const _imageBase = 'https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5/exercises';

/// Foto de la posición inicial (0) o final (1); null si el ejercicio no tiene imágenes.
String? exerciseImage(Exercise e, [int frame = 0]) {
  if (e.custom || e.images < 2) return null;
  return '$_imageBase/${Uri.encodeComponent(e.id)}/$frame.jpg';
}

/// Ficha original (inglés) con las instrucciones.
String exerciseSourceUrl(String id) => '$_imageBase/${Uri.encodeComponent(id)}.json';

const musclesEs = {
  'abdominals': 'Abdominales',
  'abductors': 'Abductores',
  'adductors': 'Aductores',
  'biceps': 'Bíceps',
  'calves': 'Pantorrillas',
  'chest': 'Pecho',
  'forearms': 'Antebrazos',
  'glutes': 'Glúteos',
  'hamstrings': 'Isquiotibiales',
  'lats': 'Dorsales',
  'lower back': 'Zona lumbar',
  'middle back': 'Espalda media',
  'neck': 'Cuello',
  'quadriceps': 'Cuádriceps',
  'shoulders': 'Hombros',
  'traps': 'Trapecio',
  'triceps': 'Tríceps',
};

const equipmentEs = {
  'bands': 'Bandas',
  'barbell': 'Barra',
  'body only': 'Peso corporal',
  'cable': 'Polea',
  'dumbbell': 'Mancuernas',
  'e-z curl bar': 'Barra Z',
  'exercise ball': 'Balón suizo',
  'foam roll': 'Rodillo',
  'kettlebells': 'Kettlebell',
  'machine': 'Máquina',
  'medicine ball': 'Balón medicinal',
  'other': 'Otro',
};

class MuscleGroup {
  const MuscleGroup(this.id, this.label, this.muscles);

  final String id;
  final String label;
  final List<String> muscles;
}

/// Grupos para filtrar el catálogo.
const muscleGroups = [
  MuscleGroup('pecho', 'Pecho', ['chest']),
  MuscleGroup('espalda', 'Espalda', ['lats', 'middle back', 'lower back', 'traps']),
  MuscleGroup('hombros', 'Hombros', ['shoulders']),
  MuscleGroup('brazos', 'Brazos', ['biceps', 'triceps', 'forearms']),
  MuscleGroup('piernas', 'Piernas', ['quadriceps', 'hamstrings', 'calves', 'adductors', 'abductors']),
  MuscleGroup('gluteos', 'Glúteos', ['glutes']),
  MuscleGroup('core', 'Core', ['abdominals']),
];

String muscleLabel(String m) => musclesEs[m] ?? m;

String equipmentLabel(String? e) => e == null ? 'Sin equipo' : (equipmentEs[e] ?? e);

/// Une el catálogo (inglés, `exercises.json`) con los nombres en español.
List<Exercise> buildExercises(List<Map<String, dynamic>> raw, Map<String, dynamic> namesEs) => [
      for (final r in raw)
        () {
          final es = namesEs[r['id']] as Map<String, dynamic>?;
          return Exercise(
            id: r['id'] as String,
            name: es?['name'] as String? ?? r['name'] as String,
            nameEn: r['name'] as String,
            aliases: (es?['aliases'] as List?)?.cast<String>() ?? const [],
            category: r['category'] as String? ?? 'strength',
            equipment: r['equipment'] as String?,
            primary: (r['primary'] as List? ?? const []).cast<String>(),
            secondary: (r['secondary'] as List? ?? const []).cast<String>(),
            images: (r['images'] as num?)?.toInt() ?? 0,
          );
        }(),
    ];

/// Similitud 0–1 entre la consulta y un texto: 1 si lo contiene; si no, cuánto
/// cubren los tokens de la consulta (prefijos o con errores de tipeo).
double _fieldScore(String q, List<String> qTokens, String text) {
  if (text.isEmpty) return 0;
  if (text.contains(q)) return text.startsWith(q) ? 1 : 0.95;
  final tokens = text.split(' ');
  var sum = 0.0;
  for (final a in qTokens) {
    var best = 0.0;
    for (final b in tokens) {
      final s = a.length >= 3 && b.startsWith(a) ? 0.9 : tokenSimilarity(a, b);
      if (s > best) best = s;
    }
    sum += best;
  }
  return sum / qTokens.length;
}

class _Indexed {
  _Indexed(this.exercise)
      : name = normalize(exercise.name),
        aliases = exercise.aliases.map(normalize).toList(),
        nameEn = normalize(exercise.nameEn);

  final Exercise exercise;
  final String name;
  final List<String> aliases;
  final String nameEn;
}

/// Busca por nombre en español o inglés y por alias, tolerando errores de tipeo.
/// Sin texto, ordena primero los ejercicios con nombre en español (los comunes).
class ExerciseIndex {
  ExerciseIndex(List<Exercise> list) : _items = list.map(_Indexed.new).toList();

  final List<_Indexed> _items;

  /// Desde esta similitud un ejercicio aparece en los resultados.
  static const _threshold = 0.75;

  static int _translated(Exercise e) => e.custom ? 0 : (e.name != e.nameEn ? 1 : 2);

  List<Exercise> search({String query = '', String? group, int limit = 60}) {
    final muscles = group == null ? null : muscleGroups.where((g) => g.id == group).firstOrNull?.muscles ?? const <String>[];
    bool inGroup(Exercise e) => muscles == null || e.primary.any(muscles.contains);
    final q = normalize(query);

    if (q.isEmpty) {
      final list = _items.map((i) => i.exercise).where(inGroup).toList()
        ..sort((a, b) {
          final t = _translated(a).compareTo(_translated(b));
          return t != 0 ? t : a.name.compareTo(b.name);
        });
      return list.take(limit).toList();
    }

    final qTokens = q.split(' ');
    final scored = <(Exercise, double)>[];
    for (final item in _items) {
      if (!inGroup(item.exercise)) continue;
      final name = _fieldScore(q, qTokens, item.name);
      final alias = item.aliases.fold(0.0, (m, a) => m > _fieldScore(q, qTokens, a) ? m : _fieldScore(q, qTokens, a));
      final en = _fieldScore(q, qTokens, item.nameEn);
      final best = [name, alias, en].reduce((a, b) => a > b ? a : b);
      if (best < _threshold) continue;
      // Ponderación como en la web: nombre (3) > alias (2) > inglés (1).
      scored.add((item.exercise, best * 10 + name * 3 + alias * 2 + en));
    }
    scored.sort((a, b) {
      final s = b.$2.compareTo(a.$2);
      if (s != 0) return s;
      final t = _translated(a.$1).compareTo(_translated(b.$1));
      return t != 0 ? t : a.$1.name.length.compareTo(b.$1.name.length);
    });
    return scored.take(limit).map((s) => s.$1).toList();
  }
}
