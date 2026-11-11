import 'package:asistente_deportivo/core/cardio/activity.dart';
import 'package:asistente_deportivo/core/strength/programs.dart';
import 'package:asistente_deportivo/core/suggestions/profile.dart';
import 'package:asistente_deportivo/core/suggestions/reason.dart';
import 'package:asistente_deportivo/core/suggestions/weekly_plan.dart';
import 'package:flutter_test/flutter_test.dart';

AthleteProfile athlete({
  Experience experience = Experience.intermediate,
  AthleteGoal goal = AthleteGoal.hybrid,
  int days = 5,
  int minutes = 60,
  Equipment equipment = Equipment.gym,
  Set<Discipline> disciplines = const {Discipline.cycling},
}) =>
    AthleteProfile(experience: experience, goal: goal, days: days, minutes: minutes, equipment: equipment, disciplines: disciplines);

int _next(int d) => d % 7 + 1;

/// Reglas que todo plan debe cumplir, para cualquier perfil.
void expectValidPlan(AthleteProfile p, WeeklyPlan plan) {
  final c = classify(p);
  final label = '${p.toMap()}';
  expect(plan.strength.length, c.strengthSessions, reason: label);
  expect(plan.cardio.length, p.disciplines.isEmpty ? 0 : c.cardioSessions, reason: label);
  expect(plan.trainingWeekdays.length, lessThanOrEqualTo(p.days), reason: 'no usa más días de los disponibles: $label');
  for (var day = 1; day <= 7; day++) {
    final s = plan.on(day);
    expect(s.where((x) => x.kind == SessionKind.strength).length, lessThanOrEqualTo(1), reason: label);
    expect(s.where((x) => x.kind == SessionKind.cardio).length, lessThanOrEqualTo(1), reason: label);
    for (final x in s) {
      expect(x.sharedDay, s.length == 2, reason: 'marca los días compartidos: $label');
    }
  }
  final intensities = plan.cardio.map((s) => s.intensity).toList();
  expect(intensities.where((i) => i == CardioIntensity.intervals).length, lessThanOrEqualTo(1), reason: label);
  expect(intensities.where((i) => i == CardioIntensity.long).length, lessThanOrEqualTo(1), reason: label);
  if (p.experience == Experience.beginner) expect(intensities, isNot(contains(CardioIntensity.intervals)), reason: label);
  expect(plan.plannedLoad, plan.sessions.fold<int>(0, (a, s) => a + s.rpe * s.minutes));
  expect(plan.why, isNotEmpty);
  expect(programById(plan.programId), isNotNull, reason: label);
}

