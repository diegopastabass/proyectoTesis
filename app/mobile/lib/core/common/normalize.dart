/// Normalización de texto en español: sin tildes, minúsculas y singular aproximado.
library;

const _accents = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c', 'ý': 'y', 'ÿ': 'y',
  'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A', 'Ã': 'A', 'Å': 'A',
  'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
  'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
  'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O', 'Õ': 'O',
  'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
  'Ñ': 'N', 'Ç': 'C', 'Ý': 'Y',
};

String stripAccents(String s) {
  final out = StringBuffer();
  for (final ch in s.split('')) {
    out.write(_accents[ch] ?? ch);
  }
  return out.toString();
}

final _nonAlnum = RegExp(r'[^a-z0-9\s]');
final _spaces = RegExp(r'\s+');

/// Minúsculas, sin tildes ni signos, espacios colapsados.
String normalize(String s) =>
    stripAccents(s.toLowerCase()).replaceAll(_nonAlnum, ' ').replaceAll(_spaces, ' ').trim();

final _lnrdjEs = RegExp(r'[lnrdj]es$');

/// Singular aproximado en español: tomates → tomate, panes → pan, nueces → nuez.
String singularizeWord(String w) {
  if (w.length <= 3) return w;
  if (w.endsWith('ces')) return '${w.substring(0, w.length - 3)}z';
  if (_lnrdjEs.hasMatch(w)) return w.substring(0, w.length - 2);
  if (w.endsWith('s') && !w.endsWith('ss')) return w.substring(0, w.length - 1);
  return w;
}

String singularize(String phrase) => phrase.split(' ').map(singularizeWord).join(' ');

const _stopwords = {'de', 'del', 'el', 'la', 'los', 'las', 'en', 'al', 'a', 'con', 'y'};

/// Tokens significativos (normalizados, en singular, sin artículos ni preposiciones).
List<String> keyTokens(String s) =>
    singularize(normalize(s)).split(' ').where((t) => t.isNotEmpty && !_stopwords.contains(t)).toList();
