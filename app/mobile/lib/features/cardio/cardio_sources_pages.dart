/// Otras formas de registrar cardio: a mano (CU-17), desde el reloj (CU-03) y desde
/// un archivo `.fit` (CU-04). La lectura de Salud y de archivos aún no está conectada:
/// estas pantallas muestran datos de ejemplo (`sim_data.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/sim_providers.dart';
import '../../app/theme.dart';
import '../../core/cardio/activity.dart';
import '../../core/training/load.dart';
import '../../data/simulated/sim_data.dart';
import '../../ui/sim_widgets.dart';
import '../../ui/widgets.dart';
import 'cardio_widgets.dart';

/// CU-17: anotar una sesión de cardio a mano.
class ManualCardioPage extends StatefulWidget {
  const ManualCardioPage({super.key, this.example = false});

  /// Rellena el formulario con un ejemplo (lo usa el modo de capturas).
  final bool example;

  @override
  State<ManualCardioPage> createState() => _ManualCardioPageState();
}

class _ManualCardioPageState extends State<ManualCardioPage> {
  Discipline _discipline = Discipline.cycling;
  late final _minutes = TextEditingController(text: widget.example ? '75' : '');
  late final _km = TextEditingController(text: widget.example ? '32,5' : '');
  late int? _rpe = widget.example ? 6 : null;
  bool _tried = false;

  @override
  void dispose() {
    _minutes.dispose();
    _km.dispose();
    super.dispose();
  }

  bool get _valid => (int.tryParse(_minutes.text) ?? 0) > 0 && _rpe != null;

  void _save() {
    setState(() => _tried = true);
    if (!_valid) return;
    showToast(context, 'Sesión guardada. Ya cuenta en tu carga de la semana.');
    context.go('/cardio/historial');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Anotar a mano')),
      bottomNavigationBar: BottomActions(children: [FilledButton(onPressed: _save, child: const Text('Guardar sesión'))]),
      body: PageBody(children: [
        Center(child: DisciplinePicker(value: _discipline, onChanged: (d) => setState(() => _discipline = d))),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Datos de la sesión', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: NumberField(controller: _minutes, label: 'Duración (min)', decimal: false, error: _tried && (int.tryParse(_minutes.text) ?? 0) <= 0, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 10),
              Expanded(child: NumberField(controller: _km, label: 'Distancia (km)')),
            ]),
            if (_tried && (int.tryParse(_minutes.text) ?? 0) <= 0) ...[
              const SizedBox(height: 6),
              Text('Indica cuántos minutos duró.', style: TextStyle(fontSize: 12, color: c.danger)),
            ],
          ]),
        ),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('¿Qué tan dura la sentiste?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong)),
            const SizedBox(height: 2),
            Text(_rpe == null ? '1 es muy suave y 10 es tu máximo.' : rpeLabel(_rpe!), style: TextStyle(fontSize: 13, color: _rpe == null ? c.muted : c.primary)),
            const SizedBox(height: 12),
            RpePicker(value: _rpe, onChanged: (v) => setState(() => _rpe = v)),
            if (_tried && _rpe == null) ...[
              const SizedBox(height: 8),
              Text('Elige un valor para calcular tu carga.', style: TextStyle(fontSize: 12, color: c.danger)),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// CU-03: traer las sesiones desde la app de salud del teléfono.
class WatchImportPage extends ConsumerStatefulWidget {
  const WatchImportPage({super.key, this.connected = false});

  /// Abre directamente con el permiso dado (lo usa el modo de capturas).
  final bool connected;

  @override
  ConsumerState<WatchImportPage> createState() => _WatchImportPageState();
}

class _WatchImportPageState extends ConsumerState<WatchImportPage> {
  late bool _denied = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sim = ref.watch(simProvider);
    final connected = widget.connected || sim.healthConnected;
    return Scaffold(
      appBar: AppBar(title: const Text('Sesiones del reloj')),
      bottomNavigationBar: connected
          ? null
          : BottomActions(children: [
              FilledButton.icon(
                onPressed: () => ref.read(simProvider.notifier).connectHealth(true),
                icon: const Icon(Icons.favorite_border),
                label: const Text('Conectar con Salud'),
              ),
              OutlinedButton(onPressed: () => setState(() => _denied = true), child: const Text('Ahora no')),
            ]),
      body: connected
          ? PageBody(children: [
              InfoNote(icon: Icons.sync, color: c.success, title: 'Conectado con Apple Salud', text: 'Las sesiones nuevas de ciclismo, running y trekking llegan solas. Solo leemos estos datos: nunca escribimos en Salud.'),
              const SectionTitle('Sesiones nuevas'),
              for (final s in simWatchSessions) _WatchSessionCard(session: s),
            ])
          : PageBody(children: [
              const SizedBox(height: 8),
              const Center(child: GradientIcon(Icons.watch_outlined, size: 72)),
              Text('Trae tus sesiones sin anotar nada', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: c.fgStrong)),
              Text('Después de entrenar con tu reloj, la aplicación toma tus sesiones de la app Salud del teléfono.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.4, color: c.muted)),
              CardList(header: const CardHeader('Para qué usamos estos datos', icon: Icons.shield_outlined), children: [
                for (final (icon, title, text) in const [
                  (Icons.directions_bike, 'Entrenamientos', 'Para sumar la sesión a tu historial.'),
                  (Icons.straighten, 'Duración y distancia', 'Para calcular tu carga de la semana.'),
                  (Icons.favorite_border, 'Pulso', 'Para estimar el esfuerzo si no lo indicas.'),
                ])
                  ListTile(
                    dense: true,
                    leading: Icon(icon, color: c.primary),
                    title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.fgStrong)),
                    subtitle: Text(text, style: TextStyle(fontSize: 12, color: c.muted)),
                  ),
              ]),
              if (_denied)
                InfoNote(icon: Icons.info_outline, color: c.warning, text: 'Sin permiso no leemos nada. Puedes seguir anotando tus sesiones a mano o conectar Salud más adelante en Ajustes.')
              else
                Text('Puedes quitar el permiso cuando quieras en Ajustes.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.faint)),
            ]),
    );
  }
}

