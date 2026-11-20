/// Temporizador del descanso entre series fuera de la app.
///
/// En iOS 26 o superior usa AlarmKit, el mismo mecanismo del temporizador del
/// reloj de iPhone: la cuenta regresiva se ve en la isla dinámica y en la pantalla
/// bloqueada con botones para pausar y cancelar, y al terminar suena una alarma
/// (también en modo silencio). Antes de iOS 26, en la web y en las pruebas, avisa
/// con una notificación local, como antes.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/strength/rest_sync.dart';
import '../capability.dart';
import '../notifications/notification_service.dart';

abstract interface class RestTimerService {
  /// true si el teléfono tiene temporizador del sistema (isla dinámica y alarma).
  Future<bool> get systemTimer;

  /// true si el descanso se está llevando en el temporizador del sistema: lo
  /// tiene y el usuario no negó el permiso. Si es false, lo que informe el
  /// sistema no corresponde al descanso de la app.
  Future<bool> get systemActive;

  Future<CapabilityStatus> status();

  /// Pide el permiso de alarmas (o de notificaciones, si no hay AlarmKit).
  Future<CapabilityStatus> requestAccess();

  /// Empieza (o reemplaza) la cuenta de `seconds` segundos.
  Future<void> start({required int seconds, String? exercise});
  Future<void> pause();

  /// Sigue con los `seconds` segundos que quedaban.
  Future<void> resume({required int seconds, String? exercise});
  Future<void> cancel();

  /// Estado actual del temporizador del sistema (null = no hay).
  Future<RestAlarmSnapshot?> current();

  /// Cambios hechos fuera de la app (pausar, seguir o cancelar desde la pantalla
  /// bloqueada, o que sonó la alarma). null = ya no hay temporizador.
  Stream<RestAlarmSnapshot?> get changes;
}

/// Sin temporizador del sistema: una notificación al terminar.
class NotificationRestTimerService implements RestTimerService {
  NotificationRestTimerService(this._notifications);

  final NotificationService _notifications;

  @override
  Future<bool> get systemTimer async => false;

  @override
  Future<bool> get systemActive async => false;

  @override
  Future<CapabilityStatus> status() => _notifications.status();

  @override
  Future<CapabilityStatus> requestAccess() => _notifications.requestPermission();

  @override
  Future<void> start({required int seconds, String? exercise}) => _notifications.scheduleRestEnd(DateTime.now().add(Duration(seconds: seconds)));

  @override
  Future<void> pause() => _notifications.scheduleRestEnd(null);

  @override
  Future<void> resume({required int seconds, String? exercise}) => start(seconds: seconds, exercise: exercise);

  @override
  Future<void> cancel() => _notifications.scheduleRestEnd(null);

  @override
  Future<RestAlarmSnapshot?> current() async => null;

  @override
  Stream<RestAlarmSnapshot?> get changes => const Stream.empty();
}

/// iOS: AlarmKit si el sistema lo tiene (iOS 26+); si no, la notificación.
class IosRestTimerService implements RestTimerService {
  IosRestTimerService(NotificationService notifications) : _fallback = NotificationRestTimerService(notifications);

  static const _channel = MethodChannel('nutriapp/rest_timer');
  static const _events = EventChannel('nutriapp/rest_timer/events');

  /// Tope para cada orden al sistema: si AlarmKit no responde, se usa la notificación.
  static const _timeout = Duration(seconds: 8);

  final NotificationRestTimerService _fallback;

  /// Respuesta del sistema a "¿tienes AlarmKit?". Solo se guarda una respuesta
  /// real: si la consulta falla (por ejemplo, el canal aún no estaba listo), se
  /// vuelve a preguntar la próxima vez en vez de quedar sin temporizador hasta
  /// reinstalar la app.
  bool? _supported;

  late final _changes = StreamController<RestAlarmSnapshot?>.broadcast(onListen: () => unawaited(_connect()), onCancel: _disconnect);
  StreamSubscription<Object?>? _sub;
  bool _connecting = false;

