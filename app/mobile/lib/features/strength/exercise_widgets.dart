import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/strength/catalog.dart';
import '../../core/strength/models.dart';
import '../../ui/widgets.dart';

/// Miniatura: foto de la posición inicial, o un ícono si no hay foto.
class ExerciseThumb extends StatelessWidget {
  const ExerciseThumb(this.exercise, {super.key, this.size = 40});

  final Exercise? exercise;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final src = exercise == null ? null : exerciseImage(exercise!);
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(10)),
      child: Icon(Icons.fitness_center, size: size * 0.5, color: c.primary),
    );
    if (src == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        src,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (context, child, progress) => progress == null ? child : Container(width: size, height: size, color: c.surface2),
      ),
    );
  }
}

/// "Animación" del ejercicio: alterna la foto inicial y la final con un fundido.
/// Se detiene si el sistema pide reducir el movimiento.
class ExerciseAnimation extends StatefulWidget {
  const ExerciseAnimation(this.exercise, {super.key});

  final Exercise exercise;

  @override
  State<ExerciseAnimation> createState() => _ExerciseAnimationState();
}

class _ExerciseAnimationState extends State<ExerciseAnimation> {
  int _frame = 0;
  bool? _playing;
  Timer? _timer;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _playing ??= !MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  void _sync() {
    _timer?.cancel();
    if (_playing == true) _timer = Timer.periodic(const Duration(milliseconds: 900), (_) => setState(() => _frame = 1 - _frame));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final start = exerciseImage(widget.exercise, 0);
    final end = exerciseImage(widget.exercise, 1);
    final placeholder = AspectRatio(
      aspectRatio: 3 / 2,
      child: Container(
        decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(14)),
        child: Icon(Icons.fitness_center, size: 48, color: c.primary),
      ),
    );
    if (start == null || end == null || _failed) return placeholder;

    return AspectRatio(
      aspectRatio: 3 / 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(fit: StackFit.expand, children: [
          Container(color: c.surface2),
          for (final (i, src) in [(0, start), (1, end)])
            AnimatedOpacity(
              opacity: _frame == i ? 1 : 0,
              duration: const Duration(milliseconds: 500),
              child: Image.network(
                src,
                fit: BoxFit.cover,
                semanticLabel: '${widget.exercise.name}: posición ${i == 0 ? 'inicial' : 'final'}',
                errorBuilder: (_, _, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_failed) setState(() => _failed = true);
                  });
                  return const SizedBox();
                },
              ),
            ),
          Positioned(
            left: 8,
            bottom: 10,
            child: Row(children: [
              for (final i in [0, 1])
                Container(
                  width: 20,
                  height: 4,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(color: _frame == i ? c.primary : Colors.white38, borderRadius: BorderRadius.circular(2)),
                ),
            ]),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: IconButton.filledTonal(
              tooltip: _playing == true ? 'Pausar animación' : 'Reproducir animación',
              onPressed: () => setState(() {
                _playing = !(_playing ?? false);
                _sync();
              }),
              icon: Icon(_playing == true ? Icons.pause : Icons.play_arrow),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Músculos principales (resaltados), secundarios y equipo.
class MuscleChips extends StatelessWidget {
  const MuscleChips(this.exercise, {super.key});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget chip(String text, bool primary) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: primary ? c.primarySoft : null,
            border: primary ? null : Border.all(color: c.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(text, style: TextStyle(fontSize: 12, fontWeight: primary ? FontWeight.w500 : null, color: primary ? c.primary : c.muted)),
        );
    return Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (final m in exercise.primary) chip(muscleLabel(m), true),
      for (final m in exercise.secondary) chip(muscleLabel(m), false),
      Text('· ${equipmentLabel(exercise.equipment)}', style: TextStyle(fontSize: 12, color: c.faint)),
      if (exercise.nameEn.isNotEmpty && exercise.nameEn != exercise.name)
        Text('· ${exercise.nameEn}', style: TextStyle(fontSize: 12, color: c.faint)),
    ]);
  }
}

/// Nombre y detalle de un ejercicio en una fila de lista.
class ExerciseRowInfo extends StatelessWidget {
  const ExerciseRowInfo(this.exercise, {super.key});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final muscles = exercise.primary.map(muscleLabel).join(', ');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(exercise.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.fg)),
      Text(
        '${[muscles, equipmentLabel(exercise.equipment)].where((s) => s.isNotEmpty).join(' · ')}${exercise.custom ? ' · propio' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: c.faint),
      ),
    ]);
  }
}

/// Buscador con filtro por grupo muscular.
class ExerciseFilters extends StatelessWidget {
  const ExerciseFilters({super.key, required this.controller, required this.group, required this.onChanged, required this.onGroup, this.autofocus = false});

