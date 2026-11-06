import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/body/progress.dart';
import '../../core/common/date.dart';
import '../../core/common/numbers.dart';
import '../../ui/format.dart';
import '../../ui/trend_chart.dart';
import '../../ui/widgets.dart';

const _minKg = 20.0;
const _maxKg = 400.0;

String _kg(num n) => formatNumber(n, maxFractionDigits: 1);

String _signed(num n) => '${n > 0 ? '+' : n < 0 ? '−' : ''}${_kg(n.abs())}';

class _GoalMeta {
  const _GoalMeta(this.label, this.short, this.icon, this.hint);

  final String label;
  final String short;
  final IconData icon;
  final String hint;
}

const _goalMeta = {
  GoalType.lose: _GoalMeta('Perder peso', 'Perder', Icons.trending_down, 'Peso objetivo menor al actual'),
  GoalType.maintain: _GoalMeta('Mantener peso', 'Mantener', Icons.drag_handle, 'Peso que quieres sostener'),
  GoalType.gain: _GoalMeta('Ganar masa muscular', 'Ganar', Icons.trending_up, 'Peso objetivo mayor al actual'),
};

enum _Period { d30, d90, all }

/// Meta corporal, registro de peso y tendencia.
class ProgressPage extends ConsumerStatefulWidget {
  const ProgressPage({super.key});

  @override
  ConsumerState<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends ConsumerState<ProgressPage> {
  _Period _period = _Period.all;
  bool _editingGoal = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final weights = ref.watch(weightsProvider);
    final goal = ref.watch(bodyGoalProvider);
    return AsyncView(
      combineAsync([weights, goal], () => (weights.requireValue, goal.requireValue)),
      builder: (data) {
        final (entries, goal) = data;
        final stats = progressStats(entries, goal);
        final days = switch (_period) {
          _Period.d30 => 30,
          _Period.d90 => 90,
          _Period.all => null,
        };
        final visible = days == null ? entries : entries.where((e) => e.date.compareTo(addDays(todayKey(), -days)) >= 0).toList();
        final history = entries.reversed.take(60).toList();

        return PageBody(children: [
          if (goal == null || _editingGoal)
            _GoalForm(goal: goal, currentKg: stats.current?.kg, onDone: () => setState(() => _editingGoal = false))
          else
            _GoalCard(goal: goal, stats: stats, onEdit: () => setState(() => _editingGoal = true)),
          if (entries.isNotEmpty) _StatTiles(stats: stats, goal: goal),
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('Peso', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong))),
                if (entries.length > 1)
                  ChoicePills<_Period>(
                    options: _Period.values,
                    selected: _period,
                    onSelected: (p) => setState(() => _period = p),
                    label: (p) => switch (p) {
                      _Period.d30 => '30 d',
                      _Period.d90 => '90 d',
                      _Period.all => 'Todo',
                    },
                  ),
              ]),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                const EmptyState(
                  icon: Icons.monitor_weight_outlined,
                  title: 'Aún no registras tu peso',
                  message: 'Anota tu peso de hoy abajo; con unos pocos registros verás tu gráfica.',
                )
              else if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text('Sin registros en este período.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.muted)),
                )
              else
                TrendChart<WeightEntry>(
                  points: [for (final e in visible) TrendPoint(date: e.date, value: e.kg, data: e)],
                  unit: 'kg',
                  label: 'peso',
                  reference: goal?.targetKg == null ? null : ChartReference(goal!.targetKg!, 'Meta ${_kg(goal.targetKg!)} kg'),
                ),
              if (entries.length == 1)
                Text('Registra un segundo peso para ver la tendencia.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.faint)),
            ]),
          ),
          _WeightForm(entries: entries),
          if (history.isNotEmpty)
            CardList(header: const CardHeader('Historial'), children: [
              for (var i = 0; i < history.length; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(children: [
                    Expanded(child: Text(capitalize(weekdayDateYear(history[i].date)), style: TextStyle(fontSize: 14, color: c.muted))),
                    if (i + 1 < history.length && round1(history[i].kg - history[i + 1].kg) != 0)
                      Text(_signed(round1(history[i].kg - history[i + 1].kg)), style: TextStyle(fontSize: 12, color: c.faint, fontFeatures: tabular)),
                    SizedBox(
                      width: 72,
                      child: Text('${_kg(history[i].kg)} kg',
                          textAlign: TextAlign.right, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong, fontFeatures: tabular)),
                    ),
                    IconButton(
                      tooltip: 'Eliminar el registro del ${shortDate(history[i].date)}',
                      onPressed: () {
                        final date = history[i].date;
                        runGuarded(context, () => ref.read(nutritionActionsProvider).deleteWeight(date), success: 'Registro eliminado');
                      },
                      icon: Icon(Icons.delete_outline, size: 20, color: c.danger),
                    ),
                  ]),
                ),
            ]),
        ]);
      },
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.stats, required this.onEdit});

  final BodyGoal goal;
  final ProgressStats stats;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meta = _goalMeta[goal.type]!;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        Row(children: [
          GradientIcon(meta.icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(meta.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
              Text(
                '${goal.targetKg != null ? 'Meta ${_kg(goal.targetKg!)} kg' : 'Sin peso objetivo'}'
                '${stats.percent != null ? ' · ${stats.percent}% logrado' : ''}',
                style: TextStyle(fontSize: 12, color: c.muted),
              ),
            ]),
          ),
          IconButton(tooltip: 'Editar meta', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
        ]),
        if (stats.percent != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: stats.percent! / 100),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: c.bgHard, color: c.primary),
            ),
          ),
        ],
      ]),
    );
  }
}

