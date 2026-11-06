/// Registro con ayuda del asistente de IA: CU-02 (fuerza con palabras), CU-07 (comida
/// con foto) y CU-16 (comida con palabras). El asistente todavía no está conectado:
/// el resultado es siempre el mismo ejemplo (`sim_data.dart`). Las comidas confirmadas
/// sí se guardan en el diario del modo demostración.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/common/date.dart';
import '../../core/nutrition/models.dart';
import '../../data/simulated/sim_data.dart';
import '../../ui/format.dart';
import '../../ui/sim_widgets.dart';
import '../../ui/widgets.dart';

/// Etapas de los flujos: escribir o sacar la foto, esperar al asistente y revisar.
enum _Step { input, working, review }

_Step _stepFrom(String? estado) => switch (estado) {
      'analizando' => _Step.working,
      'revision' => _Step.review,
      _ => _Step.input,
    };

class _Working extends StatelessWidget {
  const _Working(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 3.5, color: c.primary)),
      const SizedBox(height: 16),
      Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong)),
      const SizedBox(height: 4),
      Text('Puedes revisar y corregir el resultado antes de guardar.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.muted)),
    ]);
  }
}

/// Campo para escribir o dictar, compartido por CU-02 y CU-16.
class _SpeakOrType extends StatefulWidget {
  const _SpeakOrType({required this.controller, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;

  @override
  State<_SpeakOrType> createState() => _SpeakOrTypeState();
}

class _SpeakOrTypeState extends State<_SpeakOrType> {
  bool _listening = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: widget.controller,
          onChanged: (_) => widget.onChanged(),
          minLines: 5,
          maxLines: 9,
          decoration: InputDecoration(hintText: widget.hint),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Text(_listening ? 'Escuchando… habla con normalidad.' : 'Escribe o toca el micrófono para dictar.', style: TextStyle(fontSize: 12, color: _listening ? c.primary : c.muted)),
          ),
          IconButton.filled(
            tooltip: _listening ? 'Terminar el dictado' : 'Dictar',
            onPressed: () => setState(() => _listening = !_listening),
            style: IconButton.styleFrom(backgroundColor: _listening ? c.danger : c.primary, foregroundColor: c.onPrimary),
            icon: Icon(_listening ? Icons.stop : Icons.mic_none),
          ),
        ]),
      ]),
    );
  }
}

/// CU-02: contar la sesión de fuerza con las propias palabras.
class AiStrengthPage extends StatefulWidget {
  const AiStrengthPage({super.key, this.estado});

  final String? estado;

  @override
  State<AiStrengthPage> createState() => _AiStrengthPageState();
}

class _AiStrengthPageState extends State<AiStrengthPage> {
  late _Step _step = _stepFrom(widget.estado);
  late final _text = TextEditingController(text: widget.estado == null ? '' : simStrengthExample);
  bool _picked = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _organize() {
    FocusScope.of(context).unfocus();
    setState(() => _step = _Step.working);
    _timer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _step = _Step.review);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(_step == _Step.review ? 'Revisa tu sesión' : 'Contar mi sesión')),
      bottomNavigationBar: switch (_step) {
        _Step.input => BottomActions(children: [
            FilledButton.icon(onPressed: _text.text.trim().isEmpty ? null : _organize, icon: const Icon(Icons.auto_awesome), label: const Text('Ordenar con el asistente')),
            OutlinedButton(onPressed: () => context.go('/fuerza'), child: const Text('Usar el formulario')),
          ]),
        _Step.working => null,
        _Step.review => BottomActions(children: [
            FilledButton(
              onPressed: _picked
                  ? () {
                      showToast(context, 'Sesión guardada en tu historial');
                      context.go('/fuerza/historial');
                    }
                  : null,
              child: const Text('Guardar sesión'),
            ),
          ]),
      },
      body: switch (_step) {
        _Step.input => PageBody(children: [
            const InfoNote(icon: Icons.auto_awesome, text: 'Cuéntalo como se lo dirías a alguien: qué ejercicios hiciste, cuántas series y con cuánto peso.'),
            _SpeakOrType(controller: _text, hint: 'Sentadilla, 4 series de 8 con 80 kilos…', onChanged: () => setState(() {})),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _text.text = simStrengthExample),
                icon: const Icon(Icons.lightbulb_outline, size: 18),
                label: const Text('Ver un ejemplo'),
              ),
            ),
          ]),
        _Step.working => const Center(child: Padding(padding: EdgeInsets.all(24), child: _Working('El asistente está ordenando tu sesión…'))),
        _Step.review => PageBody(children: [
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Text('«${_text.text}»', style: TextStyle(fontSize: 13, height: 1.4, fontStyle: FontStyle.italic, color: c.muted)),
            ),
            if (!_picked)
              InfoNote(icon: Icons.help_outline, color: c.warning, title: 'Falta confirmar un ejercicio', text: 'No reconocimos «Caminata del granjero» en la lista. Elígelo para poder guardar.'),
            for (final e in simParsedStrength) _ParsedExerciseCard(exercise: e, picked: _picked, onPick: () => setState(() => _picked = true)),
          ]),
      },
    );
  }
}

