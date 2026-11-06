/// Control de datos (CU-21) y suscripción (CU-24 y CU-25). Pantallas de diseño: el
/// pago y la cuenta aún no están conectados, y aquí nunca se borra ni se cobra nada real.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/sim_providers.dart';
import '../../app/theme.dart';
import '../../core/common/date.dart';
import '../../data/simulated/sim_data.dart';
import '../../ui/format.dart';
import '../../ui/sim_widgets.dart';
import '../../ui/widgets.dart';

/// CU-21: revisar y corregir los datos, y decidir qué puede leer la aplicación.
class PrivacyPage extends ConsumerStatefulWidget {
  const PrivacyPage({super.key});

  @override
  ConsumerState<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends ConsumerState<PrivacyPage> {
  bool _location = true;
  bool _notifications = true;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final health = ref.watch(simProvider).healthConnected;
    TextStyle title() => TextStyle(fontSize: 14, color: c.fgStrong);
    TextStyle sub() => TextStyle(fontSize: 12, color: c.muted);
    Widget data(String label, String value) => ListTile(
          dense: true,
          onTap: () => context.push('/perfil'),
          title: Text(label, style: title()),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(value, style: TextStyle(fontSize: 14, color: c.muted, fontFeatures: tabular)),
            Icon(Icons.chevron_right, color: c.faint),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Mis datos y privacidad')),
      body: PageBody(children: [
        const SectionTitle('Tus datos'),
        CardList(children: [
          data('Nombre', 'Usuario de prueba'),
          data('Fecha de nacimiento', '14 mar 1997'),
          data('Estatura', '178 cm'),
          data('Peso', '82 kg'),
        ]),
        const SectionTitle('Permisos'),
        CardList(children: [
          SwitchListTile.adaptive(
            value: health,
            onChanged: (v) {
              ref.read(simProvider.notifier).connectHealth(v);
              showToast(context, v ? 'Conectamos con Apple Salud' : 'Dejamos de leer tus datos de salud');
            },
            title: Text('Datos de salud', style: title()),
            subtitle: Text('Sesiones, pulso y pasos de Apple Salud.', style: sub()),
          ),
          SwitchListTile.adaptive(
            value: _location,
            onChanged: (v) => setState(() => _location = v),
            title: Text('Ubicación', style: title()),
            subtitle: Text('Para grabar tus rutas con el GPS.', style: sub()),
          ),
          SwitchListTile.adaptive(
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
            title: Text('Notificaciones', style: title()),
            subtitle: Text('Alertas de fatiga y recordatorios.', style: sub()),
          ),
        ]),
        const SectionTitle('Tu cuenta'),
        CardList(children: [
          ListTile(
            dense: true,
            onTap: () => context.push('/bienvenida/terminos'),
            leading: const Icon(Icons.description_outlined),
            title: Text('Términos de uso y aviso legal', style: title()),
            subtitle: Text('Versión 1.0 aceptada', style: sub()),
            trailing: Icon(Icons.chevron_right, color: c.faint),
          ),
          ListTile(
            dense: true,
            onTap: () => context.push('/ajustes/datos/eliminar'),
            leading: Icon(Icons.delete_outline, color: c.danger),
            title: Text('Eliminar mi cuenta', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.danger)),
            subtitle: Text('Borra todos tus datos de forma definitiva.', style: sub()),
          ),
        ]),
      ]),
    );
  }
}

