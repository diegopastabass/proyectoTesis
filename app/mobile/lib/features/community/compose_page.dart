import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/cardio_providers.dart';
import '../../app/providers.dart';
import '../../app/sim_providers.dart';
import '../../app/theme.dart';
import '../../data/simulated/sim_data.dart';
import '../../ui/format.dart';
import '../../ui/sim_widgets.dart';
import '../../ui/widgets.dart';

const _maxPhotos = 4;

enum _Visibility {
  everyone('Todos', Icons.public),
  followers('Seguidores', Icons.group_outlined),
  private('Solo yo', Icons.lock_outline);

  const _Visibility(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// CU-09: publicar una sesión, ruta o comida ya registrada.
class ComposePostPage extends ConsumerStatefulWidget {
  const ComposePostPage({super.key, this.initialKind, this.example = false});

  /// sesion, ruta o comida.
  final String? initialKind;

  /// Rellena el formulario con un ejemplo (lo usa el modo de capturas).
  final bool example;

  @override
  ConsumerState<ComposePostPage> createState() => _ComposePostPageState();
}

class _ComposePostPageState extends ConsumerState<ComposePostPage> {
  late SimPostKind _kind = switch (widget.initialKind) {
    'ruta' => SimPostKind.route,
    'comida' => SimPostKind.meal,
    _ => SimPostKind.workout,
  };
  late final _text = TextEditingController(text: widget.example ? 'Buena sesión antes del fin de semana. ¡Se sintió liviano!' : '');
  late int _photos = widget.example && _kind != SimPostKind.route ? 2 : 0;
  late bool _declared = widget.example;
  _Visibility _visibility = _Visibility.followers;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _addPhoto() {
    if (_photos >= _maxPhotos) {
      showToast(context, 'Puedes agregar hasta $_maxPhotos fotos.', error: true);
      return;
    }
    setState(() => _photos++);
  }

  void _publish(String title) {
    ref.read(simProvider.notifier).publish(SimPost(
          id: 'mine-${DateTime.now().millisecondsSinceEpoch}',
          authorId: 'me',
          kind: _kind,
          title: title,
          text: _text.text.trim(),
          when: 'Ahora · ${_visibility.label}',
          photos: _photos,
          routeSeed: _kind == SimPostKind.route ? 2 : null,
        ));
    showToast(context, 'Publicación compartida');
    context.go('/comunidad');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final workouts = ref.watch(workoutsProvider).value ?? const [];
    final routes = ref.watch(cardioActivitiesProvider).value ?? const [];
    final (recordTitle, recordDetail) = switch (_kind) {
      SimPostKind.route => routes.isEmpty ? ('Sin rutas registradas', '') : (routes.first.title, capitalize(weekdayDate(routes.first.date))),
      SimPostKind.meal => ('Almuerzo de hoy', 'Pechuga de pollo y arroz'),
      _ => workouts.isEmpty ? ('Sin sesiones registradas', '') : (workouts.first.name, capitalize(weekdayDate(workouts.first.date))),
    };
    final canPublish = _text.text.trim().isNotEmpty && (_photos == 0 || _declared);

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva publicación')),
      bottomNavigationBar: BottomActions(children: [
        FilledButton(onPressed: canPublish ? () => _publish(recordTitle) : null, child: const Text('Publicar')),
      ]),
      body: PageBody(children: [
        AppSegmented<SimPostKind>(
          value: _kind,
          segments: const {
            SimPostKind.workout: Text('Sesión'),
            SimPostKind.route: Text('Ruta'),
            SimPostKind.meal: Text('Comida'),
          },
          onChanged: (k) => setState(() => _kind = k),
        ),
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            GradientIcon(switch (_kind) {
              SimPostKind.route => Icons.route_outlined,
              SimPostKind.meal => Icons.restaurant,
              _ => Icons.fitness_center,
            }),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(recordTitle, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
                Text(recordDetail, style: TextStyle(fontSize: 12, color: c.muted)),
              ]),
            ),
            TextButton(onPressed: () {}, child: const Text('Cambiar')),
          ]),
        ),
        if (_kind == SimPostKind.route) ...[
          const SimRoutePreview(seed: 2, height: 150),
          InfoNote(icon: Icons.shield_outlined, text: 'Ocultamos el inicio y el final del recorrido para que nadie sepa dónde vives.', color: c.fiber),
        ],
        TextField(
          controller: _text,
          onChanged: (_) => setState(() {}),
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'Cuéntales cómo te fue…'),
        ),
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('Fotos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong))),
              Text('$_photos de $_maxPhotos', style: TextStyle(fontSize: 12, color: c.muted, fontFeatures: tabular)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              for (var i = 0; i < _maxPhotos; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: i < _photos
                      ? GestureDetector(onTap: () => setState(() => _photos--), child: SimPhoto(icon: Icons.photo_outlined, tone: i, height: 66, radius: 10))
                      : i == _photos
                          ? GestureDetector(
                              onTap: _addPhoto,
                              child: Container(
                                height: 66,
                                decoration: ShapeDecoration(color: c.surface2.withValues(alpha: 0.7), shape: smoothShape(10)),
                                child: Icon(Icons.add_a_photo_outlined, color: c.muted),
                              ),
                            )
                          : Container(height: 66, decoration: ShapeDecoration(color: c.surface2.withValues(alpha: 0.3), shape: smoothShape(10))),
                ),
              ],
            ]),
            if (_photos > 0) ...[
              const SizedBox(height: 6),
              CheckboxListTile(
                value: _declared,
                onChanged: (v) => setState(() => _declared = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text('Son mías o tengo permiso para publicarlas.', style: TextStyle(fontSize: 13, color: c.fg)),
              ),
              Text('Las comprimimos y les borramos la ubicación antes de subirlas.', style: TextStyle(fontSize: 11, color: c.faint)),
            ],
          ]),
        ),
        Text('¿Quién la puede ver?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
        AppSegmented<_Visibility>(
          value: _visibility,
          segments: {
            for (final v in _Visibility.values) v: Row(mainAxisSize: MainAxisSize.min, children: [Icon(v.icon), const SizedBox(width: 4), Text(v.label)]),
          },
          onChanged: (v) => setState(() => _visibility = v),
        ),
      ]),
    );
  }
}
