import '../../core/activity/models.dart';
import '../capability.dart';

/// GPS del teléfono, para rutas de cardio.
abstract interface class LocationService {
  Future<CapabilityStatus> status();

  /// `background`: seguir registrando con la pantalla apagada (requiere el modo
  /// de fondo "location" en Info.plist y el permiso "Siempre").
  Future<CapabilityStatus> requestAccess({bool background = false});

  Future<GeoPoint?> current();

  /// Puntos de la ruta mientras se escucha el stream. `background`: seguir con la
  /// app en segundo plano (solo al grabar; si no, iOS apaga el GPS al salir).
  Stream<GeoPoint> track({double distanceFilterMeters = 5, bool background = false});
}

class UnavailableLocationService implements LocationService {
  const UnavailableLocationService([this._status = CapabilityStatus.notImplemented]);

  final CapabilityStatus _status;

  @override
  Future<CapabilityStatus> status() async => _status;

  @override
  Future<CapabilityStatus> requestAccess({bool background = false}) async => _status;

  @override
  Future<GeoPoint?> current() async => null;

  @override
  Stream<GeoPoint> track({double distanceFilterMeters = 5, bool background = false}) => const Stream.empty();
}
