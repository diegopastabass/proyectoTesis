import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/common/numbers.dart';
import '../../core/common/units.dart';
import '../../core/strength/models.dart';
import '../../core/strength/session.dart';
import '../../core/strength/unit_check.dart';
import '../../core/strength/weights.dart';
import '../../platform/capability.dart';
import '../../platform/platform_providers.dart';
import '../../ui/format.dart';
import '../../ui/rpe.dart';
import '../../ui/widgets.dart';
import 'active_workout_pill.dart';
import 'exercise_block.dart';
import 'exercise_widgets.dart';
import 'set_options.dart';
import 'unit_sheets.dart';

/// Sesión en curso: marcar series, agregar ejercicios y terminar.
class WorkoutPage extends ConsumerStatefulWidget {
  const WorkoutPage({super.key});

  @override
  ConsumerState<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends ConsumerState<WorkoutPage> {
  late final TextEditingController _name = TextEditingController(text: ref.read(activeWorkoutProvider)?.name ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  ActiveWorkoutController get _ctrl => ref.read(activeWorkoutProvider.notifier);

  void _updateExercise(String key, DraftExercise Function(DraftExercise) fn) =>
      _ctrl.update((w) => w.copyWith(exercises: [for (final e in w.exercises) e.key == key ? fn(e) : e]));

  Future<void> _startRest(int seconds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _ctrl.update((w) => w.withRest(RestTimer(endsAt: now + seconds * 1000, seconds: seconds)));
    // La primera vez se pide permiso: de alarmas en iOS 26+ (isla dinámica, pantalla
    // bloqueada y alarma al terminar) o de notificaciones en versiones anteriores.
    final timer = ref.read(restTimerServiceProvider);
    var status = await timer.status();
    if (status == CapabilityStatus.notDetermined) {
      status = await timer.requestAccess();
      if (!await timer.systemTimer) ref.invalidate(notificationStatusProvider);
      // Con el permiso recién dado, se envía el descanso que ya corre.
      if (status == CapabilityStatus.granted) await _ctrl.resyncRest();
    }
    // Sin permiso de alarmas, el fin del descanso se avisa con una notificación.
    if (status == CapabilityStatus.denied && await timer.systemTimer && await ref.read(notificationStatusProvider.future) == CapabilityStatus.notDetermined) {
      if (await requestNotifications(ref) == CapabilityStatus.granted) await _ctrl.resyncRest();
    }
  }

  /// Cambia kg ↔ lb. Si ya hay pesos escritos, pregunta si convertirlos o mantenerlos.
  Future<void> _switchUnit(DraftExercise ex, WeightUnit to) async {
    var convert = false;
    if (ex.sets.any((s) => parseAmount(s.kg) != null)) {
      final answer = await askUnitSwitch(context, to: to);
      if (answer == null) return;
      convert = answer;
    }
    HapticFeedback.selectionClick();
    _updateExercise(ex.key, (e) => switchUnit(e, to, convert: convert));
  }

  Future<void> _finish(ActiveWorkout active, StrengthData data) async {
    if (doneSets(active) == 0) {
      showToast(context, 'Marca al menos una serie como hecha (✓)', error: true);
      return;
    }
    final pending = pendingSets(active);
    if (pending > 0 &&
        !await confirm(context, 'Hay $pending ${pending == 1 ? 'serie sin marcar: no se guardará' : 'series sin marcar: no se guardarán'}. ¿Terminar igual?',
            accept: 'Terminar')) {
      return;
    }
    // La hora de término es la de tocar Terminar, no la de responder el esfuerzo.
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!mounted) return;
    // ¿Algún peso parece anotado en la otra unidad (kg en una máquina en libras)?
    final suspicions = suspectUnits(active, data.workouts);
    if (suspicions.isNotEmpty) {
      final fixes = await reviewUnits(context, suspicions, data.nameOf);
      if (fixes == null || !mounted) return;
      if (fixes.isNotEmpty) {
        active = applyUnitFixes(active, fixes);
        _ctrl.set(active);
      }
    }
    if (!mounted) return;
    final answer = await askSessionRpe(context, title: '¿Qué tan duro fue el entrenamiento?');
    if (answer == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final id = await ref.read(strengthActionsProvider).saveWorkout(finishWorkout(active, now, data.nameOf, rpe: answer.rpe));
      if (!mounted) return;
      _ctrl.set(null);
      context.pushReplacement('/fuerza/historial/$id?nuevo=1');
    } on Object catch (e) {
      if (!mounted) return;
      showToast(context, errorMessage(e), error: true);
      setState(() => _saving = false);
    }
  }

  Future<void> _discard() async {
    if (!await confirm(context, '¿Descartar este entrenamiento? Se perderán las series registradas.', accept: 'Descartar', destructive: true)) return;
    if (!mounted) return;
    _ctrl.set(null);
    context.go('/fuerza');
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeWorkoutProvider);
    if (active == null) {
      return PageBody(children: [
        const AppCard(child: EmptyState(icon: Icons.fitness_center, title: 'No hay un entrenamiento en curso')),
        FilledButton(onPressed: () => context.go('/fuerza'), child: const Text('Volver')),
      ]);
    }

    return AsyncView(ref.watch(strengthDataProvider), builder: (data) {
      final volume = activeVolume(active);
      final done = doneSets(active);
      final rest = active.rest;
      return Stack(children: [
        Positioned.fill(child: _body(active, data, volume, done, resting: rest != null)),
        if (rest != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12 + MediaQuery.paddingOf(context).bottom,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: RestBar(
                  key: ValueKey(rest.endsAt),
                  rest: rest,
                  onAdjust: (d) => _ctrl.update((w) => w.rest == null ? w : w.withRest(adjustRest(w.rest!, d, DateTime.now().millisecondsSinceEpoch))),
                  onDone: () => _ctrl.update((w) => w.withRest(null)),
                  onPause: () => _ctrl.update((w) {
                    final r = w.rest;
                    if (r == null) return w;
                    final now = DateTime.now().millisecondsSinceEpoch;
                    return w.withRest(r.paused ? r.resume(now) : r.pause(now));
                  }),
                ),
              ),
            ),
          ),
      ]);
    });
  }

  Widget _body(ActiveWorkout active, StrengthData data, double volume, int done, {required bool resting}) {
    final c = context.colors;
    // Con el descanso a la vista, el final de la lista queda sobre la barra.
    return PageBody(gap: 12, bottomPadding: resting ? 130 : 48, children: [
      AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _name,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.fgStrong),
                decoration: const InputDecoration(filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, isDense: true),
                onChanged: (v) => _ctrl.update((w) => w.copyWith(name: v)),
              ),
            ),
            IconButton(tooltip: 'Descartar entrenamiento', onPressed: _discard, icon: Icon(Icons.delete_outline, color: c.danger)),
            FilledButton.icon(onPressed: _saving ? null : () => _finish(active, data), icon: const Icon(Icons.check), label: const Text('Terminar')),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.timer_outlined, size: 15, color: c.primary),
            const SizedBox(width: 4),
            ElapsedText(active.startedAt, style: TextStyle(fontSize: 12, color: c.muted)),
            const SizedBox(width: 16),
            Tooltip(
              message: 'Volumen de las series hechas (sin calentamiento)',
              child: Row(children: [
                Icon(Icons.scale_outlined, size: 15, color: c.primary),
                const SizedBox(width: 4),
                Text(formatVolume(volume, ref.watch(weightUnitProvider)), style: TextStyle(fontSize: 12, color: c.muted, fontFeatures: tabular)),
              ]),
            ),
            const SizedBox(width: 16),
            Icon(Icons.check, size: 15, color: c.primary),
            const SizedBox(width: 4),
            Text('$done ${done == 1 ? 'serie' : 'series'}', style: TextStyle(fontSize: 12, color: c.muted)),
          ]),
        ]),
      ),
      if (active.exercises.isEmpty)
        const AppCard(
          child: EmptyState(icon: Icons.fitness_center, title: 'Agrega tu primer ejercicio', message: 'Busca en el catálogo de más de 800 ejercicios o crea uno propio.'),
        ),
      for (var i = 0; i < active.exercises.length; i++)
        () {
          final ex = active.exercises[i];
          final prev = previousFor(ex, data.workouts, active.startedAt);
          final progress = progressionKg(ex, prev, step: progressionStepIn(data.exercise(ex.exerciseId), ex.unit));
          final range = ex.sets.where((s) => s.type != SetType.warmup && s.targetRepsMax != null).firstOrNull;
          return ExerciseBlock(
            note: range == null ? null : 'Objetivo: ${repsRangeLabel(range.targetReps, range.targetRepsMax)} reps por serie',
            highlight: progress == null
                ? null
                : 'La última vez llegaste al tope en todas las series: sube a ${formatWeight(progress, ex.unit)} y vuelve a ${plainEs(range?.targetReps)} reps.',
            key: ValueKey(ex.key),
            index: i,
            total: active.exercises.length,
            exercise: data.exercise(ex.exerciseId),
            name: data.nameOf(ex.exerciseId),
            previous: prev,
            unit: ex.unit,
            onUnitChange: (to) => _switchUnit(ex, to),
            rows: [
              for (var j = 0; j < ex.sets.length; j++)
                () {
                  final s = ex.sets[j];
                  final hint = suggestion(s, prev[j], progressKg: progress);
                  return SetRow(key: s.key, type: s.type, kg: s.kg, reps: s.reps, done: s.done, hintKg: hint.kg, hintReps: hint.reps);
                }(),
            ],
            onChange: (j, p) => _updateExercise(ex.key, (e) => e.withSets([
                  for (var k = 0; k < e.sets.length; k++) k == j ? e.sets[k].copyWith(type: p.type, kg: p.kg, reps: p.reps) : e.sets[k],
                ])),
            onRemoveSet: (j) => _updateExercise(ex.key, (e) => e.withSets([...e.sets]..removeAt(j))),
            onAddSet: () => _updateExercise(ex.key, (e) => e.withSets(appendSet(e.sets))),
            onAddDrop: (j) => _updateExercise(ex.key, (e) => e.withSets(insertDrop(e.sets, j, fromKg: suggestion(e.sets[j], prev[j], progressKg: progress).kg, unit: e.unit))),
            restSec: ex.restSec,
            onRestChange: (sec) => _updateExercise(ex.key, (e) => e.withRest(sec)),
            onToggleDone: (j) {
              final next = toggleDone(ex.sets[j], prev[j], progressKg: progress, unit: ex.unit);
              if (next == null) {
                showToast(context, 'Escribe las repeticiones de la serie', error: true);
                return;
              }
              if (next.done) HapticFeedback.lightImpact();
              _updateExercise(ex.key, (e) => e.withSets([for (var k = 0; k < e.sets.length; k++) k == j ? next : e.sets[k]]));
              final rest = next.done ? restAfter(ex, j) : null;
              if (rest != null) unawaited(_startRest(rest));
            },
            onMove: (d) => _ctrl.update((w) {
              final list = [...w.exercises];
              final item = list.removeAt(i);
              list.insert(i + d, item);
              return w.copyWith(exercises: list);
            }),
            onRemove: () async {
              if (ex.sets.any((s) => s.done) &&
                  !await confirm(context, '¿Quitar ${data.nameOf(ex.exerciseId)} y sus series?', accept: 'Quitar', destructive: true)) {
                return;
              }
              _ctrl.update((w) => w.copyWith(exercises: w.exercises.where((e) => e.key != ex.key).toList()));
            },
          );
        }(),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        onPressed: () async {
          final exercise = await pickExercise(context, selected: active.exercises.map((e) => e.exerciseId).toList());
          if (exercise == null) return;
          _ctrl.update((w) => w.copyWith(exercises: [
                ...w.exercises,
                DraftExercise(
                  key: newKey(),
                  exerciseId: exercise.id,
                  sets: setsForNewExercise(exercise.id, data.workouts),
                  restSec: restForNewExercise(exercise.id, data.workouts),
                  unit: unitForExercise(exercise.id, data.workouts, fallback: ref.read(weightUnitProvider)),
                ),
              ]));
        },
        icon: const Icon(Icons.add),
        label: const Text('Agregar ejercicio'),
      ),
      // Al final de la lista, donde se llega tras la última serie.
      if (active.exercises.isNotEmpty) ...[
        const SizedBox(height: 4),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: _saving ? null : () => _finish(active, data),
          icon: const Icon(Icons.check),
          label: const Text('Terminar entrenamiento'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: c.danger),
          onPressed: _discard,
          child: const Text('Descartar entrenamiento'),
        ),
      ],
    ]);
  }
}
