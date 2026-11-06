import '../common/normalize.dart';

enum Unit {
  g('g'),
  ml('ml'),
  unidad('unidad'),
  porcion('porción'),
  taza('taza'),
  vaso('vaso'),
  cda('cda'),
  cdta('cdta'),
  rebanada('rebanada'),
  lata('lata'),
  scoop('scoop');

  const Unit(this.label);

  final String label;
}

enum PortionSize {
  pequeno('pequeño'),
  mediano('mediano'),
  grande('grande');

  const PortionSize(this.label);

  /// También es el nombre de la porción en el catálogo.
  final String label;
}

class UnitAlias {
  const UnitAlias(this.unit, this.factor);

  final Unit unit;

  /// Multiplicador hacia la unidad base (kg → g = 1000).
  final double factor;
}

final Map<String, UnitAlias> _unitAliases = () {
  final map = <String, UnitAlias>{};
  void alias(Unit unit, double factor, List<String> words) {
    for (final w in words) {
      map[w] = UnitAlias(unit, factor);
    }
  }

  alias(Unit.g, 1, ['g', 'gr', 'grs', 'gramo', 'gramos']);
  alias(Unit.g, 1000, ['kg', 'kgs', 'kilo', 'kilos', 'kilogramo', 'kilogramos']);
  alias(Unit.ml, 1, ['ml', 'cc', 'mililitro', 'mililitros']);
  alias(Unit.ml, 1000, ['l', 'lt', 'lts', 'litro', 'litros']);
  alias(Unit.unidad, 1, ['unidad', 'unidades', 'u', 'ud', 'uds', 'und', 'pieza', 'piezas']);
  alias(Unit.porcion, 1, ['porcion', 'porciones', 'plato', 'platos']);
  alias(Unit.taza, 1, ['taza', 'tazas']);
  alias(Unit.vaso, 1, ['vaso', 'vasos']);
  alias(Unit.cda, 1, ['cda', 'cdas', 'cucharada', 'cucharadas']);
  alias(Unit.cdta, 1, ['cdta', 'cdtas', 'cdita', 'cditas', 'cucharadita', 'cucharaditas']);
  alias(Unit.rebanada, 1, ['rebanada', 'rebanadas', 'lamina', 'laminas', 'lonja', 'lonjas', 'tajada', 'tajadas', 'rodaja', 'rodajas']);
  alias(Unit.lata, 1, ['lata', 'latas']);
  alias(Unit.scoop, 1, ['scoop', 'scoops', 'medida', 'medidas']);
  return map;
}();

UnitAlias? lookupUnit(String token) => _unitAliases[token];

const _sizeAliases = {
  'pequeno': PortionSize.pequeno,
  'pequena': PortionSize.pequeno,
  'chico': PortionSize.pequeno,
  'chica': PortionSize.pequeno,
  'mediano': PortionSize.mediano,
  'mediana': PortionSize.mediano,
  'grande': PortionSize.grande,
  'grandes': PortionSize.grande,
};

PortionSize? lookupSize(String token) => _sizeAliases[token];

/// Volúmenes genéricos (ml) cuando el alimento no define la porción.
const genericMl = {Unit.taza: 240.0, Unit.vaso: 200.0, Unit.cda: 15.0, Unit.cdta: 5.0};

/// Pesos genéricos (g) cuando el alimento no define la porción.
const genericG = {Unit.scoop: 30.0};

bool samePortionName(String a, String b) => normalize(a) == normalize(b);
