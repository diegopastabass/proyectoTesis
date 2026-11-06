/// Datos simulados de las pantallas de diseño (comunidad, IA, reloj, archivos y
/// suscripción). Estas funciones todavía no tienen backend: las pantallas solo se
/// muestran en modo demostración y nada de esto se guarda en Firebase.
/// Las personas son ficticias.
library;

import 'dart:math' as math;

import '../../core/cardio/geo.dart';

class SimUser {
  const SimUser({required this.id, required this.name, required this.handle, required this.bio, required this.sport, required this.followers, required this.following, required this.tone});

  final String id;
  final String name;
  final String handle;
  final String bio;
  final String sport;
  final int followers;
  final int following;

  /// Índice del color del avatar.
  final int tone;

  String get initials => name.split(' ').take(2).map((w) => w[0]).join();
}

const simUsers = [
  SimUser(id: 'camila', name: 'Camila Rojas', handle: '@camirojas', bio: 'Triatleta aficionada. Fuerza dos veces por semana y mucho pedal.', sport: 'Triatlón', followers: 248, following: 112, tone: 0),
  SimUser(id: 'matias', name: 'Matías Soto', handle: '@matisoto', bio: 'Corro cerros los fines de semana y entreno pierna sin miedo.', sport: 'Trail running', followers: 96, following: 80, tone: 1),
  SimUser(id: 'fernanda', name: 'Fernanda Díaz', handle: '@ferdiaz', bio: 'Nutricionista y ciclista de fin de semana. Recetas simples.', sport: 'Ciclismo', followers: 412, following: 150, tone: 2),
  SimUser(id: 'tomas', name: 'Tomás Araya', handle: '@tomasaraya', bio: 'Powerlifting y trote suave para el corazón.', sport: 'Fuerza', followers: 63, following: 41, tone: 3),
  SimUser(id: 'carla', name: 'Carla Muñoz', handle: '@carlamunoz', bio: 'Preparando mi primer medio maratón.', sport: 'Running', followers: 37, following: 58, tone: 4),
];

SimUser simUser(String id) => simUsers.firstWhere((u) => u.id == id);

enum SimPostKind {
  workout('Sesión de fuerza', 'Agregar a mis rutinas', 'tus rutinas'),
  route('Ruta', 'Agregar a mi cardio', 'tu módulo de cardio'),
  meal('Comida', 'Agregar a mis recetas', 'tu módulo de nutrición'),
  recipe('Receta', 'Agregar a mi nutrición', 'tu módulo de nutrición');

  const SimPostKind(this.label, this.addLabel, this.destination);

  final String label;
  final String addLabel;
  final String destination;
}

class SimStat {
  const SimStat(this.label, this.value);

  final String label;
  final String value;
}

class SimIngredient {
  const SimIngredient(this.name, this.grams);

  final String name;
  final double grams;
}

class SimLine {
  const SimLine(this.name, this.detail);

  final String name;
  final String detail;
}

/// Macronutrientes de una porción de receta.
class SimMacros {
  const SimMacros(this.kcal, this.protein, this.carbs, this.fat);

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  SimMacros times(double f) => SimMacros(kcal * f, protein * f, carbs * f, fat * f);
}

class SimPost {
  const SimPost({
    required this.id,
    required this.authorId,
    required this.kind,
    required this.title,
    required this.text,
    required this.when,
    this.photos = 0,
    this.stats = const [],
    this.lines = const [],
    this.ingredients = const [],
    this.macros,
    this.routeSeed,
  });

  final String id;
  final String authorId;
  final SimPostKind kind;
  final String title;
  final String text;
  final String when;

  /// Cantidad de fotos (se dibujan como imágenes de ejemplo).
  final int photos;
  final List<SimStat> stats;

  /// Ejercicios de una sesión.
  final List<SimLine> lines;
  final List<SimIngredient> ingredients;
  final SimMacros? macros;
  final int? routeSeed;
}

