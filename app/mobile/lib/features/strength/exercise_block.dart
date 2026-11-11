import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/common/numbers.dart';
import '../../core/common/units.dart';
import '../../core/strength/catalog.dart';
import '../../core/strength/models.dart';
import '../../ui/format.dart';
import '../../ui/widgets.dart';
import 'exercise_widgets.dart';
import 'set_options.dart';
import 'unit_sheets.dart';

/// Fila editable de la tabla de series (rutina o sesión en curso).
class SetRow {
  const SetRow({required this.key, required this.type, required this.kg, required this.reps, this.done, this.hintKg, this.hintReps});

  final String key;
  final SetType type;
  final String kg;
  final String reps;

  /// Solo en la sesión en curso.
  final bool? done;

  /// Sugerencias (placeholder) cuando el campo está vacío. El peso, en kg.
  final double? hintKg;
  final double? hintReps;
}

class SetPatch {
  const SetPatch({this.type, this.kg, this.reps});

  final SetType? type;
  final String? kg;
  final String? reps;
}

/// Tarjeta de un ejercicio con su tabla de series.
class ExerciseBlock extends StatelessWidget {
  const ExerciseBlock({
    super.key,
    required this.index,
    required this.total,
    required this.exercise,
    required this.name,
    required this.rows,
    required this.previous,
    required this.onChange,
    required this.onRemoveSet,
    required this.onAddSet,
    required this.onAddDrop,
    required this.onMove,
    required this.onRemove,
    required this.restSec,
    required this.onRestChange,
    this.onToggleDone,
    this.note,
    this.highlight,
    this.unit = WeightUnit.kg,
    this.onUnitChange,
  });

  final int index;
  final int total;
  final Exercise? exercise;
  final String name;
  final List<SetRow> rows;

  /// Serie equivalente de la última sesión con este ejercicio.
  final List<StrengthSet?> previous;
  final void Function(int setIndex, SetPatch patch) onChange;
  final void Function(int setIndex) onRemoveSet;
  final VoidCallback onAddSet;

  /// Agrega un drop set a la serie (después de ella y de sus drops).
  final void Function(int setIndex) onAddDrop;
  final void Function(int delta) onMove;
  final VoidCallback onRemove;

  /// Descanso entre series del ejercicio (0 = sin temporizador).
  final int restSec;
  final ValueChanged<int> onRestChange;

  /// Si se entrega, se muestra la columna ✓ (sesión en curso).
  final void Function(int setIndex)? onToggleDone;

  /// Texto bajo el encabezado ("Objetivo: 8–12 reps").
  final String? note;

  /// Aviso destacado (sugerencia de subir el peso).
  final String? highlight;

  /// Unidad en que se escriben los pesos (la de la máquina o las pesas).
  final WeightUnit unit;

  /// Si se entrega, el menú permite cambiar entre kg y lb.
  final ValueChanged<WeightUnit>? onUnitChange;