void main() {
  group('clasificación', () {
    test('solo fuerza: orientación a la fuerza, sin cardio', () {
      final c = classify(athlete(goal: AthleteGoal.muscle, days: 4, disciplines: const {}));
      expect((c.level, c.orientation, c.strengthSessions, c.cardioSessions), (Level.intermediate, Orientation.strength, 4, 0));
    });

    test('híbrido: reparte los días entre fuerza y cardio', () {
      final c = classify(athlete(days: 5));
      expect((c.orientation, c.strengthSessions, c.cardioSessions), (Orientation.balanced, 3, 2));
    });

    test('resistencia: dos días de fuerza y el resto de cardio', () {
      final c = classify(athlete(goal: AthleteGoal.performance, days: 6, experience: Experience.advanced));
      expect((c.level, c.orientation, c.strengthSessions, c.cardioSessions), (Level.advanced, Orientation.endurance, 2, 4));
    });

    test('fuerza con cardio de complemento', () {
      final c = classify(athlete(goal: AthleteGoal.strength, days: 5));
      expect((c.orientation, c.strengthSessions, c.cardioSessions), (Orientation.strength, 3, 2));
    });

    test('bajar de peso con cardio es equilibrado; sin cardio, fuerza', () {
      expect(classify(athlete(goal: AthleteGoal.fatLoss, days: 4)).orientation, Orientation.balanced);
      expect(classify(athlete(goal: AthleteGoal.fatLoss, days: 4, disciplines: const {})).orientation, Orientation.strength);
    });

    test('principiante con muchos días: hasta 4 de fuerza', () {
      final c = classify(athlete(experience: Experience.beginner, goal: AthleteGoal.muscle, days: 6, disciplines: const {}));
      expect(c.strengthSessions, 4);
      expect(c.why.map((r) => r.text), contains(contains('4 días de fuerza bastan')));
    });

    test('con pocos días un día junta fuerza y cardio, y lo explica', () {
      final c = classify(athlete(days: 2));
      expect(c.strengthSessions + c.cardioSessions, greaterThan(2));
      expect(c.why.where((r) => r.source == Sources.concurrent), isNotEmpty);
    });
  });

  group('cardio', () {
    test('casi todo suave: a lo más intervalos y una larga', () {
      expect(cardioIntensities(1, Level.beginner), [CardioIntensity.easy]);
      expect(cardioIntensities(3, Level.beginner), [CardioIntensity.easy, CardioIntensity.easy, CardioIntensity.long]);
      expect(cardioIntensities(2, Level.intermediate), [CardioIntensity.intervals, CardioIntensity.long]);
      expect(cardioIntensities(4, Level.advanced), [CardioIntensity.easy, CardioIntensity.easy, CardioIntensity.intervals, CardioIntensity.long]);
      expect(cardioIntensities(0, Level.advanced), isEmpty);
    });

    test('rutinas con mucha pierna', () {
      final tp = programById('torso-pierna-4')!;
      expect(tp.routines.map(isLegHeavy), [false, true, false, true]);
      expect(legShare(tp.routines[1]), greaterThan(0.5));
    });
  });

  group('plan semanal', () {
    test('perfil de ejemplo: sin pierna pesada antes de lo exigente y la larga el fin de semana', () {
      final plan = buildWeeklyPlan(exampleAthlete);
      expectValidPlan(exampleAthlete, plan);
      expect(plan.orientation, Orientation.balanced);
      for (final s in plan.strength.where((s) => s.legHeavy)) {
        expect(plan.on(_next(s.weekday)).any((x) => x.demanding), isFalse, reason: '$s');
        expect(plan.on(s.weekday).any((x) => x.demanding), isFalse, reason: '$s');
      }
      final long = plan.cardio.firstWhere((s) => s.intensity == CardioIntensity.long);
      expect(long.weekday, greaterThanOrEqualTo(6));
      expect(plan.sessions.any((s) => s.sharedDay), isFalse, reason: 'con 5 días no hace falta juntar sesiones');
      expect(plan.why.map((r) => r.text), contains(contains('No hay pierna pesada')));
    });

    test('torso/pierna con cardio exigente: la pierna lejos de los intervalos y de la larga', () {
      final p = athlete(goal: AthleteGoal.hybrid, days: 7, disciplines: const {Discipline.running, Discipline.trekking});
      final plan = buildWeeklyPlan(p);
      expectValidPlan(p, plan);
      expect(plan.programId, 'torso-pierna-4');
      for (final s in plan.strength.where((s) => s.legHeavy)) {
        expect(plan.on(_next(s.weekday)).any((x) => x.demanding), isFalse, reason: '$s');
      }
      expect(plan.cardio.firstWhere((s) => s.intensity == CardioIntensity.long).discipline, Discipline.trekking);
      expect(plan.cardio.firstWhere((s) => s.intensity == CardioIntensity.intervals).discipline, Discipline.running);
    });

    test('con gimnasio prefiere un programa de gimnasio si casi empata', () {
      expect(programById(buildWeeklyPlan(exampleAthlete).programId)!.equipment, Equipment.gym);
      expect(programById(buildWeeklyPlan(athlete(equipment: Equipment.bodyweight)).programId)!.equipment, Equipment.bodyweight);
    });

    test('es determinista', () {
      final a = buildWeeklyPlan(exampleAthlete).toMap();
      final b = buildWeeklyPlan(exampleAthlete).toMap();
      expect(a, b);
    });

    test('cumple las reglas para muchos perfiles', () {
      const disciplineSets = [<Discipline>{}, {Discipline.running}, {Discipline.cycling, Discipline.running}, {Discipline.trekking}];
      for (final goal in AthleteGoal.values) {
        for (var days = 2; days <= 7; days++) {
          for (final d in disciplineSets) {
            for (final e in [Experience.beginner, Experience.advanced]) {
              final p = athlete(goal: goal, days: days, disciplines: d, experience: e, equipment: days.isEven ? Equipment.gym : Equipment.dumbbells);
              expectValidPlan(p, buildWeeklyPlan(p));
            }
          }
        }
      }
    });
  });

  group('guardado', () {
    test('perfil y plan se guardan y se leen igual', () {
      final p = exampleAthlete.copyWith(answeredAt: '2026-11-09');
      expect(AthleteProfile.fromMap(p.toMap())!.toMap(), p.toMap());
      expect(AthleteProfile.fromMap({'goal': 'hybrid'}), isNull);
      final plan = buildWeeklyPlan(p).accepted('2026-11-09');
      final back = WeeklyPlan.fromMap(plan.toMap())!;
      expect(back.toMap(), plan.toMap());
      expect(back.createdAt, '2026-11-09');
      expect(back.strengthWeekdays, plan.strengthWeekdays);
      expect(WeeklyPlan.fromMap(null), isNull);
    });

    test('las razones muestran su fuente con un nombre legible', () {
      expect(Sources.label(Sources.concurrent), contains('concurrente'));
      expect(Sources.label('otra'), 'otra');
    });
  });
}
