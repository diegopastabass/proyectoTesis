import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/sim_providers.dart';
import '../../app/theme.dart';
import '../../core/common/numbers.dart';
import '../../core/strength/insights.dart';
import '../../core/strength/models.dart';
import '../../core/strength/session.dart';
import '../../core/strength/stats.dart';
import '../../core/training/load.dart';
import '../../ui/format.dart';
import '../../ui/rpe.dart';
import '../../ui/sim_widgets.dart';
import '../../ui/widgets.dart';
import 'exercise_widgets.dart';
import 'set_options.dart';

const _insightIcon = {
  InsightKind.first: Icons.auto_awesome,
  InsightKind.record: Icons.emoji_events_outlined,
  InsightKind.weight: Icons.trending_up,
  InsightKind.reps: Icons.repeat,
  InsightKind.sets: Icons.layers_outlined,
  InsightKind.volume: Icons.scale_outlined,
  InsightKind.streak: Icons.local_fire_department_outlined,
  InsightKind.week: Icons.event_available,
  InsightKind.milestone: Icons.military_tech_outlined,
  InsightKind.fresh: Icons.auto_awesome,
};

class WorkoutDetailPage extends ConsumerWidget {
  const WorkoutDetailPage({super.key, required this.id, this.isNew = false, this.exampleNote});

  final String id;

  /// Recién terminado: muestra la celebración y vuelve al inicio del módulo.
  final bool isNew;

  /// Borrador de ejemplo de la nota (lo usa el modo de capturas).
  final String? exampleNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(ref.watch(strengthDataProvider), builder: (data) {
      final workout = data.workouts.where((w) => w.id == id).firstOrNull;
      if (workout == null) return const LoadingView(text: 'Entrenamiento no encontrado.');
      return _WorkoutDetail(key: ValueKey(id), workout: workout, data: data, isNew: isNew, exampleNote: exampleNote);
    });
  }
}

class _WorkoutDetail extends ConsumerStatefulWidget {
  const _WorkoutDetail({super.key, required this.workout, required this.data, required this.isNew, this.exampleNote});

  final Workout workout;
  final StrengthData data;
  final bool isNew;
  final String? exampleNote;

  @override
  ConsumerState<_WorkoutDetail> createState() => _WorkoutDetailState();
}

class _WorkoutDetailState extends ConsumerState<_WorkoutDetail> {
  bool _routineUpdated = false;

