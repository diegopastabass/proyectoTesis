import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/common/numbers.dart';
import '../../core/strength/insights.dart';
import '../../core/strength/models.dart';
import '../../core/strength/stats.dart';
import '../../ui/format.dart';
import '../../ui/trend_chart.dart';
import '../../ui/widgets.dart';
import 'exercise_widgets.dart';

enum _Metric {
  e1rm('1RM est.', 'kg', 'Fuerza máxima estimada de tu mejor serie (fórmula de Epley)'),
  maxKg('Peso máx.', 'kg', 'Mayor peso de la sesión'),
  volume('Volumen', 'kg', 'kg × repeticiones de las series efectivas'),
  reps('Reps máx.', 'reps', 'Más repeticiones en una serie');

  const _Metric(this.label, this.unit, this.hint);

  final String label;
  final String unit;
  final String hint;

  double value(ExerciseSession s) => switch (this) {
        _Metric.e1rm => round1(s.best1RM),
        _Metric.maxKg => s.maxKg,
        _Metric.volume => s.volume,
        _Metric.reps => s.maxReps,
      };
}

class ExerciseDetailPage extends ConsumerWidget {
  const ExerciseDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(ref.watch(strengthDataProvider), builder: (data) {
      final exercise = data.exercise(id);
      final fallback = data.workouts.expand((w) => w.exercises).where((e) => e.exerciseId == id).firstOrNull?.name;
      if (exercise == null && fallback == null) return const LoadingView(text: 'Ejercicio no encontrado.');
      return _ExerciseDetail(key: ValueKey(id), id: id, exercise: exercise, name: exercise?.name ?? fallback!, workouts: data.workouts);
    });
  }
}

class _ExerciseDetail extends ConsumerStatefulWidget {
  const _ExerciseDetail({super.key, required this.id, required this.exercise, required this.name, required this.workouts});

  final String id;
  final Exercise? exercise;
  final String name;
  final List<Workout> workouts;

  @override
  ConsumerState<_ExerciseDetail> createState() => _ExerciseDetailState();
}

class _ExerciseDetailState extends ConsumerState<_ExerciseDetail> {
  _Metric? _metric;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final history = exerciseHistory(widget.workouts, widget.id);
    final weighted = history.any((h) => h.maxKg > 0);
    final metric = _metric ?? (weighted ? _Metric.e1rm : _Metric.reps);
    final exercise = widget.exercise;

    ExerciseSession? bestKg;
    for (final h in history) {
      if (bestKg == null || h.maxKg > bestKg.maxKg || (h.maxKg == bestKg.maxKg && h.repsAtMax > bestKg.repsAtMax)) bestKg = h;
    }
    final best1RM = history.fold(0.0, (m, h) => math.max(m, h.best1RM));
    final bestReps = history.fold(0.0, (m, h) => math.max(m, h.maxReps));
    final bestVolume = history.fold(0.0, (m, h) => math.max(m, h.volume));

