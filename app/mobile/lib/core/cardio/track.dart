/// Puntos GPS de una ruta y cálculo de sus métricas.
///
/// Las mismas reglas se usan en vivo (punto a punto mientras se graba) y al
/// guardar (recorriendo la ruta completa), así los números no cambian al terminar.
library;

import 'dart:math' as math;

import 'geo.dart';

/// Punto de la ruta. `t` en milisegundos desde epoch.
class TrackPoint {
  const TrackPoint({required this.lat, required this.lng, required this.t, this.alt, this.accuracy, this.speed});

  /// Formato compacto para el archivo local: [lat, lng, t, alt, accuracy, speed].
  factory TrackPoint.fromJson(List<dynamic> j) => TrackPoint(
        lat: (j[0] as num).toDouble(),
        lng: (j[1] as num).toDouble(),
        t: (j[2] as num).toInt(),
        alt: j.length > 3 ? (j[3] as num?)?.toDouble() : null,
        accuracy: j.length > 4 ? (j[4] as num?)?.toDouble() : null,
        speed: j.length > 5 ? (j[5] as num?)?.toDouble() : null,
      );

  final double lat;
  final double lng;
  final int t;

  /// Metros sobre el nivel del mar.
  final double? alt;

  /// Radio de incertidumbre horizontal en metros.
  final double? accuracy;

  /// Velocidad Doppler del GPS en m/s (más precisa que la calculada entre puntos).
  final double? speed;

  LatLng get latLng => LatLng(lat, lng);

  List<dynamic> toJson() => [lat, lng, t, alt, accuracy, speed];
}

/// Puntos con más incertidumbre que esto se descartan.
const maxAccuracyMeters = 30.0;

/// Saltos imposibles (más de ~180 km/h) son errores del GPS.
const maxPlausibleSpeedMs = 50.0;

/// Bajo esta velocidad se considera detenido (no suma tiempo en movimiento).
const movingSpeedMs = 0.5;

/// Huecos más largos (túnel, GPS perdido) no suman tiempo en movimiento.
const maxMovingGapSeconds = 30;

/// Diferencia mínima de altura para contar subida o bajada (filtra el ruido del GPS).
const elevationThreshold = 4.0;

/// Puntos que se promedian para suavizar la altura.
const _altitudeWindow = 5;

/// ¿Se acepta el punto? Descarta precisión mala, tiempos repetidos y saltos imposibles.
bool acceptPoint(TrackPoint? last, TrackPoint p) {
  if (p.accuracy != null && p.accuracy! > maxAccuracyMeters) return false;
  if (last == null) return true;
  final dt = (p.t - last.t) / 1000;
  if (dt <= 0) return false;
  return haversine(last.lat, last.lng, p.lat, p.lng) / dt <= maxPlausibleSpeedMs;
}

/// Parcial (por kilómetro).
class Split {
  const Split({required this.index, required this.distanceM, required this.movingS, required this.gainM});

  /// 1 = primer kilómetro.
  final int index;

  /// 1000, salvo el último (parcial).
  final double distanceM;
  final double movingS;
  final double gainM;

  /// Segundos por kilómetro.
  double get paceSPerKm => distanceM > 0 ? movingS / distanceM * 1000 : 0;
}

/// Acumula métricas punto a punto. Al reanudar tras una pausa se llama a
/// [startSegment] para que el tramo pausado no sume distancia.
class TrackAccumulator {
  double distanceM = 0;
  double movingS = 0;
  double gainM = 0;
  double lossM = 0;
  double? maxAltM;
  double? minAltM;
  double maxSpeedMs = 0;
  final splits = <Split>[];

  TrackPoint? _last;
  final _alts = <double>[];
  double? _refAlt;
  double _splitStartMoving = 0;
  double _splitStartGain = 0;

  /// Último punto aceptado (para el filtro y el mapa en vivo).
  TrackPoint? get last => _last;

  void startSegment() => _last = null;

  void add(TrackPoint p) {
    final last = _last;
    if (last != null) {
      final d = haversine(last.lat, last.lng, p.lat, p.lng);
      final dt = (p.t - last.t) / 1000;
      if (dt > 0) {
        final v = d / dt;
        final before = distanceM;
        final movingBefore = movingS;
        final gainBefore = gainM;
        distanceM += d;
        if (v >= movingSpeedMs && dt <= maxMovingGapSeconds) movingS += dt;
        // La velocidad Doppler es más estable; la calculada entre puntos, el respaldo.
        final speed = p.speed != null && p.speed! >= 0 ? p.speed! : v;
        if (speed <= maxPlausibleSpeedMs) maxSpeedMs = math.max(maxSpeedMs, speed);
        _updateElevation(p.alt);
        _closeSplits(before, movingBefore, gainBefore);
        _last = p;
        return;
      }
    }
    _updateElevation(p.alt);
    _last = p;
  }

  void _updateElevation(double? alt) {
    if (alt == null) return;
    _alts.add(alt);
    if (_alts.length > _altitudeWindow) _alts.removeAt(0);
    final smooth = _alts.reduce((a, b) => a + b) / _alts.length;
    maxAltM = math.max(maxAltM ?? smooth, smooth);
    minAltM = math.min(minAltM ?? smooth, smooth);
    final ref = _refAlt;
    if (ref == null) {
      _refAlt = smooth;
    } else if (smooth - ref >= elevationThreshold) {
      gainM += smooth - ref;
      _refAlt = smooth;
    } else if (ref - smooth >= elevationThreshold) {
      lossM += ref - smooth;
      _refAlt = smooth;
    }
  }

  /// Cierra los kilómetros completados en este tramo, interpolando el tiempo del cruce.
  void _closeSplits(double distBefore, double movingBefore, double gainBefore) {
    while (distanceM >= (splits.length + 1) * 1000) {
      final boundary = (splits.length + 1) * 1000.0;
      final f = distanceM == distBefore ? 1.0 : (boundary - distBefore) / (distanceM - distBefore);
      final movingAt = movingBefore + (movingS - movingBefore) * f;
      final gainAt = gainBefore + (gainM - gainBefore) * f;
      splits.add(Split(index: splits.length + 1, distanceM: 1000, movingS: movingAt - _splitStartMoving, gainM: gainAt - _splitStartGain));
      _splitStartMoving = movingAt;
      _splitStartGain = gainAt;
    }
  }

  /// Parciales con el tramo final incompleto (si recorrió al menos 100 m).
  List<Split> splitsWithRemainder() {
    final rest = distanceM - splits.length * 1000;
    if (rest < 100) return [...splits];
    return [...splits, Split(index: splits.length + 1, distanceM: rest, movingS: movingS - _splitStartMoving, gainM: gainM - _splitStartGain)];
  }

  /// Recorre una ruta completa (lista de tramos separados por pausas).
  static TrackAccumulator replay(List<List<TrackPoint>> segments) {
    final acc = TrackAccumulator();
    for (final seg in segments) {
      acc.startSegment();
      for (final p in seg) {
        acc.add(p);
      }
    }
    return acc;
  }
}
