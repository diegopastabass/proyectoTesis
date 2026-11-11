/// Al crear la cuenta: términos de uso (CU-26, pantalla de diseño), cuestionario
/// inicial y plan semanal sugerido (CU-12, reales: se guardan en el perfil y el plan
/// lo arma el motor de sugerencias de `core/suggestions/`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/body/energy.dart';
import '../../core/cardio/activity.dart';
import '../../core/common/date.dart';
import '../../core/common/numbers.dart';
import '../../core/strength/programs.dart';
import '../../core/suggestions/profile.dart';
import '../../core/suggestions/reason.dart';
import '../../core/suggestions/weekly_plan.dart';
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

/// CU-12: cuestionario inicial, en tres pasos y 10 preguntas.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key, this.step = 0, this.example = false, this.missing = false});

  final int step;

  /// Rellena las respuestas con el perfil de ejemplo (lo usa el modo de capturas).
  final bool example;

  /// Muestra el aviso de pregunta sin responder (lo usa el modo de capturas).
  final bool missing;

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  late int _step = widget.step;
  late bool _showMissing = widget.missing;
  bool _saving = false;

  Experience? _experience;
  AthleteGoal? _goal;
  int? _days;
  int _minutes = 60;
  Equipment? _equipment;
  final Set<Discipline> _disciplines = {};
  Sex? _sex;
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Parte con lo que ya se sabe: el cuestionario anterior, el perfil corporal y el último peso.
    final saved = widget.example ? exampleAthlete : ref.read(athleteProfileProvider).value;
    if (saved != null && !widget.missing) {
      _experience = saved.experience;
      _goal = saved.goal;
      _days = saved.days;
      _minutes = saved.minutes;
      _equipment = saved.equipment;
      _disciplines.addAll(saved.disciplines);
    }
    final body = ref.read(bodyProfileProvider).value ?? const BodyProfile();
    final weight = ref.read(weightsProvider).value?.lastOrNull?.kg;
    if (widget.example) {
      _sex = Sex.male;
      _age.text = '29';
      _height.text = '178';
      _weight.text = '82';
    } else if (!widget.missing) {
      _sex = body.sex;
      if (body.birthDate != null) _age.text = '${ageOn(body.birthDate!, todayKey())}';
      if (body.heightCm != null) _height.text = plainEs(body.heightCm!);
      if (weight != null) _weight.text = plainEs(round1(weight));
    }
  }

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  int? get _ageValue => switch (parseNum(_age.text)) { final v? when v >= 14 && v <= 90 => v.round(), _ => null };

  double? get _heightValue => switch (parseNum(_height.text)) { final v? when v >= 120 && v <= 230 => v, _ => null };

  double? get _weightValue => switch (parseNum(_weight.text)) { final v? when v >= 30 && v <= 300 => v, _ => null };

  bool get _complete => switch (_step) {
        0 => _experience != null && _goal != null,
        1 => _days != null && _equipment != null,
        _ => _sex != null && _ageValue != null && _heightValue != null && _weightValue != null,
      };

  Future<void> _next() async {
    if (!_complete) {
      setState(() => _showMissing = true);
      return;
    }
    if (_step < 2) {
      setState(() {
        _step++;
        _showMissing = false;
      });
      return;
    }
    setState(() => _saving = true);
    final today = todayKey();
    final body = ref.read(bodyProfileProvider).value ?? const BodyProfile();
    // Se conserva la fecha de nacimiento si calza con la edad; si no, se aproxima (se corrige en Perfil corporal).
    final age = _ageValue!;
    final keepBirth = body.birthDate != null && ageOn(body.birthDate!, today) == age;
    final now = DateTime.now();
    final profile = AthleteProfile(
      experience: _experience!,
      goal: _goal!,
      days: _days!,
      minutes: _minutes,
      equipment: _equipment!,
      disciplines: {..._disciplines},
    );
    final ok = await runGuarded(
      context,
      () => ref.read(nutritionActionsProvider).saveAthleteAnswers(
            profile,
            body: BodyProfile(
              heightCm: _heightValue,
              birthDate: keepBirth ? body.birthDate : toDateKey(DateTime(now.year - age, now.month, now.day)),
              sex: _sex,
              activity: body.activity,
            ),
            weightKg: round1(_weightValue!),
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) context.push('/bienvenida/plan');
  }

  Widget _question(String title, [String? help]) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: context.colors.fgStrong)),
        if (help != null) ...[const SizedBox(height: 2), Text(help, style: TextStyle(fontSize: 12, color: context.colors.muted))],
      ]);

  Widget _options<T>(List<T> options, T? value, String Function(T) label, ValueChanged<T> onTap) => CardList(children: [
        for (final o in options) OptionTile(title: label(o), selected: value == o, onTap: () => onTap(o)),
      ]);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = switch (_step) {
      0 => <Widget>[
          _question('¿Cuánta experiencia tienes entrenando?'),
          _options(Experience.values, _experience, (e) => e.label, (v) => setState(() => _experience = v)),
          _question('¿Cuál es tu objetivo principal?'),
          _options(AthleteGoal.values, _goal, (g) => g.label, (v) => setState(() => _goal = v)),
        ],
      1 => <Widget>[
          _question('¿Cuántos días puedes entrenar a la semana?', 'Sumando fuerza y cardio.'),
          ChoicePills<int>(scrollable: true, options: const [2, 3, 4, 5, 6, 7], selected: _days ?? 0, label: (d) => '$d días', onSelected: (d) => setState(() => _days = d)),
          _question('¿Cuánto tiempo tienes por sesión?'),
          ChoicePills<int>(options: const [45, 60, 90], selected: _minutes, label: (m) => m == 90 ? '90 min o más' : 'Hasta $m min', onSelected: (m) => setState(() => _minutes = m)),
          _question('¿Con qué equipamiento cuentas?'),
          _options(Equipment.values, _equipment, (e) => e.label, (v) => setState(() => _equipment = v)),
          _question('¿Qué deportes de resistencia practicas?', 'Si solo haces fuerza, déjalo sin marcar.'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in Discipline.values)
              FilterChip(
                label: Text(d.label, style: TextStyle(color: _disciplines.contains(d) ? c.onPrimary : c.fg)),
                selected: _disciplines.contains(d),
                onSelected: (on) => setState(() => on ? _disciplines.add(d) : _disciplines.remove(d)),
              ),
          ]),
        ],
      _ => <Widget>[
          _question('Cuéntanos sobre ti', 'Con esto estimamos tu gasto calórico (ecuación de Mifflin-St Jeor) y ajustamos tus metas.'),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              NumberField(controller: _age, label: 'Edad (años)', decimal: false, error: _showMissing && _ageValue == null, onChanged: (_) => setState(() {})),
              const SizedBox(height: 10),
              NumberField(controller: _height, label: 'Estatura (cm)', decimal: false, error: _showMissing && _heightValue == null, onChanged: (_) => setState(() {})),
              const SizedBox(height: 10),
              NumberField(controller: _weight, label: 'Peso (kg)', error: _showMissing && _weightValue == null, onChanged: (_) => setState(() {})),
            ]),
          ),
          _question('Sexo', 'Solo para el cálculo del gasto en reposo.'),
          _options(Sex.values, _sex, (s) => s == Sex.female ? 'Mujer' : 'Hombre', (v) => setState(() => _sex = v)),
        ],
    };
    return Scaffold(
      appBar: AppBar(title: Text('Paso ${_step + 1} de 3')),
      bottomNavigationBar: BottomActions(children: [
        FilledButton(onPressed: _saving ? null : _next, child: Text(_step == 2 ? 'Ver mi plan' : 'Continuar')),
      ]),
      body: PageBody(children: [
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (_step + 1) / 3, minHeight: 6, backgroundColor: c.surface2, color: c.primary)),
        ...content,
        if (_showMissing && !_complete)
          InfoNote(
            icon: Icons.error_outline,
            color: c.danger,
            text: _step == 2 ? 'Revisa los datos: edad entre 14 y 90 años, estatura entre 120 y 230 cm y peso entre 30 y 300 kg.' : 'Responde todas las preguntas para continuar.',
          ),
      ]),
    );
  }
}

