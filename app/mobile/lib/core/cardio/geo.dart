/// Geometría de rutas: distancias, polilíneas codificadas y simplificación.
library;

import 'dart:math' as math;

/// Coordenada simple (grados).
class LatLng {
  const LatLng(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) => other is LatLng && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'LatLng($lat, $lng)';
}

const _earthRadius = 6371008.8;

double _rad(double deg) => deg * math.pi / 180;

/// Distancia en metros sobre la esfera (fórmula del haversine).
double haversine(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadius * math.asin(math.min(1, math.sqrt(a)));
}

/// Codifica con el algoritmo de polilíneas de Google (precisión 1e-5 ≈ 1 m).
String encodePolyline(List<LatLng> points) {
  final out = StringBuffer();
  var lastLat = 0;
  var lastLng = 0;
  // Aritmética en vez de operadores de bits: en la web los bits son de 32 sin signo.
  void write(int v) {
    var n = v < 0 ? -v * 2 - 1 : v * 2;
    while (n >= 32) {
      out.writeCharCode(32 + n % 32 + 63);
      n ~/= 32;
    }
    out.writeCharCode(n + 63);
  }

  for (final p in points) {
    final lat = (p.lat * 1e5).round();
    final lng = (p.lng * 1e5).round();
    write(lat - lastLat);
    write(lng - lastLng);
    lastLat = lat;
    lastLng = lng;
  }
  return out.toString();
}

List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;
  int read() {
    var factor = 1;
    var result = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result += (b % 32) * factor;
      factor *= 32;
    } while (b >= 32);
    return result.isOdd ? -(result + 1) ~/ 2 : result ~/ 2;
  }

  while (index < encoded.length) {
    lat += read();
    lng += read();
    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}

/// Distancia en metros de `p` al segmento a–b (proyección plana local, suficiente para tramos cortos).
double _segmentDistance(LatLng p, LatLng a, LatLng b) {
  final k = math.cos(_rad(a.lat));
  final ax = a.lng * k, ay = a.lat, bx = b.lng * k, by = b.lat, px = p.lng * k, py = p.lat;
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  var t = len2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2;
  t = t.clamp(0.0, 1.0);
  final cx = ax + t * dx, cy = ay + t * dy;
  return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy)) * math.pi / 180 * _earthRadius;
}

/// Simplificación de Douglas-Peucker: conserva la forma con menos puntos.
List<LatLng> simplify(List<LatLng> points, double toleranceMeters) {
  if (points.length < 3) return [...points];
  final keep = List.filled(points.length, false);
  keep[0] = keep[points.length - 1] = true;
  final stack = <(int, int)>[(0, points.length - 1)];
  while (stack.isNotEmpty) {
    final (from, to) = stack.removeLast();
    var maxD = 0.0;
    var index = -1;
    for (var i = from + 1; i < to; i++) {
      final d = _segmentDistance(points[i], points[from], points[to]);
      if (d > maxD) {
        maxD = d;
        index = i;
      }
    }
    if (index >= 0 && maxD > toleranceMeters) {
      keep[index] = true;
      stack
        ..add((from, index))
        ..add((index, to));
    }
  }
  return [for (var i = 0; i < points.length; i++) if (keep[i]) points[i]];
}

/// Simplifica subiendo la tolerancia hasta quedar en `maxPoints` o menos.
List<LatLng> simplifyTo(List<LatLng> points, int maxPoints) {
  var tolerance = 2.0;
  var out = simplify(points, tolerance);
  while (out.length > maxPoints && tolerance < 5000) {
    tolerance *= 1.6;
    out = simplify(points, tolerance);
  }
  return out;
}

class GeoBounds {
  const GeoBounds(this.south, this.west, this.north, this.east);

  static GeoBounds? of(Iterable<LatLng> points) {
    if (points.isEmpty) return null;
    var s = 90.0, w = 180.0, n = -90.0, e = -180.0;
    for (final p in points) {
      s = math.min(s, p.lat);
      n = math.max(n, p.lat);
      w = math.min(w, p.lng);
      e = math.max(e, p.lng);
    }
    return GeoBounds(s, w, n, e);
  }

  final double south;
  final double west;
  final double north;
  final double east;
}
