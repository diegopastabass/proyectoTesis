/// Programas de fuerza sugeridos y cómo elegirlos.
///
/// Plantillas propias basadas en estructuras ampliamente recomendadas (cuerpo
/// completo, torso/pierna, empuje/tirón/pierna y progresión por niveles al estilo
/// GZCLP), no copias de programas comerciales. Criterios:
/// - Cada músculo al menos 2 veces por semana; con el volumen igualado, lo que más
///   pesa son las series semanales por músculo (Schoenfeld et al., 2016 y 2019).
/// - Entrenamiento concurrente: la interferencia con el cardio baja separando las
///   sesiones 6 a 8 horas o en días distintos, con el cardio primero si van el
///   mismo día. Con mucho cardio se sugieren menos días de fuerza y menos pierna.
library;

import 'models.dart';

enum Experience {
  beginner('Menos de 6 meses'),
  intermediate('6 meses a 2 años'),
  advanced('Más de 2 años');

  const Experience(this.label);

  final String label;
}

enum TrainingGoal {
  strength('Ser más fuerte'),
  hypertrophy('Ganar músculo'),
  both('Fuerza y músculo'),
  endurance('Rendir en mi deporte de resistencia');

  const TrainingGoal(this.label);

  final String label;
}

enum Equipment {
  gym('Gimnasio completo'),
  dumbbells('Mancuernas y banco'),
  bodyweight('Peso corporal');

  const Equipment(this.label);

  final String label;
}

enum CardioType {
  running('Correr'),
  cycling('Bicicleta'),
  swimming('Natación'),
  mixed('Mixto (HYROX, CrossFit…)');

  const CardioType(this.label);

  final String label;
}

/// Respuestas del cuestionario.
class ProgramAnswers {
  const ProgramAnswers({
    this.days = 3,
    this.experience = Experience.beginner,
    this.goal = TrainingGoal.both,
    this.minutes = 60,
    this.equipment = Equipment.gym,
    this.cardioDays = 0,
    this.cardio = CardioType.running,
  });

  /// Días por semana que quiere entrenar fuerza.
  final int days;
  final Experience experience;
  final TrainingGoal goal;

  /// Tiempo máximo por sesión.
  final int minutes;
  final Equipment equipment;

  /// Días de cardio por semana.
  final int cardioDays;
  final CardioType cardio;

  ProgramAnswers copyWith({int? days, Experience? experience, TrainingGoal? goal, int? minutes, Equipment? equipment, int? cardioDays, CardioType? cardio}) =>
      ProgramAnswers(
        days: days ?? this.days,
        experience: experience ?? this.experience,
        goal: goal ?? this.goal,
        minutes: minutes ?? this.minutes,
        equipment: equipment ?? this.equipment,
        cardioDays: cardioDays ?? this.cardioDays,
        cardio: cardio ?? this.cardio,
      );
}

class ProgramExercise {
  const ProgramExercise(this.exerciseId, this.sets, this.repsMin, this.repsMax, {this.warmups = 0});

  final String exerciseId;

  /// Series efectivas.
  final int sets;
  final int repsMin;
  final int repsMax;

  /// Series de calentamiento antes de las efectivas.
  final int warmups;

  String get reps => repsMin == repsMax ? '$repsMin' : '$repsMin–$repsMax';
}

class ProgramDay {
  const ProgramDay(this.name, this.exercises);

  final String name;
  final List<ProgramExercise> exercises;
}

class Program {
  const Program({
    required this.id,
    required this.name,
    required this.summary,
    required this.forWhom,
    required this.days,
    required this.levels,
    required this.goals,
    required this.equipment,
    required this.minutes,
    required this.cardioFriendly,
    required this.rotation,
    required this.routines,
  });

  final String id;
  final String name;
  final String summary;

  /// Para quién sirve (se muestra en la sugerencia).
  final String forWhom;

  /// Sesiones por semana.
  final int days;
  final Set<Experience> levels;
  final Set<TrainingGoal> goals;
  final Equipment equipment;

  /// Duración aproximada de cada sesión.
  final int minutes;

  /// Poco volumen de pierna y pocas sesiones: convive bien con mucho cardio.
  final bool cardioFriendly;

  /// Cómo se rotan las rutinas en la semana.
  final String rotation;
  final List<ProgramDay> routines;
}