class _GoalForm extends ConsumerStatefulWidget {
  const _GoalForm({required this.goal, required this.currentKg, required this.onDone});

  final BodyGoal? goal;
  final double? currentKg;
  final VoidCallback onDone;

  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  late GoalType _type = widget.goal?.type ?? GoalType.lose;
  late final _target = TextEditingController(text: widget.goal?.targetKg == null ? '' : plain(widget.goal!.targetKg!));
  late String _startDate = widget.goal?.startDate ?? todayKey();
  bool _saving = false;

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await pickDate(context, title: 'Inicio de la meta', initial: fromDateKey(_startDate), first: DateTime(2015), last: DateTime.now());
    if (picked != null) setState(() => _startDate = toDateKey(picked));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final kg = parseNum(_target.text);
    final hasTarget = _target.text.trim().isNotEmpty;
    final targetInvalid = hasTarget && !(kg != null && kg >= _minKg && kg <= _maxKg);
    final current = widget.currentKg;
    final wrongDirection = hasTarget &&
        !targetInvalid &&
        current != null &&
        ((_type == GoalType.lose && kg! >= current) || (_type == GoalType.gain && kg! <= current));
    final missingTarget = _type != GoalType.maintain && !hasTarget;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.flag_outlined, size: 18, color: c.primary),
          const SizedBox(width: 8),
          Text(widget.goal != null ? 'Editar meta' : '¿Cuál es tu meta?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
        ]),
        const SizedBox(height: 12),
        AppSegmented<GoalType>(
          value: _type,
          segments: {
            for (final t in GoalType.values)
              t: Row(mainAxisSize: MainAxisSize.min, children: [Icon(_goalMeta[t]!.icon), const SizedBox(width: 4), Text(_goalMeta[t]!.short)]),
          },
          onChanged: (t) => setState(() => _type = t),
        ),
        const SizedBox(height: 6),
        Text('${_goalMeta[_type]!.label}. ${_goalMeta[_type]!.hint}.', style: TextStyle(fontSize: 11, color: c.faint)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: NumberField(
              controller: _target,
              label: 'Peso objetivo (kg)${_type == GoalType.maintain ? ' · opcional' : ''}',
              hint: current != null ? plain(current) : 'ej: 78',
              error: targetInvalid,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event, size: 18),
              label: Text('Desde ${shortDate(_startDate)}'),
            ),
          ),
        ]),
        if (targetInvalid) ...[
          const SizedBox(height: 6),
          Text('El peso debe estar entre ${plain(_minKg)} y ${plain(_maxKg)} kg.', style: TextStyle(fontSize: 12, color: c.danger)),
        ],
        if (wrongDirection) ...[
          const SizedBox(height: 6),
          Text(
            'Tu último peso es ${_kg(current)} kg: para «${_goalMeta[_type]!.short.toLowerCase()}» la meta debería estar '
            '${_type == GoalType.lose ? 'por debajo' : 'por encima'}.',
            style: TextStyle(fontSize: 11, color: c.warning),
          ),
        ],
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (widget.goal != null) TextButton(onPressed: widget.onDone, child: const Text('Cancelar')),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: _saving || targetInvalid || missingTarget
                ? null
                : () async {
                    setState(() => _saving = true);
                    final goal = BodyGoal(type: _type, targetKg: hasTarget ? kg : null, startDate: _startDate);
                    final ok = await runGuarded(context, () => ref.read(nutritionActionsProvider).saveBodyGoal(goal), success: 'Meta guardada');
                    if (!mounted) return;
                    setState(() => _saving = false);
                    if (ok) widget.onDone();
                  },
            child: const Text('Guardar'),
          ),
        ]),
      ]),
    );
  }
}

class _StatTiles extends StatelessWidget {
  const _StatTiles({required this.stats, required this.goal});

