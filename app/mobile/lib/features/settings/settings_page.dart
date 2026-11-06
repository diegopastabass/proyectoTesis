import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/repositories.dart';
import '../../platform/capability.dart';
import '../../platform/platform_providers.dart';
import '../../ui/widgets.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(sessionUserProvider);
    final backend = ref.watch(backendProvider).kind;
    final theme = ref.watch(themeModeProvider);
    final capabilities = ref.watch(capabilitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: PageBody(children: [
        if (user != null)
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: c.primarySoft,
                foregroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child: Text(user.initial, style: TextStyle(color: c.primary, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.label, style: TextStyle(fontWeight: FontWeight.w600, color: c.fgStrong)),
                  if (user.email != null) Text(user.email!, style: TextStyle(fontSize: 12, color: c.muted)),
                ]),
              ),
              TextButton.icon(
                onPressed: () async {
                  if (await confirm(context, '¿Cerrar sesión?', accept: 'Cerrar sesión')) {
                    await ref.read(backendProvider).auth.signOut();
                  }
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Salir'),
              ),
            ]),
          ),
        CardList(children: [
          ListTile(
            onTap: () => context.push('/perfil'),
            leading: const Icon(Icons.accessibility_new),
            title: Text('Perfil corporal', style: TextStyle(fontSize: 14, color: c.fgStrong)),
            subtitle: Text('Estatura, edad y actividad para estimar tu gasto calórico', style: TextStyle(fontSize: 12, color: c.muted)),
            trailing: Icon(Icons.chevron_right, color: c.faint),
          ),
          ListTile(
            onTap: () => context.push('/notificaciones'),
            leading: const Icon(Icons.notifications_none),
            title: Text('Notificaciones', style: TextStyle(fontSize: 14, color: c.fgStrong)),
            subtitle: Text('Recordatorios de comidas, entrenamientos y racha', style: TextStyle(fontSize: 12, color: c.muted)),
            trailing: Icon(Icons.chevron_right, color: c.faint),
          ),
          ListTile(
            onTap: () => context.push('/actividad'),
            leading: const Icon(Icons.local_fire_department_outlined),
            title: Text('Racha y calendario', style: TextStyle(fontSize: 14, color: c.fgStrong)),
            subtitle: Text('Días con comidas o entrenamientos registrados', style: TextStyle(fontSize: 12, color: c.muted)),
            trailing: Icon(Icons.chevron_right, color: c.faint),
          ),
        ]),
        const SectionTitle('Apariencia'),
        AppSegmented<ThemeMode>(
          value: theme,
          segments: const {
            ThemeMode.system: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.brightness_auto), SizedBox(width: 6), Text('Sistema')]),
            ThemeMode.light: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.light_mode), SizedBox(width: 6), Text('Claro')]),
            ThemeMode.dark: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.dark_mode), SizedBox(width: 6), Text('Oscuro')]),
          },
          onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
        ),
        const SectionTitle('Integraciones del sistema'),
        AsyncView(
          capabilities,
          builder: (map) => CardList(children: [
            for (final entry in map.entries) _CapabilityRow(capability: entry.key, status: entry.value),
          ]),
        ),
        Text(
          'Apple Salud entrega los pasos del Diario. El podómetro en vivo y la ubicación (para cardio) ya tienen su lugar '
          'en la arquitectura (lib/platform). Los permisos se cambian en la app Salud › tu perfil › Apps, o en Ajustes de iOS.',
          style: TextStyle(fontSize: 11, color: c.faint, height: 1.4),
        ),
        const SectionTitle('Datos'),
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(backend == BackendKind.firebase ? Icons.cloud_done_outlined : Icons.science_outlined, color: c.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                switch (backend) {
                  BackendKind.firebase => 'Sincronizado con Firebase.',
                  BackendKind.emulator => 'Conectado al emulador local de Firebase (los datos se borran al detenerlo).',
                  BackendKind.memory => 'Modo demostración: los datos viven en memoria y se borran al cerrar la app.',
                },
                style: TextStyle(fontSize: 13, color: c.fg),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _CapabilityRow extends ConsumerWidget {
  const _CapabilityRow({required this.capability, required this.status});

  final Capability capability;
  final CapabilityStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final icon = switch (capability) {
      Capability.health => Icons.favorite_border,
      Capability.pedometer => Icons.directions_walk,
      Capability.location => Icons.location_on_outlined,
      Capability.camera => Icons.qr_code_scanner,
      Capability.notifications => Icons.notifications_none,
    };
    final connectable = capability == Capability.health || capability == Capability.notifications;
    final (text, color) = switch (status) {
      CapabilityStatus.granted => (capability == Capability.health ? 'Conectado' : 'Activo', c.success),
      CapabilityStatus.denied => ('Sin permiso', c.danger),
      CapabilityStatus.notDetermined => (connectable ? 'Conectar' : 'Se pide al usarla', connectable ? c.primary : c.muted),
      CapabilityStatus.notImplemented => ('Próximamente', c.warning),
      CapabilityStatus.unsupported => ('No disponible aquí', c.faint),
    };
    final canConnect = connectable && status == CapabilityStatus.notDetermined;
    return ListTile(
      onTap: canConnect
          ? () => runGuarded(context, () => capability == Capability.health ? connectHealth(ref) : requestNotifications(ref))
          : null,
      leading: Icon(icon),
      title: Text(capability.label, style: TextStyle(fontSize: 14, color: c.fgStrong)),
      subtitle: Text(capability.purpose, style: TextStyle(fontSize: 12, color: c.muted)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
      ),
    );
  }
}
