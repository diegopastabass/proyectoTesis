import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/body/energy.dart';
import '../../core/body/progress.dart';
import '../../core/common/date.dart';
import '../../core/common/numbers.dart';
import '../../core/nutrition/models.dart';
import '../../ui/format.dart';
import '../../ui/widgets.dart';

const _activityText = {
  ActivityLevel.sedentary: ('Sedentaria', 'Trabajo sentado y casi sin entrenar'),
  ActivityLevel.light: ('Ligera', '1 a 3 entrenamientos por semana'),
  ActivityLevel.moderate: ('Moderada', '3 a 5 entrenamientos por semana'),
  ActivityLevel.high: ('Alta', '6 o 7 entrenamientos por semana, o trabajo físico'),
  ActivityLevel.veryHigh: ('Muy alta', 'Dobles sesiones (fuerza y cardio) casi a diario'),
};

const _goalText = {GoalType.lose: 'bajar de peso', GoalType.maintain: 'mantener el peso', GoalType.gain: 'subir de peso'};

/// Estatura, edad, sexo y actividad: estiman el gasto calórico y sugieren objetivos.
class BodyProfilePage extends ConsumerWidget {
  const BodyProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(bodyProfileProvider);
    final weights = ref.watch(weightsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil corporal')),
      body: AsyncView(
        combineAsync([profile, weights], () => (profile.requireValue, weights.requireValue.lastOrNull)),
        builder: (data) => _ProfileEditor(
          key: ValueKey('${data.$1.toMap()}${data.$2?.kg}'),
          profile: data.$1,
          latestWeight: data.$2,
        ),
      ),
    );
  }
}

class _ProfileEditor extends ConsumerStatefulWidget {
  const _ProfileEditor({super.key, required this.profile, required this.latestWeight});

  final BodyProfile profile;
  final WeightEntry? latestWeight;

  @override
  ConsumerState<_ProfileEditor> createState() => _ProfileEditorState();
}

enum _Source { formula, observed }

class _ProfileEditorState extends ConsumerState<_ProfileEditor> {
  late final _height = TextEditingController(text: widget.profile.heightCm == null ? '' : plainEs(widget.profile.heightCm));
  late final double? _latestKg = widget.latestWeight == null ? null : round1(widget.latestWeight!.kg);
  late final _weight = TextEditingController(text: plainEs(_latestKg));
  late String? _birthDate = widget.profile.birthDate;
  late Sex? _sex = widget.profile.sex;
  late ActivityLevel _activity = widget.profile.activity;
  _Source? _source;
  bool _saving = false;

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  BodyProfile get _draft => BodyProfile(heightCm: _validHeight, birthDate: _birthDate, sex: _sex, activity: _activity);

  double? get _validHeight {
    final v = parseNum(_height.text);
    return v != null && v >= 100 && v <= 250 ? v : null;
  }

  double? get _validWeight {
    final v = parseNum(_weight.text);
    return v != null && v >= 30 && v <= 300 ? v : null;
  }

  bool get _heightError => _height.text.trim().isNotEmpty && _validHeight == null;

