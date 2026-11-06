/// Redondeos y formatos numéricos compartidos (compatibles con la versión web).
library;

/// `Math.round` de JavaScript: las mitades suben hacia +∞ (también en negativos).
int jsRound(num n) => (n + 0.5).floor();

double round1(num n) => jsRound(n * 10) / 10;

double round2(num n) => jsRound(n * 100) / 100;

/// Texto plano sin ".0" sobrante: 100.0 → "100", 52.5 → "52.5".
String plain(num n) => n == n.truncate() ? n.truncate().toString() : n.toString();

/// Igual que [plain] pero con coma decimal, para mostrar y editar ("52,5").
String plainEs(num? n) => n == null ? '' : plain(n).replaceAll('.', ',');

/// Convierte texto a número aceptando coma decimal. Devuelve null si no es válido.
double? parseNum(String s) {
  final t = s.trim().replaceFirst(',', '.');
  if (t.isEmpty) return null;
  final n = double.tryParse(t);
  return n != null && n.isFinite ? n : null;
}

double numOr(String s, double fallback) => parseNum(s) ?? fallback;

/// Formato es-CL: punto de miles (desde 5 dígitos, como ICU) y coma decimal.
String formatNumber(num n, {int maxFractionDigits = 1}) {
  final negative = n < 0;
  var factor = 1;
  for (var i = 0; i < maxFractionDigits; i++) {
    factor *= 10;
  }
  final scaled = jsRound(n.abs() * factor);
  final intPart = scaled ~/ factor;
  var frac = (scaled % factor).toString().padLeft(maxFractionDigits, '0');
  while (frac.endsWith('0')) {
    frac = frac.substring(0, frac.length - 1);
  }
  var digits = intPart.toString();
  if (digits.length >= 5) {
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
      out.write(digits[i]);
    }
    digits = out.toString();
  }
  final sign = negative && (intPart > 0 || frac.isNotEmpty) ? '-' : '';
  return frac.isEmpty || maxFractionDigits == 0 ? '$sign$digits' : '$sign$digits,$frac';
}

/// Número compacto para ejes: 12.500 → "12,5 mil".
String compactNumber(num n) {
  final a = n.abs();
  if (a >= 1000000) return '${formatNumber(n / 1000000, maxFractionDigits: 1)} M';
  // Bajo 10 mil se usan dos decimales para no repetir marcas del eje (1,1 / 1,15 / 1,2 mil).
  if (a >= 1000) return '${formatNumber(n / 1000, maxFractionDigits: a < 10000 ? 2 : 1)} mil';
  return formatNumber(n, maxFractionDigits: 1);
}
