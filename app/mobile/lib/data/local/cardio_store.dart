import 'dart:convert';
import 'dart:io';

import '../../core/cardio/activity.dart';

/// Actividades de cardio guardadas en el teléfono: la fuente de verdad. Se graban
/// y se guardan sin internet; el respaldo en la nube se hace después (ver `CardioSync`).
abstract interface class CardioLocalStore {
  /// Resúmenes, de la más reciente a la más antigua.
  Future<List<CardioActivity>> activities();
  Future<CardioTrack?> track(String id);

  /// Crea o reemplaza el resumen y, si se entrega, la ruta.
  Future<void> put(CardioActivity activity, [CardioTrack? track]);

  /// Borra la actividad y deja una marca para borrarla también en la nube.
  Future<void> remove(String id);

  /// Actividades borradas aquí que aún no se borran en la nube.
  Future<Set<String>> deleted();
  Future<void> clearDeleted(String id);

  /// Grabación en curso (sobrevive a cerrar la app).
  Future<Recording?> readRecording();
  Future<void> writeRecording(Recording? recording);
}

/// Archivos JSON en la carpeta de la app: `index.json` (resúmenes y borradas),
/// `tracks/{id}.json` (rutas) y `recording.json` (grabación en curso).
class FileCardioLocalStore implements CardioLocalStore {
  FileCardioLocalStore(this.dir);

  final Directory dir;

  File get _index => File('${dir.path}/index.json');
  File get _recording => File('${dir.path}/recording.json');
  File _track(String id) => File('${dir.path}/tracks/$id.json');

  /// Escribe en un archivo temporal y lo renombra: un cierre a mitad no deja el archivo corrupto.
  Future<void> _write(File f, Object data) async {
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(f.path);
  }

  Future<Object?> _read(File f) async {
    if (!await f.exists()) return null;
    try {
      return jsonDecode(await f.readAsString());
    } on FormatException {
      return null;
    }
  }

  Future<({Map<String, CardioActivity> activities, Set<String> deleted})> _load() async {
    final raw = await _read(_index);
    final m = raw is Map ? raw : const {};
    return (
      activities: {
        for (final a in m['activities'] as List? ?? const [])
          (a as Map)['id'] as String: CardioActivity.fromMap(a['id'] as String, a.cast<String, dynamic>()),
      },
      deleted: {for (final id in m['deleted'] as List? ?? const []) id as String},
    );
  }

  Future<void> _save(Map<String, CardioActivity> activities, Set<String> deleted) => _write(_index, {
        'activities': [for (final a in activities.values) {'id': a.id, ...a.toMap(local: true)}],
        'deleted': deleted.toList(),
      });

  @override
  Future<List<CardioActivity>> activities() async => _sorted((await _load()).activities.values);

  @override
  Future<CardioTrack?> track(String id) async {
    final raw = await _read(_track(id));
    return raw == null ? null : CardioTrack.fromJson(raw);
  }

  @override
  Future<void> put(CardioActivity activity, [CardioTrack? track]) async {
    // La ruta primero: si se corta, el resumen aún no apunta a una ruta a medias.
    if (track != null) await _write(_track(activity.id), track.toJson());
    final s = await _load();
    await _save({...s.activities, activity.id: activity}, s.deleted);
  }

  @override
  Future<void> remove(String id) async {
    final s = await _load();
    await _save({...s.activities}..remove(id), {...s.deleted, id});
    final f = _track(id);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<Set<String>> deleted() async => (await _load()).deleted;

  @override
  Future<void> clearDeleted(String id) async {
    final s = await _load();
    await _save(s.activities, {...s.deleted}..remove(id));
  }

  @override
  Future<Recording?> readRecording() async {
    final raw = await _read(_recording);
    if (raw is! Map) return null;
    try {
      return Recording.fromJson(raw.cast<String, dynamic>());
    } on Object {
      return null;
    }
  }

  @override
  Future<void> writeRecording(Recording? recording) async {
    if (recording == null) {
      if (await _recording.exists()) await _recording.delete();
    } else {
      await _write(_recording, recording.toJson());
    }
  }
}

/// En memoria: modo demostración y pruebas.
class MemoryCardioLocalStore implements CardioLocalStore {
  MemoryCardioLocalStore({List<({CardioActivity activity, CardioTrack track})> initial = const []}) {
    for (final e in initial) {
      _activities[e.activity.id] = e.activity;
      _tracks[e.activity.id] = e.track;
    }
  }

  final _activities = <String, CardioActivity>{};
  final _tracks = <String, CardioTrack>{};
  final _deleted = <String>{};
  Map<String, dynamic>? _recording;

  @override
  Future<List<CardioActivity>> activities() async => _sorted(_activities.values);

  @override
  Future<CardioTrack?> track(String id) async => _tracks[id];

  @override
  Future<void> put(CardioActivity activity, [CardioTrack? track]) async {
    _activities[activity.id] = activity;
    if (track != null) _tracks[activity.id] = track;
  }

  @override
  Future<void> remove(String id) async {
    _activities.remove(id);
    _tracks.remove(id);
    _deleted.add(id);
  }

  @override
  Future<Set<String>> deleted() async => {..._deleted};

  @override
  Future<void> clearDeleted(String id) async => _deleted.remove(id);

  // Se guarda como JSON, igual que en el archivo, para no compartir el objeto mutable.
  @override
  Future<Recording?> readRecording() async => _recording == null ? null : Recording.fromJson(jsonDecode(jsonEncode(_recording)) as Map<String, dynamic>);

  @override
  Future<void> writeRecording(Recording? recording) async => _recording = recording?.toJson();
}

List<CardioActivity> _sorted(Iterable<CardioActivity> list) => [...list]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