const simPosts = [
  SimPost(
    id: 'p1',
    authorId: 'camila',
    kind: SimPostKind.workout,
    title: 'Rutina de pecho y empuje',
    text: 'Hoy tocó empuje antes de la salida larga del domingo. Dejé dos repeticiones en reserva para no llegar cansada a la bici.',
    when: 'Hace 2 h',
    stats: [SimStat('Duración', '58 min'), SimStat('Series', '14'), SimStat('Esfuerzo', '7/10')],
    lines: [
      SimLine('Press de banca con barra', '4 series · 8 repeticiones · 50 kg'),
      SimLine('Press inclinado con mancuernas', '3 series · 10 repeticiones · 18 kg'),
      SimLine('Fondos en paralelas', '3 series · 10 repeticiones'),
      SimLine('Elevaciones laterales', '4 series · 12 repeticiones · 7 kg'),
    ],
  ),
  SimPost(
    id: 'p2',
    authorId: 'fernanda',
    kind: SimPostKind.recipe,
    title: 'Bowl de pollo, quinoa y palta',
    text: 'Mi almuerzo de los días con doble sesión. Se prepara en 20 minutos y aguanta bien en el refrigerador.',
    when: 'Hace 5 h',
    photos: 2,
    stats: [SimStat('Calorías', '640 kcal'), SimStat('Proteína', '48 g'), SimStat('Porción', '1')],
    ingredients: [
      SimIngredient('Pechuga de pollo cocida', 150),
      SimIngredient('Quinoa cocida', 180),
      SimIngredient('Palta', 60),
      SimIngredient('Tomate', 80),
      SimIngredient('Aceite de oliva', 5),
    ],
    macros: SimMacros(640, 48, 62, 22),
  ),
  SimPost(
    id: 'p3',
    authorId: 'matias',
    kind: SimPostKind.route,
    title: 'Vuelta al cerro Manquehue',
    text: 'Subida exigente pero con una vista increíble. Salí temprano para evitar el calor.',
    when: 'Ayer',
    stats: [SimStat('Distancia', '9,4 km'), SimStat('Desnivel', '620 m'), SimStat('Tiempo', '1:52:10')],
    routeSeed: 3,
  ),
  SimPost(
    id: 'p4',
    authorId: 'tomas',
    kind: SimPostKind.meal,
    title: 'Almuerzo post pierna',
    text: 'Arroz, carne y ensalada. Nada elegante, pero hace la pega después de sentadillas pesadas.',
    when: 'Ayer',
    photos: 1,
    stats: [SimStat('Calorías', '780 kcal'), SimStat('Proteína', '52 g'), SimStat('Carbohidratos', '88 g')],
    ingredients: [SimIngredient('Arroz blanco cocido', 250), SimIngredient('Posta negra', 180), SimIngredient('Ensalada surtida', 150)],
    macros: SimMacros(780, 52, 88, 22),
  ),
];

SimPost simPost(String id) => simPosts.firstWhere((p) => p.id == id);

/// Ruta de ejemplo para las miniaturas: una curva cerrada a partir de una semilla.
List<LatLng> simRoute(int seed) {
  final out = <LatLng>[];
  for (var i = 0; i <= 80; i++) {
    final a = i / 80 * 2 * math.pi;
    final r = 1 + 0.25 * math.sin(a * (seed + 1)) + 0.12 * math.cos(a * (seed + 3));
    out.add(LatLng(-33.4 + 0.01 * r * math.sin(a), -70.6 + 0.014 * r * math.cos(a)));
  }
  return out;
}

/// Sesiones nuevas que traería la app de salud del teléfono (CU-03).
class SimWatchSession {
  const SimWatchSession({required this.id, required this.title, required this.when, required this.source, required this.stats});

  final String id;
  final String title;
  final String when;
  final String source;
  final List<SimStat> stats;
}

const simWatchSessions = [
  SimWatchSession(
    id: 'w1',
    title: 'Ciclismo',
    when: 'Hoy, 07:12',
    source: 'Apple Watch',
    stats: [SimStat('Duración', '1:24:32'), SimStat('Distancia', '38,6 km'), SimStat('Pulso medio', '142 ppm')],
  ),
  SimWatchSession(
    id: 'w2',
    title: 'Running',
    when: 'Ayer, 19:40',
    source: 'Apple Watch',
    stats: [SimStat('Duración', '42:18'), SimStat('Distancia', '8,1 km'), SimStat('Pulso medio', '155 ppm')],
  ),
];

/// Lo que devolvería el asistente de IA al leer una comida (CU-07 y CU-16).
class SimFoodEstimate {
  const SimFoodEstimate(this.name, this.grams, this.kcal, this.protein, this.carbs, this.fat, {this.unsure = false});