  bool get _weightError => _weight.text.trim().isNotEmpty && _validWeight == null;

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await pickDate(
      context,
      title: 'Fecha de nacimiento',
      initial: _birthDate != null ? fromDateKey(_birthDate!) : DateTime(now.year - 30, 1, 1),
      first: DateTime(now.year - 100),
      last: DateTime(now.year - 12, now.month, now.day),
    );
    if (picked != null) setState(() => _birthDate = toDateKey(picked));
  }

  Future<void> _save() async {
    final actions = ref.read(nutritionActionsProvider);
    final kg = _validWeight;
    setState(() => _saving = true);
    await runGuarded(context, () async {
      await actions.saveBodyProfile(_draft);
      // Un peso nuevo queda en el registro de hoy (el mismo de Progreso).
      if (kg != null && kg != _latestKg) await actions.saveWeight(WeightEntry(date: todayKey(), kg: kg));
    }, success: 'Perfil guardado');
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _apply(Goals goals) async {
    if (!await confirm(context, 'Se reemplazarán los rangos de tus objetivos diarios. Los pesos del puntaje no cambian.', accept: 'Aplicar')) return;
    if (!mounted) return;
    final ok = await runGuarded(context, () => ref.read(nutritionActionsProvider).saveGoals(goals), success: 'Objetivos actualizados');
    if (ok && mounted) context.go('/objetivos');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = todayKey();
    final kg = _validWeight;
    final formula = formulaEnergy(_draft, kg, today);
    final days = ref.watch(loggedDaysProvider).value ?? const [];
    final weights = ref.watch(weightsProvider).value ?? const [];
    final observed = observedEnergy(days, weights, today);
    final progress = observedProgress(days, weights, today);
    final goal = ref.watch(bodyGoalProvider).value?.type ?? GoalType.maintain;
    final current = ref.watch(goalsProvider).value;

    // Por defecto se prefiere el gasto medido con los registros: se ajusta a la persona.
    final source = _source ?? (observed != null ? _Source.observed : _Source.formula);
    final tdee = source == _Source.observed ? observed?.tdee : formula?.tdee;
    final suggestion = tdee != null && kg != null && current != null ? suggestGoals(tdee: tdee, kg: kg, goal: goal, current: current) : null;

    return PageBody(gap: 12, children: [
      const SectionTitle('Tus datos'),
      AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: NumberField(controller: _height, label: 'Estatura (cm)', hint: '175', error: _heightError, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 12),
            Expanded(child: NumberField(controller: _weight, label: 'Peso (kg)', hint: '75', error: _weightError, onChanged: (_) => setState(() {}))),
          ]),
          if (widget.latestWeight != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Último peso registrado: ${shortDate(widget.latestWeight!.date)}', style: TextStyle(fontSize: 11, color: c.faint)),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickBirthDate,
            icon: const Icon(Icons.cake_outlined, size: 18),
            label: Text(_birthDate == null ? 'Fecha de nacimiento' : '${longDate(_birthDate!)} · ${ageOn(_birthDate!, today)} años'),
          ),
          const SizedBox(height: 12),
          Text('Sexo (la fórmula usa valores distintos)', style: TextStyle(fontSize: 12, color: c.muted)),
          const SizedBox(height: 6),
          AppSegmented<Sex>(
            value: _sex,
            segments: const {Sex.female: Text('Mujer'), Sex.male: Text('Hombre')},
            onChanged: (s) => setState(() => _sex = s),
          ),
        ]),
      ),
      const SectionTitle('Actividad en una semana normal'),
      CardList(children: [
        for (final level in ActivityLevel.values)
          ListTile(
            onTap: () => setState(() => _activity = level),
            leading: Icon(_activity == level ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: _activity == level ? c.primary : c.faint),
            title: Text(_activityText[level]!.$1, style: TextStyle(fontSize: 14, color: c.fgStrong)),
            subtitle: Text(_activityText[level]!.$2, style: TextStyle(fontSize: 12, color: c.muted)),
            trailing: Text('× ${plainEs(level.factor)}', style: TextStyle(fontSize: 12, color: c.faint, fontFeatures: tabular)),
          ),
      ]),
      FilledButton(onPressed: _saving || _heightError || _weightError ? null : _save, child: const Text('Guardar perfil')),
      const SectionTitle('Gasto calórico estimado'),
      TileGrid(children: [
        StatTile(
          icon: Icons.calculate_outlined,
          label: 'Con la fórmula',
          value: formula == null ? '–' : '${formatNumber(formula.tdee)} kcal',
          caption: formula == null ? 'Completa tus datos' : 'Reposo ${formatNumber(formula.bmr)} kcal',
        ),
        StatTile(
          icon: Icons.insights,
          label: 'Con tus registros',
          value: observed == null ? '–' : '${formatNumber(observed.tdee)} kcal',
          caption: observed == null
              ? '${progress.loggedDays} de $minObservedDays días registrados'
              : '${observed.days} días · ${observed.ratePerWeek > 0 ? '+' : ''}${formatNumber(observed.ratePerWeek, maxFractionDigits: 2)} kg/sem',
        ),
      ]),
      Text(
        observed == null
            ? 'Para medir tu gasto real hacen falta $minObservedDays días con comidas registradas y al menos 3 pesajes que abarquen '
                '$minWeightSpanDays días, dentro de las últimas 4 semanas (llevas ${progress.weighIns} '
                '${progress.weighIns == 1 ? 'pesaje' : 'pesajes'} en ${progress.weightSpanDays} días). Mientras, se usa la fórmula de Mifflin-St Jeor.'
            : 'Tu gasto real es la ingesta promedio (${formatNumber(observed.avgIntake)} kcal) menos el cambio de peso convertido en calorías. '
                'Los días anotados a medias no se cuentan.',
        style: TextStyle(fontSize: 11, color: c.faint, height: 1.5),
      ),
      const SectionTitle('Objetivos sugeridos'),
      if (formula != null && observed != null)
        ChoicePills<_Source>(
          options: _Source.values,
          selected: source,
          label: (s) => s == _Source.formula ? 'Según la fórmula' : 'Según tus registros',
          onSelected: (s) => setState(() => _source = s),
        ),
      if (suggestion == null)
        const AppCard(
          child: EmptyState(
            icon: Icons.track_changes,
            title: 'Faltan datos',
            message: 'Completa estatura, peso, fecha de nacimiento y sexo para calcular una sugerencia.',
          ),
        )
      else ...[
        CardList(
          header: CardHeader('Para ${_goalText[goal]} · ${formatNumber(jsRound(tdee! * goalFactor[goal]! / 10) * 10)} kcal', icon: Icons.track_changes),
          children: [
            for (final k in MacroKey.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: c.macro(k), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(macroMeta[k]!.label, style: TextStyle(fontSize: 14, color: c.fg))),
                  Text(_range(suggestion.range(k), k), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong, fontFeatures: tabular)),
                  SizedBox(
                    width: 92,
                    child: Text('hoy ${_range(current!.range(k), k)}', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: c.faint, fontFeatures: tabular)),
                  ),
                ]),
              ),
          ],
        ),
        FilledButton.tonalIcon(
          onPressed: () => _apply(suggestion),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Aplicar a mis objetivos'),
        ),
        Text(
          'Meta: ${_goalText[goal]} (se cambia en Nutrición › Progreso), con ${goal == GoalType.lose ? '15 % menos' : goal == GoalType.gain ? '10 % más' : 'las mismas'} calorías '
          'que tu gasto. Proteína ${goal == GoalType.lose ? '2,2–2,8' : '1,6–2,2'} g por kg (ISSN), grasa 20–30 % de las calorías, '
          'fibra 14 g cada 1000 kcal y el resto en carbohidratos.',
          style: TextStyle(fontSize: 11, color: c.faint, height: 1.5),
        ),
      ],
    ]);
  }

  String _range(Range r, MacroKey k) => '${formatMacro(k, r.min)}–${formatMacro(k, r.max)}';
}
