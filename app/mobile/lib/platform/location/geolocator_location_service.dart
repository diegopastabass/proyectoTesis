import 'package:geolocator/geolocator.dart' as geo;

import '../../core/activity/models.dart';
import '../capability.dart';
import 'location_service.dart';

/// GPS del iPhone (paquete geolocator, CoreLocation).
///
/// Para grabar con la pantalla bloqueada basta el permiso "Al usar la app" con el
/// modo de fondo `location` en Info.plist: iOS muestra el indicador azul y sigue
/// entregando puntos mientras dure la grabación.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  static CapabilityStatus _map(geo.LocationPermission p) => switch (p) {
        geo.LocationPermission.always || geo.LocationPermission.whileInUse => CapabilityStatus.granted,
        geo.LocationPermission.denied => CapabilityStatus.notDetermined,
        geo.LocationPermission.deniedForever => CapabilityStatus.denied,
        geo.LocationPermission.unableToDetermine => CapabilityStatus.notDetermined,
      };

  @override
  Future<CapabilityStatus> status() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) return CapabilityStatus.denied;
    return _map(await geo.Geolocator.checkPermission());
  }

  @override
  Future<CapabilityStatus> requestAccess({bool background = false}) async => _map(await geo.Geolocator.requestPermission());

  @override
  Future<GeoPoint?> current() async {
    final p = await geo.Geolocator.getLastKnownPosition();
    return p == null ? null : _point(p);
  }

  @override
  Stream<GeoPoint> track({double distanceFilterMeters = 5, bool background = false}) => geo.Geolocator.getPositionStream(
        locationSettings: geo.AppleSettings(
          accuracy: geo.LocationAccuracy.bestForNavigation,
          activityType: geo.ActivityType.fitness,
          distanceFilter: distanceFilterMeters.round(),
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: background,
          allowBackgroundLocationUpdates: background,
        ),
      ).map(_point);

  static GeoPoint _point(geo.Position p) => GeoPoint(
        latitude: p.latitude,
        longitude: p.longitude,
        at: p.timestamp,
        altitude: p.altitude,
        accuracy: p.accuracy,
        // iOS entrega -1 cuando no conoce la velocidad.
        speed: p.speed >= 0 ? p.speed : null,
      );
}