  final ProgressStats stats;
  final BodyGoal? goal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final change = stats.change;
    // Si el cambio va hacia la meta se muestra con ✓; si se aleja, con aviso (nunca solo color).
    bool? good;
    if (goal != null && change != null && change != 0) {
      good = switch (goal!.type) {
        GoalType.lose => change < 0,
        GoalType.gain => change > 0,
        GoalType.maintain => change.abs() <= 1,
      };
    }
    final target = goal?.targetKg;
    return TileGrid(children: [
      StatTile(
        icon: Icons.monitor_weight_outlined,
        label: 'Peso actual',
        value: stats.current != null ? '${_kg(stats.current!.kg)} kg' : '—',
        caption: stats.current != null ? shortDate(stats.current!.date) : null,
      ),
      StatTile(
        icon: Icons.speed,
        label: goal != null ? 'Cambio desde el inicio' : 'Cambio total',
        value: change != null ? '${_signed(change)} kg' : '—',
        caption: stats.ratePerWeek != null ? '${_signed(stats.ratePerWeek!)} kg por semana' : null,
        trailing: good == null
            ? null
            : Tooltip(
                message: good ? 'Va hacia tu meta' : 'Se aleja de tu meta',
                child: Icon(good ? Icons.check_circle : Icons.warning_amber, size: 16, color: good ? c.success : c.warning),
              ),
      ),
      if (target != null) ...[
        StatTile(
          icon: Icons.flag_outlined,
          label: 'Para llegar a la meta',
          value: stats.remaining != null ? '${_signed(stats.remaining!)} kg' : '—',
          caption: 'Meta ${_kg(target)} kg',
        ),
        StatTile(
          icon: Icons.event_available,
          label: 'Llegada estimada',
          value: stats.eta != null ? shortDate(stats.eta!) : '—',
          caption: stats.eta != null ? 'según tu tendencia' : 'sin tendencia hacia la meta',
          tooltip: 'Proyección con la tendencia de las últimas 4 semanas',
        ),
      ],
    ]);
  }
}

class _WeightForm extends ConsumerStatefulWidget {
  const _WeightForm({required this.entries});

  final List<WeightEntry> entries;

  @override
  ConsumerState<_WeightForm> createState() => _WeightFormState();
}

class _WeightFormState extends ConsumerState<_WeightForm> {
  String _date = todayKey();
  final _kgField = TextEditingController();
  bool _invalid = false;
  bool _saving = false;

  @override
  void dispose() {
    _kgField.dispose();
    super.dispose();
  }

  Future<void> _submit(WeightEntry? existing) async {
    final value = parseNum(_kgField.text);
    if (value == null || value < _minKg || value > _maxKg) {
      setState(() => _invalid = true);
      return;
    }
    setState(() => _saving = true);
    final ok = await runGuarded(
      context,
      () => ref.read(nutritionActionsProvider).saveWeight(WeightEntry(date: _date, kg: round1(value))),
      success: existing != null ? 'Peso actualizado' : 'Peso registrado',
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _kgField.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final last = widget.entries.lastOrNull;
    final existing = widget.entries.where((e) => e.date == _date).firstOrNull;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.monitor_weight_outlined, size: 18, color: c.primary),
          const SizedBox(width: 8),
          Text('Registrar peso', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final picked = await pickDate(context, title: 'Fecha del registro', initial: fromDateKey(_date), first: DateTime(2015), last: DateTime.now());
                if (picked != null) setState(() => _date = toDateKey(picked));
              },
              icon: const Icon(Icons.event, size: 18),
              label: Text(capitalize(dateLabel(_date, todayKey()))),
            ),
          ),
          const SizedBox(width: 8),
          NumberField(
            controller: _kgField,
            width: 100,
            hint: last != null ? plain(last.kg) : 'kg',
            error: _invalid,
            onChanged: (_) => setState(() => _invalid = false),
            onSubmitted: (_) => _submit(existing),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: existing != null ? 'Actualizar el peso de ese día' : 'Registrar peso',
            onPressed: _saving || _kgField.text.trim().isEmpty ? null : () => _submit(existing),
            icon: const Icon(Icons.add),
          ),
        ]),
        if (_invalid) ...[
          const SizedBox(height: 6),
          Text('Ingresa un peso entre ${plain(_minKg)} y ${plain(_maxKg)} kg.', style: TextStyle(fontSize: 12, color: c.danger)),
        ],
        if (existing != null && !_invalid) ...[
          const SizedBox(height: 6),
          Text('Ya hay un registro de ${_kg(existing.kg)} kg ese día; se reemplazará.', style: TextStyle(fontSize: 11, color: c.faint)),
        ],
      ]),
    );
  }
}