  @override
  Future<bool> get systemTimer async {
    final known = _supported;
    if (known != null) return known;
    try {
      return _supported = await _channel.invokeMethod<bool>('supported') ?? false;
    } on Object catch (e) {
      debugPrint('Temporizador del sistema no disponible (se reintentará): $e');
      return false;
    }
  }

  /// AlarmKit si el sistema lo tiene y el usuario no negó el permiso; si lo negó,
  /// el fin del descanso se avisa con una notificación, como antes.
  Future<bool> _useSystem() async {
    if (!await systemTimer) return false;
    try {
      return await _channel.invokeMethod<String>('status') != 'denied';
    } on Object catch (e) {
      debugPrint('No se pudo leer el permiso de alarmas: $e');
      return false;
    }
  }

  @override
  Future<bool> get systemActive => _useSystem();

  Future<T> _either<T>(Future<T> Function() system, Future<T> Function() fallback) async => await systemTimer ? system() : fallback();

  /// Envía la orden al sistema; si falla o no responde, usa la notificación (al
  /// menos avisa al terminar) y relanza el error para que la app lo sepa. Con la
  /// orden aceptada se quita la notificación que pudo quedar de un intento fallido.
  Future<void> _command(Future<void> Function() system, Future<void> Function() fallback) async {
    if (!await _useSystem()) return fallback();
    try {
      await system().timeout(_timeout);
    } on Object catch (e) {
      debugPrint('El temporizador del sistema falló, se usa la notificación: $e');
      await fallback();
      rethrow;
    }
    unawaited(_connect());
    await _fallback.cancel();
  }

  static CapabilityStatus _status(String? s) => switch (s) {
        'authorized' => CapabilityStatus.granted,
        'denied' => CapabilityStatus.denied,
        _ => CapabilityStatus.notDetermined,
      };

  @override
  Future<CapabilityStatus> status() => _either(() async => _status(await _channel.invokeMethod<String>('status')), _fallback.status);

  @override
  Future<CapabilityStatus> requestAccess() => _either(() async => _status(await _channel.invokeMethod<String>('request')), _fallback.requestAccess);

  @override
  Future<void> start({required int seconds, String? exercise}) => _command(
        () => _channel.invokeMethod<void>('start', {'seconds': seconds, 'exercise': exercise}),
        () => _fallback.start(seconds: seconds, exercise: exercise),
      );

  @override
  Future<void> pause() => _command(() => _channel.invokeMethod<void>('pause'), _fallback.pause);

  @override
  Future<void> resume({required int seconds, String? exercise}) => _command(
        () => _channel.invokeMethod<void>('resume', {'seconds': seconds, 'exercise': exercise}),
        () => _fallback.resume(seconds: seconds, exercise: exercise),
      );

  @override
  Future<void> cancel() async {
    // Se limpian los dos: el permiso pudo cambiar desde que empezó el descanso.
    try {
      if (await systemTimer) await _channel.invokeMethod<void>('cancel').timeout(_timeout);
    } finally {
      await _fallback.cancel();
    }
  }

  @override
  Future<RestAlarmSnapshot?> current() => _either(() async => RestAlarmSnapshot.fromMap(await _channel.invokeMethod<Object?>('current')), _fallback.current);

  /// Se conecta a los avisos del sistema mientras alguien escucha. Si al empezar
  /// a escuchar aún no se sabía si había AlarmKit, se reintenta con cada orden.
  Future<void> _connect() async {
    if (_sub != null || _connecting || !_changes.hasListener) return;
    _connecting = true;
    try {
      if (!await systemTimer || _sub != null || !_changes.hasListener) return;
      _sub = _events.receiveBroadcastStream().listen(
            (e) => _changes.add(RestAlarmSnapshot.fromMap(e)),
            onError: (Object e) => debugPrint('Temporizador: $e'),
          );
    } finally {
      _connecting = false;
    }
  }

  void _disconnect() {
    final sub = _sub;
    _sub = null;
    unawaited(sub?.cancel());
  }

  @override
  Stream<RestAlarmSnapshot?> get changes => _changes.stream;
}
