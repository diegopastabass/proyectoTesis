import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/cardio_providers.dart';
import '../../app/sim_providers.dart';
import '../../app/modules.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/activity/calendar.dart';
import '../../core/activity/streak.dart';
import '../../core/cardio/activity.dart';
import '../../core/common/date.dart';
import '../../core/nutrition/models.dart';
import '../../ui/format.dart';
import '../../ui/widgets.dart';
import '../../ui/sim_widgets.dart';
import '../cardio/cardio_widgets.dart';

const _weekDays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const _weekDayNames = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

/// "sábado y domingo", "lunes, miércoles y viernes".
String _restDaysLabel(Set<int> days) {
  final names = [for (final d in days.toList()..sort()) _weekDayNames[d - 1]];
  return names.length <= 1 ? names.join() : '${names.take(names.length - 1).join(', ')} y ${names.last}';
}

/// Elegir los días de descanso de la racha. null si se cierra sin guardar.
Future<Set<int>?> _pickRestDays(BuildContext context, Set<int> current) {
  var selected = {...current};
  return showModalBottomSheet<Set<int>>(
    context: context,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (context) => StatefulBuilder(builder: (context, setState) {
      final c = context.colors;
      final full = selected.length >= maxStreakRestDays;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Días de descanso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: c.fgStrong)),
          const SizedBox(height: 6),
          Text(
            'Esos días no necesitas registrar nada: la racha sigue sin sumar ni gastar el protector, y no llegan recordatorios '
            'de comidas ni de racha. Si igual registras algo, el día suma. Hasta $maxStreakRestDays por semana.',
            style: TextStyle(fontSize: 12, color: c.muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          Row(children: [
            for (var d = 1; d <= 7; d++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Semantics(
                    label: _weekDayNames[d - 1],
                    selected: selected.contains(d),
                    button: true,
                    excludeSemantics: true,
                    child: ChoiceChip(
                      label: SizedBox(width: double.infinity, child: Text(_weekDays[d - 1], textAlign: TextAlign.center)),
                      labelPadding: EdgeInsets.zero,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      showCheckmark: false,
                      selected: selected.contains(d),
                      onSelected: !selected.contains(d) && full
                          ? null
                          : (on) => setState(() => selected = on ? {...selected, d} : ({...selected}..remove(d))),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(context, selected), child: const Text('Guardar')),
        ]),
      );
    }),
  );
}

const _kindLabels = {ActivityKind.nutrition: 'Nutrición', ActivityKind.strength: 'Fuerza', ActivityKind.cardio: 'Cardio'};

const _kindModules = {ActivityKind.nutrition: ModuleId.nutricion, ActivityKind.strength: ModuleId.fuerza, ActivityKind.cardio: ModuleId.cardio};

/// Módulos que ya registran actividad (cardio aparece cuando su módulo esté listo).
List<ActivityKind> get _readyKinds => [for (final k in ActivityKind.values) if (moduleById(_kindModules[k]!).ready) k];

Color kindColor(AppColors c, ActivityKind k) => switch (k) {
      ActivityKind.nutrition => c.kcal,
      ActivityKind.strength => c.protein,
      ActivityKind.cardio => c.fiber,
    };

/// Racha de uso y calendario de los días con registros.
class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> {
  String _month = monthStart(todayKey());

  /// 1 si se avanzó de mes, -1 si se retrocedió (la grilla entra desde ese lado).
  int _direction = 1;

  /// null = todos los módulos.
  ActivityKind? _filter;

  @override
  Widget build(BuildContext context) {
    final activity = ref.watch(activityProvider);
    final streak = ref.watch(streakProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Actividad')),
      body: AsyncView(
        combineAsync([activity, streak], () => (activity.requireValue, streak.requireValue)),
        builder: (data) {
          final (days, s) = data;
          return PageBody(children: [
            if (ref.watch(previewEnabledProvider))
              EntryCard(icon: Icons.show_chart, title: 'Carga en el tiempo', subtitle: 'Cómo ha cambiado tu carga de entrenamiento', onTap: () => context.push('/carga')),
            _StreakCard(
              streak: s,
              restDays: ref.watch(streakRestDaysProvider).value ?? const {},
              onRestDays: (days) => runGuarded(context, () => ref.read(nutritionActionsProvider).saveStreakRestDays(days)),
            ),
            if (!ref.watch(reminderSettingsProvider).any)
              AppCard(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                onTap: () => context.push('/notificaciones'),
                child: Row(children: [
                  Icon(Icons.notifications_none, color: context.colors.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Activa recordatorios para no olvidar registrar y entrenar.', style: TextStyle(fontSize: 13, color: context.colors.fg))),
                  Icon(Icons.chevron_right, color: context.colors.faint),
                ]),
              ),
            ChoicePills<ActivityKind?>(
              options: [null, ..._readyKinds],
              selected: _filter,
              label: (k) => k == null ? 'Todo' : _kindLabels[k]!,
              onSelected: (k) => setState(() => _filter = k),
            ),
            _MonthCard(
              month: _month,
              days: days,
              streak: s,
              filter: _filter,
              direction: _direction,
              onMonth: (m) => setState(() {
                _direction = m.compareTo(_month) > 0 ? 1 : -1;
                _month = m;
              }),
              onDay: (d) => _showDay(d, days[d]),
            ),
            _Legend(filter: _filter),
          ]);
        },
      ),
    );
  }

  void _showDay(String date, DayActivity? day) {
    final workouts = [for (final w in ref.read(workoutsProvider).value ?? const []) if (w.date == date) w];
    final routes = [for (final a in ref.read(cardioActivitiesProvider).value ?? const <CardioActivity>[]) if (a.date == date) a];
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheet) {
        final c = sheet.colors;
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(capitalize(longDate(date)), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.fgStrong)),
            ),
            if (day != null && day.late)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Registrado después del día siguiente: no suma a la racha.', style: TextStyle(fontSize: 12, color: c.muted)),
              ),
            ListTile(
              leading: Icon(Icons.restaurant, color: kindColor(c, ActivityKind.nutrition)),
              title: Text(day?.has(ActivityKind.nutrition) ?? false ? '${day!.entries} ${day.entries == 1 ? 'registro' : 'registros'}' : 'Sin comidas registradas'),
              subtitle: day?.has(ActivityKind.nutrition) ?? false ? Text('${formatMacro(MacroKey.kcal, day!.kcal)} kcal') : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(sheet);
                context.go('/?d=$date');
              },
            ),
            for (final w in workouts)
              ListTile(
                leading: Icon(Icons.fitness_center, color: kindColor(c, ActivityKind.strength)),
                title: Text(w.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheet);
                  context.go('/fuerza/historial/${w.id}');
                },
              ),
            if (workouts.isEmpty)
              ListTile(
                leading: Icon(Icons.fitness_center, color: c.faint),
                title: Text('Sin entrenamientos', style: TextStyle(color: c.muted)),
              ),
            for (final a in routes)
              ListTile(
                leading: Icon(disciplineIcon(a.discipline), color: kindColor(c, ActivityKind.cardio)),
                title: Text(a.title),
                subtitle: Text(headlineMetrics(a.discipline, a.stats).map((m) => m.value).join(' · ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheet);
                  context.go('/cardio/historial/${a.id}');
                },
              ),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak, required this.restDays, required this.onRestDays});

  final StreakInfo streak;
  final Set<int> restDays;
  final ValueChanged<Set<int>> onRestDays;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = streak;
    final today = todayKey();
    final next = nextStreakMilestone(s.current);
    final previous = s.current == 0 ? 0 : [0, 5, 7, 10, for (var m = 30; m < next; m += 30) m].lastWhere((m) => m <= s.current);
    final shieldUsed = s.protectorUsedInWeek(today);
    final message = s.current == 0
        ? 'Registra una comida o un entrenamiento para empezar tu racha.'
        : s.restToday && !s.activeToday
            ? 'Hoy es tu día de descanso: la racha sigue aunque no registres nada.'
            : s.activeToday
            ? 'Hoy ya sumaste. Faltan ${next - s.current} ${next - s.current == 1 ? 'día' : 'días'} para ${streakMilestoneTitle(next).replaceAll(RegExp('[¡!]'), '').toLowerCase()}.'
            : 'Registra algo hoy para llegar a ${s.current + 1} ${s.current + 1 == 1 ? 'día' : 'días'}.';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.local_fire_department, size: 44, color: s.current > 0 ? c.warning : c.faint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s.current} ${s.current == 1 ? 'día' : 'días'} seguidos',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c.fgStrong, fontFeatures: tabular)),
              Text('Mejor racha: ${s.best} ${s.best == 1 ? 'día' : 'días'}', style: TextStyle(fontSize: 12, color: c.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: next == previous ? 1 : (s.current - previous) / (next - previous),
            minHeight: 6,
            backgroundColor: c.bgHard,
            color: c.warning,
            semanticsLabel: 'Avance hacia el próximo hito',
          ),
        ),
        const SizedBox(height: 8),
        Text(message, style: TextStyle(fontSize: 13, color: c.fg, height: 1.4)),
        const SizedBox(height: 8),
        Row(children: [
          Icon(shieldUsed ? Icons.shield_outlined : Icons.shield, size: 16, color: shieldUsed ? c.faint : c.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              shieldUsed
                  ? 'Ya usaste el protector de esta semana: una falta más corta la racha.'
                  : 'Protector disponible: si un día de esta semana no registras nada, la racha no se corta.',
              style: TextStyle(fontSize: 12, color: c.muted, height: 1.4),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final picked = await _pickRestDays(context, restDays);
            if (picked != null && (picked.length != restDays.length || !picked.containsAll(restDays))) onRestDays(picked);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Icon(Icons.bedtime_outlined, size: 16, color: restDays.isEmpty ? c.faint : c.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  restDays.isEmpty ? 'Sin días de descanso' : 'Días de descanso: ${_restDaysLabel(restDays)}',
                  style: TextStyle(fontSize: 12, color: c.muted, height: 1.4),
                ),
              ),
              Text('Cambiar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.primary)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.days,
    required this.streak,
    required this.filter,
    required this.onMonth,
    required this.onDay,
    this.direction = 1,
  });

  final int direction;

  final String month;
  final Map<String, DayActivity> days;
  final StreakInfo streak;
  final ActivityKind? filter;
  final ValueChanged<String> onMonth;
  final ValueChanged<String> onDay;

  bool _marked(DayActivity? d) => d != null && (filter == null ? d.counts : d.has(filter!));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = todayKey();
    final weeks = monthWeeks(month);
    final inMonth = [for (final w in weeks) ...w.nonNulls];
    final marked = inMonth.where((d) => _marked(days[d])).length;
    final isCurrent = month == monthStart(today);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconButton(onPressed: () => onMonth(addMonths(month, -1)), icon: const Icon(Icons.chevron_left), tooltip: 'Mes anterior'),
          Expanded(
            child: Column(children: [
              Text(capitalize(monthYear(month)), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong)),
              Text('$marked ${marked == 1 ? 'día' : 'días'} ${filter == null ? 'con registro' : 'de ${_kindLabels[filter]!.toLowerCase()}'}',
                  style: TextStyle(fontSize: 12, color: c.muted)),
            ]),
          ),
          IconButton(
            onPressed: isCurrent ? null : () => onMonth(addMonths(month, 1)),
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Mes siguiente',
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          for (final d in _weekDays)
            Expanded(child: Text(d, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.faint))),
        ]),
        const SizedBox(height: 4),
        // El mes nuevo entra desde el lado hacia el que se avanzó.
        AnimatedSwitcher(
          duration: Motion.standardDuration,
          switchInCurve: Motion.standard,
          switchOutCurve: Curves.easeOut,
          transitionBuilder: (child, a) {
            final incoming = child.key == ValueKey(month);
            final from = Offset(0.25 * direction * (incoming ? 1 : -1), 0);
            return FadeTransition(
              opacity: a,
              child: Motion.reduced(context) ? child : SlideTransition(position: Tween(begin: from, end: Offset.zero).animate(a), child: child),
            );
          },
          layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
          child: Column(
            key: ValueKey(month),
            children: [
              for (final week in weeks)
                Row(children: [
                  for (final date in week)
                    Expanded(
                      child: date == null
                          ? const SizedBox(height: 46)
                          : _DayCell(
                              date: date,
                              today: today,
                              day: days[date],
                              marked: _marked(days[date]),
                              shield: streak.protectedDays.contains(date),
                              rest: streak.restDays.contains(date),
                              showDots: filter == null,
                              onTap: () => onDay(date),
                            ),
                    ),
                ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.today,
    required this.day,
    required this.marked,
    required this.shield,
    required this.rest,
    required this.showDots,
    required this.onTap,
  });

  final String date;
  final String today;
  final DayActivity? day;
  final bool marked;
  final bool shield;

  /// Día de descanso sin registro que mantuvo la racha.
  final bool rest;
  final bool showDots;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final future = date.compareTo(today) > 0;
    final isToday = date == today;
    final late = showDots && (day?.late ?? false);
    final number = fromDateKey(date).day;
    final label = [
      longDate(date),
      if (marked) 'con registro',
      if (late) 'registrado tarde',
      if (shield) 'protegido',
      if (rest && !marked) 'día de descanso',
    ].join(', ');

    return Semantics(
      button: !future,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: future ? null : onTap,
        radius: 22,
        child: SizedBox(
          height: 46,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedContainer(
              duration: Motion.standardDuration,
              curve: Motion.standard,
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: marked ? c.success : (late ? c.success.withValues(alpha: 0.25) : null),
                shape: BoxShape.circle,
                border: isToday ? Border.all(color: c.primary, width: 2) : null,
              ),
              child: shield && !marked
                  ? Icon(Icons.shield, size: 16, color: c.primary)
                  : rest && !marked
                  ? Icon(Icons.bedtime_outlined, size: 16, color: c.primary)
                  : Text('$number',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: marked ? FontWeight.w600 : FontWeight.normal,
                        color: marked ? c.onPrimary : (future ? c.faint : c.fg),
                        fontFeatures: tabular,
                      )),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 5,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (showDots)
                  for (final k in ActivityKind.values)
                    if (day?.has(k) ?? false)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(color: kindColor(c, k), shape: BoxShape.circle),
                      ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.filter});

  final ActivityKind? filter;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget item(Widget mark, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          mark,
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 11, color: c.muted)),
        ]);
    Widget dot(Color color, [double size = 8]) => Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 14, runSpacing: 6, children: [
        item(dot(c.success, 12), filter == null ? 'Suma a la racha' : 'Con registro'),
        if (filter == null) ...[
          item(dot(c.success.withValues(alpha: 0.25), 12), 'Registrado tarde'),
          item(Icon(Icons.shield, size: 12, color: c.primary), 'Protector'),
          for (final k in _readyKinds) item(dot(kindColor(c, k)), _kindLabels[k]!),
        ],
      ]),
      const SizedBox(height: 10),
      Text(
        'Un día suma a la racha si registras una comida, un entrenamiento o una ruta. Puedes completar el día anterior: '
        'lo que anotes hoy sobre ayer también cuenta. Cada semana (lunes a domingo) tienes un protector: '
        'una falta no corta la racha, aunque ese día no suma.',
        style: TextStyle(fontSize: 11, color: c.faint, height: 1.5),
      ),
    ]);
  }
}