  /// Peso con que abrir la calculadora de discos: el de la primera serie pendiente.
  double? get _plateStart {
    final row = rows.where((r) => r.done != true).firstOrNull ?? rows.lastOrNull;
    if (row == null) return null;
    return parseNum(row.kg) ?? (row.hintKg == null ? null : displayWeight(row.hintKg!, unit));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = rows.where((r) => r.done == true).length;
    final muscles = exercise != null && exercise!.primary.isNotEmpty ? ' · ${exercise!.primary.map(muscleLabel).join(', ')}' : '';
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
          child: Row(children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: exercise == null ? null : () => showExerciseInfo(context, exercise!),
                child: Row(children: [
                  ExerciseThumb(exercise),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.primary)),
                      Text(
                        '${onToggleDone != null ? '$done/${rows.length} series' : '${rows.length} ${rows.length == 1 ? 'serie' : 'series'}'}$muscles',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: c.faint),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opciones de $name',
              icon: Icon(Icons.more_vert, color: c.muted),
              onSelected: (v) => switch (v) {
                'up' => onMove(-1),
                'down' => onMove(1),
                'unit' => onUnitChange?.call(unit.other),
                'plates' => showPlateCalculator(context, unit: unit, initial: _plateStart),
                _ => onRemove(),
              },
              itemBuilder: (_) => [
                if (onUnitChange != null) PopupMenuItem(value: 'unit', child: Text('Anotar en ${unit.other.plural} (${unit.other.symbol})')),
                if (usesPlates(exercise?.equipment)) const PopupMenuItem(value: 'plates', child: Text('Calcular discos')),
                PopupMenuItem(value: 'up', enabled: index > 0, child: const Text('Subir')),
                PopupMenuItem(value: 'down', enabled: index < total - 1, child: const Text('Bajar')),
                PopupMenuItem(value: 'remove', child: Text('Quitar', style: TextStyle(color: c.danger))),
              ],
            ),
          ]),
        ),
        if (highlight != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: c.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.trending_up, size: 18, color: c.success),
              const SizedBox(width: 8),
              Expanded(child: Text(highlight!, style: TextStyle(fontSize: 12, color: c.fgStrong, height: 1.3))),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 12, 4),
          child: Row(children: [
            RestChip(
              seconds: restSec,
              onTap: () async {
                final picked = await pickRest(context, current: restSec);
                if (picked != null) onRestChange(picked);
              },
            ),
            if (unit != WeightUnit.kg) ...[
              const SizedBox(width: 8),
              _UnitBadge(unit: unit, onTap: onUnitChange == null ? null : () => onUnitChange!(unit.other)),
            ],
            if (note != null) ...[
              const SizedBox(width: 8),
              Expanded(child: Text(note!, textAlign: TextAlign.end, style: TextStyle(fontSize: 11, color: c.muted))),
            ],
          ]),
        ),
        _SetTable(rows: rows, previous: previous, unit: unit, onChange: onChange, onRemove: onRemoveSet, onAddDrop: onAddDrop, onToggleDone: onToggleDone),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: TextButton.icon(
            style: TextButton.styleFrom(backgroundColor: c.surface2, foregroundColor: c.muted, minimumSize: const Size.fromHeight(36)),
            onPressed: onAddSet,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Agregar serie', style: TextStyle(fontSize: 12)),
          ),
        ),
      ]),
    );
  }
}

/// Etiqueta "lb" junto al descanso, para que se note que el ejercicio no está en kg.
class _UnitBadge extends StatelessWidget {
  const _UnitBadge({required this.unit, this.onTap});

  final WeightUnit unit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: 'Pesos en ${unit.plural}. Toca para cambiar',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: c.warning.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
          child: Text('En ${unit.symbol}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.fgStrong)),
        ),
      ),
    );
  }
}

/// Tabla SERIE · ANTERIOR · KG · REPS · ✓
class _SetTable extends StatelessWidget {
  const _SetTable({
    required this.rows,
    required this.previous,
    required this.unit,
    required this.onChange,
    required this.onRemove,
    required this.onAddDrop,
    this.onToggleDone,
  });

  final List<SetRow> rows;
  final List<StrengthSet?> previous;
  final WeightUnit unit;
  final void Function(int, SetPatch) onChange;
  final void Function(int) onRemove;
  final void Function(int) onAddDrop;
  final void Function(int)? onToggleDone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labels = setLabels(rows.map((r) => r.type).toList());
    final head = TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: c.faint);

    Widget cells({required Widget serie, required Widget prev, required Widget kg, required Widget reps, Widget? check, required Widget options}) =>
        Row(children: [
          SizedBox(width: 34, child: serie),
          const SizedBox(width: 4),
          Expanded(child: prev),
          SizedBox(width: 64, child: kg),
          const SizedBox(width: 6),
          SizedBox(width: 54, child: reps),
          if (check != null) ...[const SizedBox(width: 6), SizedBox(width: 36, child: check)],
          SizedBox(width: 30, child: options),
        ]);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: cells(
          serie: Text('SERIE', textAlign: TextAlign.center, style: head),
          prev: Text('ANTERIOR', style: head),
          kg: Text(unit.symbol.toUpperCase(), textAlign: TextAlign.center, style: head),
          reps: Text('REPS', textAlign: TextAlign.center, style: head),
          check: onToggleDone != null ? Icon(Icons.check, size: 14, color: c.faint) : null,
          options: const SizedBox(),
        ),
      ),
      for (var i = 0; i < rows.length; i++)
        _SetRowView(
          key: ValueKey(rows[i].key),
          row: rows[i],
          label: labels[i],
          prev: i < previous.length ? previous[i] : null,
          unit: unit,
          cells: cells,
          canDrop: i > 0,
          onChange: (p) => onChange(i, p),
          onRemove: () => onRemove(i),
          onAddDrop: () => onAddDrop(i),
          onToggleDone: onToggleDone == null ? null : () => onToggleDone!(i),
        ),
    ]);
  }
}