  void _back() => widget.isNew ? context.go('/fuerza') : (context.canPop() ? context.pop() : context.go('/fuerza/historial'));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final w = widget.workout;
    final data = widget.data;
    final totals = workoutTotals(w);
    final insights = workoutInsights(w, data.workouts);
    // Misma rutina (o mismo nombre si fue libre), la vez anterior.
    final previous = (data.workouts
            .where((x) => x.startedAt < w.startedAt && (w.routineId != null ? x.routineId == w.routineId : x.name == w.name))
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt)))
        .firstOrNull;
    final prevVolume = previous == null ? null : workoutVolume(previous);
    final delta = prevVolume != null && prevVolume > 0 ? jsRound((totals.volume / prevVolume - 1) * 100) : null;
    final routine = w.routineId == null ? null : data.routines.where((r) => r.id == w.routineId).firstOrNull;
    final load = strengthSessionLoad(w);
    final unit = ref.watch(weightUnitProvider);

    return PageBody(children: [
      PageHeader(
        title: w.name,
        subtitle: capitalize(longDate(w.date)),
        onBack: _back,
        actions: [
          IconButton(
            tooltip: 'Eliminar entrenamiento',
            onPressed: () async {
              if (!await confirm(context, '¿Eliminar este entrenamiento del historial?', accept: 'Eliminar', destructive: true)) return;
              if (!context.mounted) return;
              final ok = await runGuarded(context, () => ref.read(strengthActionsProvider).deleteWorkout(w.id), success: 'Entrenamiento eliminado');
              if (ok && context.mounted) context.go('/fuerza/historial');
            },
            icon: Icon(Icons.delete_outline, color: c.danger),
          ),
        ],
      ),
      if (widget.isNew)
        Column(children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            builder: (_, s, child) => Transform.scale(scale: s, child: child),
            child: const GradientIcon(Icons.check, size: 52),
          ),
          const SizedBox(height: 8),
          Text('¡Entrenamiento terminado!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.fgStrong)),
        ]),
      AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text('Peso total levantado', style: TextStyle(fontSize: 12, color: c.muted)),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: totals.volume.toDouble()),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(formatVolume(v, unit), style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: c.fgStrong, fontFeatures: tabular)),
          ),
          if (delta != null && previous != null)
            Text(
              '${delta > 0 ? '+' : delta < 0 ? '−' : ''}${delta.abs()} % vs. ${formatVolume(prevVolume!, unit)} la vez anterior (${longDate(previous.date)})',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: delta > 0 ? c.success : c.muted),
            ),
          const SizedBox(height: 4),
          Text('Suma de peso × repeticiones de las series efectivas (sin calentamiento).',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.faint)),
        ]),
      ),
      TileGrid(columns: 3, children: [
        StatTile(icon: Icons.layers_outlined, label: 'Series', value: '${totals.sets}'),
        StatTile(icon: Icons.repeat, label: 'Repeticiones', value: '${totals.reps}'),
        StatTile(icon: Icons.timer_outlined, label: 'Duración', value: formatDuration(totals.durationMin)),
      ]),
      TileGrid(children: [
        StatTile(
          icon: Icons.speed,
          label: 'Esfuerzo',
          value: w.rpe == null ? 'Indicar' : '${w.rpe}/10',
          caption: w.rpe == null ? 'Toca para indicarlo' : rpeLabel(w.rpe!),
          onTap: () async {
            final answer = await askSessionRpe(context, title: '¿Qué tan duro fue el entrenamiento?', initial: w.rpe, allowSkip: false);
            final rpe = answer?.rpe;
            if (rpe == null || rpe == w.rpe || !context.mounted) return;
            await runGuarded(context, () => ref.read(strengthActionsProvider).setWorkoutRpe(w.id, rpe));
          },
        ),
        StatTile(
          icon: Icons.bolt,
          label: 'Carga',
          value: formatLoad(load.load),
          caption: load.estimated ? 'Estimada (sin esfuerzo)' : 'Esfuerzo × minutos',
          tooltip: 'Carga de la sesión: esfuerzo percibido (1–10) × minutos. Sirve para comparar fuerza y cardio.',
        ),
      ]),
      if (ref.watch(previewEnabledProvider)) FeelingNoteCard(noteKey: 'fuerza-${w.id}', initial: widget.exampleNote),
      if (insights.isNotEmpty)
        CardList(header: const CardHeader('Tus avances'), children: [
          for (final ins in insights)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                () {
                  final gold = ins.kind == InsightKind.record || ins.kind == InsightKind.milestone;
                  return Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: gold ? c.warning.withValues(alpha: 0.15) : c.primarySoft, borderRadius: BorderRadius.circular(8)),
                    child: Icon(_insightIcon[ins.kind], size: 17, color: gold ? c.warning : c.primary),
                  );
                }(),
                const SizedBox(width: 12),
                Expanded(child: Padding(padding: const EdgeInsets.only(top: 4), child: Text(ins.text, style: TextStyle(fontSize: 14, color: c.fg, height: 1.35)))),
              ]),
            ),
        ]),
      if (routine != null)
        Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(child: Text('¿Usar lo de hoy como plantilla de «${routine.name}»?', style: TextStyle(fontSize: 12, color: c.muted))),
            TextButton.icon(
              onPressed: _routineUpdated
                  ? null
                  : () async {
                      final ok = await runGuarded(
                        context,
                        () => ref.read(strengthActionsProvider).saveRoutine(name: routine.name, exercises: routineExercisesFrom(w, routine), id: routine.id),
                        success: 'Rutina actualizada con esta sesión',
                      );
                      if (ok && mounted) setState(() => _routineUpdated = true);
                    },
              icon: Icon(_routineUpdated ? Icons.check : Icons.restart_alt, size: 18),
              label: Text(_routineUpdated ? 'Listo' : 'Actualizar'),
            ),
          ]),
        ),
      for (final e in w.exercises)
        () {
          final labels = setLabels(e.sets.map((s) => s.type).toList());
          final best = e.sets.where(isEffective).fold(0.0, (m, s) => math.max(m, estimate1RM(s.kg ?? 0, s.reps ?? 0)));
          return AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              InkWell(
                onTap: () => context.push('/fuerza/ejercicios/${Uri.encodeComponent(e.exerciseId)}'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  child: Row(children: [
                    ExerciseThumb(data.exercise(e.exerciseId), size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(data.nameOf(e.exerciseId, e.name),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.primary)),
                    ),
                    if (best > 0) Text('1RM est. ${formatWeight(round1(best), e.unit)}', style: TextStyle(fontSize: 11, color: c.faint)),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Column(children: [
                  for (var j = 0; j < e.sets.length; j++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        SizedBox(
                          width: 22,
                          child: Text(labels[j],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: setTypeColor(c, e.sets[j].type),
                              )),
                        ),
                        const SizedBox(width: 10),
                        Text(formatSet(kg: e.sets[j].kg, reps: e.sets[j].reps, unit: e.unit), style: TextStyle(fontSize: 14, color: c.fg, fontFeatures: tabular)),
                      ]),
                    ),
                ]),
              ),
            ]),
          );
        }(),
      if (widget.isNew) FilledButton.icon(onPressed: () => context.go('/fuerza'), icon: const Icon(Icons.fitness_center), label: const Text('Listo')),
    ]);
  }
}
