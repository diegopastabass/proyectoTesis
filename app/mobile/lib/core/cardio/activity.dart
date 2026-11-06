/// Actividades de cardio (running, ciclismo y trekking) grabadas con el GPS.
library;

import 'dart:math' as math;

import '../common/date.dart';
import '../common/numbers.dart';
import 'geo.dart';
import 'track.dart';

enum Discipline {
  running('Running', 'Carrera'),
  cycling('Ciclismo', 'Ruta en bici'),
  trekking('Trekking', 'Trekking');

  const Discipline(this.label, this.titleBase);

  final String label;

  /// Base del título por defecto ("Carrera de la mañana").
  final String titleBase;

  static Discipline from(Object? name) => Discipline.values.where((d) => d.name == name).firstOrNull ?? Discipline.running;
}

class CardioStats {
  const CardioStats({
    this.distanceM = 0,
    this.durationS = 0,
    this.movingS = 0,
    this.gainM = 0,
    this.lossM = 0,
    this.maxAltM,
    this.minAltM,
    this.maxSpeedMs = 0,
  });

  factory CardioStats.fromMap(Object? data) {
    final m = data is Map ? data : const {};
    double v(String k) => (m[k] as num?)?.toDouble() ?? 0;
    return CardioStats(
      distanceM: v('distanceM'),
      durationS: v('durationS'),
      movingS: v('movingS'),
      gainM: v('gainM'),
      lossM: v('lossM'),
      maxAltM: (m['maxAltM'] as num?)?.toDouble(),
      minAltM: (m['minAltM'] as num?)?.toDouble(),
      maxSpeedMs: v('maxSpeedMs'),
    );
  }

  factory CardioStats.from(TrackAccumulator a, {required double durationS}) => CardioStats(
        distanceM: a.distanceM,
        durationS: durationS,
        movingS: math.min(a.movingS, durationS),
        gainM: a.gainM,
        lossM: a.lossM,
        maxAltM: a.maxAltM,
        minAltM: a.minAltM,
        maxSpeedMs: a.maxSpeedMs,
      );

  final double distanceM;

  /// Tiempo total sin las pausas manuales.
  final double durationS;

  /// Tiempo en movimiento (sin las detenciones).
  final double movingS;
  final double gainM;
  final double lossM;
  final double? maxAltM;
  final double? minAltM;
  final double maxSpeedMs;

  /// Velocidad media en movimiento (m/s).
  double get avgSpeedMs => movingS > 0 ? distanceM / movingS : 0;

  /// Ritmo medio en movimiento (segundos por kilómetro).
  double get paceSPerKm => distanceM > 0 ? movingS / distanceM * 1000 : 0;

  /// Velocidad de ascenso (metros por hora en movimiento).
  double get ascentRateMh => movingS > 0 ? gainM / movingS * 3600 : 0;

  Map<String, dynamic> toMap() => {
        'distanceM': round1(distanceM),
        'durationS': durationS.round(),
        'movingS': movingS.round(),
        'gainM': round1(gainM),
        'lossM': round1(lossM),
        'maxAltM': maxAltM == null ? null : round1(maxAltM!),
        'minAltM': minAltM == null ? null : round1(minAltM!),
        'maxSpeedMs': round2(maxSpeedMs),
      };
}

/// Estado del respaldo en la nube (solo existe en el teléfono).
enum SyncState { pending, synced }

/// Resumen de una actividad: lo que se ve en el historial. La ruta completa va aparte ([CardioTrack]).
class CardioActivity {
  const CardioActivity({
    required this.id,
    required this.discipline,
    required this.title,
    this.description = '',
    required this.startedAt,
    required this.finishedAt,
    required this.stats,
    this.preview = '',
    required this.updatedAt,
    this.syncState = SyncState.pending,
    this.rpe,
  });

  factory CardioActivity.fromMap(String id, Map<String, dynamic> m) => CardioActivity(
        id: id,
        discipline: Discipline.from(m['discipline']),
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        startedAt: (m['startedAt'] as num?)?.toInt() ?? 0,
        finishedAt: (m['finishedAt'] as num?)?.toInt() ?? 0,
        stats: CardioStats.fromMap(m['stats']),
        preview: m['preview'] as String? ?? '',
        updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
        syncState: m['syncState'] == SyncState.synced.name ? SyncState.synced : SyncState.pending,
        rpe: (m['rpe'] as num?)?.toInt(),
      );

  final String id;
  final Discipline discipline;
  final String title;
  final String description;

  /// Milisegundos desde epoch.
  final int startedAt;
  final int finishedAt;
  final CardioStats stats;

  /// Polilínea simplificada (codificada) para miniaturas.
  final String preview;

  /// Última modificación (ms): gana la más reciente entre el teléfono y la nube.
  final int updatedAt;
  final SyncState syncState;

  /// Esfuerzo percibido de la sesión (escala CR-10 de Foster, 1–10). null = no se indicó.
  final int? rpe;

  /// Día local en que empezó (YYYY-MM-DD).
  String get date => toDateKey(DateTime.fromMillisecondsSinceEpoch(startedAt));

