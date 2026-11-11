import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/common/numbers.dart';
import '../../core/common/units.dart';
import '../../core/strength/models.dart';
import '../../core/strength/session.dart';
import '../../core/strength/stats.dart';
import '../../core/strength/weights.dart';
import '../../ui/widgets.dart';
import 'exercise_block.dart';
import 'exercise_widgets.dart';
import 'unit_sheets.dart';

class RoutineEditorPage extends ConsumerWidget {
  const RoutineEditorPage({super.key, required this.id});

  /// "nueva" para crear.
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(ref.watch(strengthDataProvider), builder: (data) {
      final routine = id == 'nueva' ? null : data.routines.where((r) => r.id == id).firstOrNull;
      if (id != 'nueva' && routine == null) return const LoadingView(text: 'Rutina no encontrada.');
      return _RoutineEditor(key: ValueKey(routine?.id ?? 'nueva'), routine: routine, data: data);
    });
  }
}

class _Block {
  _Block(this.exerciseId, this.sets, this.restSec, this.unit, {this.explicitUnit = false}) : key = newKey();

  final String key;
  final String exerciseId;
  List<SetRow> sets;
  int restSec;

  /// Unidad de los pesos escritos (la de la máquina).
  WeightUnit unit;

  /// La rutina ya indicaba la unidad o el usuario la cambió: se guarda con ella.
  bool explicitUnit;
}

SetRow _row(SetType type, String kg, String reps) => SetRow(key: newKey(), type: type, kg: kg, reps: reps);

/// Peso guardado (kg) como texto en la unidad del ejercicio.
String _kgText(double? kg, WeightUnit unit) => kg == null ? '' : plainEs(displayWeight(kg, unit, decimals: 2));

/// Los pesos se escriben en la unidad del ejercicio y se guardan en kg.
double? _parseKg(String text, WeightUnit unit) => switch (parseAmount(text)) { final v? => toKg(v, unit), null => null };

class _RoutineEditor extends ConsumerStatefulWidget {
  const _RoutineEditor({super.key, required this.routine, required this.data});

  final Routine? routine;
  final StrengthData data;

  @override
  ConsumerState<_RoutineEditor> createState() => _RoutineEditorState();
}

class _RoutineEditorState extends ConsumerState<_RoutineEditor> {
  late final _name = TextEditingController(text: widget.routine?.name ?? '');
  late final WeightUnit _preferred = ref.read(weightUnitProvider);

  WeightUnit _unitFor(String exerciseId) => unitForExercise(exerciseId, widget.data.workouts, fallback: _preferred);

  late final List<_Block> _blocks = [
    for (final e in widget.routine?.exercises ?? const <RoutineExercise>[])
      () {
        final unit = e.unit ?? _unitFor(e.exerciseId);
        return _Block(
          e.exerciseId,
          [for (final s in e.sets) _row(s.type, _kgText(s.kg, unit), formatRepsRange(s.reps, s.repsMax))],
          e.restSec ?? defaultRestSec,
          unit,
          explicitUnit: e.unit != null,
        );
      }(),
  ];
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && _blocks.isNotEmpty && _blocks.every((b) => b.sets.isNotEmpty);

  List<RoutineExercise> _toExercises() => [
        for (final b in _blocks)
          RoutineExercise(exerciseId: b.exerciseId, restSec: b.restSec, unit: b.explicitUnit || b.unit != _preferred ? b.unit : null, sets: [
            for (final s in b.sets)
              () {
                final reps = parseRepsRange(s.reps);
                return StrengthSet(type: s.type, kg: _parseKg(s.kg, b.unit), reps: reps.min, repsMax: reps.max);
              }(),
          ]),
      ];