class _SetRowView extends StatefulWidget {
  const _SetRowView({
    super.key,
    required this.row,
    required this.label,
    required this.prev,
    required this.unit,
    required this.cells,
    required this.canDrop,
    required this.onChange,
    required this.onRemove,
    required this.onAddDrop,
    this.onToggleDone,
  });

  final SetRow row;
  final String label;
  final StrengthSet? prev;
  final WeightUnit unit;
  final Widget Function({required Widget serie, required Widget prev, required Widget kg, required Widget reps, Widget? check, required Widget options}) cells;

  /// Puede ser un drop (tiene una serie antes).
  final bool canDrop;
  final ValueChanged<SetPatch> onChange;
  final VoidCallback onRemove;
  final VoidCallback onAddDrop;
  final VoidCallback? onToggleDone;

  @override
  State<_SetRowView> createState() => _SetRowViewState();
}

class _SetRowViewState extends State<_SetRowView> {
  late final _kg = TextEditingController(text: widget.row.kg);
  late final _reps = TextEditingController(text: widget.row.reps);

  @override
  void didUpdateWidget(_SetRowView old) {
    super.didUpdateWidget(old);
    // Valores que cambian desde fuera (al marcar con sugerencia o al copiar la anterior).
    if (widget.row.kg != _kg.text) _kg.text = widget.row.kg;
    if (widget.row.reps != _reps.text) _reps.text = widget.row.reps;
  }

  @override
  void dispose() {
    _kg.dispose();
    _reps.dispose();
    super.dispose();
  }

  Future<void> _options() async {
    final option = await showSetOptions(context, label: widget.label, type: widget.row.type, canDrop: widget.canDrop);
    switch (option) {
      case ChangeSetType(:final type) when type != widget.row.type:
        widget.onChange(SetPatch(type: type));
      case AddDropSet():
        widget.onAddDrop();
      case RemoveSet():
        widget.onRemove();
      case ChangeSetType() || null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final row = widget.row;
    final done = row.done == true;
    final drop = row.type == SetType.drop;
    final prev = widget.prev;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: done ? c.primarySoft : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: widget.cells(
        serie: Tooltip(
          message: '${setTypeName(row.type)}. Toca para ver las opciones',
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: _options,
            child: SizedBox(
              height: 36,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                // Los drops cuelgan de la serie anterior.
                if (drop) Icon(Icons.subdirectory_arrow_right, size: 12, color: setTypeColor(c, row.type)),
                Text(widget.label, style: TextStyle(fontSize: drop ? 12 : 14, fontWeight: FontWeight.bold, color: setTypeColor(c, row.type))),
              ]),
            ),
          ),
        ),
        prev: InkWell(
          onTap: prev == null
              ? null
              : () => widget.onChange(SetPatch(kg: prev.kg == null ? '' : plainEs(displayWeight(prev.kg!, widget.unit)), reps: plainEs(prev.reps))),
          child: Text(prev == null ? '—' : formatSet(kg: prev.kg, reps: prev.reps, unit: widget.unit),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.faint, fontFeatures: tabular)),
        ),
        kg: NumberField(
          controller: _kg,
          dense: true,
          textAlign: TextAlign.center,
          hint: row.hintKg == null ? '0' : plainEs(displayWeight(row.hintKg!, widget.unit)),
          onChanged: (v) => widget.onChange(SetPatch(kg: v)),
        ),
        reps: NumberField(
          controller: _reps,
          dense: true,
          decimal: false,
          // En el editor de rutinas se puede escribir un rango ("8-12").
          allowRange: widget.onToggleDone == null,
          textAlign: TextAlign.center,
          hint: plainEs(row.hintReps).isEmpty ? '0' : plainEs(row.hintReps),
          onChanged: (v) => widget.onChange(SetPatch(reps: v)),
        ),
        check: widget.onToggleDone == null
            ? null
            : Semantics(
                button: true,
                toggled: done,
                label: done ? 'Desmarcar serie ${widget.label}' : 'Marcar serie ${widget.label} como hecha',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: widget.onToggleDone,
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: done ? c.gradient : null,
                      color: done ? null : c.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.check, size: 18, color: done ? c.onPrimary : c.faint),
                  ),
                ),
              ),
        options: IconButton(
          tooltip: 'Opciones de la serie ${widget.label}',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          onPressed: _options,
          icon: Icon(Icons.more_horiz, size: 18, color: c.faint),
        ),
      ),
    );
  }
}
