import '../capability.dart';

/// Podómetro del teléfono (CoreMotion en iOS): pasos en vivo, por ejemplo
/// durante una caminata. Para totales diarios históricos se usa [HealthService].
abstract interface class PedometerService {
  Future<CapabilityStatus> status();

  Future<CapabilityStatus> requestAccess();

  /// Pasos acumulados desde `start`, actualizados mientras se escucha.
  Stream<int> stepsSince(DateTime start);
}

class UnavailablePedometerService implements PedometerService {
  const UnavailablePedometerService([this._status = CapabilityStatus.notImplemented]);

  final CapabilityStatus _status;

  @override
  Future<CapabilityStatus> status() async => _status;

  @override
  Future<CapabilityStatus> requestAccess() async => _status;

  @override
  Stream<int> stepsSince(DateTime start) => const Stream.empty();
}
