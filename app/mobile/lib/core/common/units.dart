/// Conversión de unidades (lógica pura, sin Flutter).
///
/// La app guarda siempre en el sistema métrico (kg, m, s, kcal) y convierte solo
/// al mostrar o al leer lo que escribe el usuario. Así los datos guardados, los
/// cálculos (volumen, 1RM, carga, gasto) y la comparación entre sesiones no
/// dependen de la unidad elegida.
///
/// Factores exactos por definición (NIST SP 811): 1 lb = 0,45359237 kg;
/// 1 oz = 28,349523125 g; 1 mi = 1609,344 m; 1 ft = 0,3048 m; 1 in = 2,54 cm;
/// 1 fl oz (EE. UU.) = 29,5735295625 ml; 1 kcal = 4,184 kJ (caloría termoquímica).
library;

import 'numbers.dart';

const kgPerLb = 0.45359237;
const gPerOz = 28.349523125;
const mPerMile = 1609.344;
const mPerFoot = 0.3048;
const cmPerInch = 2.54;
const mlPerFlOz = 29.5735295625;
const kjPerKcal = 4.184;

// ---------------------------------------------------------------------------
// Peso (cargas de fuerza y peso corporal)
// ---------------------------------------------------------------------------

enum WeightUnit {
  kg('kg', 1),
  lb('lb', kgPerLb);

  const WeightUnit(this.symbol, this.kgFactor);

  /// Símbolo para mostrar ("kg", "lb").
  final String symbol;

  /// Cuántos kg es una unidad.
  final double kgFactor;

  WeightUnit get other => this == kg ? lb : kg;

  /// Nombre largo para los textos ("kilos", "libras").
  String get plural => this == kg ? 'kilos' : 'libras';

  /// Valor guardado → unidad. `null` si el texto no es una unidad conocida.
  static WeightUnit? tryParse(Object? v) => WeightUnit.values.where((u) => u.name == v).firstOrNull;

  /// Valor guardado → unidad (kg si falta o no se reconoce).
  static WeightUnit from(Object? v) => tryParse(v) ?? kg;
}

/// Valor en `unit` → kg.
double toKg(double value, WeightUnit unit) => value * unit.kgFactor;

/// kg → valor en `unit`.
double fromKg(double kg, WeightUnit unit) => kg / unit.kgFactor;

/// Convierte un valor entre dos unidades de peso.
double convertWeight(double value, WeightUnit from, WeightUnit to) => from == to ? value : fromKg(toKg(value, from), to);

/// kg → valor en `unit` redondeado a `decimals` (para mostrar o proponer).
/// 20,4116 kg en libras da 45 (y no 44,99999), porque la vuelta es exacta.
double displayWeight(double kg, WeightUnit unit, {int decimals = 1}) {
  final v = fromKg(kg, unit);
  return decimals == 1 ? round1(v) : (decimals == 2 ? round2(v) : jsRound(v).toDouble());
}

/// Redondea al múltiplo de `step` más cercano (2,5 kg, 5 lb…).
double roundToStep(double value, double step) => step <= 0 ? value : jsRound(value / step) * step;

// ---------------------------------------------------------------------------
// Distancia, altura y desnivel
// ---------------------------------------------------------------------------

enum DistanceUnit {
  km('km'),
  mi('mi');

  const DistanceUnit(this.symbol);

  final String symbol;

  /// Metros que tiene una unidad.
  double get meters => this == km ? 1000 : mPerMile;
}

double metersTo(double meters, DistanceUnit unit) => meters / unit.meters;

double toMeters(double value, DistanceUnit unit) => value * unit.meters;

/// Metros → pies (desnivel).
double metersToFeet(double m) => m / mPerFoot;

double feetToMeters(double ft) => ft * mPerFoot;

/// Estatura en cm → pies y pulgadas (5′ 9″). Las pulgadas se redondean al entero.
({int feet, int inches}) cmToFeetInches(double cm) {
  final totalIn = jsRound(cm / cmPerInch);
  return (feet: totalIn ~/ 12, inches: totalIn % 12);
}

double feetInchesToCm(int feet, double inches) => (feet * 12 + inches) * cmPerInch;

// ---------------------------------------------------------------------------
// Ritmo y velocidad
// ---------------------------------------------------------------------------

/// Ritmo en segundos por km → segundos por milla (y al revés).
double paceSecPerKmToMile(double secPerKm) => secPerKm * mPerMile / 1000;

double paceSecPerMileToKm(double secPerMile) => secPerMile * 1000 / mPerMile;

double kmhToMph(double kmh) => kmh * 1000 / mPerMile;

double mphToKmh(double mph) => mph * mPerMile / 1000;

/// m/s → km/h.
double msToKmh(double ms) => ms * 3.6;

/// Velocidad (km/h) → ritmo en segundos por km. null si está detenido.
double? kmhToPaceSecPerKm(double kmh) => kmh <= 0 ? null : 3600 / kmh;

// ---------------------------------------------------------------------------
// Nutrición: energía, masa y volumen pequeños
// ---------------------------------------------------------------------------

double kcalToKj(double kcal) => kcal * kjPerKcal;

double kjToKcal(double kj) => kj / kjPerKcal;

double ozToG(double oz) => oz * gPerOz;

double gToOz(double g) => g / gPerOz;

double flOzToMl(double flOz) => flOz * mlPerFlOz;

double mlToFlOz(double ml) => ml / mlPerFlOz;
