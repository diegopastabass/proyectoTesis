import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/activity/streak.dart';
import '../data/repositories.dart';
import '../features/strength/active_workout_pill.dart';
import '../ui/widgets.dart';
import 'modules.dart';
import 'providers.dart';
import 'theme.dart';

/// Alto de la barra de pestañas (sin el borde seguro inferior), como en iOS.
const tabBarHeight = 52.0;

/// Marco de la app: selector de módulos arriba y pestañas del módulo abajo. Ambas
/// barras son translúcidas y el contenido pasa por debajo, desenfocado.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final module = moduleForPath(location);
    final sections = module.sections;
    final selected = sections.indexWhere((s) => s.matches(location));
    final user = ref.watch(sessionUserProvider);
    final backend = ref.watch(backendProvider).kind;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    ref.listen(pendingMilestoneProvider, (_, milestone) {
      if (milestone != null) _celebrate(context, ref, milestone);
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        titleSpacing: 12,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        flexibleSpace: const GlassBar(top: true, child: SizedBox.expand()),
        title: Row(children: [
          // Sin Firebase real, un punto sobre el logo avisa que los datos son de prueba.
          Stack(clipBehavior: Clip.none, children: [
            const AppLogo(size: 32),
            if (backend != BackendKind.firebase) Positioned(right: -3, top: -3, child: _BackendBadge(backend)),
          ]),
          const SizedBox(width: 8),
          // En pantallas angostas (iPhone SE) el selector se achica en vez de desbordarse.
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: FittedBox(fit: BoxFit.scaleDown, child: _ModuleSwitcher(current: module))),
          ),
        ]),
        actions: [
          const _StreakChip(),
          Pressable(
            scale: 0.9,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Ajustes',
              onPressed: () => context.push('/ajustes'),
              icon: CircleAvatar(
                radius: 15,
                backgroundColor: c.primarySoft,
                foregroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
                child: Text(user?.initial ?? '?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.primary)),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(children: [
        Positioned.fill(child: child),
        if (module.id == ModuleId.fuerza && location != '/fuerza' && location != '/fuerza/entrenar')
          Positioned(
            left: 0,
            right: 0,
            bottom: 12 + (sections.isEmpty ? 0 : tabBarHeight) + bottomInset,
            child: const Center(child: ActiveWorkoutPill()),
          ),
      ]),
      bottomNavigationBar: sections.isEmpty
          ? null
          : _TabBar(sections: sections, selected: selected < 0 ? 0 : selected, onSelect: (i) => context.go(sections[i].path)),
    );
  }
}

/// Barra de pestañas de iOS: ícono y nombre siempre visibles, color en la elegida.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.sections, required this.selected, required this.onSelect});

  final List<Section> sections;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassBar(
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: tabBarHeight,
          child: Row(children: [
            for (var i = 0; i < sections.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == selected,
                  label: sections[i].label,
                  excludeSemantics: true,
                  child: Tooltip(
                    message: sections[i].label,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(i),
                      child: Pressable(
                        scale: 0.9,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          // La pestaña elegida "salta" un poco al tocarla.
                          AnimatedScale(
                            scale: i == selected ? 1.08 : 1,
                            duration: Motion.bouncyDuration,
                            curve: Motion.bouncy,
                            child: Icon(sections[i].icon, size: 24, color: i == selected ? c.primary : c.muted),
                          ),
                          const SizedBox(height: 2),
                          AnimatedDefaultTextStyle(
                            duration: Motion.fast,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500,
                              color: i == selected ? c.primary : c.muted,
                            ),
                            child: Text(sections[i].label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Celebra un hito de la racha. Se marca como celebrado antes de mostrarlo para
/// que no se repita (tampoco en otro dispositivo).
void _celebrate(BuildContext context, WidgetRef ref, int milestone) {
  final streak = ref.read(streakProvider).value;
  if (streak?.start == null) return;
  ref.read(nutritionActionsProvider).markStreakCelebrated(StreakCelebration(start: streak!.start!, milestone: milestone)).ignore();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    HapticFeedback.heavyImpact();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black54,
      transitionDuration: Motion.bouncyDuration,
      pageBuilder: (_, _, _) => _MilestoneDialog(milestone: milestone, onCalendar: () => context.push('/actividad')),
      // Una celebración puede rebotar (amortiguación 0,75); con "Reducir movimiento", solo fundido.
      transitionBuilder: (ctx, a, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: Motion.reduced(ctx) ? child : ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: a, curve: Motion.bouncy)), child: child),
      ),
    );
  });
}

class _MilestoneDialog extends StatelessWidget {
  const _MilestoneDialog({required this.milestone, required this.onCalendar});

  final int milestone;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final next = nextStreakMilestone(milestone);
    return AlertDialog(
      icon: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1),
        duration: Motion.bouncyDuration,
        curve: Motion.bouncy,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(gradient: c.gradient, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.primary.withValues(alpha: 0.4), blurRadius: 24)]),
          child: Icon(Icons.local_fire_department, size: 42, color: c.onPrimary),
        ),
      ),
      title: Text(streakMilestoneTitle(milestone), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.4)),
      content: Text(
        'Llevas $milestone días seguidos registrando comidas o entrenamientos. La constancia es lo que más rinde: '
        'tu próximo hito es a los $next días.',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onCalendar();
          },
          child: const Text('Ver calendario'),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('¡Vamos!')),
      ],
    );
  }
}

