/// Similitud entre palabras tolerante a errores de tipeo.
library;

import 'dart:math' as math;

int levenshtein(String a, String b) {
  if (a == b) return 0;
  var prev = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      cur[j] = math.min(
        math.min(prev[j] + 1, cur[j - 1] + 1),
        prev[j - 1] + (a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1),
      );
    }
    prev = cur;
  }
  return prev[b.length];
}

/// 1 si son iguales; si no, 1 - distancia relativa, o 0 bajo 0,75.
double tokenSimilarity(String a, String b) {
  if (a == b) return 1;
  final sim = 1 - levenshtein(a, b) / math.max(a.length, b.length);
  return sim >= 0.75 ? sim : 0;
}

/// Promedio, para cada token de `from`, de su mejor similitud con algún token de `to`.
double bestCoverage(List<String> from, List<String> to) {
  if (from.isEmpty) return 0;
  var sum = 0.0;
  for (final a in from) {
    var best = 0.0;
    for (final b in to) {
      final s = tokenSimilarity(a, b);
      if (s > best) best = s;
    }
    sum += best;
  }
  return sum / from.length;
}
