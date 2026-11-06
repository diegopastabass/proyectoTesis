/// Al crear la cuenta: términos de uso (CU-26), cuestionario inicial y plan sugerido
/// (CU-12). Pantallas de diseño: las respuestas no se guardan y el plan es un ejemplo.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/simulated/sim_data.dart';
import '../../ui/sim_widgets.dart';
import '../../ui/widgets.dart';

const _termsVersion = '1.0';

const _termsSections = [
  ('Qué hace la aplicación', 'Te ayuda a registrar tus entrenamientos y tus comidas, y a ver cómo se relacionan. Sus sugerencias son orientativas.'),
  ('No reemplaza a un profesional', 'La aplicación no entrega diagnósticos ni tratamientos. Ante una lesión o una condición de salud, consulta a un profesional.'),
  ('Tus datos', 'Los datos de salud se tratan como datos sensibles, según la Ley N° 19.628. Tú decides qué compartir y puedes eliminar tu cuenta cuando quieras.'),
  ('Lo que publicas', 'Eres responsable de tus publicaciones. Solo puedes subir fotos propias o con permiso, y el contenido que no cumpla las normas se puede ocultar.'),
];

/// CU-26: aceptar los términos de uso y el aviso legal.
class TermsPage extends StatefulWidget {
  const TermsPage({super.key, this.updated = false, this.refused = false, this.accepted = false});

  /// Los términos cambiaron desde la última aceptación.
  final bool updated;

  /// Muestra el aviso de que son necesarios (lo usa el modo de capturas).
  final bool refused;

  /// Marca las casillas (lo usa el modo de capturas).
  final bool accepted;

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  late bool _terms = widget.accepted;
  late bool _legal = widget.accepted;
  late bool _refused = widget.refused;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Términos de uso')),
      bottomNavigationBar: BottomActions(children: [
        FilledButton(onPressed: _terms && _legal ? () => context.push('/bienvenida/cuestionario') : null, child: const Text('Aceptar y continuar')),
        OutlinedButton(onPressed: () => setState(() => _refused = true), child: const Text('No acepto')),
      ]),
      body: PageBody(children: [
        if (widget.updated)
          InfoNote(icon: Icons.update, color: c.warning, title: 'Actualizamos los términos', text: 'Revisa los cambios para seguir usando la aplicación.')
        else
          Text('Antes de empezar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: c.fgStrong)),
        CardList(children: [
          for (final (title, text) in _termsSections)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
                const SizedBox(height: 3),
                Text(text, style: TextStyle(fontSize: 13, height: 1.35, color: c.fg)),
              ]),
            ),
        ]),
        Text('Versión $_termsVersion. Guardamos la fecha y la versión que aceptes.', style: TextStyle(fontSize: 11, color: c.faint)),
        AppCard(
          child: Column(children: [
            CheckboxListTile(
              value: _terms,
              onChanged: (v) => setState(() => _terms = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: Text('Leí y acepto los términos de uso.', style: TextStyle(fontSize: 14, color: c.fgStrong)),
            ),
            const Divider(indent: 14),
            CheckboxListTile(
              value: _legal,
              onChanged: (v) => setState(() => _legal = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: Text('Entiendo el aviso legal: las sugerencias no son consejo médico.', style: TextStyle(fontSize: 14, color: c.fgStrong)),
            ),
          ]),
        ),
        if (_refused)
          InfoNote(icon: Icons.error_outline, color: c.danger, title: 'Son necesarios para continuar', text: 'Sin aceptarlos no podemos crear tu cuenta ni tratar tus datos.'),
      ]),
    );
  }
}

