/// Estado de las pantallas de diseño. Vive en memoria y se pierde al cerrar la app,
/// igual que el resto del modo demostración.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories.dart';
import '../data/simulated/sim_data.dart';
import 'providers.dart';

/// Las pantallas de diseño solo se muestran en modo demostración: con Firebase real
/// no aparecen, porque todavía no tienen backend.
final previewEnabledProvider = Provider<bool>((ref) => ref.watch(backendProvider).kind == BackendKind.memory);

enum SimPlan { free, premium, canceled }

class SimState {
  const SimState({
    this.followed = const {'camila', 'fernanda', 'matias', 'tomas'},
    this.notes = const {},
    this.reported = const {},
    this.added = const {},
    this.published = const [],
    this.plan = SimPlan.free,
    this.healthConnected = false,
    this.importedWatch = const {},
  });

  final Set<String> followed;

  /// Notas de "cómo me sentí", por registro (CU-20).
  final Map<String, String> notes;
  final Set<String> reported;

  /// Publicaciones ya agregadas a los módulos (CU-13).
  final Set<String> added;
  final List<SimPost> published;
  final SimPlan plan;
  final bool healthConnected;
  final Set<String> importedWatch;

  SimState copyWith({
    Set<String>? followed,
    Map<String, String>? notes,
    Set<String>? reported,
    Set<String>? added,
    List<SimPost>? published,
    SimPlan? plan,
    bool? healthConnected,
    Set<String>? importedWatch,
  }) =>
      SimState(
        followed: followed ?? this.followed,
        notes: notes ?? this.notes,
        reported: reported ?? this.reported,
        added: added ?? this.added,
        published: published ?? this.published,
        plan: plan ?? this.plan,
        healthConnected: healthConnected ?? this.healthConnected,
        importedWatch: importedWatch ?? this.importedWatch,
      );
}

class SimController extends Notifier<SimState> {
  @override
  SimState build() => const SimState();

  void toggleFollow(String id) => state = state.copyWith(
        followed: state.followed.contains(id) ? ({...state.followed}..remove(id)) : {...state.followed, id},
      );

  void setNote(String key, String text) => state = state.copyWith(notes: {...state.notes, key: text});

  void report(String id) => state = state.copyWith(reported: {...state.reported, id});

  void add(String id) => state = state.copyWith(added: {...state.added, id});

  void publish(SimPost post) => state = state.copyWith(published: [post, ...state.published]);

  void setPlan(SimPlan plan) => state = state.copyWith(plan: plan);

  void connectHealth(bool value) => state = state.copyWith(healthConnected: value);

  void importWatch(String id) => state = state.copyWith(importedWatch: {...state.importedWatch, id});
}

final simProvider = NotifierProvider<SimController, SimState>(SimController.new);
