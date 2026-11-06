/// Estado del módulo de cardio: grabación en curso, actividades guardadas en el
/// teléfono y su respaldo en la nube.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/activity/models.dart';
import '../core/cardio/activity.dart';
import '../core/cardio/track.dart';
import '../data/local/cardio_store.dart';
import '../platform/capability.dart';
import '../platform/platform_providers.dart';
import 'providers.dart';

/// Crea el almacenamiento local de cada usuario. En main.dart se reemplaza por
/// archivos; por defecto (modo demostración y pruebas) vive en memoria.
final cardioStoreFactoryProvider = Provider<CardioLocalStore Function(String uid)>((ref) {
  final stores = <String, CardioLocalStore>{};
  return (uid) => stores.putIfAbsent(uid, MemoryCardioLocalStore.new);
});

final cardioStoreProvider = Provider<CardioLocalStore?>((ref) {
  final uid = ref.watch(sessionUserProvider)?.uid;
  return uid == null ? null : ref.watch(cardioStoreFactoryProvider)(uid);
});

/// Muestra el mapa de fondo (teselas de OpenStreetMap). Las pruebas lo apagan para no usar red.
final mapTilesProvider = Provider<bool>((ref) => true);

/// Actividades guardadas en el teléfono, de la más reciente a la más antigua.
/// Cada cambio se guarda primero aquí y después se respalda en la nube.
class CardioActivitiesController extends AsyncNotifier<List<CardioActivity>> {
  bool _syncing = false;
  bool _again = false;

  CardioLocalStore? get _store => ref.read(cardioStoreProvider);

  @override
  Future<List<CardioActivity>> build() async {
    final store = ref.watch(cardioStoreProvider);
    if (store == null) return const [];
    final lifecycle = AppLifecycleListener(onResume: () => unawaited(sync()));
    ref.onDispose(lifecycle.dispose);
    final list = await store.activities();
    Future.microtask(sync);
    return list;
  }

  Future<void> _reload() async {
    final store = _store;
    if (store != null) state = AsyncData(await store.activities());
  }

  Future<CardioTrack?> track(String id) async => _store?.track(id);

  Future<void> add(CardioActivity activity, CardioTrack track) async {
    await _store?.put(activity.copyWith(syncState: SyncState.pending), track);
    await _reload();
    unawaited(sync());
  }

  /// Cambia título, descripción o disciplina.
  Future<void> edit(CardioActivity activity) async {
    await _store?.put(activity.copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch, syncState: SyncState.pending));
    await _reload();
    unawaited(sync());
  }

  Future<void> remove(String id) async {
    await _store?.remove(id);
    await _reload();
    unawaited(sync());
  }

  /// Sube lo pendiente, borra en la nube lo borrado aquí y baja lo que falta
  /// (por ejemplo, en un teléfono nuevo). Sin internet, Firestore guarda las
  /// escrituras y las envía al reconectarse; mientras, quedan como pendientes.
  Future<void> sync() async {
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _again = false;
        await _syncOnce();
      } while (_again);
    } on Object catch (e) {
      debugPrint('Respaldo de cardio pendiente: $e');
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncOnce() async {
    final store = _store;
    final uid = ref.read(sessionUserProvider)?.uid;
    if (store == null || uid == null) return;
    final remote = ref.read(backendProvider).cardio;

    for (final id in await store.deleted()) {
      await remote.deleteActivity(uid, id);
      await store.clearDeleted(id);
    }
    for (final a in await store.activities()) {
      if (a.syncState == SyncState.synced) continue;
      await remote.saveActivity(uid, a, await store.track(a.id));
      // Si se editó mientras subía, queda pendiente para la próxima vuelta.
      final current = (await store.activities()).where((x) => x.id == a.id).firstOrNull;
      if (current != null && current.updatedAt == a.updatedAt) await store.put(current.copyWith(syncState: SyncState.synced));
    }
    await _reload();

    final local = {for (final a in await store.activities()) a.id: a};
    final deleted = await store.deleted();
    for (final MapEntry(key: id, value: updatedAt) in (await remote.index(uid)).entries) {
      final mine = local[id];
      if (deleted.contains(id) || (mine != null && (mine.syncState == SyncState.pending || mine.updatedAt >= updatedAt))) continue;
      final loaded = await remote.loadActivity(uid, id);
      if (loaded != null) await store.put(loaded.activity.copyWith(syncState: SyncState.synced), mine == null ? loaded.track : null);
    }
    await _reload();
  }
}

final cardioActivitiesProvider = AsyncNotifierProvider<CardioActivitiesController, List<CardioActivity>>(CardioActivitiesController.new);

/// Si la app está en primer plano. `inactive` cuenta como visible (Centro de
/// control, una llamada entrante): dura poco y la pantalla sigue a la vista.
class AppForegroundController extends Notifier<bool> {
  @override
  bool build() {
    final listener = AppLifecycleListener(onStateChange: (s) => state = _visible(s));
    ref.onDispose(listener.dispose);
    return _visible(WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed);
  }

  static bool _visible(AppLifecycleState s) => s == AppLifecycleState.resumed || s == AppLifecycleState.inactive;
}

final appForegroundProvider = NotifierProvider<AppForegroundController, bool>(AppForegroundController.new);

/// Última posición del GPS mientras se mira la pantalla de inicio de cardio:
/// así el GPS ya tiene señal cuando se toca "Iniciar". Se apaga al salir de la
/// app aunque la pantalla siga abierta (solo la grabación usa el GPS de fondo).
final gpsWarmupProvider = StreamProvider.autoDispose<GeoPoint>((ref) async* {
  if (!ref.watch(appForegroundProvider)) return;
  final status = await ref.watch(locationStatusProvider.future);
  if (!status.usable) return;
  yield* ref.watch(locationServiceProvider).track(distanceFilterMeters: 0);
});

