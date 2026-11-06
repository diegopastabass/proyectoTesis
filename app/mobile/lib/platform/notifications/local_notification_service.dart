import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/activity/reminders.dart';
import '../capability.dart';
import 'notification_service.dart';

/// Notificaciones locales de iOS (paquete flutter_local_notifications).
///
/// iOS no dice si el permiso aún no se pidió o si se negó: se recuerda si ya se
/// mostró el diálogo, igual que con Apple Salud.
class LocalNotificationService implements NotificationService {
  LocalNotificationService({required this.wasRequested, required this.markRequested});

  final bool Function() wasRequested;
  final Future<void> Function() markRequested;

  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String>.broadcast();
  Future<void>? _ready;

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  Future<void> _init() => _ready ??= () async {
        tzdata.initializeTimeZones();
        try {
          tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
        } on Object catch (e) {
          // Sin zona horaria se usa UTC: los avisos saldrían a otra hora, pero salen.
          debugPrint('Zona horaria no disponible: $e');
        }
        // El permiso se pide aparte, cuando el usuario activa un recordatorio.
        const darwin = DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);
        await _plugin.initialize(
          settings: const InitializationSettings(iOS: darwin, macOS: darwin),
          onDidReceiveNotificationResponse: (r) {
            if (r.payload case final route? when route.isNotEmpty) _taps.add(route);
          },
        );
      }();

  @override
  Future<CapabilityStatus> status() async {
    await _init();
    if ((await _ios?.checkPermissions())?.isEnabled ?? false) return CapabilityStatus.granted;
    return wasRequested() ? CapabilityStatus.denied : CapabilityStatus.notDetermined;
  }

  @override
  Future<CapabilityStatus> requestPermission() async {
    await _init();
    final ok = await _ios?.requestPermissions(alert: true, sound: true);
    await markRequested();
    return ok ?? false ? CapabilityStatus.granted : CapabilityStatus.denied;
  }

  /// Fuera del rango de los recordatorios (0, 1, 2…).
  static const _restId = 900000;

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    await _init();
    // Todos menos el del descanso en curso.
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.id != _restId) await _plugin.cancel(id: p.id);
    }
    for (var i = 0; i < reminders.length; i++) {
      final r = reminders[i];
      await _plugin.zonedSchedule(
        id: i,
        scheduledDate: tz.TZDateTime(tz.local, r.at.year, r.at.month, r.at.day, r.at.hour, r.at.minute),
        notificationDetails: NotificationDetails(iOS: DarwinNotificationDetails(threadIdentifier: r.kind.name)),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
        payload: r.route,
      );
    }
  }

  @override
  Future<void> scheduleRestEnd(DateTime? at) async {
    await _init();
    await _plugin.cancel(id: _restId);
    if (at == null || !at.isAfter(DateTime.now())) return;
    // Sin permiso no hay aviso: el descanso se ve igual en la pantalla del entrenamiento.
    if (!((await _ios?.checkPermissions())?.isEnabled ?? false)) return;
    await _plugin.zonedSchedule(
      id: _restId,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      // Con la app abierta suena y se muestra arriba (puede estar en otra pantalla).
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(threadIdentifier: 'rest', presentBanner: true, presentSound: true, presentList: false),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      title: 'Descanso terminado',
      body: 'Es hora de la siguiente serie.',
      payload: '/fuerza/entrenar',
    );
  }

  @override
  Future<String?> launchRoute() async {
    await _init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false ? details!.notificationResponse?.payload : null;
  }

  @override
  Stream<String> get taps => _taps.stream;
}
