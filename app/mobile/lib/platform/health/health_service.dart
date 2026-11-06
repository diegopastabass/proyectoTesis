import '../../core/activity/models.dart';
import '../capability.dart';

/// Tipos de dato de salud que la app podría leer.
enum HealthMetric { steps, heartRate, activeEnergy, workouts, bodyMass }

/// Acceso a la base de salud del sistema (Apple Salud en iOS, Health Connect en Android).
///
/// Notas de HealthKit que la implementación debe respetar:
/// - Si el usuario niega la lectura, iOS no lo informa: las consultas devuelven
///   vacío. Por eso [status] solo puede afirmar `notDetermined` o "ya se pidió".
/// - Los totales de días pasados cambian cuando el reloj sincroniza más tarde:
///   conviene volver a leer los últimos días al abrir la app.
/// - Los pasos se piden agregados por día (HKStatisticsCollectionQuery), que
///   descuenta duplicados entre el iPhone y el Apple Watch.
abstract interface class HealthService {
  /// Nombre a mostrar: "Apple Salud", "Health Connect".
  String get providerName;

  Future<CapabilityStatus> status();

  /// Muestra la hoja de permisos del sistema para los tipos indicados.
  Future<CapabilityStatus> requestAccess(Set<HealthMetric> metrics);

  /// Total de pasos por día local, entre `from` y `to` (YYYY-MM-DD, inclusive).
  Future<List<DailySteps>> dailySteps({required String from, required String to});

  Future<List<HeartRateSample>> heartRate({required DateTime from, required DateTime to});

  /// Entrenamientos registrados por el reloj u otras apps.
  Future<List<ActivitySession>> sessions({required DateTime from, required DateTime to});
}

/// Implementación por defecto mientras no se integre HealthKit (ver docs/arquitectura).
class UnavailableHealthService implements HealthService {
  const UnavailableHealthService({this.currentStatus = CapabilityStatus.notImplemented, this.providerName = 'Apple Salud'});

  final CapabilityStatus currentStatus;

  @override
  final String providerName;

  @override
  Future<CapabilityStatus> status() async => currentStatus;

  @override
  Future<CapabilityStatus> requestAccess(Set<HealthMetric> metrics) async => currentStatus;

  @override
  Future<List<DailySteps>> dailySteps({required String from, required String to}) async => const [];

  @override
  Future<List<HeartRateSample>> heartRate({required DateTime from, required DateTime to}) async => const [];

  @override
  Future<List<ActivitySession>> sessions({required DateTime from, required DateTime to}) async => const [];
}