IconData _sessionIcon(PlannedSession s) => switch (s.kind) {
      SessionKind.strength => Icons.fitness_center,
      SessionKind.cardio => switch (s.discipline) {
          Discipline.cycling => Icons.directions_bike,
          Discipline.trekking => Icons.terrain,
          _ => Icons.directions_run,
        },
    };

/// CU-12: plan de la semana sugerido por el motor, que se puede aceptar, cambiar o ignorar.
class WeeklyPlanPage extends ConsumerStatefulWidget {
  const WeeklyPlanPage({super.key, this.accepted = false});

  /// Muestra el plan como aceptado (lo usa el modo de capturas).
  final bool accepted;

  @override
  ConsumerState<WeeklyPlanPage> createState() => _WeeklyPlanPageState();
}

class _WeeklyPlanPageState extends ConsumerState<WeeklyPlanPage> {
  bool _saving = false;

  Future<void> _accept(WeeklyPlan plan) async {
    setState(() => _saving = true);
    var created = 0;
    final ok = await runGuarded(context, () async => created = await ref.read(strengthActionsProvider).acceptWeeklyPlan(plan));
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) showToast(context, created > 0 ? 'Plan listo: $created rutinas de fuerza creadas' : 'Plan listo');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final profile = ref.watch(athleteProfileProvider);
    final saved = ref.watch(weeklyPlanProvider).value;
    final plan = ref.watch(suggestedPlanProvider);

