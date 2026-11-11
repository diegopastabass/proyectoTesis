/// Perfil del deportista (CU-12, R13, RNF-14): lo que declara en el cuestionario
/// inicial y cómo se clasifica por nivel y orientación.
///
/// El cuestionario tiene 10 preguntas (requisito: máximo 10): experiencia,
/// objetivo, días disponibles, minutos por sesión, equipamiento y disciplinas de
/// cardio, que se guardan aquí, y edad, sexo, estatura y peso, que van al perfil
/// corporal (`BodyProfile`) y al registro de peso, donde ya los usa el gasto calórico.
library;

import '../cardio/activity.dart';
import '../strength/programs.dart';
import 'reason.dart';

/// Objetivo principal. Incluye "fuerza y resistencia por igual", que es el caso
/// del deportista híbrido al que apunta la tesis.
enum AthleteGoal {
  strength('Ganar fuerza'),
  muscle('Ganar músculo'),
  hybrid('Fuerza y resistencia por igual'),
  performance('Rendir mejor en mi deporte de resistencia'),
  fatLoss('Bajar de peso');

  const AthleteGoal(this.label);

  final String label;

  static AthleteGoal? tryParse(Object? v) => AthleteGoal.values.where((g) => g.name == v).firstOrNull;
}

enum Level {
  beginner('Principiante'),
  intermediate('Intermedio'),
  advanced('Avanzado');

  const Level(this.label);

  final String label;
}

/// Hacia dónde se inclina el plan (RNF-14: más fuerza, más resistencia o equilibrada).
enum Orientation {
  strength('Más fuerza'),
  balanced('Equilibrada'),
  endurance('Más resistencia');

  const Orientation(this.label);

  final String label;
}

/// Respuestas guardadas del cuestionario (`users/{uid}.athlete`).
class AthleteProfile {
  const AthleteProfile({
    required this.experience,
    required this.goal,
    required this.days,
    this.minutes = 60,
    this.equipment = Equipment.gym,
    this.disciplines = const {},
    this.answeredAt,
  });

  static AthleteProfile? fromMap(Object? data) {
    if (data is! Map) return null;
    final experience = Experience.values.where((e) => e.name == data['experience']).firstOrNull;
    final goal = AthleteGoal.tryParse(data['goal']);
    final days = (data['days'] as num?)?.toInt();
    if (experience == null || goal == null || days == null) return null;
    return AthleteProfile(
      experience: experience,
      goal: goal,
      days: days.clamp(minDays, maxDays),
      minutes: (data['minutes'] as num?)?.toInt() ?? 60,
      equipment: Equipment.values.where((e) => e.name == data['equipment']).firstOrNull ?? Equipment.gym,
      disciplines: {
        for (final d in data['disciplines'] as List? ?? const [])
          if (Discipline.values.any((x) => x.name == d)) Discipline.from(d),
      },
      answeredAt: data['answeredAt'] as String?,
    );
  }

  static const minDays = 2;
  static const maxDays = 7;

  final Experience experience;
  final AthleteGoal goal;

  /// Días por semana que puede entrenar, sumando fuerza y cardio.
  final int days;

  /// Tiempo máximo por sesión.
  final int minutes;
  final Equipment equipment;

  /// Disciplinas de resistencia que practica (vacío = solo fuerza). La tesis las
  /// acota a ciclismo, running y trekking.
  final Set<Discipline> disciplines;

  /// Cuándo respondió el cuestionario (YYYY-MM-DD).
  final String? answeredAt;

  AthleteProfile copyWith({Experience? experience, AthleteGoal? goal, int? days, int? minutes, Equipment? equipment, Set<Discipline>? disciplines, String? answeredAt}) =>
      AthleteProfile(
        experience: experience ?? this.experience,
        goal: goal ?? this.goal,
        days: days ?? this.days,
        minutes: minutes ?? this.minutes,
        equipment: equipment ?? this.equipment,
        disciplines: disciplines ?? this.disciplines,
        answeredAt: answeredAt ?? this.answeredAt,
      );

  Map<String, dynamic> toMap() => {
        'experience': experience.name,
        'goal': goal.name,
        'days': days,
        'minutes': minutes,
        'equipment': equipment.name,
        'disciplines': [for (final d in Discipline.values) if (disciplines.contains(d)) d.name],
        'answeredAt': ?answeredAt,
      };
}

