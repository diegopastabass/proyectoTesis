import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/strength/stats.dart';
import '../../ui/widgets.dart';
import 'exercise_widgets.dart';

const _page = 60;

/// Catálogo de ejercicios con búsqueda y filtro por grupo muscular.
class ExercisesPage extends ConsumerStatefulWidget {
  const ExercisesPage({super.key});

  @override
  ConsumerState<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends ConsumerState<ExercisesPage> {
  final _query = TextEditingController();
  String? _group;
  int _limit = _page;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final created = await showSheet(
      context,
      title: 'Nuevo ejercicio',
      builder: (sheet) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CustomExerciseForm(
          initialName: _query.text.trim(),
          onCancel: () => Navigator.pop(sheet),
          onCreated: (e) => Navigator.pop(sheet, e),
        ),
      ),
    );
    if (created != null && mounted) context.push('/fuerza/ejercicios/${Uri.encodeComponent(created.id)}');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final workouts = ref.watch(workoutsProvider).value ?? const [];
    final sessions = {for (final f in exerciseFrequency(workouts)) f.exerciseId: f.sessions};

    return AsyncView(ref.watch(exercisesProvider), loadingText: 'Cargando catálogo…', builder: (catalog) {
      final results = catalog.index.search(query: _query.text, group: _group, limit: _limit);
      return PageBody(gap: 12, children: [
        SectionTitle('Ejercicios', trailing: IconButton.filled(tooltip: 'Crear un ejercicio propio', onPressed: _create, icon: const Icon(Icons.add))),
        ExerciseFilters(
          controller: _query,
          group: _group,
          onChanged: () => setState(() => _limit = _page),
          onGroup: (g) => setState(() {
            _group = g;
            _limit = _page;
          }),
        ),
        if (results.isEmpty)
          Text('Sin resultados.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.muted))
        else
          CardList(children: [
            for (final e in results)
              ListTile(
                onTap: () => context.push('/fuerza/ejercicios/${Uri.encodeComponent(e.id)}'),
                leading: ExerciseThumb(e),
                title: ExerciseRowInfo(e),
                trailing: sessions[e.id] == null
                    ? null
                    : Tooltip(
                        message: 'Sesiones en que lo hiciste',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(10)),
                          child: Text('${sessions[e.id]}×', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.primary)),
                        ),
                      ),
              ),
          ]),
        if (results.length == _limit)
          Center(child: TextButton.icon(onPressed: () => setState(() => _limit += _page), icon: const Icon(Icons.expand_more), label: const Text('Mostrar más'))),
        Wrap(children: [
          Text('${catalog.exercises.length} ejercicios. Catálogo e imágenes de ', style: TextStyle(fontSize: 11, color: c.faint)),
          GestureDetector(
            onTap: () => launchUrl(Uri.parse('https://github.com/yuhonas/free-exercise-db'), mode: LaunchMode.externalApplication),
            child: Text('free-exercise-db', style: TextStyle(fontSize: 11, color: c.primary, decoration: TextDecoration.underline)),
          ),
          Text(
            ' (dominio público). Los nombres en español de los ejercicios más comunes son propios; el resto aparece en inglés.',
            style: TextStyle(fontSize: 11, color: c.faint),
          ),
        ]),
      ]);
    });
  }
}
