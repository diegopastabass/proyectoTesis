/// Datos de actividad que llegan desde el sistema (Apple Salud, sensores, GPS).
///
/// Son modelos puros: no dependen de HealthKit ni de ningún paquete, para que la
/// lógica (calorías por pasos, ritmo de una carrera, zonas de frecuencia…) se pueda
/// probar sin un teléfono y reutilizar si se cambia el proveedor de datos.
library;

/// De dónde viene un dato. Se guarda junto al dato para saber cómo interpretarlo.
enum DataSource {
  manual,

  /// Apple Salud (HealthKit), que agrega iPhone, Apple Watch y apps de terceros.
  appleHealth,

  /// Health Connect de Android.
  healthConnect,

  /// Sensores del propio teléfono (podómetro de CoreMotion, GPS).
  device,
}

/// Total de pasos de un día local.
class DailySteps {
  const DailySteps({required this.date, required this.steps, required this.source});

  /// YYYY-MM-DD local.
  final String date;
  final int steps;
  final DataSource source;
}

class HeartRateSample {
  const HeartRateSample({required this.at, required this.bpm, required this.source});

  final DateTime at;
  final double bpm;
  final DataSource source;
}

/// Punto de una ruta GPS.
class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude, required this.at, this.altitude, this.accuracy, this.speed});

  final double latitude;
  final double longitude;
  final DateTime at;

  /// Metros sobre el nivel del mar.
  final double? altitude;

  /// Radio de incertidumbre en metros.
  final double? accuracy;

  /// Metros por segundo.
  final double? speed;
}

enum ActivityType { walking, running, cycling, swimming, strength, other }

/// Sesión registrada por un reloj o por otra app (por ejemplo, una carrera en el Apple Watch).
class ActivitySession {
  const ActivitySession({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
    required this.source,
    this.distanceMeters,
    this.activeKcal,
    this.averageHeartRate,
  });

  final String id;
  final ActivityType type;
  final DateTime start;
  final DateTime end;
  final DataSource source;
  final double? distanceMeters;
  final double? activeKcal;
  final double? averageHeartRate;

  Duration get duration => end.difference(start);
}