  CardioActivity copyWith({Discipline? discipline, String? title, String? description, int? updatedAt, SyncState? syncState, int? rpe}) => CardioActivity(
        id: id,
        discipline: discipline ?? this.discipline,
        title: title ?? this.title,
        description: description ?? this.description,
        startedAt: startedAt,
        finishedAt: finishedAt,
        stats: stats,
        preview: preview,
        updatedAt: updatedAt ?? this.updatedAt,
        syncState: syncState ?? this.syncState,
        rpe: rpe ?? this.rpe,
      );

  /// Campos guardados. `local` agrega el estado del respaldo (no se sube a la nube).
  Map<String, dynamic> toMap({bool local = false}) => {
        'discipline': discipline.name,
        'title': title,
        'description': description,
        'startedAt': startedAt,
        'finishedAt': finishedAt,
        'date': date,
        'stats': stats.toMap(),
        'preview': preview,
        'updatedAt': updatedAt,
        'rpe': ?rpe,
        if (local) 'syncState': syncState.name,
      };
}

/// Ruta completa: tramos separados por las pausas.
class CardioTrack {
  const CardioTrack(this.segments);

  factory CardioTrack.fromJson(Object? data) => CardioTrack([
        for (final seg in data is List ? data : const [])
          [for (final p in seg as List) TrackPoint.fromJson(p as List)],
      ]);

  final List<List<TrackPoint>> segments;

  Iterable<TrackPoint> get points => segments.expand((s) => s);

  List<List<dynamic>> toJson() => [for (final s in segments) [for (final p in s) p.toJson()]];
}

/// Puntos por documento de la nube (cada documento queda muy por debajo de 1 MB).
const trackChunkSize = 2000;

/// Ruta en documentos para Firestore: polilínea codificada, alturas (0,1 m) y
/// segundos desde el inicio. Un tramo largo se reparte en varios documentos.
List<Map<String, dynamic>> trackToChunks(CardioTrack track, int startedAt) {
  final chunks = <Map<String, dynamic>>[];
  for (var s = 0; s < track.segments.length; s++) {
    final seg = track.segments[s];
    for (var i = 0; i < seg.length; i += trackChunkSize) {
      final part = seg.sublist(i, math.min(seg.length, i + trackChunkSize));
      chunks.add({
        'segment': s,
        'polyline': encodePolyline([for (final p in part) p.latLng]),
        'alts': [for (final p in part) p.alt == null ? null : round1(p.alt!)],
        'times': [for (final p in part) ((p.t - startedAt) / 1000).round()],
      });
    }
  }
  return chunks;
}

CardioTrack trackFromChunks(List<Map<String, dynamic>> chunks, int startedAt) {
  final segments = <int, List<TrackPoint>>{};
  for (final c in chunks) {
    final coords = decodePolyline(c['polyline'] as String? ?? '');
    final alts = c['alts'] as List? ?? const [];
    final times = c['times'] as List? ?? const [];
    final seg = segments.putIfAbsent((c['segment'] as num?)?.toInt() ?? 0, () => []);
    for (var i = 0; i < coords.length; i++) {
      seg.add(TrackPoint(
        lat: coords[i].lat,
        lng: coords[i].lng,
        t: startedAt + ((i < times.length ? times[i] as num? : null) ?? 0).toInt() * 1000,
        alt: i < alts.length ? (alts[i] as num?)?.toDouble() : null,
      ));
    }
  }
  final keys = segments.keys.toList()..sort();
  return CardioTrack([for (final k in keys) segments[k]!]);
}

/// Grabación en curso. Es mutable: recibe un punto por segundo y no conviene
/// copiar la ruta completa cada vez.
class Recording {
  Recording({required this.id, required this.discipline, required this.startedAt});

  factory Recording.fromJson(Map<String, dynamic> j) {
    final r = Recording(id: j['id'] as String, discipline: Discipline.from(j['discipline']), startedAt: (j['startedAt'] as num).toInt())
      ..pausedMs = (j['pausedMs'] as num?)?.toInt() ?? 0
      ..pausedAt = (j['pausedAt'] as num?)?.toInt();
    r.segments
      ..clear()
      ..addAll(CardioTrack.fromJson(j['segments']).segments);
    if (r.segments.isEmpty) r.segments.add([]);
    final replayed = TrackAccumulator.replay(r.segments);
    r._acc = replayed;
    return r;
  }

  final String id;
  Discipline discipline;
  final int startedAt;
  final segments = <List<TrackPoint>>[[]];
  int pausedMs = 0;
  int? pausedAt;
  TrackAccumulator _acc = TrackAccumulator();

  TrackAccumulator get metrics => _acc;
  bool get paused => pausedAt != null;
  TrackPoint? get lastPoint => _acc.last ?? segments.expand((s) => s).lastOrNull;

  /// Agrega un punto del GPS; false si se descartó (pausa o punto malo).
  bool add(TrackPoint p) {
    if (paused || !acceptPoint(_acc.last, p)) return false;
    segments.last.add(p);
    _acc.add(p);
    return true;
  }