/// CU-21: confirmación para eliminar la cuenta. Es de diseño: no borra nada.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key, this.example = false});

  final bool example;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  late final _confirm = TextEditingController(text: widget.example ? 'ELIMINAR' : '');

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ready = _confirm.text.trim().toUpperCase() == 'ELIMINAR';
    return Scaffold(
      appBar: AppBar(title: const Text('Eliminar mi cuenta')),
      bottomNavigationBar: BottomActions(children: [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: c.danger),
          onPressed: ready
              ? () {
                  showToast(context, 'Modo demostración: no se eliminó ningún dato.');
                  context.pop();
                }
              : null,
          child: const Text('Eliminar definitivamente'),
        ),
        OutlinedButton(onPressed: () => context.pop(), child: const Text('Cancelar')),
      ]),
      body: PageBody(children: [
        InfoNote(icon: Icons.warning_amber_rounded, color: c.danger, title: 'Esta acción no se puede deshacer', text: 'Se borran tus datos de nuestros servidores, como exige la Ley N° 19.628.'),
        CardList(header: const CardHeader('Qué se elimina'), children: [
          for (final (icon, text) in const [
            (Icons.fitness_center, 'Tus entrenamientos y rutinas'),
            (Icons.restaurant, 'Tus comidas, recetas y metas'),
            (Icons.route_outlined, 'Tus rutas y archivos'),
            (Icons.groups_outlined, 'Tus publicaciones y fotos'),
          ])
            ListTile(dense: true, leading: Icon(icon, color: c.muted), title: Text(text, style: TextStyle(fontSize: 14, color: c.fgStrong))),
        ]),
        InfoNote(icon: Icons.credit_card_off_outlined, color: c.warning, text: 'Si tienes una suscripción, cancélala en tu tienda de aplicaciones: eliminar la cuenta no la cancela.'),
        Text('Escribe ELIMINAR para confirmar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
        TextField(controller: _confirm, onChanged: (_) => setState(() {}), textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'ELIMINAR')),
      ]),
    );
  }
}

const _planRows = [
  ('Cuestionario y plan semanal', true),
  ('Registro de fuerza, cardio y comidas', true),
  ('Código de barras', true),
  ('Progreso y control de tus datos', true),
  ('Sesiones del reloj y archivos .fit', false),
  ('Registro con inteligencia artificial', false),
  ('Alertas de fatiga y metas según tu entrenamiento', false),
  ('Red social deportiva', false),
];

/// CU-24: qué incluye el plan premium, su precio final y cada cuánto se cobra.
class PremiumPage extends ConsumerStatefulWidget {
  const PremiumPage({super.key, this.estado});

  /// activo o rechazado (los usa el modo de capturas).
  final String? estado;

  @override
  ConsumerState<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends ConsumerState<PremiumPage> {
  late final bool _declined = widget.estado == 'rechazado';

  Future<void> _buy() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      builder: (sheet) => const _StoreSheet(),
    );
    if (ok == true) ref.read(simProvider.notifier).setPlan(SimPlan.premium);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = widget.estado == 'activo' || ref.watch(simProvider).plan == SimPlan.premium;
    return Scaffold(
      appBar: AppBar(title: const Text('Plan premium')),
      bottomNavigationBar: BottomActions(children: [
        if (active)
          FilledButton(onPressed: () => context.push('/premium/suscripcion'), child: const Text('Ver mi suscripción'))
        else ...[
          FilledButton(onPressed: _buy, child: const Text('Contratar por $simPremiumPrice al mes')),
          TextButton(onPressed: () => context.pop(), child: const Text('Seguir con el plan gratuito')),
        ],
      ]),
      body: PageBody(children: [
        if (active)
          InfoNote(icon: Icons.check_circle, color: c.success, title: 'Ya tienes el plan premium', text: 'Todas las funciones quedaron activas.')
        else
          Column(children: [
            const GradientIcon(Icons.workspace_premium_outlined, size: 62),
            const SizedBox(height: 12),
            Text('Cruza tu entrenamiento y tu nutrición', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: c.fgStrong)),
          ]),
        if (_declined) InfoNote(icon: Icons.error_outline, color: c.danger, title: 'No se pudo completar el pago', text: 'La tienda rechazó el pago. Sigues con el plan gratuito y no se te cobró nada.'),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$simPremiumPrice al mes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: c.fgStrong, fontFeatures: tabular)),
                Text('Precio final en pesos, con IVA incluido.', style: TextStyle(fontSize: 12, color: c.muted)),
                Text('Se cobra cada mes en tu tienda de aplicaciones.', style: TextStyle(fontSize: 12, color: c.muted)),
                Text('Cancela cuando quieras.', style: TextStyle(fontSize: 12, color: c.muted)),
              ]),
            ),
          ]),
        ),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(children: [
                Expanded(child: Text('Qué incluye', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong))),
                SizedBox(width: 56, child: Text('Gratis', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.muted))),
                SizedBox(width: 56, child: Text('Premium', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.primary))),
              ]),
            ),
            for (final (text, free) in _planRows) ...[
              const Divider(indent: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
                child: Row(children: [
                  Expanded(child: Text(text, style: TextStyle(fontSize: 13, height: 1.25, color: c.fg))),
                  SizedBox(width: 56, child: Icon(free ? Icons.check : Icons.remove, size: 18, color: free ? c.primary : c.faint)),
                  SizedBox(width: 56, child: Icon(Icons.check, size: 18, color: c.primary)),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Lugar donde se abre el pago de la tienda. Es una representación: no hay cobros.
class _StoreSheet extends StatelessWidget {
  const _StoreSheet();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Pago en la tienda', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.fgStrong)),
          const SizedBox(height: 6),
          Text('Aquí se abre el pago de la tienda de aplicaciones. En esta demostración no se realiza ningún cobro.', style: TextStyle(fontSize: 13, height: 1.35, color: c.muted)),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: Text('NutriApp Premium · mensual', style: TextStyle(fontSize: 14, color: c.fgStrong))),
              Text(simPremiumPrice, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.fgStrong)),
            ]),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simular pago aprobado')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cerrar')),
        ]),
      ),
    );
  }
}

