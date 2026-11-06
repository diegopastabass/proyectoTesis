/// Parser por reglas: "Arroz 100g", "1 Tomate mediano", "Huevos x3".
library;

import '../common/normalize.dart';
import 'units.dart';

/// Ítem extraído de una línea de texto, antes de buscarlo en el catálogo.
class ParsedItem {
  const ParsedItem({required this.raw, required this.query, this.quantity, this.unit, this.size});

  final String raw;

  /// Texto a buscar en el catálogo (sin cantidad, unidad ni tamaño).
  final String query;

  /// Cantidad ya convertida a la unidad base (kg → g, l → ml). null = no indicada.
  final double? quantity;
  final Unit? unit;
  final PortionSize? size;

  @override
  String toString() => 'ParsedItem($query, $quantity, $unit, $size)';
}

final _bullet = RegExp(r'^\s*(?:[-*•·]+|\d+\))\s*');
final _num = RegExp(r'^\d+(?:[.,]\d+)?$');
final _fraction = RegExp(r'^(\d+)/(\d+)$');
final _splitter = RegExp(r'\n|;|,(?!\d)');

const _wordNumbers = <String, double>{
  'un': 1, 'una': 1, 'uno': 1, 'medio': 0.5, 'media': 0.5,
  'dos': 2, 'tres': 3, 'cuatro': 4, 'cinco': 5, 'seis': 6,
  'siete': 7, 'ocho': 8, 'nueve': 9, 'diez': 10, 'doce': 12,
};

/// Palabras que indican una cantidad imprecisa: la cantidad se asume.
const _vague = {'poco', 'poquito', 'algo', 'porcioncita'};

const _edgeConnectors = {'de', 'del', 'el', 'la', 'los', 'las', 'en', 'con', 'y', 'a', 'al'};

/// Sin unidad, un número desde este valor se interpreta como gramos ("arroz 150").
const _bareNumberGramsThreshold = 20;

/// Separa el texto en líneas o ítems (salto de línea, punto y coma o coma no decimal).
List<String> splitItems(String text) =>
    text.split(_splitter).map((s) => s.replaceFirst(_bullet, '').trim()).where((s) => s.isNotEmpty).toList();

double? _fractionValue(String token) {
  final f = _fraction.firstMatch(token);
  if (f == null || int.parse(f[2]!) == 0) return null;
  return int.parse(f[1]!) / int.parse(f[2]!);
}

double? _readNumber(String token, bool allowWords) {
  if (_num.hasMatch(token)) return double.parse(token.replaceFirst(',', '.'));
  final f = _fractionValue(token);
  if (f != null) return f;
  if (allowWords) return _wordNumbers[token];
  return null;
}

final _spacedFraction = RegExp(r'(\d)\s*/\s*(\d)');
final _digitLetter = RegExp(r'(\d)([a-z])');
final _letterDigit = RegExp(r'([a-z])(\d)');
final _junk = RegExp(r'[^a-z0-9.,/\s]');
final _edgePunct = RegExp(r'^[.,]+|[.,]+$');

List<String> _tokenize(String raw) {
  final s = stripAccents(raw.toLowerCase())
      .replaceAllMapped(_spacedFraction, (m) => '${m[1]}/${m[2]}') // "1 / 2" → "1/2"
      .replaceAllMapped(_digitLetter, (m) => '${m[1]} ${m[2]}') // "100g" → "100 g", "3x" → "3 x"
      .replaceAllMapped(_letterDigit, (m) => '${m[1]} ${m[2]}') // "x3" → "x 3"
      .replaceAll(_junk, ' ');
  return s.split(RegExp(r'\s+')).map((t) => t.replaceAll(_edgePunct, '')).where((t) => t.isNotEmpty).toList();
}

/// Interpreta una línea como "Arroz 100g", "1 tomate mediano", "Huevos x3".
ParsedItem? parseLine(String raw) {
  final tokens = _tokenize(raw);
  final used = <int>{};
  double? quantity;
  Unit? unit;
  double factor = 1;
  PortionSize? size;
  var vague = false;

  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];

    if (quantity == null) {
      // "x 3" (multiplicador antes del número)
      if (t == 'x' && i + 1 < tokens.length) {
        final n = _readNumber(tokens[i + 1], false);
        if (n != null) {
          quantity = n;
          used.addAll([i, i + 1]);
          i++;
          continue;
        }
      }
      // Números escritos en palabras solo al inicio: evita "torta tres leches".
      final n = _readNumber(t, i == 0);
      if (n != null) {
        quantity = n;
        used.add(i);
        if (i + 1 < tokens.length && n == n.truncateToDouble()) {
          final fr = _fractionValue(tokens[i + 1]);
          if (fr != null) {
            quantity = quantity + fr; // "1 1/2"
            used.add(++i);
          }
        }
        if (i + 1 < tokens.length && tokens[i + 1] == 'x') used.add(++i); // "3 x"
        continue;
      }
    }

    if (t == 'par') {
      quantity = 2;
      used.add(i);
      continue;
    }

    if (unit == null) {
      final u = lookupUnit(t);
      if (u != null) {
        unit = u.unit;
        factor = u.factor;
        used.add(i);
        continue;
      }
    }

    if (size == null) {
      final sz = lookupSize(t);
      if (sz != null) {
        size = sz;
        used.add(i);
        continue;
      }
    }

    if (_vague.contains(t)) {
      vague = true;
      used.add(i);
    }
  }

  if (vague) {
    quantity = null;
  } else if (unit != null && quantity == null) {
    quantity = 1;
  }
  if (quantity != null && unit == null && quantity >= _bareNumberGramsThreshold) unit = Unit.g;
  if (quantity != null) quantity *= factor;

  final rest = normalize([for (var i = 0; i < tokens.length; i++) if (!used.contains(i)) tokens[i]].join(' ')).split(' ');
  while (rest.isNotEmpty && _edgeConnectors.contains(rest.first)) {
    rest.removeAt(0);
  }
  while (rest.isNotEmpty && _edgeConnectors.contains(rest.last)) {
    rest.removeLast();
  }
  final query = rest.join(' ').trim();
  if (query.isEmpty) return null;

  return ParsedItem(raw: raw.trim(), query: query, quantity: quantity, unit: unit, size: size);
}

List<ParsedItem> parseText(String text) => splitItems(text).map(parseLine).whereType<ParsedItem>().toList();
