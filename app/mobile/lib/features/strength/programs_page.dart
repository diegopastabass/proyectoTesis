import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/strength/plan.dart';
import '../../core/strength/programs.dart';
import '../../ui/widgets.dart';

const _weekDays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

/// "L, X, V".
String weekdaysLabel(Set<int> days) => (days.toList()..sort()).map((d) => _weekDays[d - 1]).join(', ');

/// Cuestionario y programas sugeridos. Las sugerencias se actualizan con cada respuesta.
class ProgramsPage extends ConsumerStatefulWidget {
  const ProgramsPage({super.key});

  @override
  ConsumerState<ProgramsPage> createState() => _ProgramsPageState();
}

class _ProgramsPageState extends ConsumerState<ProgramsPage> {
  var _answers = const ProgramAnswers();

  void _set(ProgramAnswers a) => setState(() => _answers = a);

  Future<void> _adopt(Program p) async {
    final weekdays = defaultWeekdays(p.days);
    final ok = await confirm(
      context,
      'Se crearán ${p.routines.length} rutinas (${p.routines.map((r) => r.name).join(', ')}) y quedará como tu programa. '
      'Días sugeridos: ${weekdaysLabel(weekdays)}; puedes cambiarlos en Ajustes › Notificaciones.',
      accept: 'Usar programa',
    );
    if (!ok || !mounted) return;
    var created = 0;
    final done = await runGuarded(context, () async => created = await ref.read(strengthActionsProvider).adoptProgram(p, weekdays: weekdays));
    if (done && mounted) {
      context.go('/fuerza');
      showToast(context, 'Programa listo: $created rutinas creadas');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = _answers;
    final matches = recommendPrograms(a);
    final tips = concurrentTips(a);
    final current = ref.watch(trainingPlanProvider).value?.programId;
    final names = ref.watch(exercisesProvider).value?.byId;

    Widget question(String text, Widget pills) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.fgStrong),
        ),
        const SizedBox(height: 6),
        pills,
      ],
    );

    return PageBody(
      gap: 16,
      children: [
        PageHeader(title: 'Programas sugeridos', onBack: () => context.canPop() ? context.pop() : context.go('/fuerza')),
        Text(
          'Responde y te sugerimos un programa. Al elegirlo se crean sus rutinas y la app te dice cuál toca cada día.',
          style: TextStyle(fontSize: 13, color: c.muted, height: 1.4),
        ),
        question(
          '¿Cuántos días a la semana quieres entrenar fuerza?',
          ChoicePills<int>(
            options: const [2, 3, 4, 5, 6],
            selected: a.days,
            label: (d) => '$d días',
            onSelected: (d) => _set(a.copyWith(days: d)),
          ),
        ),
        question(
          '¿Cuánto llevas entrenando fuerza?',
          ChoicePills<Experience>(
            options: Experience.values,
            selected: a.experience,
            label: (e) => e.label,
            onSelected: (e) => _set(a.copyWith(experience: e)),
          ),
        ),
        question(
          '¿Qué buscas?',
          ChoicePills<TrainingGoal>(
            options: TrainingGoal.values,
            selected: a.goal,
            label: (g) => g.label,
            onSelected: (g) => _set(a.copyWith(goal: g)),
          ),
        ),
        question(
          '¿Cuánto tiempo tienes por sesión?',
          ChoicePills<int>(
            options: const [45, 60, 90],
            selected: a.minutes,
            label: (m) => m == 90 ? '90 min o más' : 'Hasta $m min',
            onSelected: (m) => _set(a.copyWith(minutes: m)),
          ),
        ),
        question(
          '¿Con qué equipo cuentas?',
          ChoicePills<Equipment>(
            options: Equipment.values,
            selected: a.equipment,
            label: (e) => e.label,
            onSelected: (e) => _set(a.copyWith(equipment: e)),
          ),
        ),
        question(
          '¿Cuántos días a la semana haces cardio?',
          ChoicePills<int>(
            options: const [0, 1, 2, 3, 4, 5, 6],
            selected: a.cardioDays,
            label: (d) => d == 0 ? 'Ninguno' : (d == 6 ? '6 o más' : '$d'),
            onSelected: (d) => _set(a.copyWith(cardioDays: d)),
          ),
        ),
        if (a.cardioDays > 0)
          question(
            '¿Qué cardio haces?',
            ChoicePills<CardioType>(
              options: CardioType.values,
              selected: a.cardio,
              label: (t) => t.label,
              onSelected: (t) => _set(a.copyWith(cardio: t)),
            ),
          ),
        const SectionTitle('Sugeridos para ti'),
        if (matches.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.search_off,
              title: 'Sin programas para esa combinación',
              message: 'Prueba con otro equipo o con menos días por semana.',
            ),
          ),
        for (var i = 0; i < matches.length; i++)
          _ProgramCard(
            match: matches[i],
            best: i == 0,
            current: matches[i].program.id == current,
            nameOf: (id) => names?[id]?.name ?? id.replaceAll('_', ' '),
            onAdopt: () => _adopt(matches[i].program),
          ),
        if (tips.isNotEmpty)
          CardList(
            header: const CardHeader('Fuerza y cardio', icon: Icons.tips_and_updates_outlined),
            children: [
              for (final t in tips)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(t, style: TextStyle(fontSize: 13, color: c.fg, height: 1.4)),
                ),
            ],
          ),
      ],
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.match, required this.best, required this.current, required this.nameOf, required this.onAdopt});

  final ProgramMatch match;
  final bool best;
  final bool current;
  final String Function(String exerciseId) nameOf;
  final VoidCallback onAdopt;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = match.program;
    final levels = p.levels.length == Experience.values.length
        ? 'todos los niveles'
        : p.levels
              .map(
                (l) => switch (l) {
                  Experience.beginner => 'principiante',
                  Experience.intermediate => 'intermedio',
                  Experience.advanced => 'avanzado',
                },
              )
              .join(' a ');

    return AppCard(
      borderColor: best ? c.primary.withValues(alpha: 0.6) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (best)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'MEJOR OPCIÓN',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: c.primary),
                    ),
                  ),
                Text(
                  p.name,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong),
                ),
                const SizedBox(height: 2),
                Text('${p.days} días · ~${p.minutes} min · $levels', style: TextStyle(fontSize: 12, color: c.muted)),
                const SizedBox(height: 8),
                Text(p.summary, style: TextStyle(fontSize: 13, color: c.fg, height: 1.4)),
                const SizedBox(height: 4),
                Text(p.forWhom, style: TextStyle(fontSize: 12, color: c.muted, height: 1.4)),
                const SizedBox(height: 8),
                for (final r in match.reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check, size: 14, color: c.success),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(r, style: TextStyle(fontSize: 12, color: c.fg)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              title: Text('Ver rutinas (${p.routines.length})', style: TextStyle(fontSize: 13, color: c.primary)),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.rotation, style: TextStyle(fontSize: 12, color: c.muted, height: 1.4)),
                for (final day in p.routines) ...[
                  const SizedBox(height: 10),
                  Text(
                    day.name,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.fgStrong),
                  ),
                  for (final e in day.exercises)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 64,
                            child: Text(
                              '${e.sets} × ${e.reps}',
                              style: TextStyle(fontSize: 12, color: c.muted, fontFeatures: tabular),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              nameOf(e.exerciseId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: c.fg),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: current
                ? const OutlinedButton(onPressed: null, child: Text('Es tu programa actual'))
                : best
                ? FilledButton(onPressed: onAdopt, child: const Text('Usar este programa'))
                : FilledButton.tonal(onPressed: onAdopt, child: const Text('Usar este programa')),
          ),
        ],
      ),
    );
  }
}
