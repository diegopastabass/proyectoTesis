/// Hojas de unidades de peso: cambiar kg/lb en un ejercicio, calcular discos y
/// revisar al terminar los ejercicios que parecen anotados en la otra unidad.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/common/numbers.dart';
import '../../core/common/units.dart';
import '../../core/strength/unit_check.dart';
import '../../core/strength/weights.dart';
import '../../ui/format.dart';
import '../../ui/widgets.dart';
import 'set_options.dart';

/// Equipos que se cargan con discos en una barra.
bool usesPlates(String? equipment) => equipment == 'barbell' || equipment == 'e-z curl bar';

/// Pregunta qué hacer con los pesos ya escritos al cambiar de unidad.
/// true = convertirlos; false = mantener los números; null = cancelar.
Future<bool?> askUnitSwitch(BuildContext context, {required WeightUnit to}) {
  final c = context.colors;
  return compactSheet<bool>(context, title: 'Anotar en ${to.plural}', children: (sheet) => [
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text('Ya escribiste pesos en este ejercicio. ¿Qué hacemos con ellos?', style: TextStyle(fontSize: 13, color: c.muted, height: 1.3)),
    ),
    ListTile(
      leading: Icon(Icons.pin_outlined, color: c.primary),
      title: const Text('Mantener los números'),
      subtitle: Text('Los anotaste mirando la máquina, que está en ${to.plural}.', style: TextStyle(fontSize: 12, color: c.muted)),
      onTap: () => Navigator.pop(sheet, false),
    ),
    ListTile(
      leading: Icon(Icons.swap_horiz, color: c.primary),
      title: const Text('Convertirlos'),
      subtitle: Text('El peso es el mismo, solo cambia cómo se muestra (100 kg → 220,5 lb).', style: TextStyle(fontSize: 12, color: c.muted)),
      onTap: () => Navigator.pop(sheet, true),
    ),
  ]);
}

/// Revisión al terminar: lista los ejercicios sospechosos con una casilla cada uno.
/// Devuelve los que hay que corregir (vacío = está todo bien) o null si se cierra.
Future<List<UnitSuspicion>?> reviewUnits(BuildContext context, List<UnitSuspicion> suspicions, String Function(String exerciseId) nameOf) {
  final selected = {for (final s in suspicions) s.exerciseKey};
  return compactSheet<List<UnitSuspicion>>(context, title: '¿Revisamos las unidades?', children: (sheet) {
    final c = sheet.colors;
    return [
      StatefulBuilder(
        builder: (context, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              suspicions.length == 1
                  ? 'Este peso es muy distinto al de la última vez y calza con la otra unidad. ¿La máquina estaba en la otra unidad?'
                  : 'Estos pesos son muy distintos a los de la última vez y calzan con la otra unidad. Marca los que estaban en la otra unidad.',
              style: TextStyle(fontSize: 13, color: c.muted, height: 1.3),
            ),
          ),
          for (final s in suspicions)
            CheckboxListTile(
              value: selected.contains(s.exerciseKey),
              onChanged: (v) => setState(() => v == true ? selected.add(s.exerciseKey) : selected.remove(s.exerciseKey)),
              title: Text(nameOf(s.exerciseId), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
              subtitle: Text(
                'Anotaste ${plainEs(round1(s.typical))} ${s.entered.symbol}; la última vez, ${formatWeight(s.referenceKg, s.entered)}. '
                'Si eran ${s.likely.plural}: ${formatWeight(s.correctedKg, s.likely)} = ${formatWeight(s.correctedKg, s.entered)}.',
                style: TextStyle(fontSize: 12, color: c.muted, height: 1.3),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: FilledButton(
              onPressed: () => Navigator.pop(sheet, [for (final s in suspicions) if (selected.contains(s.exerciseKey)) s]),
              child: Text(selected.isEmpty ? 'Están bien así' : 'Corregir y seguir'),
            ),
          ),
          if (selected.isNotEmpty)
            TextButton(onPressed: () => Navigator.pop(sheet, const <UnitSuspicion>[]), child: const Text('No, están bien así')),
        ]),
      ),
    ];
  });
}

