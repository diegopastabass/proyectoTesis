/// Funciones del sistema que la app puede usar y su estado de permiso.
///
/// Cada función del sistema se expone con un servicio abstracto
/// (`HealthService`, `LocationService`, `PedometerService`) y se elige la
/// implementación en `platform_providers.dart`. Las pantallas nunca llaman a
/// HealthKit ni a CoreLocation directamente: así se pueden probar con dobles,
/// usar en la web (que no tiene esas APIs) y cambiar de paquete sin tocar la UI.
library;

enum Capability {
  /// Apple Salud: pasos, frecuencia cardiaca, entrenamientos del Apple Watch.
  health('Apple Salud', 'Pasos, frecuencia cardiaca y entrenamientos del reloj'),

  /// Podómetro del teléfono (CoreMotion), en vivo.
  pedometer('Podómetro', 'Pasos contados por el iPhone en tiempo real'),

  /// GPS para registrar rutas de cardio.
  location('Ubicación', 'Ruta, distancia, ritmo y desnivel de las actividades de cardio'),

  /// Cámara para leer códigos de barras.
  camera('Cámara', 'Escanear el código de barras de un alimento'),

  /// Recordatorios locales para registrar comidas y entrenar.
  notifications('Notificaciones', 'Recordatorios de comidas, entrenamientos y racha');

  const Capability(this.label, this.purpose);

  final String label;
  final String purpose;
}

enum CapabilityStatus {
  /// La plataforma no la ofrece (por ejemplo, Apple Salud en la web).
  unsupported,

  /// Prevista en la arquitectura, pero aún no hay implementación nativa.
  notImplemented,

  /// Aún no se pide permiso.
  notDetermined,

  /// El usuario negó el permiso (se puede cambiar en Ajustes de iOS).
  denied,

  granted;

  bool get usable => this == CapabilityStatus.granted;
}

/// Error común de los servicios de plataforma.
class CapabilityException implements Exception {
  const CapabilityException(this.capability, this.status, [this.message]);

  final Capability capability;
  final CapabilityStatus status;
  final String? message;

  @override
  String toString() => message ?? '${capability.label}: ${status.name}';
}