const _all = {Experience.beginner, Experience.intermediate, Experience.advanced};

ProgramExercise _e(String id, int sets, int min, int max, {int w = 0}) => ProgramExercise(id, sets, min, max, warmups: w);

final programs = <Program>[
  Program(
    id: 'cuerpo-completo-2',
    name: 'Cuerpo completo · 2 días',
    summary: 'Dos sesiones A y B con los básicos: el mínimo que sigue dando resultados.',
    forWhom: 'Quien tiene poco tiempo o mucho cardio y quiere mantener o ganar fuerza.',
    days: 2,
    levels: _all,
    goals: {TrainingGoal.both, TrainingGoal.strength, TrainingGoal.hypertrophy, TrainingGoal.endurance},
    equipment: Equipment.gym,
    minutes: 60,
    cardioFriendly: true,
    rotation: 'A y B, con 2 o 3 días entre sesiones.',
    routines: [
      ProgramDay('Cuerpo completo A', [
        _e('Barbell_Squat', 3, 5, 8, w: 2),
        _e('Barbell_Bench_Press_-_Medium_Grip', 3, 6, 10, w: 1),
        _e('Bent_Over_Barbell_Row', 3, 8, 12),
        _e('Romanian_Deadlift', 2, 8, 10),
        _e('Hanging_Leg_Raise', 2, 8, 15),
      ]),
      ProgramDay('Cuerpo completo B', [
        _e('Barbell_Deadlift', 3, 3, 5, w: 2),
        _e('Standing_Military_Press', 3, 6, 10, w: 1),
        _e('Wide-Grip_Lat_Pulldown', 3, 8, 12),
        _e('Dumbbell_Lunges', 2, 8, 12),
        _e('Face_Pull', 2, 12, 15),
      ]),
    ],
  ),
  Program(
    id: 'resistencia-2',
    name: 'Fuerza para resistencia · 2 días',
    summary: 'Cargas altas y pocas repeticiones, trabajo a una pierna y saltos: más economía de carrera o pedaleo con poca fatiga.',
    forWhom: 'Corredores, ciclistas y triatletas que quieren rendir más y lesionarse menos.',
    days: 2,
    levels: _all,
    goals: {TrainingGoal.endurance},
    equipment: Equipment.gym,
    minutes: 45,
    cardioFriendly: true,
    rotation: 'A y B. Lejos (mejor 48 h) de la sesión de cardio más exigente.',
    routines: [
      ProgramDay('Fuerza resistencia A', [
        _e('Barbell_Squat', 3, 4, 6, w: 2),
        _e('Split_Squat_with_Dumbbells', 3, 6, 8),
        _e('Romanian_Deadlift', 3, 6, 8),
        _e('Standing_Calf_Raises', 3, 10, 15),
        _e('Pullups', 3, 5, 10),
      ]),
      ProgramDay('Fuerza resistencia B', [
        _e('Barbell_Deadlift', 3, 3, 5, w: 2),
        _e('Barbell_Hip_Thrust', 3, 6, 10),
        _e('Box_Jump_Multiple_Response', 3, 5, 5),
        _e('Seated_Calf_Raise', 3, 10, 15),
        _e('Pushups', 3, 10, 20),
      ]),
    ],
  ),
  Program(
    id: 'cuerpo-completo-3',
    name: 'Cuerpo completo · 3 días',
    summary: 'Progresión lineal: los básicos con 5 repeticiones y un poco más de peso cada sesión.',
    forWhom: 'Principiantes: es la forma más rápida de ganar fuerza los primeros meses.',
    days: 3,
    levels: {Experience.beginner},
    goals: {TrainingGoal.strength, TrainingGoal.both},
    equipment: Equipment.gym,
    minutes: 60,
    cardioFriendly: true,
    rotation: 'A, B, A una semana y B, A, B la siguiente (lunes, miércoles y viernes, por ejemplo).',
    routines: [
      ProgramDay('Cuerpo completo A', [
        _e('Barbell_Squat', 3, 5, 5, w: 2),
        _e('Barbell_Bench_Press_-_Medium_Grip', 3, 5, 5, w: 1),
        _e('Bent_Over_Barbell_Row', 3, 6, 8),
      ]),
      ProgramDay('Cuerpo completo B', [
        _e('Barbell_Squat', 3, 5, 5, w: 2),
        _e('Standing_Military_Press', 3, 5, 5, w: 1),
        _e('Barbell_Deadlift', 1, 5, 5, w: 2),
        _e('Chin-Up', 3, 5, 8),
      ]),
    ],
  ),
  Program(
    id: 'niveles-3',
    name: 'Fuerza por niveles · 3 días',
    summary: 'Al estilo GZCLP: un básico pesado (5×3), uno de volumen (3×10) y un accesorio liviano en cada sesión.',
    forWhom: 'Quien ya domina los básicos y quiere seguir progresando en fuerza.',
    days: 3,
    levels: {Experience.beginner, Experience.intermediate},
    goals: {TrainingGoal.strength, TrainingGoal.both},
    equipment: Equipment.gym,
    minutes: 75,
    cardioFriendly: false,
    rotation: 'Cuatro sesiones en orden (A1, B1, A2, B2), tres por semana.',
    routines: [
      ProgramDay('Niveles A1', [
        _e('Barbell_Squat', 5, 3, 3, w: 2),
        _e('Barbell_Bench_Press_-_Medium_Grip', 3, 10, 10, w: 1),
        _e('Wide-Grip_Lat_Pulldown', 3, 15, 20),
      ]),
      ProgramDay('Niveles B1', [
        _e('Standing_Military_Press', 5, 3, 3, w: 2),
        _e('Barbell_Deadlift', 3, 10, 10, w: 1),
        _e('One-Arm_Dumbbell_Row', 3, 15, 20),
      ]),
      ProgramDay('Niveles A2', [
        _e('Barbell_Bench_Press_-_Medium_Grip', 5, 3, 3, w: 2),
        _e('Barbell_Squat', 3, 10, 10, w: 1),
        _e('Wide-Grip_Lat_Pulldown', 3, 15, 20),
      ]),
      ProgramDay('Niveles B2', [
        _e('Barbell_Deadlift', 5, 3, 3, w: 2),
        _e('Standing_Military_Press', 3, 10, 10, w: 1),
        _e('One-Arm_Dumbbell_Row', 3, 15, 20),
      ]),
    ],
  ),
  Program(
    id: 'torso-pierna-4',
    name: 'Torso / Pierna · 4 días',
    summary: 'Cada músculo dos veces por semana: un día más pesado y otro de más repeticiones.',
    forWhom: 'La opción más equilibrada entre fuerza y músculo para quien puede entrenar 4 días.',
    days: 4,
    levels: {Experience.beginner, Experience.intermediate},
    goals: {TrainingGoal.both, TrainingGoal.hypertrophy, TrainingGoal.strength},
    equipment: Equipment.gym,
    minutes: 60,
    cardioFriendly: false,
    rotation: 'Torso A, Pierna A, descanso, Torso B, Pierna B.',
    routines: [
      ProgramDay('Torso A', [
        _e('Barbell_Bench_Press_-_Medium_Grip', 4, 5, 8, w: 1),
        _e('Bent_Over_Barbell_Row', 4, 6, 10),
        _e('Standing_Military_Press', 3, 8, 10),
        _e('Wide-Grip_Lat_Pulldown', 3, 10, 12),
        _e('Triceps_Pushdown_-_Rope_Attachment', 2, 10, 15),
        _e('Barbell_Curl', 2, 10, 15),
      ]),
      ProgramDay('Pierna A', [
        _e('Barbell_Squat', 4, 5, 8, w: 2),
        _e('Romanian_Deadlift', 3, 8, 10),
        _e('Leg_Press', 3, 10, 12),
        _e('Lying_Leg_Curls', 3, 10, 15),
        _e('Standing_Calf_Raises', 3, 10, 15),
      ]),
      ProgramDay('Torso B', [
        _e('Incline_Dumbbell_Press', 3, 8, 12),
        _e('Seated_Cable_Rows', 3, 10, 12),
        _e('Dumbbell_Shoulder_Press', 3, 10, 12),
        _e('Pullups', 3, 6, 10),
        _e('Side_Lateral_Raise', 3, 12, 20),
        _e('Hammer_Curls', 2, 10, 15),
      ]),
      ProgramDay('Pierna B', [
        _e('Barbell_Deadlift', 3, 3, 5, w: 2),
        _e('Split_Squat_with_Dumbbells', 3, 8, 12),
        _e('Barbell_Hip_Thrust', 3, 8, 12),
        _e('Leg_Extensions', 3, 12, 15),
        _e('Seated_Calf_Raise', 3, 12, 15),
      ]),
    ],
  ),
  Program(
    id: 'torso-pierna-epp-5',
    name: 'Torso / Pierna + Empuje / Tirón / Pierna · 5 días',
    summary: 'Dos días de fuerza (torso y pierna) y tres de volumen por patrón de movimiento.',
    forWhom: 'Intermedios que se recuperan bien y quieren más volumen sin llegar a 6 días.',
    days: 5,
    levels: {Experience.intermediate, Experience.advanced},
    goals: {TrainingGoal.hypertrophy, TrainingGoal.both},
    equipment: Equipment.gym,
    minutes: 75,
    cardioFriendly: false,
    rotation: 'Torso, Pierna, descanso, Empuje, Tirón, Pierna.',
    routines: [
      ProgramDay('Torso fuerza', [
        _e('Barbell_Bench_Press_-_Medium_Grip', 4, 4, 6, w: 1),
        _e('Bent_Over_Barbell_Row', 4, 5, 8),
        _e('Standing_Military_Press', 3, 6, 8),
        _e('Pullups', 3, 6, 10),
      ]),
      ProgramDay('Pierna fuerza', [
        _e('Barbell_Squat', 4, 4, 6, w: 2),
        _e('Romanian_Deadlift', 3, 6, 8),
        _e('Leg_Press', 3, 8, 12),
        _e('Standing_Calf_Raises', 3, 10, 15),
      ]),
      ProgramDay('Empuje', [
        _e('Incline_Dumbbell_Press', 3, 8, 12),
        _e('Dumbbell_Shoulder_Press', 3, 8, 12),
        _e('Dips_-_Chest_Version', 3, 8, 12),
        _e('Side_Lateral_Raise', 3, 12, 20),
        _e('Triceps_Pushdown_-_Rope_Attachment', 3, 10, 15),
      ]),
      ProgramDay('Tirón', [
        _e('Wide-Grip_Lat_Pulldown', 3, 8, 12),
        _e('Seated_Cable_Rows', 3, 8, 12),
        _e('Face_Pull', 3, 12, 15),
        _e('Barbell_Curl', 3, 8, 12),
        _e('Hammer_Curls', 2, 10, 15),
      ]),
      ProgramDay('Pierna volumen', [
        _e('Front_Barbell_Squat', 3, 6, 10, w: 1),
        _e('Barbell_Hip_Thrust', 3, 8, 12),
        _e('Lying_Leg_Curls', 3, 10, 15),
        _e('Leg_Extensions', 3, 12, 15),
        _e('Seated_Calf_Raise', 3, 12, 15),
      ]),
    ],
  ),
  Program(
    id: 'empuje-tiron-pierna-6',
    name: 'Empuje / Tirón / Pierna × 2 · 6 días',
    summary: 'Tres rutinas que se repiten dos veces por semana: mucho volumen por músculo.',
    forWhom: 'Intermedios o avanzados que priorizan ganar músculo y hacen poco cardio.',
    days: 6,
    levels: {Experience.intermediate, Experience.advanced},
    goals: {TrainingGoal.hypertrophy, TrainingGoal.both},
    equipment: Equipment.gym,
    minutes: 75,
    cardioFriendly: false,
    rotation: 'Empuje, Tirón, Pierna, Empuje, Tirón, Pierna y un día de descanso.',
    routines: [
      ProgramDay('Empuje', [
        _e('Barbell_Bench_Press_-_Medium_Grip', 4, 5, 8, w: 1),
        _e('Standing_Military_Press', 3, 8, 10),
        _e('Incline_Dumbbell_Press', 3, 8, 12),
        _e('Side_Lateral_Raise', 3, 12, 20),
        _e('Triceps_Pushdown_-_Rope_Attachment', 3, 10, 15),
        _e('Cable_Rope_Overhead_Triceps_Extension', 2, 10, 15),
      ]),
      ProgramDay('Tirón', [
        _e('Barbell_Deadlift', 2, 3, 5, w: 2),
        _e('Pullups', 3, 6, 10),
        _e('Seated_Cable_Rows', 3, 8, 12),
        _e('Face_Pull', 3, 12, 15),
        _e('Barbell_Curl', 3, 8, 12),
        _e('Hammer_Curls', 2, 10, 15),
      ]),
      ProgramDay('Pierna', [
        _e('Barbell_Squat', 4, 5, 8, w: 2),
        _e('Romanian_Deadlift', 3, 8, 10),
        _e('Leg_Press', 3, 10, 12),
        _e('Lying_Leg_Curls', 3, 10, 15),
        _e('Standing_Calf_Raises', 4, 10, 15),
      ]),
    ],
  ),
  Program(
    id: 'mancuernas-3',
    name: 'Mancuernas en casa · 3 días',
    summary: 'Cuerpo completo A/B solo con mancuernas y un banco.',
    forWhom: 'Quien entrena en casa: suficiente para ganar músculo los primeros años.',
    days: 3,
    levels: {Experience.beginner, Experience.intermediate},
    goals: {TrainingGoal.hypertrophy, TrainingGoal.both, TrainingGoal.strength},
    equipment: Equipment.dumbbells,
    minutes: 45,
    cardioFriendly: true,
    rotation: 'A, B, A una semana y B, A, B la siguiente.',
    routines: [
      ProgramDay('Mancuernas A', [
        _e('Goblet_Squat', 3, 8, 12),
        _e('Dumbbell_Bench_Press', 3, 8, 12),
        _e('One-Arm_Dumbbell_Row', 3, 8, 12),
        _e('Stiff-Legged_Dumbbell_Deadlift', 3, 10, 12),
        _e('Side_Lateral_Raise', 2, 12, 20),
      ]),
      ProgramDay('Mancuernas B', [
        _e('Split_Squat_with_Dumbbells', 3, 8, 12),
        _e('Dumbbell_Shoulder_Press', 3, 8, 12),
        _e('Pushups', 3, 8, 20),
        _e('Dumbbell_Incline_Row', 3, 10, 12),
        _e('Dumbbell_Bicep_Curl', 2, 10, 15),
        _e('Crunches', 2, 12, 20),
      ]),
    ],
  ),
  Program(
    id: 'peso-corporal-3',
    name: 'Peso corporal · 3 días',
    summary: 'Cuerpo completo sin pesas. Necesitas una barra de dominadas (o una mesa firme para el remo invertido).',
    forWhom: 'Quien entrena en casa o viajando, o complementa mucho cardio.',
    days: 3,
    levels: {Experience.beginner, Experience.intermediate},
    goals: {TrainingGoal.both, TrainingGoal.hypertrophy, TrainingGoal.strength},
    equipment: Equipment.bodyweight,
    minutes: 40,
    cardioFriendly: true,
    rotation: 'A, B, A una semana y B, A, B la siguiente.',
    routines: [
      ProgramDay('Peso corporal A', [
        _e('Bodyweight_Squat', 3, 12, 20),
        _e('Pushups', 3, 6, 15),
        _e('Inverted_Row', 3, 6, 12),
        _e('Single_Leg_Glute_Bridge', 3, 10, 15),
        _e('Crunches', 3, 12, 20),
      ]),
      ProgramDay('Peso corporal B', [
        _e('Bodyweight_Walking_Lunge', 3, 10, 16),
        _e('Chin-Up', 3, 3, 8),
        _e('Dips_-_Triceps_Version', 3, 6, 12),
        _e('Hanging_Leg_Raise', 3, 6, 12),
      ]),
    ],
  ),
];

