import 'dart:math' as math;

import 'package:asistente_deportivo/core/cardio/activity.dart';
import 'package:asistente_deportivo/core/strength/models.dart';
import 'package:asistente_deportivo/core/strength/session.dart';
import 'package:asistente_deportivo/core/training/load.dart';
import 'package:flutter_test/flutter_test.dart';

int at(String date, [int hour = 19]) => DateTime.parse('${date}T${hour.toString().padLeft(2, '0')}:00:00').millisecondsSinceEpoch;

Workout workout(String date, {int minutes = 60, int? rpe}) =>
    Workout(id: 'w-$date', routineId: null, name: 'Pierna', date: date, startedAt: at(date), finishedAt: at(date) + minutes * 60000, exercises: const [], rpe: rpe);

CardioActivity activity(String date, {Discipline discipline = Discipline.running, double km = 10, double minutes = 50, double gainM = 0, int? rpe}) =>
    CardioActivity(
      id: 'a-$date',
      discipline: discipline,
      title: 'x',
      startedAt: at(date, 8),
      finishedAt: at(date, 8) + (minutes * 60000).round(),
      stats: CardioStats(distanceM: km * 1000, durationS: minutes * 60, movingS: minutes * 60, gainM: gainM),
      updatedAt: 0,
      rpe: rpe,
    );

SessionLoad session(String date, LoadKind kind, double load) => SessionLoad(date: date, kind: kind, minutes: load / 5, rpe: 5, estimated: false);