  void pause(int now) => pausedAt ??= now;

  void resume(int now) {
    final at = pausedAt;
    if (at == null) return;
    pausedMs += now - at;
    pausedAt = null;
    breakSegment();
  }

  /// Empieza un tramo nuevo: lo recorrido sin GPS (pausa o app cerrada) no suma distancia.
  void breakSegment() {
    if (segments.last.isNotEmpty) segments.add([]);
    _acc.startSegment();
  }

  /// Milisegundos de grabación sin contar las pausas.
  int activeMs(int now) => math.max(0, (pausedAt ?? now) - startedAt - pausedMs);

  CardioStats stats(int now) => CardioStats.from(_acc, durationS: activeMs(now) / 1000);

  Map<String, dynamic> toJson() => {
        'id': id,
        'discipline': discipline.name,
        'startedAt': startedAt,
        'pausedMs': pausedMs,
        'pausedAt': pausedAt,
        'segments': CardioTrack(segments).toJson(),
      };
}

final _random = math.Random();

/// Id único y ordenable por fecha.
String newActivityId(int now) => '${now.toRadixString(36)}${_random.nextInt(1 << 30).toRadixString(36)}';

/// "Carrera de la mañana", "Ruta en bici de la tarde"…
String defaultTitle(Discipline d, int startedAt) {
  final h = DateTime.fromMillisecondsSinceEpoch(startedAt).hour;
  final part = h < 5 ? 'de la noche' : (h < 12 ? 'de la mañana' : (h < 20 ? 'de la tarde' : 'de la noche'));
  return '${d.titleBase} $part';
}

/// Actividad lista para guardar a partir de la grabación terminada.
({CardioActivity activity, CardioTrack track}) finishRecording(Recording r, {required int now, String? title, String description = '', int? rpe}) {
  final end = r.pausedAt ?? now;
  final segments = [for (final s in r.segments) if (s.isNotEmpty) s];
  final acc = TrackAccumulator.replay(segments);
  final all = [for (final s in segments) for (final p in s) p.latLng];
  return (
    activity: CardioActivity(
      id: r.id,
      discipline: r.discipline,
      title: (title ?? '').trim().isEmpty ? defaultTitle(r.discipline, r.startedAt) : title!.trim(),
      description: description.trim(),
      startedAt: r.startedAt,
      finishedAt: end,
      stats: CardioStats.from(acc, durationS: r.activeMs(now) / 1000),
      preview: encodePolyline(simplifyTo(all, 200)),
      updatedAt: now,
      rpe: rpe,
    ),
    track: CardioTrack(segments),
  );
}

/// Parciales por kilómetro de una ruta guardada.
List<Split> splitsOf(CardioTrack track) => TrackAccumulator.replay(track.segments).splitsWithRemainder();

/// Perfil de altura: (distancia en km, altura en m), muestreado a ~`samples` puntos.
List<(double km, double alt)> elevationProfile(CardioTrack track, {int samples = 120}) {
  final out = <(double, double)>[];
  var dist = 0.0;
  TrackPoint? last;
  final total = track.points.length;
  final every = math.max(1, total ~/ samples);
  var i = 0;
  for (final seg in track.segments) {
    last = null;
    for (final p in seg) {
      if (last != null) dist += haversine(last.lat, last.lng, p.lat, p.lng);
      if (p.alt != null && (i % every == 0 || i == total - 1)) out.add((dist / 1000, p.alt!));
      last = p;
      i++;
    }
  }
  return out;
}

/// MET (Compendium of Physical Activities) según la velocidad media en km/h.
double metFor(Discipline d, double kmh) {
  List<(double, double)> table;
  switch (d) {
    case Discipline.running:
      // Trote lento a carrera rápida (2011 y 2024 Adult Compendium).
      table = const [(6.4, 6.0), (8.0, 8.3), (9.7, 9.8), (10.8, 10.5), (11.3, 11.0), (12.1, 11.5), (12.9, 11.8), (14.5, 12.8), (16.1, 14.5), (17.7, 16.0), (19.3, 19.0)];
    case Discipline.cycling:
      table = const [(14.0, 4.0), (17.5, 6.8), (20.5, 8.0), (24.0, 10.0), (28.0, 12.0), (32.0, 15.8)];
    case Discipline.trekking:
      // Excursión normal por cerros a campo traviesa.
      table = const [(3.0, 5.3), (5.0, 6.0), (6.5, 7.8)];
  }
  if (kmh <= table.first.$1) return table.first.$2;
  for (var i = 1; i < table.length; i++) {
    final (x0, y0) = table[i - 1];
    final (x1, y1) = table[i];
    if (kmh <= x1) return y0 + (y1 - y0) * (kmh - x0) / (x1 - x0);
  }
  return table.last.$2;
}

/// Calorías estimadas: MET × peso × horas en movimiento. null sin peso.
int? estimateKcal(Discipline d, CardioStats s, double? kg) {
  if (kg == null || kg <= 0 || s.movingS <= 0) return null;
  return jsRound(metFor(d, s.avgSpeedMs * 3.6) * kg * s.movingS / 3600);
}