Program? programById(String? id) => programs.where((p) => p.id == id).firstOrNull;

/// Días de fuerza que conviene sugerir: con mucho cardio o poca experiencia, menos.
int strengthDaysFor(ProgramAnswers a) {
  var days = a.days;
  if (a.cardioDays >= 6) {
    days = days.clamp(1, 2);
  } else if (a.cardioDays >= 4) {
    days = days.clamp(1, 3);
  }
  if (a.experience == Experience.beginner) days = days.clamp(1, 4);
  return days.clamp(2, 6);
}

class ProgramMatch {
  const ProgramMatch({required this.program, required this.score, required this.reasons});

  final Program program;
  final int score;
  final List<String> reasons;
}

bool _equipmentFits(Equipment program, Equipment available) => switch (program) {
      Equipment.gym => available == Equipment.gym,
      Equipment.dumbbells => available != Equipment.bodyweight,
      Equipment.bodyweight => true,
    };

/// Los programas que mejor calzan, del más al menos recomendado (hasta `limit`).
List<ProgramMatch> recommendPrograms(ProgramAnswers a, {int limit = 3}) {
  final days = strengthDaysFor(a);
  final matches = <ProgramMatch>[];
  for (final p in programs) {
    // Menos días de los pedidos sirve; más, no.
    if (!_equipmentFits(p.equipment, a.equipment) || p.days > days || p.days < days - 1) continue;
    var score = p.days == days ? 6 : 2;
    final reasons = <String>[p.days == days ? 'Calza con tus $days días de fuerza' : 'Con ${p.days} días te queda uno libre'];
    if (p.levels.contains(a.experience)) {
      score += 3;
    } else {
      score -= 4;
      reasons.add(a.experience == Experience.beginner ? 'Exigente para quien recién empieza' : 'Pensado para quien recién empieza');
    }
    if (p.goals.contains(a.goal)) {
      score += 3;
      reasons.add('Apunta a tu objetivo: ${a.goal.label.toLowerCase()}');
      // Un programa hecho solo para ese objetivo gana a uno general.
      if (p.goals.length == 1) score += 2;
    }
    if (p.minutes <= a.minutes) {
      score += 1;
    } else {
      score -= 2;
      reasons.add('Sesiones de unos ${p.minutes} min, más de lo que tienes');
    }
    if (a.cardioDays >= 3) {
      score += p.cardioFriendly ? 2 : -2;
      if (p.cardioFriendly) reasons.add('Poca fatiga de pierna: convive con ${a.cardioDays} días de cardio');
    }
    if (p.equipment == a.equipment) score += 1;
    matches.add(ProgramMatch(program: p, score: score, reasons: reasons));
  }
  matches.sort((x, y) => y.score.compareTo(x.score));
  return matches.take(limit).toList();
}

