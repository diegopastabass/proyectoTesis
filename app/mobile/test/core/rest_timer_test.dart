import 'package:asistente_deportivo/core/strength/rest_sync.dart';
import 'package:asistente_deportivo/core/strength/session.dart';
import 'package:flutter_test/flutter_test.dart';

const now = 1000000;

RestTimer running(int leftMs, {int seconds = 90}) => RestTimer(endsAt: now + leftMs, seconds: seconds);

RestTimer paused(int leftMs, {int seconds = 90}) => RestTimer(endsAt: now, seconds: seconds, pausedLeft: leftMs);

void main() {
  group('pausa del descanso', () {
    test('pausar congela lo que falta y seguir lo retoma', () {
      final r = running(60000);
      final p = r.pause(now + 10000);
      expect(p.paused, isTrue);
      expect(p.remaining(now + 999999), 50, reason: 'en pausa no avanza');
      expect(p.progress(now + 999999), closeTo(50 / 90, 1e-9));
      final back = p.resume(now + 30000);
      expect(back.paused, isFalse);
      expect(back.endsAt, now + 30000 + 50000);
      expect(identical(r.resume(now), r), isTrue);
      expect(identical(p.pause(now), p), isTrue);
    });

    test('ajustar ±15 s también en pausa', () {
      expect(adjustRest(paused(20000), 15, now)!.pausedLeft, 35000);
      expect(adjustRest(paused(10000), -15, now), isNull);
      expect(adjustRest(running(20000), 15, now)!.endsAt, now + 35000);
    });

    test('la pausa sobrevive a cerrar la app', () {
      final w = ActiveWorkout(name: 'Pecho', startedAt: 0, rest: paused(42000));
      expect(ActiveWorkout.fromJson(w.toJson()).rest!.pausedLeft, 42000);
      expect(ActiveWorkout.fromJson(ActiveWorkout(name: 'x', startedAt: 0, rest: running(5000)).toJson()).rest!.paused, isFalse);
    });
  });

  group('qué decirle al sistema', () {
    test('empezar, pausar, seguir, ajustar y saltar', () {
      expect(restCommand(null, running(90000), now), const StartRest(90));
      expect(restCommand(running(60000), running(60000).pause(now), now), isA<PauseRest>());
      expect(restCommand(paused(40000), paused(40000).resume(now), now), const ResumeRest(40));
      expect(restCommand(running(60000), running(75000), now), const StartRest(75), reason: '+15 s reemplaza la cuenta');
      expect(restCommand(paused(30000), paused(45000), now), const StartRest(45, paused: true));
      expect(restCommand(running(30000), null, now), isA<CancelRest>(), reason: 'saltar');
      expect(restCommand(paused(30000), null, now), isA<CancelRest>());
      expect(restCommand(running(30000), running(30000), now), isNull);
      expect(restCommand(null, null, now), isNull);
    });

    test('si llegó a cero solo, quitarlo no apaga la alarma que está sonando', () {
      expect(restCommand(running(0), null, now), isNull);
      expect(restCommand(running(-5000), null, now), isNull);
      // Otro descanso después de uno terminado empieza de cero.
      expect(restCommand(running(-5000), running(60000), now), const StartRest(60));
    });
  });

  group('lo que llega desde la pantalla bloqueada', () {
    test('pausar, seguir y cancelar desde fuera', () {
      final r = running(60000);
      final p = applyRestSnapshot(r, const RestAlarmSnapshot(state: RestAlarmPhase.paused, leftMs: 41000), now)!;
      expect((p.paused, p.pausedLeft), (true, 41000));
      final back = applyRestSnapshot(p, const RestAlarmSnapshot(state: RestAlarmPhase.countdown, endsAt: now + 41000), now)!;
      expect((back.paused, back.endsAt, back.seconds), (false, now + 41000, 90));
      expect(applyRestSnapshot(r, null, now), isNull, reason: 'cancelado');
      expect(applyRestSnapshot(r, const RestAlarmSnapshot(state: RestAlarmPhase.alerting), now), isNull, reason: 'sonó la alarma');
    });

    test('sin cambios reales devuelve el mismo descanso', () {
      final r = running(60000);
      expect(identical(applyRestSnapshot(r, const RestAlarmSnapshot(state: RestAlarmPhase.countdown, endsAt: now + 60400), now), r), isTrue);
      final p = paused(30000);
      expect(identical(applyRestSnapshot(p, const RestAlarmSnapshot(state: RestAlarmPhase.paused, leftMs: 30000), now), p), isTrue);
    });

    test('el estado llega del canal nativo como mapa', () {
      final s = RestAlarmSnapshot.fromMap({'state': 'countdown', 'endsAt': 123});
      expect((s!.state, s.endsAt), (RestAlarmPhase.countdown, 123));
      expect(RestAlarmSnapshot.fromMap(null), isNull);
      expect(RestAlarmSnapshot.fromMap({'state': 'otro'}), isNull);
    });
  });
}
