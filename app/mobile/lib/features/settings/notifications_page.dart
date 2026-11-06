import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/activity/reminders.dart';
import '../../core/common/date.dart';
import '../../core/nutrition/models.dart';
import '../../core/strength/plan.dart';
import '../../platform/capability.dart';
import '../../platform/platform_providers.dart';
import '../../ui/format.dart';
import '../../ui/widgets.dart';

const _weekDays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const _weekDayNames = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

/// Recordatorios para registrar comidas, entrenar y mantener la racha.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  /// Pide el permiso la primera vez que se activa un recordatorio.
  static Future<void> _ensurePermission(BuildContext context, WidgetRef ref) async {
    final status = await ref.read(notificationStatusProvider.future);
    if (status == CapabilityStatus.notDetermined) {
      final result = await requestNotifications(ref);
      if (result == CapabilityStatus.denied && context.mounted) {
        showToast(context, 'Sin permiso no llegarán los avisos. Puedes activarlo en Ajustes de iOS.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(reminderSettingsProvider);
    final status = ref.watch(notificationStatusProvider).value;
    final plan = ref.watch(trainingPlanProvider).value ?? const TrainingPlan();
    final nextRoutine = ref.watch(nextRoutineProvider);
    final upcoming = ref.watch(reminderPlanProvider) ?? const [];
    final ctrl = ref.read(reminderSettingsProvider.notifier);

    Future<void> update(ReminderSettings next, {bool enabling = false}) async {
      if (enabling) await _ensurePermission(context, ref);
      ctrl.set(next);
    }

    Widget timeButton(int minutes, ValueChanged<int> onPicked, {required bool enabled}) => TextButton(
          onPressed: enabled ? () async => onPicked(await pickTime(context, minutes: minutes) ?? minutes) : null,
          child: Text(formatClock(minutes), style: const TextStyle(fontFeatures: tabular)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: PageBody(gap: 12, children: [
        _PermissionCard(status: status, onRequest: () => _ensurePermission(context, ref)),
        if (!settings.any)
          FilledButton.icon(
            onPressed: () async {
              await update(ReminderSettings.suggested, enabling: true);
              if (plan.weekdays.isEmpty) await ref.read(nutritionActionsProvider).saveTrainingPlan(plan.copyWith(weekdays: defaultWeekdays(3)));
            },
            icon: const Icon(Icons.notifications_active_outlined, size: 18),
            label: const Text('Activar los recordatorios sugeridos'),
          ),
        const SectionTitle('Comidas'),
        CardList(children: [
          for (final slot in MealSlot.values)
            _SwitchRow(
              icon: mealMeta[slot]!.icon,
              title: mealMeta[slot]!.label,
              subtitle: 'Solo si aún no la registras ese día',
              value: settings.meals.containsKey(slot),
              onChanged: (on) => update(settings.withMeal(slot, on ? defaultMealTimes[slot] : null), enabling: on),
              trailing: timeButton(settings.meals[slot] ?? defaultMealTimes[slot]!, (m) => update(settings.withMeal(slot, m)),
                  enabled: settings.meals.containsKey(slot)),
            ),
        ]),
        const SectionTitle('Entrenamiento'),
        CardList(children: [
          _SwitchRow(
            icon: Icons.fitness_center,
            title: 'Hoy toca entrenar',
            subtitle: nextRoutine != null ? 'Dice qué rutina de tu programa sigue' : 'Los días que elijas, si aún no entrenas',
            value: settings.training,
            onChanged: (on) => update(settings.copyWith(training: on), enabling: on),
            trailing: timeButton(settings.trainingAt, (m) => update(settings.copyWith(trainingAt: m)), enabled: settings.training),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(plan.hasProgram ? 'Días de tu programa' : 'Días de entrenamiento', style: TextStyle(fontSize: 12, color: c.muted)),
              const SizedBox(height: 8),
              Row(children: [
                for (var d = 1; d <= 7; d++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _DayToggle(
                        label: _weekDays[d - 1],
                        name: _weekDayNames[d - 1],
                        selected: plan.weekdays.contains(d),
                        onTap: () {
                          final days = {...plan.weekdays};
                          if (!days.remove(d)) days.add(d);
                          runGuarded(context, () => ref.read(nutritionActionsProvider).saveTrainingPlan(plan.copyWith(weekdays: days)));
                        },
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
        ]),
        const SectionTitle('Racha'),
        CardList(children: [
          _SwitchRow(
            icon: Icons.local_fire_department_outlined,
            title: 'Racha en riesgo',
            subtitle: 'Si llega la noche y aún no registras nada',
            value: settings.streak,
            onChanged: (on) => update(settings.copyWith(streak: on), enabling: on),
            trailing: timeButton(settings.streakAt, (m) => update(settings.copyWith(streakAt: m)), enabled: settings.streak),
          ),
        ]),
        if (upcoming.isNotEmpty) ...[
          const SectionTitle('Próximos avisos'),
          CardList(children: [
            for (final r in upcoming.take(6))
              ListTile(
                dense: true,
                leading: Icon(switch (r.kind) {
                  ReminderKind.meal => Icons.restaurant,
                  ReminderKind.training => Icons.fitness_center,
                  ReminderKind.streak => Icons.local_fire_department_outlined,
                }, size: 20, color: c.muted),
                title: Text(r.title, style: TextStyle(fontSize: 13, color: c.fgStrong)),
                subtitle: Text(
                  '${capitalize(relativeDayLabel(toDateKey(r.at)))} · ${formatClock(r.at.hour * 60 + r.at.minute)}',
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
              ),
          ]),
        ],
        Text(
          'Los avisos se programan en el teléfono para los próximos 7 días y se actualizan al registrar: '
          'si ya anotaste el almuerzo o entrenaste, el aviso de hoy no llega. Las preferencias son de este dispositivo; '
          'los días de entrenamiento se comparten con tu cuenta.',
          style: TextStyle(fontSize: 11, color: c.faint, height: 1.5),
        ),
      ]),
    );
  }
}

/// "hoy", "mañana" o "jue, 30 oct".
String relativeDayLabel(String date) {
  final today = todayKey();
  if (date == today) return 'hoy';
  if (date == addDays(today, 1)) return 'mañana';
  return weekdayDate(date);
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.status, required this.onRequest});

  final CapabilityStatus? status;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, color, text) = switch (status) {
      CapabilityStatus.granted => (Icons.notifications_active, c.success, 'Notificaciones permitidas.'),
      CapabilityStatus.denied => (Icons.notifications_off_outlined, c.danger, 'iOS tiene bloqueadas las notificaciones de la app. Actívalas en Ajustes.'),
      CapabilityStatus.notDetermined => (Icons.notifications_none, c.warning, 'Al activar un recordatorio, iOS te pedirá permiso.'),
      _ => (Icons.phone_iphone, c.faint, 'Las notificaciones funcionan en el iPhone. Aquí puedes revisar qué avisos se programarían.'),
    };
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: c.fg, height: 1.4))),
        if (status == CapabilityStatus.denied)
          TextButton(onPressed: () => launchUrl(Uri.parse('app-settings:')), child: const Text('Ajustes'))
        else if (status == CapabilityStatus.notDetermined)
          TextButton(onPressed: onRequest, child: const Text('Permitir')),
      ]),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged, required this.trailing});

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
      child: Row(children: [
        Icon(icon, size: 20, color: c.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14, color: c.fgStrong)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: c.faint)),
          ]),
        ),
        trailing,
        Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: c.primary),
      ]),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({required this.label, required this.name, required this.selected, required this.onTap});

  final String label;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Entrenar el $name',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? c.gradient : null,
            border: selected ? null : Border.all(color: c.border),
            shape: BoxShape.circle,
          ),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? c.onPrimary : c.muted)),
        ),
      ),
    );
  }
}