    return PageBody(children: [
      PageHeader(title: widget.name, onBack: () => context.canPop() ? context.pop() : context.go('/fuerza/ejercicios')),
      if (exercise != null)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!exercise.custom) ...[ExerciseAnimation(exercise), const SizedBox(height: 10)],
          MuscleChips(exercise),
          if (!exercise.custom) ...[const SizedBox(height: 10), _Instructions(exercise.id)],
        ]),
      if (history.isEmpty)
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Icon(Icons.fitness_center, color: c.primary),
            const SizedBox(height: 6),
            Text('Aún no registras este ejercicio. Agrégalo a una rutina o a un entrenamiento para ver tu progreso.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.muted)),
          ]),
        )
      else ...[
        TileGrid(children: [
          if (weighted && bestKg != null)
            StatTile(icon: Icons.emoji_events_outlined, label: 'Mejor serie', value: formatSet(kg: bestKg.maxKg, reps: bestKg.repsAtMax)),
          if (weighted) StatTile(icon: Icons.scale_outlined, label: '1RM estimado', value: '${formatKg(round1(best1RM))} kg'),
          StatTile(icon: Icons.repeat, label: 'Más repeticiones', value: plain(bestReps)),
          if (weighted) StatTile(icon: Icons.scale_outlined, label: 'Mayor volumen', value: formatVolume(bestVolume)),
        ]),
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Progreso', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
            const SizedBox(height: 8),
            ChoicePills<_Metric>(
              scrollable: true,
              options: _Metric.values.where((m) => weighted || m == _Metric.reps).toList(),
              selected: metric,
              onSelected: (m) => setState(() => _metric = m),
              label: (m) => m.label,
            ),
            const SizedBox(height: 8),
            TrendChart<ExerciseSession>(
              key: ValueKey(metric),
              points: [for (final h in history) TrendPoint(date: h.date, value: metric.value(h), data: h)],
              unit: metric.unit,
              label: '${metric.label} de ${widget.name}',
              format: metric == _Metric.volume ? (n) => formatNumber(jsRound(n), maxFractionDigits: 0) : formatKg,
              axisFormat: metric == _Metric.volume ? compactNumber : formatKg,
              minPad: switch (metric) {
                _Metric.volume => 50,
                _Metric.reps => 1,
                _ => 2.5,
              },
              compareLabel: 'vs. sesión anterior',
              detail: (s) => 'Mejor serie ${formatSet(kg: s.maxKg, reps: s.repsAtMax)} · ${s.sets} series',
              onSelect: (s) => context.push('/fuerza/historial/${s.workoutId}'),
            ),
            if (history.length == 1)
              Text('Con una segunda sesión verás la curva.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.faint)),
            Text('${metric.hint}.', style: TextStyle(fontSize: 11, color: c.faint)),
          ]),
        ),
        CardList(header: const CardHeader('Historial'), children: [
          for (final h in history.reversed)
            InkWell(
              onTap: () => context.push('/fuerza/historial/${h.workoutId}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  Expanded(child: Text(capitalize(longDate(h.date)), style: TextStyle(fontSize: 14, color: c.muted))),
                  Text('${h.sets} series', style: TextStyle(fontSize: 12, color: c.faint)),
                  SizedBox(
                    width: 100,
                    child: Text(
                      formatSet(kg: h.maxKg, reps: h.maxKg > 0 ? h.repsAtMax : h.maxReps),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong, fontFeatures: tabular),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: c.faint),
                ]),
              ),
            ),
        ]),
      ],
    ]);
  }
}

/// Instrucciones del catálogo original (en inglés), pedidas solo si el usuario las quiere ver.
class _Instructions extends ConsumerStatefulWidget {
  const _Instructions(this.id);

  final String id;

  @override
  ConsumerState<_Instructions> createState() => _InstructionsState();
}

class _InstructionsState extends ConsumerState<_Instructions> {
  Future<List<String>>? _steps;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_steps == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => setState(() => _steps = ref.read(lookupProvider).exerciseInstructions(widget.id)),
          icon: const Icon(Icons.menu_book_outlined, size: 18),
          label: const Text('Instrucciones'),
        ),
      );
    }
    return FutureBuilder<List<String>>(
      future: _steps,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView();
        if (snap.hasError) {
          return Row(children: [
            Text('No se pudieron cargar. Revisa tu conexión.', style: TextStyle(fontSize: 12, color: c.danger)),
            TextButton(
              onPressed: () => setState(() => _steps = ref.read(lookupProvider).exerciseInstructions(widget.id)),
              child: const Text('Reintentar'),
            ),
          ]);
        }
        final steps = snap.data ?? const [];
        return AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Instrucciones (en inglés)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.muted)),
            const SizedBox(height: 6),
            if (steps.isEmpty) Text('Sin instrucciones.', style: TextStyle(fontSize: 12, color: c.faint)),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${i + 1}. ${steps[i]}', style: TextStyle(fontSize: 12, color: c.fg, height: 1.45)),
              ),
          ]),
        );
      },
    );
  }
}