/// Grabación en curso y última posición recibida. `version` cambia con cada punto.
class RecordingSnapshot {
  const RecordingSnapshot({required this.recording, required this.version, this.fix, this.tracking = false});

  final Recording recording;
  final int version;
  final GeoPoint? fix;

  /// El GPS está activo (falso al terminar, mientras se decide si guardar).
  final bool tracking;
}

TrackPoint _toPoint(GeoPoint g) => TrackPoint(
      lat: g.latitude,
      lng: g.longitude,
      t: g.at.millisecondsSinceEpoch,
      alt: g.altitude,
      accuracy: g.accuracy,
      speed: g.speed,
    );

/// Graba la ruta. Escribe la grabación en el teléfono cada pocos segundos y en
/// cada pausa: si iOS cierra la app, al volver a abrirla la grabación sigue.
class RecordingController extends Notifier<RecordingSnapshot?> {
  StreamSubscription<GeoPoint>? _gps;
  Timer? _persist;
  int _version = 0;
  GeoPoint? _fix;

  static const _persistEvery = Duration(seconds: 10);

  @override
  RecordingSnapshot? build() {
    ref.onDispose(_stopGps);
    final store = ref.watch(cardioStoreProvider);
    if (store != null) unawaited(_restore(store));
    return null;
  }

  Future<void> _restore(CardioLocalStore store) async {
    final r = await store.readRecording();
    if (r == null || state != null) return;
    final tracking = !r.paused;
    // Lo recorrido mientras la app estaba cerrada no tiene puntos: tramo nuevo.
    if (tracking) r.breakSegment();
    _emit(r, tracking: tracking);
    if (tracking) _listen();
  }

  Recording? get _r => state?.recording;

  void _emit(Recording r, {bool? tracking}) =>
      state = RecordingSnapshot(recording: r, version: ++_version, fix: _fix, tracking: tracking ?? state?.tracking ?? true);

  void _listen() {
    _gps?.cancel();
    _gps = ref.read(locationServiceProvider).track(distanceFilterMeters: 3, background: true).listen((g) {
      final r = _r;
      if (r == null) return;
      _fix = g;
      r.add(_toPoint(g));
      _emit(r);
    }, onError: (Object e) => debugPrint('GPS: $e'));
    _persist?.cancel();
    _persist = Timer.periodic(_persistEvery, (_) => _save());
  }

  void _stopGps() {
    _gps?.cancel();
    _gps = null;
    _persist?.cancel();
    _persist = null;
  }

  Future<void> _save() async => ref.read(cardioStoreProvider)?.writeRecording(_r);

  /// Empieza a grabar de inmediato; si es la primera vez, pide el permiso de ubicación.
  Future<CapabilityStatus> start(Discipline discipline) async {
    if (state != null) return CapabilityStatus.granted;
    var status = await ref.read(locationStatusProvider.future);
    if (status == CapabilityStatus.notDetermined) {
      status = await ref.read(locationServiceProvider).requestAccess(background: true);
      ref.invalidate(locationStatusProvider);
    }
    if (!status.usable) return status;
    final now = DateTime.now().millisecondsSinceEpoch;
    _emit(Recording(id: newActivityId(now), discipline: discipline, startedAt: now), tracking: true);
    _listen();
    unawaited(_save());
    return status;
  }

  void pause() {
    final r = _r;
    if (r == null) return;
    r.pause(DateTime.now().millisecondsSinceEpoch);
    _emit(r);
    unawaited(_save());
  }

  void resume() {
    final r = _r;
    if (r == null) return;
    r.resume(DateTime.now().millisecondsSinceEpoch);
    if (_gps == null) _listen();
    _emit(r, tracking: true);
    unawaited(_save());
  }

  void setDiscipline(Discipline d) {
    final r = _r;
    if (r == null) return;
    r.discipline = d;
    _emit(r);
    unawaited(_save());
  }

  /// Termina: congela el tiempo y apaga el GPS. Aún se puede guardar, descartar o seguir.
  Future<void> stop() async {
    final r = _r;
    if (r == null) return;
    r.pause(DateTime.now().millisecondsSinceEpoch);
    _stopGps();
    _emit(r, tracking: false);
    await _save();
  }

  Future<CardioActivity?> save({String? title, String description = '', int? rpe}) async {
    final r = _r;
    if (r == null) return null;
    final done = finishRecording(r, now: r.pausedAt ?? DateTime.now().millisecondsSinceEpoch, title: title, description: description, rpe: rpe);
    await ref.read(cardioActivitiesProvider.notifier).add(done.activity, done.track);
    await discard();
    return done.activity;
  }

  Future<void> discard() async {
    _stopGps();
    state = null;
    await ref.read(cardioStoreProvider)?.writeRecording(null);
  }
}

final recordingProvider = NotifierProvider<RecordingController, RecordingSnapshot?>(RecordingController.new);

/// Ruta completa de una actividad (se lee del teléfono al abrir el detalle).
final cardioTrackProvider = FutureProvider.autoDispose.family<CardioTrack?, String>((ref, id) async {
  // Se vuelve a leer si la lista cambia (por ejemplo, al bajar la ruta desde la nube).
  ref.watch(cardioActivitiesProvider);
  return ref.watch(cardioStoreProvider)?.track(id);
});