/// Racha de uso en el encabezado; abre el calendario de actividad.
class _StreakChip extends ConsumerWidget {
  const _StreakChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final streak = ref.watch(streakProvider).value;
    final days = streak?.current ?? 0;
    final active = streak?.activeToday ?? false;
    final color = days == 0 ? c.faint : (active ? c.warning : c.muted);
    return Semantics(
      button: true,
      label: 'Racha: $days ${days == 1 ? 'día' : 'días'}${days > 0 && !active ? ', registra algo hoy para mantenerla' : ''}',
      excludeSemantics: true,
      child: Pressable(
        scale: 0.9,
        child: GestureDetector(
          onTap: () => context.push('/actividad'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: ShapeDecoration(color: active ? c.warning.withValues(alpha: 0.16) : c.surface2.withValues(alpha: 0.7), shape: const StadiumBorder()),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AnimatedScale(
                scale: active ? 1.0 : 0.88,
                duration: Motion.bouncyDuration,
                curve: Motion.bouncy,
                child: Icon(active ? Icons.local_fire_department : Icons.local_fire_department_outlined, size: 18, color: color),
              ),
              const SizedBox(width: 2),
              AnimatedSwitcher(
                duration: Motion.medium,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(a), child: child),
                ),
                child: Text('$days',
                    key: ValueKey(days), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color, fontFeatures: const [FontFeature.tabularFigures()])),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Logo de NutriApp (la nutria). Mismo dibujo que el ícono de la pantalla de inicio.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/branding/logo.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'NutriApp',
      );
}

class _BackendBadge extends StatelessWidget {
  const _BackendBadge(this.kind);

  final BackendKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: kind == BackendKind.memory ? 'Modo demostración: datos en memoria, se borran al cerrar la app' : 'Conectado al emulador de Firebase',
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: c.warning, shape: BoxShape.circle, border: Border.all(color: c.canvas, width: 2)),
      ),
    );
  }
}

class _ModuleSwitcher extends ConsumerWidget {
  const _ModuleSwitcher({required this.current});

  final AppModule current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final preview = ref.watch(backendProvider).kind == BackendKind.memory;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: ShapeDecoration(color: c.surface2.withValues(alpha: 0.8), shape: const StadiumBorder()),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final m in modules.where((m) => preview || !m.previewOnly))
          Semantics(
            button: true,
            selected: m.id == current.id,
            label: m.ready ? m.label : '${m.label}, en desarrollo',
            child: GestureDetector(
              onTap: () {
                if (m.id != current.id) HapticFeedback.selectionClick();
                context.go(m.path);
              },
              child: Pressable(
                scale: 0.92,
                child: AnimatedContainer(
                  duration: Motion.standardDuration,
                  curve: Motion.standard,
                  height: 32,
                  padding: EdgeInsets.symmetric(horizontal: m.id == current.id ? 11 : 8),
                  decoration: ShapeDecoration(
                    gradient: m.id == current.id ? c.gradient : null,
                    shape: const StadiumBorder(),
                    shadows: m.id == current.id ? [BoxShadow(color: c.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))] : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Stack(clipBehavior: Clip.none, children: [
                      Icon(m.icon, size: 17, color: m.id == current.id ? c.onPrimary : c.muted),
                      if (!m.ready && m.id != current.id)
                        Positioned(
                          right: -3,
                          top: -2,
                          child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c.warning, shape: BoxShape.circle)),
                        ),
                    ]),
                    // El nombre aparece estirando la píldora.
                    AnimatedSize(
                      duration: Motion.standardDuration,
                      curve: Motion.standard,
                      child: m.id == current.id
                          ? Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(m.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: c.onPrimary)),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