/// CU-12: cuestionario inicial, en tres pasos.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.step = 0, this.example = false, this.missing = false});

  final int step;

  /// Rellena las respuestas (lo usa el modo de capturas).
  final bool example;

  /// Muestra el aviso de pregunta sin responder (lo usa el modo de capturas).
  final bool missing;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late int _step = widget.step;
  late bool _showMissing = widget.missing;
  late String? _experience = widget.example ? 'Entre 6 meses y 2 años' : null;
  late String? _goal = widget.example ? 'Rendir mejor en mi deporte' : null;
  late int? _days = widget.example ? 5 : null;
  late String? _equipment = widget.example ? 'Gimnasio' : null;
  late final Set<String> _sports = widget.example ? {'Ciclismo', 'Fuerza'} : {};
  late String? _sex = widget.example ? 'Hombre' : null;
  late final _age = TextEditingController(text: widget.example ? '29' : '');
  late final _height = TextEditingController(text: widget.example ? '178' : '');
  late final _weight = TextEditingController(text: widget.example ? '82' : '');

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  bool get _complete => switch (_step) {
        0 => _experience != null && _goal != null,
        1 => _days != null && _equipment != null && _sports.isNotEmpty,
        _ => _sex != null && _age.text.isNotEmpty && _height.text.isNotEmpty && _weight.text.isNotEmpty,
      };

  void _next() {
    if (!_complete) {
      setState(() => _showMissing = true);
      return;
    }
    if (_step == 2) {
      context.push('/bienvenida/plan');
    } else {
      setState(() {
        _step++;
        _showMissing = false;
      });
    }
  }

  Widget _question(String title) => Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: context.colors.fgStrong));

  Widget _options(List<String> options, String? value, ValueChanged<String> onTap) => CardList(children: [
        for (final o in options) OptionTile(title: o, selected: value == o, onTap: () => onTap(o)),
      ]);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = switch (_step) {
      0 => <Widget>[
          _question('¿Cuánta experiencia tienes entrenando?'),
          _options(const ['Menos de 6 meses', 'Entre 6 meses y 2 años', 'Más de 2 años'], _experience, (v) => setState(() => _experience = v)),
          _question('¿Cuál es tu objetivo principal?'),
          _options(const ['Ganar fuerza', 'Ganar músculo', 'Bajar de peso', 'Rendir mejor en mi deporte'], _goal, (v) => setState(() => _goal = v)),
        ],
      1 => <Widget>[
          _question('¿Cuántos días puedes entrenar a la semana?'),
          ChoicePills<int>(options: const [2, 3, 4, 5, 6], selected: _days ?? 0, label: (d) => '$d días', onSelected: (d) => setState(() => _days = d)),
          _question('¿Con qué equipamiento cuentas?'),
          _options(const ['Gimnasio', 'Mancuernas y banco', 'Peso corporal'], _equipment, (v) => setState(() => _equipment = v)),
          _question('¿Qué deportes practicas?'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in const ['Fuerza', 'Ciclismo', 'Running', 'Trekking'])
              FilterChip(
                label: Text(s, style: TextStyle(color: _sports.contains(s) ? c.onPrimary : c.fg)),
                selected: _sports.contains(s),
                onSelected: (on) => setState(() => on ? _sports.add(s) : _sports.remove(s)),
              ),
          ]),
        ],
      _ => <Widget>[
          _question('Cuéntanos sobre ti'),
          Text('Con esto estimamos tu gasto calórico y ajustamos tus metas.', style: TextStyle(fontSize: 13, color: c.muted)),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              NumberField(controller: _age, label: 'Edad (años)', decimal: false, onChanged: (_) => setState(() {})),
              const SizedBox(height: 10),
              NumberField(controller: _height, label: 'Estatura (cm)', decimal: false, onChanged: (_) => setState(() {})),
              const SizedBox(height: 10),
              NumberField(controller: _weight, label: 'Peso (kg)', onChanged: (_) => setState(() {})),
            ]),
          ),
          _question('Sexo'),
          _options(const ['Mujer', 'Hombre'], _sex, (v) => setState(() => _sex = v)),
        ],
    };
    return Scaffold(
      appBar: AppBar(title: Text('Paso ${_step + 1} de 3')),
      bottomNavigationBar: BottomActions(children: [FilledButton(onPressed: _next, child: Text(_step == 2 ? 'Ver mi plan' : 'Continuar'))]),
      body: PageBody(children: [
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (_step + 1) / 3, minHeight: 6, backgroundColor: c.surface2, color: c.primary)),
        ...content,
        if (_showMissing && !_complete) InfoNote(icon: Icons.error_outline, color: c.danger, text: 'Responde todas las preguntas para continuar.'),
      ]),
    );
  }
}

IconData _planIcon(String kind) => switch (kind) {
      'strength' => Icons.fitness_center,
      'cardio' => Icons.directions_bike,
      _ => Icons.bedtime_outlined,
    };

/// CU-12: plan de la semana sugerido, que se puede aceptar, cambiar o ignorar.
class WeeklyPlanPage extends StatefulWidget {
  const WeeklyPlanPage({super.key, this.accepted = false});

  final bool accepted;

  @override
  State<WeeklyPlanPage> createState() => _WeeklyPlanPageState();
}

class _WeeklyPlanPageState extends State<WeeklyPlanPage> {
  late bool _accepted = widget.accepted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Tu plan semanal')),
      bottomNavigationBar: BottomActions(children: [
        if (_accepted)
          FilledButton(onPressed: () => context.go('/fuerza'), child: const Text('Empezar'))
        else ...[
          FilledButton(onPressed: () => setState(() => _accepted = true), child: const Text('Aceptar el plan')),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => context.push('/fuerza/programas'), child: const Text('Cambiar'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () => context.go('/'), child: const Text('Ahora no'))),
          ]),
        ],
      ]),
      body: PageBody(children: [
        if (_accepted) InfoNote(icon: Icons.check_circle, color: c.success, title: 'Es tu plan de esta semana', text: 'Cada semana lo ajustamos según lo que cumpliste y cómo te sentiste.'),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const GradientIcon(Icons.insights),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Nivel intermedio · Orientación mixta', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong)),
                const SizedBox(height: 2),
                Text('3 sesiones de fuerza y 2 de ciclismo, separadas para que te recuperes.', style: TextStyle(fontSize: 13, height: 1.3, color: c.muted)),
              ]),
            ),
          ]),
        ),
        CardList(children: [
          for (final SimPlanDay d in simWeeklyPlan)
            ListTile(
              dense: true,
              leading: SizedBox(width: 34, child: Text(d.day, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: d.kind == 'rest' ? c.faint : c.primary))),
              title: Text(d.title, style: TextStyle(fontSize: 14, fontWeight: d.kind == 'rest' ? FontWeight.w400 : FontWeight.w600, color: d.kind == 'rest' ? c.muted : c.fgStrong)),
              subtitle: Text(d.detail, style: TextStyle(fontSize: 12, color: c.muted)),
              trailing: Icon(_planIcon(d.kind), size: 20, color: d.kind == 'rest' ? c.faint : c.primary),
            ),
        ]),
      ]),
    );
  }
}