  final String name;
  final double grams;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  /// El asistente no está seguro: se pide revisar con más cuidado.
  final bool unsure;
}

const simPhotoEstimate = [
  SimFoodEstimate('Arroz blanco cocido', 180, 234, 4.3, 51, 0.5),
  SimFoodEstimate('Pechuga de pollo a la plancha', 130, 215, 40, 0, 4.7),
  SimFoodEstimate('Ensalada de tomate', 90, 18, 0.8, 3.5, 0.2),
  SimFoodEstimate('Aderezo (aceite de oliva)', 10, 88, 0, 0, 10, unsure: true),
];

const simTextEstimate = [
  SimFoodEstimate('Arroz blanco cocido', 200, 260, 4.8, 57, 0.6),
  SimFoodEstimate('Pollo salteado', 150, 248, 46, 0, 5.4),
  SimFoodEstimate('Ensalada surtida', 120, 30, 1.5, 6, 0.3, unsure: true),
];

/// Lo que devolvería el asistente al ordenar una sesión de fuerza (CU-02).
class SimParsedExercise {
  const SimParsedExercise(this.written, this.name, this.sets, {this.unknown = false});

  final String written;
  final String name;

  /// Filas de "kg × repeticiones".
  final List<String> sets;

  /// No se reconoció: el atleta debe elegirlo de la lista.
  final bool unknown;
}

const simStrengthExample = 'Sentadilla, 4 series de 8 con 80 kilos. Después peso muerto rumano 3 de 10 con 60. Terminé con caminata del granjero, 3 vueltas con 24 kilos.';

const simParsedStrength = [
  SimParsedExercise('Sentadilla', 'Sentadilla con barra', ['80 kg × 8', '80 kg × 8', '80 kg × 8', '80 kg × 8']),
  SimParsedExercise('Peso muerto rumano', 'Peso muerto rumano', ['60 kg × 10', '60 kg × 10', '60 kg × 10']),
  SimParsedExercise('Caminata del granjero', 'Caminata del granjero', ['24 kg × 3 vueltas'], unknown: true),
];

/// Una sesión de archivo `.fit` (CU-04): series por minuto de una salida de 90 min.
class SimFitSeries {
  const SimFitSeries(this.label, this.unit, this.values, this.average, this.maximum);

  final String label;
  final String unit;
  final List<double> values;
  final String average;
  final String maximum;
}

List<double> _wave(double base, double amp, int seed) => [
      for (var i = 0; i < 60; i++) base + amp * math.sin(i / (6 + seed)) + amp * 0.45 * math.sin(i * 0.9 + seed) + amp * 0.25 * math.cos(i * 0.37),
    ];

final simFitSeries = [
  SimFitSeries('Potencia', 'W', _wave(196, 42, 1), '196 W', '412 W'),
  SimFitSeries('Cadencia', 'rpm', _wave(84, 7, 2), '84 rpm', '108 rpm'),
  SimFitSeries('Pulso', 'ppm', _wave(148, 12, 3), '148 ppm', '176 ppm'),
];

/// Sesiones sugeridas de la semana (CU-12).
class SimPlanDay {
  const SimPlanDay(this.day, this.title, this.detail, {this.kind = 'rest'});

  final String day;
  final String title;
  final String detail;

  /// strength, cardio o rest.
  final String kind;
}

const simWeeklyPlan = [
  SimPlanDay('Lun', 'Fuerza: torso', '60 min · gimnasio', kind: 'strength'),
  SimPlanDay('Mar', 'Ciclismo suave', '60 min · zona cómoda', kind: 'cardio'),
  SimPlanDay('Mié', 'Fuerza: pierna', '55 min · gimnasio', kind: 'strength'),
  SimPlanDay('Jue', 'Descanso', 'Caminata opcional'),
  SimPlanDay('Vie', 'Fuerza: cuerpo completo', '50 min · gimnasio', kind: 'strength'),
  SimPlanDay('Sáb', 'Ciclismo largo', '2 h · ritmo constante', kind: 'cardio'),
  SimPlanDay('Dom', 'Descanso', 'Recuperación'),
];

/// Precio del plan premium definido en el capítulo de factibilidad económica.
const simPremiumPrice = '\$7.990';
