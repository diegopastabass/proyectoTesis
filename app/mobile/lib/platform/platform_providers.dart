/// Punto único donde se elige la implementación de cada función del sistema.
///
/// Para integrar una función nueva:
///   1. Escribir la implementación (como `HealthKitHealthService implements HealthService`)
///      en `platform/<función>/`.
///   2. Elegirla aquí según la plataforma.
///   3. Declarar el permiso en ios/Runner/Info.plist y, si aplica, la capacidad en
///      ios/Runner/Runner.entitlements (ver docs/arquitectura-flutter.md).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/activity/models.dart';
import '../core/common/date.dart';
import 'capability.dart';
import 'health/health_service.dart';
import 'health/healthkit_health_service.dart';
import 'location/geolocator_location_service.dart';
import 'location/location_service.dart';
import 'motion/pedometer_service.dart';
import 'notifications/local_notification_service.dart';
import 'notifications/notification_service.dart';

bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// En la web no existen estas APIs; en iOS están previstas y pendientes.
CapabilityStatus get _pending => _isIos ? CapabilityStatus.notImplemented : CapabilityStatus.unsupported;

final healthServiceProvider = Provider<HealthService>((ref) {
  if (!_isIos) return const UnavailableHealthService(currentStatus: CapabilityStatus.unsupported);
  final store = ref.watch(localStoreProvider);
  return HealthKitHealthService(wasRequested: () => store.healthRequested, markRequested: store.markHealthRequested);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  if (!_isIos) return const UnavailableNotificationService();
  final store = ref.watch(localStoreProvider);
  return LocalNotificationService(wasRequested: () => store.notificationsRequested, markRequested: store.markNotificationsRequested);
});

/// Estado del permiso de notificaciones. Se invalida al pedir el permiso.
final notificationStatusProvider = FutureProvider<CapabilityStatus>((ref) => ref.watch(notificationServiceProvider).status());

/// Pide el permiso de notificaciones (iOS muestra el diálogo una sola vez).
Future<CapabilityStatus> requestNotifications(WidgetRef ref) async {
  final status = await ref.read(notificationServiceProvider).requestPermission();
  ref.invalidate(notificationStatusProvider);
  return status;
}

final locationServiceProvider = Provider<LocationService>((ref) => _isIos ? const GeolocatorLocationService() : UnavailableLocationService(_pending));

/// Permiso de ubicación. Se invalida al pedirlo.
final locationStatusProvider = FutureProvider<CapabilityStatus>((ref) => ref.watch(locationServiceProvider).status());

final pedometerServiceProvider = Provider<PedometerService>((ref) => UnavailablePedometerService(_pending));

/// Estado del permiso de Apple Salud. Se invalida al pedir el permiso.
final healthStatusProvider = FutureProvider<CapabilityStatus>((ref) => ref.watch(healthServiceProvider).status());

/// Pasos de los 7 días que terminan en `date` (YYYY-MM-DD), del más antiguo al más reciente.
final weekStepsProvider = FutureProvider.autoDispose.family<List<DailySteps>, String>((ref, date) async {
  final status = await ref.watch(healthStatusProvider.future);
  if (!status.usable) return const [];
  return ref.watch(healthServiceProvider).dailySteps(from: addDays(date, -6), to: date);
});

/// Muestra la hoja de permisos de Apple Salud para leer pasos.
Future<CapabilityStatus> connectHealth(WidgetRef ref) async {
  final status = await ref.read(healthServiceProvider).requestAccess(const {HealthMetric.steps});
  ref.invalidate(healthStatusProvider);
  return status;
}

/// Estado de cada función del sistema, para la pantalla de Integraciones.
final capabilitiesProvider = FutureProvider<Map<Capability, CapabilityStatus>>((ref) async {
  final pedometer = ref.watch(pedometerServiceProvider);
  return {
    Capability.health: await ref.watch(healthStatusProvider.future),
    Capability.pedometer: await pedometer.status(),
    Capability.location: await ref.watch(locationStatusProvider.future),
    // La cámara ya se usa (mobile_scanner pide el permiso al abrir el lector).
    Capability.camera: kIsWeb || _isIos ? CapabilityStatus.notDetermined : CapabilityStatus.unsupported,
    Capability.notifications: await ref.watch(notificationStatusProvider.future),
  };
});