void main() {
  group('carga de una sesión (RPE × minutos)', () {
    test('fuerza: con RPE, sin RPE y sesión olvidada abierta', () {
      final hard = strengthSessionLoad(workout('2026-10-20', rpe: 7));
      expect((hard.load, hard.minutes, hard.estimated, hard.kind), (420.0, 60.0, false, LoadKind.strength));

      final unknown = strengthSessionLoad(workout('2026-10-20'));
      expect((unknown.rpe, unknown.estimated, unknown.load), (defaultStrengthRpe, true, 360.0));

      // Terminada al día siguiente: no suma 15 horas.
      expect(strengthSessionLoad(workout('2026-10-20', minutes: 900, rpe: 5)).minutes, maxStrengthMinutes);
    });

    test('cardio: usa el tiempo sin pausas y el RPE indicado', () {
      final l = cardioSessionLoad(activity('2026-10-21', minutes: 45, rpe: 8));
      expect((l.date, l.kind, l.minutes, l.load, l.estimated), ('2026-10-21', LoadKind.cardio, 45.0, 360.0, false));
    });

    test('cardio sin RPE: se estima por la velocidad, y en trekking también por la subida', () {
      // 10 km en 50 min = 12 km/h: carrera exigente.
      expect(estimateCardioRpe(Discipline.running, activity('2026-10-21', km: 10, minutes: 50).stats), 7);
      // 8 km/h: trote suave.
      expect(estimateCardioRpe(Discipline.running, activity('2026-10-21', km: 8, minutes: 60).stats), 5);
      // 16 km/h en bici: paseo.
      expect(estimateCardioRpe(Discipline.cycling, activity('2026-10-21', km: 16, minutes: 60).stats), 4);
      // Trekking a 4 km/h: plano suma menos que con 400 m de subida por hora.
      final flat = activity('2026-10-21', discipline: Discipline.trekking, km: 8, minutes: 120);
      final hill = activity('2026-10-21', discipline: Discipline.trekking, km: 8, minutes: 120, gainM: 800);
      expect(estimateCardioRpe(Discipline.trekking, hill.stats), estimateCardioRpe(Discipline.trekking, flat.stats) + 1);
      expect(cardioSessionLoad(flat).estimated, isTrue);
    });

    test('escala CR-10', () {
      expect((rpeLabel(1), rpeLabel(5), rpeLabel(10)), ('Muy, muy suave', 'Duro', 'Máximo'));
    });
  });

  group('carga aguda y crónica', () {
    test('una sesión sube la ATL más rápido que la CTL', () {
      final s = const LoadState().next(100);
      expect(s.atl, closeTo(100 * (1 - math.exp(-1 / 7)), 1e-9));
      expect(s.ctl, closeTo(100 * (1 - math.exp(-1 / 42)), 1e-9));
      expect(s.tsb, lessThan(0));
    });

    test('con la misma carga todos los días, ATL y CTL llegan a esa carga', () {
      var s = const LoadState();
      for (var i = 0; i < 365; i++) {
        s = s.next(300);
      }
      expect(s.atl, closeTo(300, 0.01));
      expect(s.ctl, closeTo(300, 0.1));
      expect(s.ratio, closeTo(1, 0.001));
    });

    test('una semana con el doble de carga dispara la razón ATL/CTL', () {
      var s = const LoadState(atl: 300, ctl: 300);
      for (var i = 0; i < 7; i++) {
        s = s.next(600);
      }
      expect(s.ratio, closeTo(1.415, 0.01));
      expect(ratioZone(s.ratio!), RatioZone.high);
    });

    test('zonas de la razón', () {
      expect([0.5, 0.8, 1.0, 1.3, 1.31, 1.5, 1.6].map(ratioZone),
          [RatioZone.low, RatioZone.normal, RatioZone.normal, RatioZone.normal, RatioZone.high, RatioZone.high, RatioZone.veryHigh]);
      expect(const LoadState(atl: 50, ctl: 0.5).ratio, isNull);
    });
  });

  group('serie diaria', () {
    test('separa fuerza y cardio, suma el día y rellena los días de descanso', () {
      final series = loadSeries([
        session('2026-10-01', LoadKind.strength, 400),
        session('2026-10-01', LoadKind.cardio, 200),
        session('2026-10-03', LoadKind.cardio, 300),
        session('2026-10-09', LoadKind.strength, 999), // después del día pedido
      ], to: '2026-10-04');

      expect(series.days.map((d) => d.date), ['2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04']);
      expect(series.days.map((d) => (d.strengthLoad, d.cardioLoad)), [(400.0, 200.0), (0.0, 0.0), (0.0, 300.0), (0.0, 0.0)]);
      final first = series.days.first;
      expect(first.total.atl, closeTo(first.strength.atl + first.cardio.atl, 1e-9));
      // Sin entrenar, la carga aguda baja.
      expect(series.days[1].total.atl, lessThan(first.total.atl));
      expect((series.firstSession, series.historyDays, series.reliable), ('2026-10-01', 4, false));
    });

    test('es confiable desde 4 semanas de historial', () {
      expect(loadSeries([session('2026-09-01', LoadKind.cardio, 100)], to: '2026-09-28').reliable, isTrue);
      expect(loadSeries([session('2026-09-01', LoadKind.cardio, 100)], to: '2026-09-27').reliable, isFalse);
      expect(loadSeries(const [], to: '2026-09-27').days, isEmpty);
    });

    test('junta los entrenamientos y las rutas', () {
      final series = trainingLoad(
        workouts: [workout('2026-10-20', rpe: 7)],
        activities: [activity('2026-10-21', minutes: 45, rpe: 8)],
        to: '2026-10-21',
      );
      expect(series.days.map((d) => (d.strengthLoad, d.cardioLoad)), [(420.0, 0.0), (0.0, 360.0)]);
    });
  });

  group('el RPE se guarda', () {
    test('en la sesión de fuerza', () {
      final active = emptyWorkout(at('2026-10-20'));
      expect(finishWorkout(active, at('2026-10-20', 20), (id) => id, rpe: 8).toMap()['rpe'], 8);
      expect(finishWorkout(active, at('2026-10-20', 20), (id) => id).toMap().containsKey('rpe'), isFalse);
      expect(workout('2026-10-20').withRpe(6).rpe, 6);
    });

    test('en la actividad de cardio', () {
      final a = activity('2026-10-21', rpe: 6);
      expect(CardioActivity.fromMap(a.id, a.toMap()).rpe, 6);
      expect(CardioActivity.fromMap(a.id, activity('2026-10-21').toMap()).rpe, isNull);
      expect(a.copyWith(title: 'otro').rpe, 6);
      final r = Recording(id: 'r', discipline: Discipline.running, startedAt: 0);
      expect(finishRecording(r, now: 60000, rpe: 4).activity.rpe, 4);
    });
  });
}