/// Consejos para combinar fuerza y cardio según las respuestas.
List<String> concurrentTips(ProgramAnswers a) {
  final tips = <String>[];
  final days = strengthDaysFor(a);
  if (days < a.days) {
    tips.add(a.experience == Experience.beginner && a.cardioDays < 4
        ? 'Para empezar, $days días de fuerza bastan: progresarás igual y te recuperarás mejor.'
        : 'Con ${a.cardioDays} días de cardio te sugerimos $days días de fuerza: más días suman fatiga sin sumar resultados.');
  }
  if (a.cardioDays > 0) {
    tips.add('Si haces fuerza y cardio el mismo día, sepáralos al menos 6 horas; si no se puede, cardio primero y fuerza después.');
    final sport = switch (a.cardio) {
      CardioType.running => 'tu fondo o tus series de carrera',
      CardioType.cycling => 'tu salida larga o tus intervalos en bici',
      CardioType.swimming => 'tu sesión de natación más exigente',
      CardioType.mixed => 'tu sesión de competencia o simulacro',
    };
    tips.add('Evita la pierna pesada el día antes de $sport.');
  }
  if (a.cardioDays >= 3 && a.goal != TrainingGoal.endurance) {
    tips.add('Con tanto cardio, cuida comer suficiente: un déficit grande frena la ganancia de fuerza y músculo.');
  }
  if (a.goal == TrainingGoal.endurance) {
    tips.add('Pocas repeticiones con carga alta mejoran la economía de carrera sin ganar mucho peso.');
  }
  return tips;
}

/// Rutinas listas para guardar: series de calentamiento y efectivas con su rango de repeticiones.
List<({String name, List<RoutineExercise> exercises})> routinesFromProgram(Program p) => [
      for (final day in p.routines)
        (
          name: day.name,
          exercises: [
            for (final e in day.exercises)
              RoutineExercise(exerciseId: e.exerciseId, sets: [
                for (var i = 0; i < e.warmups; i++) const StrengthSet(type: SetType.warmup, reps: 8),
                for (var i = 0; i < e.sets; i++)
                  // Con tope (aunque sea igual al mínimo) se sugiere subir el peso al alcanzarlo.
                  StrengthSet(reps: e.repsMin.toDouble(), repsMax: e.repsMax.toDouble()),
              ]),
          ],
        ),
    ];
