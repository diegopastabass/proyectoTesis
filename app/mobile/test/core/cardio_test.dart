import 'package:asistente_deportivo/core/cardio/activity.dart';
import 'package:asistente_deportivo/core/cardio/geo.dart';
import 'package:asistente_deportivo/core/cardio/track.dart';
import 'package:flutter_test/flutter_test.dart';

/// Metros por grado de latitud.
const mPerDeg = 111194.93;

/// Ruta hacia el norte a `speed` m/s, un punto por segundo, con altura opcional.
List<TrackPoint> line({required int seconds, double speed = 3, int t0 = 0, double lat0 = -33.45, double Function(int s)? alt}) => [
      for (var s = 0; s <= seconds; s++)
        TrackPoint(lat: lat0 + s * speed / mPerDeg, lng: -70.66, t: t0 + s * 1000, alt: alt?.call(s), accuracy: 5),
    ];

void main() {
  group('geometría', () {
    test('haversine y polilínea codificada', () {
      expect(haversine(-33.45, -70.66, -33.45 + 1000 / mPerDeg, -70.66), closeTo(1000, 0.5));
      // Ejemplo de la documentación de Google.
      const pts = [LatLng(38.5, -120.2), LatLng(40.7, -120.95), LatLng(43.252, -126.453)];
      expect(encodePolyline(pts), '_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@'), pts);
    });

    test('simplificar conserva extremos y quita puntos alineados', () {
      final pts = [for (var i = 0; i <= 100; i++) LatLng(-33.45 + i / mPerDeg, -70.66)];
      expect(simplify(pts, 2), [pts.first, pts.last]);
      final zigzag = [for (var i = 0; i <= 400; i++) LatLng(-33.45 + i * 10 / mPerDeg, -70.66 + (i.isEven ? 0 : 0.001))];
      expect(simplifyTo(zigzag, 50).length, lessThanOrEqualTo(50));
    });
  });

  group('métricas de la ruta', () {
    test('distancia, tiempo en movimiento y parciales por kilómetro', () {
      // 2,5 km a 3 m/s (5:33 min/km).
      final acc = TrackAccumulator.replay([line(seconds: 833)]);
      expect(acc.distanceM, closeTo(2499, 2));
      expect(acc.movingS, 833);
      expect(acc.maxSpeedMs, closeTo(3, 0.01));
      expect(acc.splits.map((s) => s.paceSPerKm.round()), [333, 333]);
      final all = acc.splitsWithRemainder();
      expect((all.length, all.last.distanceM.round()), (3, 499));
    });

    test('las detenciones no suman tiempo en movimiento', () {
      final walk = line(seconds: 100);
      final stop = [for (var s = 1; s <= 60; s++) TrackPoint(lat: walk.last.lat, lng: walk.last.lng, t: walk.last.t + s * 1000, accuracy: 5)];
      final acc = TrackAccumulator.replay([[...walk, ...stop]]);
      expect(acc.movingS, 100);
    });

    test('la pausa no suma la distancia entre tramos', () {
      final a = line(seconds: 100);
      final b = line(seconds: 100, t0: 300000, lat0: -33.40);
      expect(TrackAccumulator.replay([a, b]).distanceM, closeTo(600, 1));
    });

    test('el desnivel ignora el ruido del GPS y suma subidas reales', () {
      final noisy = TrackAccumulator.replay([line(seconds: 300, alt: (s) => 500 + (s.isEven ? 2.5 : -2.5))]);
      expect(noisy.gainM + noisy.lossM, lessThan(5));
      final climb = TrackAccumulator.replay([line(seconds: 300, alt: (s) => 500 + s * 0.2)]);
      expect(climb.gainM, closeTo(60, 5));
      expect(climb.lossM, 0);
      expect((climb.maxAltM! > 555, climb.minAltM! < 502), (true, true));
    });

    test('descarta puntos imprecisos y saltos imposibles', () {
      final p = TrackPoint(lat: -33.45, lng: -70.66, t: 0, accuracy: 5);
      expect(acceptPoint(null, p), isTrue);
      expect(acceptPoint(p, TrackPoint(lat: -33.45, lng: -70.66, t: 1000, accuracy: 80)), isFalse);
      expect(acceptPoint(p, TrackPoint(lat: -33.44, lng: -70.66, t: 1000, accuracy: 5)), isFalse); // 1,1 km en 1 s
      expect(acceptPoint(p, TrackPoint(lat: -33.45, lng: -70.66, t: 0)), isFalse);
    });
  });

  group('grabación', () {
    test('pausa, reanuda y descuenta el tiempo pausado', () {
      final r = Recording(id: 'r', discipline: Discipline.running, startedAt: 0);
      for (final p in line(seconds: 100)) {
        r.add(p);
      }
      r.pause(100000);
      expect(r.add(TrackPoint(lat: -33.0, lng: -70.0, t: 150000)), isFalse);
      r.resume(160000);
      for (final p in line(seconds: 100, t0: 160000, lat0: -33.40)) {
        r.add(p);
      }
      final s = r.stats(260000);
      expect((s.durationS, s.distanceM.round(), r.segments.length), (200, 600, 2));
    });

    test('sobrevive a cerrar la app y al terminar calcula lo mismo', () {
      final r = Recording(id: 'r', discipline: Discipline.cycling, startedAt: 0);
      for (final p in line(seconds: 600, speed: 8, alt: (s) => 600 + s * 0.1)) {
        r.add(p);
      }
      final copy = Recording.fromJson(r.toJson());
      expect(copy.stats(600000).toMap(), r.stats(600000).toMap());
      final done = finishRecording(copy, now: 600000);
      expect(done.activity.stats.toMap(), r.stats(600000).toMap());
      expect((done.activity.discipline, done.activity.title.startsWith('Ruta en bici')), (Discipline.cycling, true));
      expect(done.activity.stats.avgSpeedMs, closeTo(8, 0.01));
      expect(decodePolyline(done.activity.preview).length, lessThanOrEqualTo(200));
    });
  });

  group('guardar y leer', () {
    final r = Recording(id: 'a1', discipline: Discipline.trekking, startedAt: 1700000000000);
    for (final p in line(seconds: 4500, speed: 1.2, t0: 1700000000000, alt: (s) => 800 + s * 0.05)) {
      r.add(p);
    }
    final done = finishRecording(r, now: 1700000000000 + 4500000, title: '  Cerro Manquehue ', description: 'Con niebla');

    test('el resumen se guarda y lee igual (con estado de respaldo solo en local)', () {
      final a = done.activity;
      expect((a.title, a.description), ('Cerro Manquehue', 'Con niebla'));
      expect(CardioActivity.fromMap(a.id, a.toMap(local: true)).toMap(local: true), a.toMap(local: true));
      expect(a.toMap().containsKey('syncState'), isFalse);
    });

    test('la ruta se reparte en documentos y se reconstruye', () {
      final chunks = trackToChunks(done.track, done.activity.startedAt);
      expect(chunks.length, 3); // 4501 puntos en trozos de 2000
      final back = trackFromChunks(chunks, done.activity.startedAt);
      expect(back.points.length, done.track.points.length);
      final acc = TrackAccumulator.replay(back.segments);
      expect(acc.distanceM, closeTo(done.activity.stats.distanceM, 5));
      expect(acc.gainM, closeTo(done.activity.stats.gainM, 2));
    });

    test('perfil de altura y parciales', () {
      final profile = elevationProfile(done.track);
      expect(profile.length, inInclusiveRange(100, 130));
      expect(profile.last.$1, closeTo(5.4, 0.05));
      expect(splitsOf(done.track).length, 6);
    });
  });

  group('calorías', () {
    test('MET según la velocidad y la disciplina', () {
      expect(metFor(Discipline.running, 9.7), 9.8);
      expect(metFor(Discipline.running, 10.25), closeTo(10.15, 0.01));
      expect(metFor(Discipline.cycling, 40), 15.8);
      expect(metFor(Discipline.trekking, 4), closeTo(5.65, 0.01));
      // 1 h en movimiento a 10,8 km/h con 70 kg.
      const s = CardioStats(distanceM: 10800, durationS: 3700, movingS: 3600);
      expect(estimateKcal(Discipline.running, s, 70), 735);
      expect(estimateKcal(Discipline.running, s, null), isNull);
    });
  });
}
