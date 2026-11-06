import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/activity/reminders.dart';
import '../platform/platform_providers.dart';
import 'providers.dart';
import 'router.dart';

/// Mantiene programados los recordatorios y abre la pantalla de cada aviso tocado.
///
/// Los avisos se recalculan cuando cambian los datos (registrar una comida quita
/// el aviso de esa comida de hoy) y cada vez que la app vuelve a primer plano.
class NotificationHost extends ConsumerStatefulWidget {
  const NotificationHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationHost> createState() => _NotificationHostState();
}

class _NotificationHostState extends ConsumerState<NotificationHost> {
  StreamSubscription<String>? _taps;
  ProviderSubscription<List<PlannedReminder>?>? _plan;
  late final AppLifecycleListener _lifecycle;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final service = ref.read(notificationServiceProvider);
    _taps = service.taps.listen(_open);
    service.launchRoute().then((route) {
      if (route != null) _open(route);
    }).ignore();
    _lifecycle = AppLifecycleListener(onResume: () {
      ref.read(reminderClockProvider.notifier).tick();
      ref.invalidate(notificationStatusProvider);
    });
    _plan = ref.listenManual(reminderPlanProvider, (_, plan) => _schedule(plan), fireImmediately: true);
  }

  void _open(String route) {
    if (mounted) ref.read(routerProvider).go(route);
  }

  /// Agrupa cambios seguidos (por ejemplo, al cargar los datos) en una sola programación.
  void _schedule(List<PlannedReminder>? plan) {
    if (plan == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      ref.read(notificationServiceProvider).replaceAll(plan).catchError((Object e) => debugPrint('No se pudieron programar los avisos: $e'));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _taps?.cancel();
    _plan?.close();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
