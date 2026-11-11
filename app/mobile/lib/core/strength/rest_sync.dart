/// Sincronía entre el descanso de la app y el temporizador del sistema (isla
/// dinámica y pantalla bloqueada). Lógica pura: qué decirle al sistema cuando el
/// descanso cambia en la app y cómo aplicar lo que cambió fuera de ella.
library;

import 'session.dart';

sealed class RestCommand {
  const RestCommand();
}

/// Empezar (o reemplazar) la cuenta con los segundos que quedan; si `paused`,
/// queda en pausa de inmediato (se ajustó el tiempo de un descanso en pausa).
class StartRest extends RestCommand {
  const StartRest(this.seconds, {this.paused = false});

  final int seconds;
  final bool paused;

  @override
  bool operator ==(Object other) => other is StartRest && other.seconds == seconds && other.paused == paused;

  @override
  int get hashCode => Object.hash(seconds, paused);

  @override
  String toString() => 'StartRest($seconds${paused ? ', en pausa' : ''})';
}

class PauseRest extends RestCommand {
  const PauseRest();
}

class ResumeRest extends RestCommand {
  const ResumeRest(this.seconds);

  final int seconds;

  @override
  bool operator ==(Object other) => other is ResumeRest && other.seconds == seconds;

  @override
  int get hashCode => seconds.hashCode;
}

class CancelRest extends RestCommand {
  const CancelRest();
}

bool _same(RestTimer? a, RestTimer? b) =>
    a == null ? b == null : b != null && a.endsAt == b.endsAt && a.seconds == b.seconds && a.pausedLeft == b.pausedLeft;

/// Qué decirle al temporizador del sistema cuando el descanso pasa de `before` a
/// `after` en la app. null = nada.
///
/// Si el descanso terminó solo (llegó a cero), quitarlo de la app no cancela la
/// alarma del sistema: está sonando y se apaga desde su propio aviso.
RestCommand? restCommand(RestTimer? before, RestTimer? after, int now) {
  if (_same(before, after)) return null;
  final beforeActive = before != null && (before.paused || before.leftMs(now) > 0);
  if (after == null) return beforeActive ? const CancelRest() : null;
  final seconds = after.remaining(now);
  if (seconds <= 0) return beforeActive ? const CancelRest() : null;
  if (!beforeActive) return after.paused ? StartRest(seconds, paused: true) : StartRest(seconds);
  if (after.paused && !before.paused) return const PauseRest();
  if (!after.paused && before.paused) return ResumeRest(seconds);
  // Se ajustó el tiempo (±15 s) o empezó otro descanso: AlarmKit no cambia la
  // duración de una cuenta, así que se reemplaza por una nueva.
  return StartRest(seconds, paused: after.paused);
}

/// Aplica al descanso de la app lo que pasó en el sistema (`snapshot`). Devuelve
/// el descanso nuevo, el mismo si no hay cambios, o null si ya no hay descanso.
RestTimer? applyRestSnapshot(RestTimer rest, RestAlarmSnapshot? snapshot, int now) {
  if (snapshot == null) {
    // Ya no hay temporizador: se canceló desde la pantalla bloqueada o sonó y se apagó.
    return null;
  }
  switch (snapshot.state) {
    case RestAlarmPhase.alerting:
      return null;
    case RestAlarmPhase.paused:
      final left = snapshot.leftMs ?? rest.leftMs(now);
      return rest.paused && rest.pausedLeft == left ? rest : RestTimer(endsAt: rest.endsAt, seconds: rest.seconds, pausedLeft: left);
    case RestAlarmPhase.countdown:
      final endsAt = snapshot.endsAt;
      if (endsAt == null) return rest;
      // Diferencias de menos de un segundo son del redondeo entre la app y el sistema.
      if (!rest.paused && (rest.endsAt - endsAt).abs() < 1000) return rest;
      return RestTimer(endsAt: endsAt, seconds: rest.seconds);
  }
}

/// Fase del temporizador del sistema.
enum RestAlarmPhase { countdown, paused, alerting }

/// Lo que informa el temporizador del sistema.
class RestAlarmSnapshot {
  const RestAlarmSnapshot({required this.state, this.endsAt, this.leftMs});

  static RestAlarmSnapshot? fromMap(Object? data) {
    if (data is! Map) return null;
    final state = RestAlarmPhase.values.where((s) => s.name == data['state']).firstOrNull;
    if (state == null) return null;
    return RestAlarmSnapshot(state: state, endsAt: (data['endsAt'] as num?)?.toInt(), leftMs: (data['leftMs'] as num?)?.toInt());
  }

  final RestAlarmPhase state;

  /// Fin de la cuenta (ms desde epoch) mientras corre.
  final int? endsAt;

  /// ms que faltan, en pausa.
  final int? leftMs;

  @override
  String toString() => 'RestAlarmSnapshot(${state.name}, endsAt: $endsAt, leftMs: $leftMs)';
}