class _ParsedExerciseCard extends StatelessWidget {
  const _ParsedExerciseCard({required this.exercise, required this.picked, required this.onPick});

  final SimParsedExercise exercise;
  final bool picked;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pending = exercise.unknown && !picked;
    return AppCard(
      padding: const EdgeInsets.all(12),
      borderColor: pending ? c.warning : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(pending ? Icons.help_outline : Icons.check_circle, size: 18, color: pending ? c.warning : c.success),
          const SizedBox(width: 8),
          Expanded(child: Text(exercise.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong))),
          if (pending) TextButton(style: TextButton.styleFrom(visualDensity: VisualDensity.compact), onPressed: onPick, child: const Text('Elegir')),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < exercise.sets.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: ShapeDecoration(color: c.surface2.withValues(alpha: 0.7), shape: smoothShape(9)),
              child: Text('${i + 1}.  ${exercise.sets[i]}', style: TextStyle(fontSize: 12, color: c.fg, fontFeatures: tabular)),
            ),
        ]),
      ]),
    );
  }
}

/// Revisión de una comida estimada por el asistente (CU-07 y CU-16).
class _MealReview extends StatelessWidget {
  const _MealReview({required this.estimate, required this.removed, required this.onRemove, this.leading});

  final List<SimFoodEstimate> estimate;
  final Set<int> removed;
  final ValueChanged<int> onRemove;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final kept = [for (var i = 0; i < estimate.length; i++) if (!removed.contains(i)) estimate[i]];
    double sum(double Function(SimFoodEstimate) f) => kept.fold(0, (a, e) => a + f(e));
    final unsure = kept.any((e) => e.unsure);
    return PageBody(children: [
      ?leading,
      AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Estimación de la comida', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted)),
          const SizedBox(height: 8),
          StatRow([
            SimStat('Calorías', '${sum((e) => e.kcal).round()} kcal'),
            SimStat('Proteína', '${sum((e) => e.protein).round()} g'),
            SimStat('Carbohidr.', '${sum((e) => e.carbs).round()} g'),
            SimStat('Grasa', '${sum((e) => e.fat).round()} g'),
          ]),
        ]),
      ),
      if (unsure)
        InfoNote(icon: Icons.warning_amber_rounded, color: c.warning, title: 'Revisa lo marcado', text: 'El asistente no está seguro de algunos alimentos. Corrige las cantidades si no coinciden con lo que comiste.'),
      CardList(header: const CardHeader('Alimentos detectados', icon: Icons.restaurant), children: [
        for (var i = 0; i < estimate.length; i++)
          if (!removed.contains(i))
            ListTile(
              dense: true,
              leading: Icon(estimate[i].unsure ? Icons.help_outline : Icons.check_circle_outline, size: 20, color: estimate[i].unsure ? c.warning : c.success),
              title: Text(estimate[i].name, style: TextStyle(fontSize: 14, color: c.fgStrong)),
              subtitle: Text('${estimate[i].kcal.round()} kcal · P ${estimate[i].protein.round()} · C ${estimate[i].carbs.round()} · G ${estimate[i].fat.round()}', style: TextStyle(fontSize: 12, color: c.muted)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                NumberField(initialValue: '${estimate[i].grams.round()}', width: 58, dense: true, textAlign: TextAlign.center, decimal: false),
                Padding(padding: const EdgeInsets.only(left: 4), child: Text('g', style: TextStyle(fontSize: 13, color: c.muted))),
                IconButton(tooltip: 'Quitar', visualDensity: VisualDensity.compact, onPressed: () => onRemove(i), icon: Icon(Icons.close, size: 18, color: c.faint)),
              ]),
            ),
      ]),
    ]);
  }
}

/// Guarda lo estimado en el diario de hoy.
Future<void> _saveEstimate(BuildContext context, WidgetRef ref, List<SimFoodEstimate> estimate, Set<int> removed) async {
  final date = todayKey();
  final entries = [
    for (var i = 0; i < estimate.length; i++)
      if (!removed.contains(i))
        NewDiaryEntry(
          kind: EntryKind.food,
          refId: 'ia-${estimate[i].name}',
          name: estimate[i].name,
          grams: estimate[i].grams,
          macros: Macros(kcal: estimate[i].kcal, protein: estimate[i].protein, carbs: estimate[i].carbs, fat: estimate[i].fat),
          meal: mealForNow(),
        ),
  ];
  final ok = await runGuarded(context, () => ref.read(nutritionActionsProvider).addEntries(date, entries), success: 'Comida guardada en tu diario');
  if (ok && context.mounted) context.go('/?d=$date');
}

/// CU-16: contar la comida con las propias palabras.
class AiMealTextPage extends ConsumerStatefulWidget {
  const AiMealTextPage({super.key, this.estado});

  final String? estado;

