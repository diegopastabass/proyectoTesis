import 'package:health/health.dart';

import '../../core/activity/models.dart';
import '../../core/common/date.dart';
import '../capability.dart';
import 'health_service.dart';

/// Apple Salud (HealthKit) con el paquete `health`.
///
/// HealthKit no informa si el usuario negó la lectura: las consultas simplemente
/// devuelven vacío. Por eso el estado se basa en si ya se mostró la hoja de
/// permisos (`wasRequested`), y la interfaz explica qué revisar si ve 0 pasos.
class HealthKitHealthService implements HealthService {
  HealthKitHealthService({required this.wasRequested, required this.markRequested, Health? health}) : _health = health ?? Health();

  final Health _health;

  /// Si ya se pidió el permiso en este dispositivo (se guarda fuera, en LocalStore).
  final bool Function() wasRequested;
  final Future<void> Function() markRequested;

  bool _configured = false;

  static const _types = {
    HealthMetric.steps: HealthDataType.STEPS,
    HealthMetric.heartRate: HealthDataType.HEART_RATE,
    HealthMetric.activeEnergy: HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthMetric.workouts: HealthDataType.WORKOUT,
    HealthMetric.bodyMass: HealthDataType.WEIGHT,
  };

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  String get providerName => 'Apple Salud';

  @override
  Future<CapabilityStatus> status() async => wasRequested() ? CapabilityStatus.granted : CapabilityStatus.notDetermined;

  @override
  Future<CapabilityStatus> requestAccess(Set<HealthMetric> metrics) async {
    await _ensureConfigured();
    final types = [for (final m in metrics) _types[m]!];
    final shown = await _health.requestAuthorization(types, permissions: [for (final _ in types) HealthDataAccess.READ]);
    if (!shown) return CapabilityStatus.denied;
    await markRequested();
    return CapabilityStatus.granted;
  }

  @override
  Future<List<DailySteps>> dailySteps({required String from, required String to}) async {
    await _ensureConfigured();
    final now = DateTime.now();
    final out = <DailySteps>[];
    for (var day = from; day.compareTo(to) <= 0; day = addDays(day, 1)) {
      final start = fromDateKey(day);
      if (start.isAfter(now)) break;
      final next = fromDateKey(addDays(day, 1));
      // Total agregado del día: HealthKit descuenta duplicados entre iPhone y reloj.
      final steps = await _health.getTotalStepsInInterval(start, next.isAfter(now) ? now : next);
      out.add(DailySteps(date: day, steps: steps ?? 0, source: DataSource.appleHealth));
    }
    return out;
  }

  @override
  Future<List<HeartRateSample>> heartRate({required DateTime from, required DateTime to}) async {
    await _ensureConfigured();
    final points = await _health.getHealthDataFromTypes(types: const [HealthDataType.HEART_RATE], startTime: from, endTime: to);
    return [
      for (final p in points)
        if (p.value case NumericHealthValue(:final numericValue))
          HeartRateSample(at: p.dateFrom, bpm: numericValue.toDouble(), source: DataSource.appleHealth),
    ];
  }

  /// Pendiente: convertir los entrenamientos (WorkoutHealthValue) cuando exista el módulo de cardio.
  @override
  Future<List<ActivitySession>> sessions({required DateTime from, required DateTime to}) async => const [];
}
