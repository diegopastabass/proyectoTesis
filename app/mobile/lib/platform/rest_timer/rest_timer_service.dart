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
  /// true si el temporizador vive en el sistema (isla dinámica y alarma).
  Future<bool> get systemTimer;

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

  final NotificationRestTimerService _fallback;
  Future<bool>? _supported;
  Stream<RestAlarmSnapshot?>? _changes;

  @override
  Future<bool> get systemTimer => _supported ??= () async {
        try {
          return await _channel.invokeMethod<bool>('supported') ?? false;
        } on Object catch (e) {
          debugPrint('Temporizador del sistema no disponible: $e');
          return false;
        }
      }();

  /// AlarmKit si el sistema lo tiene y el usuario no negó el permiso; si lo negó,
  /// el fin del descanso se avisa con una notificación, como antes.
  Future<bool> _useSystem() async {
    if (!await systemTimer) return false;
    try {
      return await _channel.invokeMethod<String>('status') != 'denied';
    } on Object {
      return false;
    }
  }

  Future<T> _either<T>(Future<T> Function() system, Future<T> Function() fallback) async => await systemTimer ? system() : fallback();

  Future<void> _command(Future<void> Function() system, Future<void> Function() fallback) async => await _useSystem() ? system() : fallback();

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
    if (await systemTimer) await _channel.invokeMethod<void>('cancel');
    await _fallback.cancel();
  }

  @override
  Future<RestAlarmSnapshot?> current() => _either(() async => RestAlarmSnapshot.fromMap(await _channel.invokeMethod<Object?>('current')), _fallback.current);

  @override
  Stream<RestAlarmSnapshot?> get changes => _changes ??= () {
        final controller = StreamController<RestAlarmSnapshot?>.broadcast();
        StreamSubscription<Object?>? sub;
        controller.onListen = () async {
          if (!await systemTimer) return;
          sub = _events.receiveBroadcastStream().listen((e) => controller.add(RestAlarmSnapshot.fromMap(e)), onError: (Object e) => debugPrint('Temporizador: $e'));
        };
        controller.onCancel = () => sub?.cancel();
        return controller.stream;
      }();
}