  @override
  ConsumerState<AiMealTextPage> createState() => _AiMealTextPageState();
}

class _AiMealTextPageState extends ConsumerState<AiMealTextPage> {
  late _Step _step = _stepFrom(widget.estado);
  late final _text = TextEditingController(text: widget.estado == null ? '' : 'Un plato de arroz con pollo y una ensalada');
  final _removed = <int>{};
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _estimate() {
    FocusScope.of(context).unfocus();
    setState(() => _step = _Step.working);
    _timer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _step = _Step.review);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(_step == _Step.review ? 'Revisa tu comida' : 'Contar mi comida')),
      bottomNavigationBar: switch (_step) {
        _Step.input => BottomActions(children: [
            FilledButton.icon(onPressed: _text.text.trim().isEmpty ? null : _estimate, icon: const Icon(Icons.auto_awesome), label: const Text('Estimar con el asistente')),
          ]),
        _Step.working => null,
        _Step.review => BottomActions(children: [
            FilledButton(onPressed: () => _saveEstimate(context, ref, simTextEstimate, _removed), child: const Text('Guardar en mi diario')),
          ]),
      },
      body: switch (_step) {
        _Step.input => PageBody(children: [
            const InfoNote(icon: Icons.auto_awesome, text: 'Describe lo que comiste con tus palabras. Si conoces las cantidades, inclúyelas: la estimación será mejor.'),
            _SpeakOrType(controller: _text, hint: 'Un plato de arroz con pollo y una ensalada…', onChanged: () => setState(() {})),
          ]),
        _Step.working => const Center(child: Padding(padding: EdgeInsets.all(24), child: _Working('El asistente está estimando tu comida…'))),
        _Step.review => _MealReview(
            estimate: simTextEstimate,
            removed: _removed,
            onRemove: (i) => setState(() => _removed.add(i)),
            leading: AppCard(
              padding: const EdgeInsets.all(12),
              child: Text('«${_text.text}»', style: TextStyle(fontSize: 13, height: 1.4, fontStyle: FontStyle.italic, color: c.muted)),
            ),
          ),
      },
    );
  }
}

/// CU-07: registrar una comida con una foto.
class AiPhotoPage extends ConsumerStatefulWidget {
  const AiPhotoPage({super.key, this.estado});

  final String? estado;

  @override
  ConsumerState<AiPhotoPage> createState() => _AiPhotoPageState();
}

class _AiPhotoPageState extends ConsumerState<AiPhotoPage> {
  late _Step _step = _stepFrom(widget.estado);
  final _removed = <int>{};
  bool _share = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _shoot() {
    setState(() => _step = _Step.working);
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _step = _Step.review);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_step == _Step.input) return _Viewfinder(onShoot: _shoot, onClose: () => context.pop());
    return Scaffold(
      appBar: AppBar(title: Text(_step == _Step.review ? 'Revisa tu comida' : 'Analizando la foto')),
      bottomNavigationBar: _step == _Step.review
          ? BottomActions(children: [
              FilledButton(onPressed: () => _saveEstimate(context, ref, simPhotoEstimate, _removed), child: const Text('Guardar en mi diario')),
            ])
          : null,
      body: _step == _Step.working
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const SimPhoto(icon: Icons.restaurant, tone: 0, height: 210),
                  const SizedBox(height: 22),
                  const _Working('El asistente está mirando tu plato…'),
                ]),
              ),
            )
          : _MealReview(
              estimate: simPhotoEstimate,
              removed: _removed,
              onRemove: (i) => setState(() => _removed.add(i)),
              leading: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SimPhoto(icon: Icons.restaurant, tone: 0, height: 120),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _share,
                  onChanged: (v) => setState(() => _share = v),
                  title: Text('Publicar este plato', style: TextStyle(fontSize: 14, color: c.fgStrong)),
                  subtitle: Text(_share ? 'La foto se guardará al publicarla.' : 'La foto se descarta al guardar la comida.', style: TextStyle(fontSize: 12, color: c.muted)),
                ),
              ]),
            ),
    );
  }
}

/// Visor de cámara. En el modo demostración muestra una imagen de ejemplo.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.onShoot, required this.onClose});

  final VoidCallback onShoot;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(toolbarHeight: 0, backgroundColor: Colors.black, systemOverlayStyle: SystemUiOverlayStyle.light),
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(onPressed: onClose, tooltip: 'Cerrar', icon: const Icon(Icons.close, color: Colors.white)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Stack(alignment: Alignment.center, children: [
                const SimPhoto(icon: Icons.restaurant, tone: 0, height: double.infinity, radius: 26),
                // Guía para encuadrar el plato.
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Encuadra tu plato completo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 4),
          Text('La foto solo se usa para estimar la comida.', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: onShoot,
            child: Container(
              width: 76,
              height: 76,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
              child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: c.primary == Colors.white ? Colors.grey : Colors.white)),
            ),
          ),
          const SizedBox(height: 14),
        ]),
      ),
    );
  }
}