  final TextEditingController controller;
  final String? group;
  final VoidCallback onChanged;
  final ValueChanged<String?> onGroup;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: (_) => onChanged(),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar en español o inglés…'),
      ),
      const SizedBox(height: 8),
      ChoicePills<String?>(
        scrollable: true,
        options: [null, ...muscleGroups.map((g) => g.id)],
        selected: group,
        onSelected: onGroup,
        label: (id) => id == null ? 'Todos' : muscleGroups.firstWhere((g) => g.id == id).label,
      ),
    ]);
  }
}

/// Hoja para elegir un ejercicio del catálogo o crear uno propio.
Future<Exercise?> pickExercise(BuildContext context, {List<String> selected = const []}) {
  return showSheet<Exercise>(context, title: 'Agregar ejercicio', builder: (_) => _ExercisePicker(selected: selected));
}

class _ExercisePicker extends ConsumerStatefulWidget {
  const _ExercisePicker({required this.selected});

  final List<String> selected;

  @override
  ConsumerState<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<_ExercisePicker> {
  final _query = TextEditingController();
  String? _group;
  bool _creating = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_creating) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CustomExerciseForm(
          initialName: _query.text.trim(),
          onCancel: () => setState(() => _creating = false),
          onCreated: (e) => Navigator.pop(context, e),
        ),
      );
    }
    return AsyncView(ref.watch(exercisesProvider), loadingText: 'Cargando catálogo…', builder: (catalog) {
      final results = catalog.index.search(query: _query.text, group: _group);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ExerciseFilters(
            controller: _query,
            group: _group,
            autofocus: true,
            onChanged: () => setState(() {}),
            onGroup: (g) => setState(() => _group = g),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? Center(child: Text('Sin resultados.', style: TextStyle(fontSize: 12, color: c.muted)))
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final e = results[i];
                    return ListTile(
                      onTap: () => Navigator.pop(context, e),
                      leading: ExerciseThumb(e),
                      title: ExerciseRowInfo(e),
                      trailing: widget.selected.contains(e.id) ? Tooltip(message: 'Ya agregado', child: Icon(Icons.check, color: c.primary)) : null,
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: OutlinedButton.icon(onPressed: () => setState(() => _creating = true), icon: const Icon(Icons.add), label: const Text('Crear ejercicio')),
          ),
        ),
      ]);
    });
  }
}

/// Formulario de ejercicio propio (privado y sin imagen).
class CustomExerciseForm extends ConsumerStatefulWidget {
  const CustomExerciseForm({super.key, this.initialName = '', required this.onCancel, required this.onCreated});

  final String initialName;
  final VoidCallback onCancel;
  final ValueChanged<Exercise> onCreated;

  @override
  ConsumerState<CustomExerciseForm> createState() => _CustomExerciseFormState();
}

class _CustomExerciseFormState extends ConsumerState<CustomExerciseForm> {
  late final _name = TextEditingController(text: widget.initialName);
  String _muscle = 'chest';
  String? _equipment = 'barbell';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final e = await ref.read(strengthActionsProvider).createCustomExercise(name: name, equipment: _equipment, primary: [_muscle]);
      if (!mounted) return;
      showToast(context, 'Ejercicio creado');
      widget.onCreated(e);
    } on Object catch (e) {
      if (!mounted) return;
      showToast(context, errorMessage(e), error: true);
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final muscles = musclesEs.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    return ListView(children: [
      TextField(
        controller: _name,
        autofocus: true,
        maxLength: 80,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej.: Remo en máquina del gimnasio', counterText: ''),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _muscle,
            decoration: const InputDecoration(labelText: 'Músculo principal'),
            items: [for (final m in muscles) DropdownMenuItem(value: m.key, child: Text(m.value))],
            onChanged: (v) => setState(() => _muscle = v ?? _muscle),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue: _equipment,
            decoration: const InputDecoration(labelText: 'Equipo'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin equipo')),
              for (final e in equipmentEs.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _equipment = v),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Text('Los ejercicios propios son privados y no tienen imagen.', style: TextStyle(fontSize: 11, color: c.faint)),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        TextButton.icon(onPressed: widget.onCancel, icon: const Icon(Icons.search), label: const Text('Catálogo')),
        const SizedBox(width: 6),
        FilledButton(onPressed: _saving || _name.text.trim().isEmpty ? null : _submit, child: const Text('Guardar')),
      ]),
    ]);
  }
}

/// Ficha rápida de un ejercicio: animación, músculos y acceso a su progreso.
Future<void> showExerciseInfo(BuildContext context, Exercise exercise) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(exercise.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: sheet.colors.fgStrong)),
          const SizedBox(height: 12),
          ExerciseAnimation(exercise),
          const SizedBox(height: 12),
          MuscleChips(exercise),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(sheet);
                context.push('/fuerza/ejercicios/${Uri.encodeComponent(exercise.id)}');
              },
              icon: const Icon(Icons.show_chart),
              label: const Text('Progreso'),
            ),
          ),
        ]),
      ),
    ),
  );
}
