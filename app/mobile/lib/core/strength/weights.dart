/// Pesos de fuerza según la unidad de la máquina o las pesas (kg o lb):
/// incrementos, drop sets, progresión y cálculo de discos.
library;

import '../common/numbers.dart';
import '../common/units.dart';
import 'models.dart';

/// Incremento habitual de carga. En kg: discos de 1,25 por lado (2,5 en total) o
/// 0,5 en pesos bajos; en lb: discos de 2,5 por lado (5 en total) o 1 en pesos bajos.
double weightStep(WeightUnit unit, {required double value}) => switch (unit) {
      WeightUnit.kg => value >= 20 ? 2.5 : 0.5,
      WeightUnit.lb => value >= 45 ? 5 : 1,
    };

/// Peso sugerido para un drop, en la misma unidad: 80 % del anterior, redondeado
/// al incremento de esa unidad. null si no hay peso o el redondeo no baja.
double? dropWeight(double? value, WeightUnit unit) {
  if (value == null || value <= 0) return null;
  final out = roundToStep(value * 0.8, weightStep(unit, value: value));
  return out > 0 && out < value ? out : null;
}

const _lowerBody = {'quadriceps', 'hamstrings', 'glutes', 'adductors', 'abductors', 'lower back'};

/// Cuánto subir al completar el rango (doble progresión), en la unidad del ejercicio.
/// kg: 5 en básicos de pierna con barra, 2 con mancuernas (cada una), 2,5 en el resto.
/// lb: 10, 5 y 5 (los saltos habituales de discos y mancuernas en libras).
double progressionStepIn(Exercise? e, WeightUnit unit) {
  final legsBarbell = e?.equipment == 'barbell' && e!.primary.any(_lowerBody.contains);
  final dumbbell = e?.equipment == 'dumbbell';
  return switch (unit) {
    WeightUnit.kg => legsBarbell ? 5 : (dumbbell ? 2 : 2.5),
    WeightUnit.lb => legsBarbell ? 10 : 5,
  };
}

// ---------------------------------------------------------------------------
// Calculadora de discos
// ---------------------------------------------------------------------------

/// Discos habituales de cada sistema (por unidad), de mayor a menor.
const standardPlates = {
  WeightUnit.kg: [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25],
  WeightUnit.lb: [45.0, 35.0, 25.0, 10.0, 5.0, 2.5],
};

/// Barras más comunes (olímpica de hombre, de mujer, barra corta o EZ).
const standardBars = {
  WeightUnit.kg: [20.0, 15.0, 10.0],
  WeightUnit.lb: [45.0, 35.0, 25.0],
};

class PlateLoad {
  const PlateLoad({required this.bar, required this.perSide, required this.target});

  final double bar;

  /// Discos de un lado, de mayor a menor.
  final List<double> perSide;
  final double target;

  /// Peso que queda armado con la barra y los discos.
  double get loaded => bar + 2 * perSide.fold<double>(0, (a, p) => a + p);

  /// Lo que falta para llegar al objetivo (0 si se puede armar exacto).
  double get missing => round2(target - loaded);

  bool get exact => missing.abs() < 0.01;
}

/// Discos por lado para llegar a `total` con una barra de `bar` (misma unidad).
/// Usa primero los discos más grandes; si no se puede exacto, queda bajo el objetivo
/// y [PlateLoad.missing] dice cuánto falta.
PlateLoad platesFor(double total, WeightUnit unit, {double? bar, List<double>? plates}) {
  final b = bar ?? standardBars[unit]!.first;
  final available = [...(plates ?? standardPlates[unit]!)]..sort((a, c) => c.compareTo(a));
  final perSide = <double>[];
  var remaining = round2((total - b) / 2);
  for (final p in available) {
    while (remaining + 1e-9 >= p) {
      perSide.add(p);
      remaining = round2(remaining - p);
    }
  }
  return PlateLoad(bar: b, perSide: perSide, target: total);
}

/// "2 × 20 + 1 × 5" para mostrar los discos de un lado.
String platesLabel(List<double> perSide) {
  if (perSide.isEmpty) return 'Solo la barra';
  final counts = <double, int>{};
  for (final p in perSide) {
    counts[p] = (counts[p] ?? 0) + 1;
  }
  return counts.entries.map((e) => '${e.value} × ${plainEs(e.key)}').join(' + ');
}