/// CU-25: datos de la suscripción y cancelación.
class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key, this.canceled = false});

  final bool canceled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final isCanceled = canceled || ref.watch(simProvider).plan == SimPlan.canceled;
    final next = longDate(addDays(todayKey(), 18));
    return Scaffold(
      appBar: AppBar(title: const Text('Mi suscripción')),
      bottomNavigationBar: isCanceled
          ? BottomActions(children: [
              FilledButton(
                onPressed: () {
                  ref.read(simProvider.notifier).setPlan(SimPlan.premium);
                  showToast(context, 'Tu plan premium sigue activo');
                },
                child: const Text('Volver a activar'),
              ),
            ])
          : BottomActions(children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: c.danger),
                onPressed: () async {
                  if (await confirm(context, 'Te llevaremos a las suscripciones de tu tienda de aplicaciones para confirmar la cancelación.', accept: 'Ir a la tienda', destructive: true)) {
                    ref.read(simProvider.notifier).setPlan(SimPlan.canceled);
                  }
                },
                child: const Text('Cancelar suscripción'),
              ),
            ]),
      body: PageBody(children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const GradientIcon(Icons.workspace_premium_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Plan premium', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: c.fgStrong)),
                  Text('$simPremiumPrice al mes, IVA incluido', style: TextStyle(fontSize: 13, color: c.muted)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: ShapeDecoration(color: (isCanceled ? c.warning : c.success).withValues(alpha: 0.16), shape: const StadiumBorder()),
                child: Text(isCanceled ? 'Cancelada' : 'Activa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isCanceled ? c.warning : c.success)),
              ),
            ]),
          ]),
        ),
        CardList(children: [
          ListTile(dense: true, leading: const Icon(Icons.event), title: Text(isCanceled ? 'Premium hasta' : 'Próximo cobro', style: TextStyle(fontSize: 14, color: c.fgStrong)), trailing: Text(next, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong))),
          ListTile(dense: true, leading: const Icon(Icons.storefront_outlined), title: Text('Se paga en', style: TextStyle(fontSize: 14, color: c.fgStrong)), trailing: Text('App Store', style: TextStyle(fontSize: 14, color: c.muted))),
          ListTile(dense: true, leading: const Icon(Icons.autorenew), title: Text('Renovación', style: TextStyle(fontSize: 14, color: c.fgStrong)), trailing: Text(isCanceled ? 'Desactivada' : 'Mensual', style: TextStyle(fontSize: 14, color: c.muted))),
        ]),
        if (isCanceled)
          InfoNote(icon: Icons.info_outline, color: c.warning, title: 'Tu suscripción quedó cancelada', text: 'Mantienes todas las funciones hasta el $next. Después vuelves al plan gratuito y conservas tus datos.')
        else
          Text('La cancelación se confirma en la tienda de aplicaciones. Mantienes el plan premium hasta que termine el periodo pagado.', style: TextStyle(fontSize: 12, height: 1.35, color: c.faint)),
      ]),
    );
  }
}