/// Calculadora de discos: qué poner a cada lado de la barra para llegar a un peso.
Future<void> showPlateCalculator(BuildContext context, {required WeightUnit unit, double? initial}) =>
    compactSheet<void>(context, title: 'Discos por lado', children: (sheet) => [_PlateCalculator(unit: unit, initial: initial)]);

class _PlateCalculator extends StatefulWidget {
  const _PlateCalculator({required this.unit, this.initial});

  final WeightUnit unit;
  final double? initial;

  @override
  State<_PlateCalculator> createState() => _PlateCalculatorState();
}

class _PlateCalculatorState extends State<_PlateCalculator> {
  late WeightUnit _unit = widget.unit;
  late double _bar = standardBars[_unit]!.first;
  late final _total = TextEditingController(text: widget.initial == null || widget.initial! <= 0 ? '' : plainEs(widget.initial!));

  @override
  void dispose() {
    _total.dispose();
    super.dispose();
  }

  void _setUnit(WeightUnit u) {
    final v = parseNum(_total.text);
    setState(() {
      if (v != null) _total.text = plainEs(round1(convertWeight(v, _unit, u)));
      _unit = u;
      _bar = standardBars[u]!.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = parseNum(_total.text);
    final load = total == null ? null : platesFor(total, _unit, bar: _bar);
    final sym = _unit.symbol;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: NumberField(controller: _total, label: 'Peso total ($sym)', hint: _unit == WeightUnit.kg ? '60' : '135', onChanged: (_) => setState(() {})),
          ),
          const SizedBox(width: 12),
          AppSegmented<WeightUnit>(
            value: _unit,
            segments: const {WeightUnit.kg: Text('kg'), WeightUnit.lb: Text('lb')},
            onChanged: _setUnit,
          ),
        ]),
        const SizedBox(height: 12),
        Text('Barra', style: TextStyle(fontSize: 12, color: c.muted)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final b in standardBars[_unit]!) ChoiceChip(label: Text('${plainEs(b)} $sym'), selected: b == _bar, onSelected: (_) => setState(() => _bar = b)),
        ]),
        const SizedBox(height: 16),
        if (load == null)
          Text('Escribe el peso total para ver los discos.', style: TextStyle(fontSize: 13, color: c.faint))
        else if (total! < _bar)
          Text('El peso es menor que la barra (${plainEs(_bar)} $sym).', style: TextStyle(fontSize: 13, color: c.warning))
        else ...[
          Text(platesLabel(load.perSide), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.fgStrong)),
          const SizedBox(height: 4),
          Text(
            load.exact
                ? 'A cada lado de la barra. Total: ${plainEs(load.loaded)} $sym (${formatWeight(toKg(load.loaded, _unit), _unit.other)}).'
                : 'No se arma exacto con discos estándar: quedan ${plainEs(load.loaded)} $sym (faltan ${plainEs(load.missing)} $sym).',
            style: TextStyle(fontSize: 12, color: load.exact ? c.muted : c.warning, height: 1.3),
          ),
          const SizedBox(height: 12),
          _PlatesBar(perSide: load.perSide, unit: _unit),
        ],
      ]),
    );
  }
}

/// Dibujo simple de un lado de la barra: discos más altos cuanto más pesan.
class _PlatesBar extends StatelessWidget {
  const _PlatesBar({required this.perSide, required this.unit});

  final List<double> perSide;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final biggest = standardPlates[unit]!.first;
    return SizedBox(
      height: 90,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(width: 40, height: 8, decoration: BoxDecoration(color: c.faint, borderRadius: BorderRadius.circular(2))),
        for (final p in perSide)
          Container(
            margin: const EdgeInsets.only(left: 2),
            width: 16,
            height: 28 + 60 * (p / biggest),
            decoration: BoxDecoration(color: c.primary.withValues(alpha: 0.35 + 0.65 * (p / biggest)), borderRadius: BorderRadius.circular(3)),
            alignment: Alignment.center,
            child: RotatedBox(quarterTurns: 3, child: Text(plainEs(p), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c.onPrimary))),
          ),
        Expanded(child: Container(height: 8, color: c.faint.withValues(alpha: 0.5))),
      ]),
    );
  }
}