class _WatchSessionCard extends ConsumerStatefulWidget {
  const _WatchSessionCard({required this.session});

  final SimWatchSession session;

  @override
  ConsumerState<_WatchSessionCard> createState() => _WatchSessionCardState();
}

class _WatchSessionCardState extends ConsumerState<_WatchSessionCard> {
  int? _rpe;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = widget.session;
    final imported = ref.watch(simProvider).importedWatch.contains(s.id);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          GradientIcon(s.title == 'Ciclismo' ? Icons.directions_bike : Icons.directions_run, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong)),
              Text('${s.when} · ${s.source}', style: TextStyle(fontSize: 12, color: c.muted)),
            ]),
          ),
          if (imported) Icon(Icons.check_circle, color: c.success),
        ]),
        const SizedBox(height: 12),
        StatRow(s.stats),
        if (!imported) ...[
          const Divider(height: 22),
          Text('¿Qué tan dura la sentiste?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.fgStrong)),
          const SizedBox(height: 8),
          RpePicker(
            value: _rpe,
            onChanged: (v) {
              setState(() => _rpe = v);
              ref.read(simProvider.notifier).importWatch(s.id);
              showToast(context, 'Actualizamos tu carga de la semana');
            },
          ),
          const SizedBox(height: 6),
          Text('Si no respondes, lo estimamos con tu pulso.', style: TextStyle(fontSize: 11, color: c.faint)),
        ],
      ]),
    );
  }
}

enum _FitStep { pick, invalid, summary }

/// CU-04: subir el archivo del ciclocomputador.
class FitUploadPage extends StatefulWidget {
  const FitUploadPage({super.key, this.estado});

  final String? estado;

  @override
  State<FitUploadPage> createState() => _FitUploadPageState();
}

class _FitUploadPageState extends State<FitUploadPage> {
  late _FitStep _step = switch (widget.estado) {
    'error' => _FitStep.invalid,
    'resumen' => _FitStep.summary,
    _ => _FitStep.pick,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(_step == _FitStep.summary ? 'Revisa la sesión' : 'Subir archivo')),
      bottomNavigationBar: _step == _FitStep.summary
          ? BottomActions(children: [
              FilledButton(
                onPressed: () {
                  showToast(context, 'Sesión guardada. Ya cuenta en tu carga de la semana.');
                  context.go('/cardio/historial');
                },
                child: const Text('Guardar sesión'),
              ),
              OutlinedButton(onPressed: () => setState(() => _step = _FitStep.pick), child: const Text('Elegir otro archivo')),
            ])
          : null,
      body: PageBody(children: [
        if (_step != _FitStep.summary) ...[
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 26, 16, 20),
            onTap: () => setState(() => _step = _FitStep.summary),
            child: Column(children: [
              const GradientIcon(Icons.upload_file, size: 60),
              const SizedBox(height: 14),
              Text('Elige tu archivo .fit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: c.fgStrong)),
              const SizedBox(height: 4),
              Text('Lo exportas desde tu ciclocomputador o reloj. Puede pesar hasta 10 MB.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.35, color: c.muted)),
              const SizedBox(height: 14),
              FilledButton(onPressed: () => setState(() => _step = _FitStep.summary), child: const Text('Abrir mis archivos')),
            ]),
          ),
          if (_step == _FitStep.invalid)
            InfoNote(icon: Icons.error_outline, color: c.danger, title: 'No pudimos usar este archivo', text: '«salida_domingo.gpx» no es un archivo .fit. Exporta la sesión en formato .fit e inténtalo de nuevo.'),
          CardList(header: const CardHeader('Qué obtienes', icon: Icons.insights), children: [
            for (final (icon, text) in const [
              (Icons.bolt, 'Potencia a lo largo de la salida'),
              (Icons.autorenew, 'Cadencia de pedaleo'),
              (Icons.favorite_border, 'Pulso y zonas'),
            ])
              ListTile(dense: true, leading: Icon(icon, color: c.primary), title: Text(text, style: TextStyle(fontSize: 14, color: c.fgStrong))),
          ]),
        ] else ...[
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const GradientIcon(Icons.directions_bike, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Salida en bicicleta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.fgStrong)),
                    Text('salida_domingo.fit · 2,4 MB', style: TextStyle(fontSize: 12, color: c.muted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              const StatRow([SimStat('Duración', '1:30:12'), SimStat('Distancia', '42,8 km'), SimStat('Desnivel', '540 m')]),
            ]),
          ),
          for (final (i, s) in simFitSeries.indexed)
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(s.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong))),
                  Text('Media ${s.average} · Máx. ${s.maximum}', style: TextStyle(fontSize: 12, color: c.muted, fontFeatures: tabular)),
                ]),
                const SizedBox(height: 10),
                SparkLine(height: 62, series: [(s.values, [c.kcal, c.primary, c.danger][i])]),
              ]),
            ),
        ],
      ]),
    );
  }
}