/// Perfil de ejemplo (modo demostración y capturas del documento).
const exampleAthlete = AthleteProfile(
  experience: Experience.intermediate,
  goal: AthleteGoal.hybrid,
  days: 5,
  minutes: 60,
  equipment: Equipment.gym,
  disciplines: {Discipline.cycling},
);

/// Clasificación del perfil, con sus razones.
class Classification {
  const Classification({required this.level, required this.orientation, required this.strengthSessions, required this.cardioSessions, required this.why});

  final Level level;
  final Orientation orientation;

  /// Sesiones de fuerza y de cardio por semana. Pueden sumar más que los días
  /// disponibles: entonces un día tiene las dos, separadas al menos 6 horas.
  final int strengthSessions;
  final int cardioSessions;
  final List<Reason> why;
}

Level _level(Experience e) => switch (e) {
      Experience.beginner => Level.beginner,
      Experience.intermediate => Level.intermediate,
      Experience.advanced => Level.advanced,
    };

Orientation _orientation(AthleteProfile p) {
  if (p.disciplines.isEmpty) return Orientation.strength;
  return switch (p.goal) {
    AthleteGoal.strength || AthleteGoal.muscle => Orientation.strength,
    AthleteGoal.performance => Orientation.endurance,
    AthleteGoal.hybrid || AthleteGoal.fatLoss => Orientation.balanced,
  };
}

/// Nivel y orientación a partir de lo declarado, y cómo repartir los días.
///
/// El nivel es el declarado; con algunas semanas de registro se podrá corregir
/// con lo observado (constancia y carga crónica), que es la fase 4 del motor.
Classification classify(AthleteProfile p) {
  final level = _level(p.experience);
  final orientation = _orientation(p);
  final d = p.days;
  final why = <Reason>[
    Reason('Nivel ${level.label.toLowerCase()}: llevas ${p.experience.label.toLowerCase()} entrenando.'),
  ];

  late int strength;
  late int cardio;
  switch (orientation) {
    case Orientation.strength:
      // El cardio, si lo hay, como complemento: 1 o 2 sesiones.
      cardio = p.disciplines.isEmpty ? 0 : (d >= 5 ? 2 : (d >= 3 ? 1 : 0));
      strength = d - cardio;
      why.add(Reason(
        p.disciplines.isEmpty
            ? 'Orientación a la fuerza: no indicaste deportes de resistencia.'
            : 'Orientación a la fuerza: tu objetivo es ${p.goal.label.toLowerCase()}, con el cardio como complemento.',
      ));
    case Orientation.balanced:
      strength = (d / 2).round().clamp(2, 4);
      cardio = (d - strength).clamp(1, 4);
      why.add(Reason(p.goal == AthleteGoal.fatLoss
          ? 'Orientación equilibrada: para bajar de peso conviene sumar cardio sin dejar la fuerza, que ayuda a conservar el músculo.'
          : 'Orientación equilibrada: buscas mejorar en fuerza y en resistencia.'));
    case Orientation.endurance:
      strength = d >= 3 ? 2 : 1;
      cardio = d - strength;
      why.add(const Reason('Orientación a la resistencia: tu deporte es la prioridad y la fuerza lo apoya con pocas sesiones.', source: Sources.concurrent));
  }
  // Quien recién empieza progresa igual con menos días de fuerza y se recupera mejor.
  if (level == Level.beginner && strength > 4) {
    strength = 4;
    why.add(const Reason('Para empezar, 4 días de fuerza bastan: progresarás igual y te recuperarás mejor.', source: Sources.design));
  }
  // Los programas llegan a 6 días; el séptimo queda de descanso. El cardio, hasta 5 sesiones.
  strength = strength.clamp(1, 6);
  cardio = cardio.clamp(0, 5);
  if (strength + cardio > d) {
    why.add(const Reason('Un día junta fuerza y cardio: hazlos separados al menos 6 horas para que interfieran menos.', source: Sources.concurrent));
  }
  return Classification(level: level, orientation: orientation, strengthSessions: strength, cardioSessions: cardio, why: why);
}

/// Objetivo del cuestionario → objetivo de los programas de fuerza.
TrainingGoal trainingGoalFor(AthleteGoal g) => switch (g) {
      AthleteGoal.strength => TrainingGoal.strength,
      AthleteGoal.muscle => TrainingGoal.hypertrophy,
      AthleteGoal.hybrid || AthleteGoal.fatLoss => TrainingGoal.both,
      AthleteGoal.performance => TrainingGoal.endurance,
    };
