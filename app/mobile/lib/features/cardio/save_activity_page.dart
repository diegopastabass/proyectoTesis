import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/cardio_providers.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/cardio/activity.dart';
import '../../ui/rpe.dart';
import '../../ui/widgets.dart';
import 'cardio_widgets.dart';

/// Al terminar: título, descripción y disciplina antes de guardar.
class SaveActivityPage extends ConsumerStatefulWidget {
  const SaveActivityPage({super.key});

  @override
  ConsumerState<SaveActivityPage> createState() => _SaveActivityPageState();
}

class _SaveActivityPageState extends ConsumerState<SaveActivityPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  int? _rpe;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    CardioActivity? saved;
    final ok = await runGuarded(context, () async {
      saved = await ref.read(recordingProvider.notifier).save(title: _title.text, description: _description.text, rpe: _rpe);
    }, success: 'Actividad guardada');
    if (!mounted) return;
    if (ok && saved != null) {
      context.go('/cardio/historial/${saved!.id}');
    } else {
      setState(() => _saving = false);
    }
  }

  Future<void> _discard() async {
    if (!await confirm(context, '¿Descartar esta actividad? La ruta no se guardará.', accept: 'Descartar', destructive: true)) return;
    await ref.read(recordingProvider.notifier).discard();
    if (mounted) context.go('/cardio');
  }

  void _continue() {
    ref.read(recordingProvider.notifier).resume();
    context.go('/cardio/grabar');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final snap = ref.watch(recordingProvider);
    if (snap == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_saving) context.go('/cardio');
      });
      return const Scaffold(body: LoadingView());
    }
    final r = snap.recording;
    final stats = r.stats(r.pausedAt ?? DateTime.now().millisecondsSinceEpoch);
    final kg = ref.watch(weightsProvider).value?.lastOrNull?.kg;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardar actividad'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _saving ? null : _discard,
            child: Text('Descartar', style: TextStyle(color: c.danger)),
          ),
        ],
      ),
      body: PageBody(
        gap: 12,
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Título', hintText: defaultTitle(r.discipline, r.startedAt)),
          ),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Descripción', hintText: '¿Cómo te sentiste? ¿Algo que recordar de la ruta?'),
          ),
          Center(
            child: DisciplinePicker(value: r.discipline, onChanged: ref.read(recordingProvider.notifier).setDiscipline),
          ),
          AppCard(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('¿Qué tan dura fue?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong)),
              const SizedBox(height: 2),
              Text('Esfuerzo de toda la sesión, de 1 a 10. Con esto se calcula tu carga de entrenamiento.',
                  style: TextStyle(fontSize: 12, color: c.muted)),
              const SizedBox(height: 10),
              RpePicker(value: _rpe, onChanged: (v) => setState(() => _rpe = v)),
            ]),
          ),
          RouteMap(
            segments: [
              for (final s in r.segments) [for (final p in s) p.latLng],
            ],
            height: 200,
          ),
          MetricGrid(activityMetrics(r.discipline, stats, kcal: estimateKcal(r.discipline, stats, kg))),
          if (stats.distanceM < 50)
            Text(
              'La ruta es muy corta (${formatMeters(stats.distanceM)}). Puedes guardarla igual o descartarla.',
              style: TextStyle(fontSize: 12, color: c.warning),
            ),
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.add_a_photo_outlined, color: c.faint),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Fotos de la ruta: en la próxima versión.', style: TextStyle(fontSize: 12, color: c.muted)),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text('Guardar'),
          ),
          OutlinedButton.icon(onPressed: _saving ? null : _continue, icon: const Icon(Icons.play_arrow), label: const Text('Seguir grabando')),
          Text(
            'Se guarda en el teléfono aunque no tengas internet y se respalda en tu cuenta cuando haya conexión.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: c.faint),
          ),
        ],
      ),
    );
  }
}
