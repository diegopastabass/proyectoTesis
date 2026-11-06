import '../../core/activity/reminders.dart';
import '../capability.dart';

/// Notificaciones locales (programadas en el teléfono, sin servidor).
abstract interface class NotificationService {
  Future<CapabilityStatus> status();

  /// Muestra el diálogo de permiso de iOS (solo la primera vez).
  Future<CapabilityStatus> requestPermission();

  /// Reemplaza todos los avisos pendientes por estos.
  Future<void> replaceAll(List<PlannedReminder> reminders);

  /// Aviso de fin del descanso entre series (hay uno a la vez); null lo cancela.
  Future<void> scheduleRestEnd(DateTime? at);

  /// Ruta del aviso con que se abrió la app, si se abrió así.
  Future<String?> launchRoute();

  /// Ruta de cada aviso tocado con la app abierta o en segundo plano.
  Stream<String> get taps;
}

/// Plataformas sin notificaciones locales (web y pruebas).
class UnavailableNotificationService implements NotificationService {
  const UnavailableNotificationService();

  @override
  Future<CapabilityStatus> status() async => CapabilityStatus.unsupported;

  @override
  Future<CapabilityStatus> requestPermission() async => CapabilityStatus.unsupported;

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {}

  @override
  Future<void> scheduleRestEnd(DateTime? at) async {}

  @override
  Future<String?> launchRoute() async => null;

  @override
  Stream<String> get taps => const Stream.empty();
}