    if (!profile.hasValue) return const Scaffold(body: LoadingView());
    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tu plan semanal')),
        body: PageBody(children: [
          AppCard(
            child: EmptyState(
              icon: Icons.insights,
              title: 'Primero, cuéntanos de ti',
              message: 'Con 10 preguntas te armamos una semana de fuerza y cardio a tu medida.',
            ),
          ),
          FilledButton(onPressed: () => context.push('/bienvenida/cuestionario'), child: const Text('Responder el cuestionario')),
        ]),
      );
    }

    final isCurrent = widget.accepted || (saved != null && _sameSessions(saved, plan));
    final program = programById(plan.programId);
    final strengthCount = plan.strength.length;
    final cardioCount = plan.cardio.length;
    final cardioNames = {for (final s in plan.cardio) s.discipline!.label.toLowerCase()}.join(' y ');

    return Scaffold(
      appBar: AppBar(title: const Text('Tu plan semanal')),
      bottomNavigationBar: BottomActions(children: [
        if (isCurrent)
          FilledButton(onPressed: () => context.go('/fuerza'), child: const Text('Empezar'))
        else ...[
          FilledButton(onPressed: _saving ? null : () => _accept(plan), child: Text(saved == null ? 'Aceptar el plan' : 'Reemplazar mi plan')),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => context.push('/bienvenida/cuestionario'), child: const Text('Mis respuestas'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () => context.canPop() ? context.pop() : context.go('/fuerza'), child: const Text('Ahora no'))),
          ]),
        ],
      ]),
      body: PageBody(children: [
        if (isCurrent)
          InfoNote(icon: Icons.check_circle, color: c.success, title: 'Es tu plan de esta semana', text: 'Puedes moverlo o ignorarlo: es una sugerencia. Más adelante lo ajustaremos según lo que cumplas y cómo te sientas.')
        else if (saved != null)
          InfoNote(icon: Icons.update, color: c.warning, title: 'Plan nuevo según tus respuestas', text: 'Si lo aceptas, reemplaza al plan que tienes ahora.'),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const GradientIcon(Icons.insights),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Nivel ${plan.level.label.toLowerCase()} · Orientación ${plan.orientation.label.toLowerCase()}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong)),
                const SizedBox(height: 2),
                Text(
                  '$strengthCount ${strengthCount == 1 ? 'sesión' : 'sesiones'} de fuerza'
                  '${cardioCount == 0 ? '' : ' y $cardioCount de $cardioNames'}'
                  '${program == null ? '' : ' · ${program.name}'}.',
                  style: TextStyle(fontSize: 13, height: 1.3, color: c.muted),
                ),
                const SizedBox(height: 4),
                Tooltip(
                  message: 'Esfuerzo planificado × minutos, la misma medida de la carga de entrenamiento',
                  child: Text('Carga planificada: ${formatNumber(plan.plannedLoad, maxFractionDigits: 0)} UA por semana', style: TextStyle(fontSize: 11, color: c.faint)),
                ),
              ]),
            ),
          ]),
        ),
        CardList(children: [
          for (var day = 1; day <= 7; day++)
            ...() {
              final sessions = plan.on(day);
              if (sessions.isEmpty) {
                return [
                  ListTile(
                    dense: true,
                    leading: SizedBox(width: 34, child: Text(weekdayShort[day - 1], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.faint))),
                    title: Text('Descanso', style: TextStyle(fontSize: 14, color: c.muted)),
                    subtitle: Text('Caminar o estirar suma sin cansar', style: TextStyle(fontSize: 12, color: c.faint)),
                    trailing: Icon(Icons.bedtime_outlined, size: 20, color: c.faint),
                  ),
                ];
              }
              return [
                for (final (i, s) in sessions.indexed)
                  ListTile(
                    dense: true,
                    leading: SizedBox(
                      width: 34,
                      child: Text(i == 0 ? weekdayShort[day - 1] : '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.primary)),
                    ),
                    title: Text(s.kind == SessionKind.strength ? 'Fuerza: ${s.title}' : s.title,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
                    subtitle: Text(sessionDetail(s), style: TextStyle(fontSize: 12, color: c.muted)),
                    trailing: Icon(_sessionIcon(s), size: 20, color: c.primary),
                  ),
              ];
            }(),
        ]),
        CardList(header: const CardHeader('¿Por qué este plan?', icon: Icons.help_outline), children: [
          for (final r in plan.why) _ReasonTile(r),
        ]),
        Text(
          'Es una sugerencia deportiva, no una prescripción médica. Si tienes una lesión o una condición de salud, consulta a un profesional.',
          style: TextStyle(fontSize: 11, color: c.faint, height: 1.4),
        ),
        if (!isCurrent)
          TextButton.icon(
            onPressed: () => context.push('/fuerza/programas'),
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('Ver otros programas de fuerza'),
          ),
      ]),
    );
  }
}

/// El plan guardado es el mismo que el sugerido (mismas sesiones el mismo día).
bool _sameSessions(WeeklyPlan a, WeeklyPlan b) {
  if (a.programId != b.programId || a.sessions.length != b.sessions.length) return false;
  for (var i = 0; i < a.sessions.length; i++) {
    final x = a.sessions[i];
    final y = b.sessions[i];
    if (x.weekday != y.weekday || x.kind != y.kind || x.title != y.title || x.minutes != y.minutes) return false;
  }
  return true;
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile(this.reason);

  final Reason reason;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.check, size: 16, color: c.primary)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(reason.text, style: TextStyle(fontSize: 13, height: 1.35, color: c.fg)),
            if (reason.source != null) Text(Sources.label(reason.source!), style: TextStyle(fontSize: 10, color: c.faint)),
          ]),
        ),
      ]),
    );
  }
}
