/// Búsqueda en el catálogo de alimentos y recetas tolerante a errores de tipeo.
///
/// La versión web recupera candidatos con Fuse.js y los ordena por similitud de
/// tokens. Aquí se calcula esa misma similitud sobre todo el catálogo (cientos o
/// pocos miles de entradas), lo que devuelve un superconjunto de esos candidatos.
library;

import '../common/fuzzy.dart';
import '../common/normalize.dart';
import 'models.dart';

class CatalogEntry {
  CatalogEntry({required this.kind, required this.id, required this.name, required this.terms, required this.order})
      : termTokens = terms.map(keyTokens).toList();

  final EntryKind kind;
  final String id;
  final String name;

  /// Nombre y alias normalizados, también en singular.
  final List<String> terms;
  final List<List<String>> termTokens;

  /// Posición en el catálogo: desempate estable.
  final int order;

  String get key => '${kind.name}:$id';
}

class Candidate {
  const Candidate({required this.kind, required this.id, required this.name, required this.confidence});

  final EntryKind kind;
  final String id;
  final String name;

  /// 0–1, similitud entre la consulta y el mejor término del catálogo.
  final double confidence;

  @override
  bool operator ==(Object other) => other is Candidate && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'Candidate($kind:$id, ${confidence.toStringAsFixed(3)})';
}

List<CatalogEntry> buildCatalog(Iterable<Food> foods, Iterable<Recipe> recipes) {
  var order = 0;
  CatalogEntry entry(EntryKind kind, String id, String name, List<String> aliases) {
    final terms = <String>{};
    for (final t in [name, ...aliases]) {
      final n = normalize(t);
      if (n.isEmpty) continue;
      terms.add(n);
      terms.add(singularize(n));
    }
    return CatalogEntry(kind: kind, id: id, name: name, terms: terms.toList(), order: order++);
  }

  return [
    for (final r in recipes) entry(EntryKind.recipe, r.id, r.name, r.aliases),
    for (final f in foods) entry(EntryKind.food, f.id, f.name, f.aliases),
  ];
}

double _f1(List<String> q, List<String> t) {
  final recall = bestCoverage(q, t);
  final precision = bestCoverage(t, q);
  if (recall + precision == 0) return 0;
  return (2 * recall * precision) / (recall + precision);
}

/// Similitud entre frases: F1 entre la cobertura de la consulta (recall) y la del
/// término (precision). "pan" vs "pan marraqueta" = 0,67: coincide pero es ambiguo.
double phraseSimilarity(String query, String term) => _f1(keyTokens(query), keyTokens(term));

class Matcher {
  Matcher(this.entries) {
    for (final e in entries) {
      for (final t in e.terms) {
        (_exact[t] ??= []).add(e);
      }
    }
  }

  final List<CatalogEntry> entries;
  final Map<String, List<CatalogEntry>> _exact = {};

  int get size => entries.length;

  /// Candidatos ordenados por confianza.
  List<Candidate> search(String query, {int limit = 5}) {
    final q = normalize(query);
    if (q.isEmpty) return const [];
    final qs = singularize(q);
    final qTokens = keyTokens(q);

    final exactHits = {...?_exact[q], ...?_exact[qs]}.map((e) => e.key).toSet();
    final scored = <(CatalogEntry, double)>[];
    for (final e in entries) {
      var confidence = 0.0;
      if (exactHits.contains(e.key)) {
        confidence = 1;
      } else {
        for (final tokens in e.termTokens) {
          final s = _f1(qTokens, tokens);
          if (s > confidence) confidence = s;
        }
      }
      if (confidence > 0) scored.add((e, confidence));
    }

    scored.sort((a, b) {
      final byConfidence = b.$2.compareTo(a.$2);
      if (byConfidence != 0) return byConfidence;
      if (a.$1.kind != b.$1.kind) return a.$1.kind == EntryKind.recipe ? -1 : 1;
      final byLength = a.$1.name.length.compareTo(b.$1.name.length);
      if (byLength != 0) return byLength;
      return a.$1.order.compareTo(b.$1.order);
    });

    return [
      for (final (e, c) in scored.take(limit)) Candidate(kind: e.kind, id: e.id, name: e.name, confidence: c),
    ];
  }
}
