import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/modules.dart';
import '../../app/theme.dart';
import '../../ui/widgets.dart';

/// Pantalla de un módulo que aún no está disponible.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key, required this.module});

  final ModuleId module;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = moduleById(module);
    final nutrition = moduleById(ModuleId.nutricion);
    return PageBody(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: c.warning.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.construction, size: 14, color: c.warning),
                    const SizedBox(width: 6),
                    Text(
                      'EN DESARROLLO',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: c.warning),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                child: Column(
                  children: [
                    GradientIcon(m.icon, size: 64),
                    const SizedBox(height: 14),
                    Text(
                      'Módulo de ${m.label.toLowerCase()}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.fgStrong),
                    ),
                    const SizedBox(height: 4),
                    Text('Estamos trabajando en este módulo.', style: TextStyle(fontSize: 12, color: c.muted)),
                    const SizedBox(height: 12),
                    Text(
                      m.summary,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: c.faint, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(onPressed: () => context.go(nutrition.path), icon: Icon(nutrition.icon), label: Text(nutrition.label)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