  Future<void> _save({bool start = false}) async {
    setState(() => _saving = true);
    try {
      final exercises = _toExercises();
      final name = _name.text.trim();
      final id = await ref.read(strengthActionsProvider).saveRoutine(name: name, exercises: exercises, id: widget.routine?.id);
      if (!mounted) return;
      showToast(context, 'Rutina guardada');
      if (!start) {
        context.go('/fuerza');
        return;
      }
      if (ref.read(activeWorkoutProvider) != null &&
          !await confirm(context, 'Ya tienes un entrenamiento en curso. ¿Descartarlo y empezar esta rutina?', accept: 'Empezar', destructive: true)) {
        if (mounted) context.go('/fuerza');
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      ref.read(activeWorkoutProvider.notifier).set(workoutFromRoutine(Routine(id: id, name: name, exercises: exercises), now, unitFor: _unitFor));
      if (mounted) context.pushReplacement('/fuerza/entrenar');
    } on Object catch (e) {
      if (!mounted) return;
      showToast(context, errorMessage(e), error: true);
      setState(() => _saving = false);
    }
  }

  Future<void> _switchUnit(_Block b, WeightUnit to) async {
    var convert = false;
    if (b.sets.any((s) => parseAmount(s.kg) != null)) {
      final answer = await askUnitSwitch(context, to: to);
      if (answer == null) return;
      convert = answer;
    }
    setState(() {
      if (convert) {
        b.sets = [
          for (final s in b.sets)
            switch (parseAmount(s.kg)) {
              final v? => SetRow(key: s.key, type: s.type, kg: plainEs(round1(convertWeight(v, b.unit, to))), reps: s.reps),
              null => s,
            },
        ];
      }
      b.unit = to;
      b.explicitUnit = true;
    });
  }

  Future<void> _delete() async {
    final r = widget.routine!;
    if (!await confirm(context, '¿Eliminar la rutina "${r.name}"? Los entrenamientos ya hechos se conservan.', accept: 'Eliminar', destructive: true)) {
      return;
    }
    if (!mounted) return;
    final ok = await runGuarded(context, () => ref.read(strengthActionsProvider).deleteRoutine(r.id), success: 'Rutina eliminada');
    if (ok && mounted) context.go('/fuerza');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final data = widget.data;
    return PageBody(gap: 12, bottomPadding: 48, children: [
      PageHeader(
        title: widget.routine != null ? 'Editar rutina' : 'Nueva rutina',
        onBack: () => context.pop(),
        actions: [
          if (widget.routine != null) IconButton(tooltip: 'Eliminar rutina', onPressed: _delete, icon: Icon(Icons.delete_outline, color: c.danger)),
          IconButton.filledTonal(tooltip: 'Guardar y empezar', onPressed: _valid && !_saving ? () => _save(start: true) : null, icon: const Icon(Icons.play_arrow)),
          const SizedBox(width: 4),
          FilledButton(onPressed: _valid && !_saving ? _save : null, child: const Text('Guardar')),
        ],
      ),
      AppCard(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _name,
          maxLength: 60,
          autofocus: widget.routine == null,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Nombre de la rutina', hintText: 'Rutina de pecho, Pierna A, Torso…', counterText: ''),
        ),
      ),
      if (_blocks.isEmpty)
        const AppCard(
          child: EmptyState(
            icon: Icons.fitness_center,
            title: 'Agrega ejercicios a la rutina',
            message: 'Define las series de cada uno: las de calentamiento (C), las efectivas, los drop sets (D) y, si quieres, los kilos, repeticiones y el descanso.',
          ),
        ),
      for (var i = 0; i < _blocks.length; i++)
        () {
          final b = _blocks[i];
          final last = lastSetsFor(data.workouts, b.exerciseId);
          final types = b.sets.map((s) => s.type).toList();
          return ExerciseBlock(
            key: ValueKey(b.key),
            index: i,
            total: _blocks.length,
            exercise: data.exercise(b.exerciseId),
            name: data.nameOf(b.exerciseId),
            rows: b.sets,
            previous: [for (var j = 0; j < b.sets.length; j++) matchPrevious(last, types, j)],
            unit: b.unit,
            onUnitChange: (to) => _switchUnit(b, to),
            onChange: (j, p) => setState(() {
              final s = b.sets[j];
              b.sets = [...b.sets]..[j] = SetRow(key: s.key, type: p.type ?? s.type, kg: p.kg ?? s.kg, reps: p.reps ?? s.reps);
            }),
            onRemoveSet: (j) => setState(() => b.sets = [...b.sets]..removeAt(j)),
            onAddSet: () => setState(() {
              final prev = b.sets.lastWhere((s) => s.type != SetType.drop, orElse: () => _row(SetType.normal, '', ''));
              final type = prev.type == SetType.warmup || b.sets.lastOrNull?.type == SetType.drop ? SetType.normal : prev.type;
              b.sets = [...b.sets, _row(type, prev.kg, prev.reps)];
            }),
            onAddDrop: (j) => setState(() {
              final at = dropInsertIndex(types, j);
              final drop = dropWeight(parseAmount(b.sets[at - 1].kg), b.unit);
              b.sets = [...b.sets]..insert(at, _row(SetType.drop, plainEs(drop), ''));
            }),
            restSec: b.restSec,
            onRestChange: (sec) => setState(() => b.restSec = sec),
            onMove: (d) => setState(() => _blocks.insert(i + d, _blocks.removeAt(i))),
            onRemove: () => setState(() => _blocks.removeAt(i)),
          );
        }(),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        onPressed: () async {
          final exercise = await pickExercise(context, selected: _blocks.map((b) => b.exerciseId).toList());
          if (exercise == null) return;
          final last = lastSetsFor(data.workouts, exercise.id);
          final unit = _unitFor(exercise.id);
          setState(() => _blocks.add(_Block(
                exercise.id,
                last != null && last.isNotEmpty
                    ? [for (final s in last) _row(s.type, _kgText(s.kg, unit), plainEs(s.reps))]
                    : [for (var k = 0; k < 3; k++) _row(SetType.normal, '', '')],
                restForNewExercise(exercise.id, data.workouts),
                unit,
              )));
        },
        icon: const Icon(Icons.add),
        label: const Text('Agregar ejercicio'),
      ),
    ]);
  }
}
