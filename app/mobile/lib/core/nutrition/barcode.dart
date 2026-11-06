/// Normaliza un código de barras a GTIN: solo dígitos y UPC-A (12) con un 0
/// adelante para que coincida con su EAN-13 equivalente.
String normalizeBarcode(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.length == 12 ? '0$digits' : digits;
}

/// Valida longitud (EAN-8, UPC-A, EAN-13, GTIN-14) y dígito verificador módulo 10.
bool isValidGtin(String code) {
  if (!RegExp(r'^\d+$').hasMatch(code) || !const [8, 12, 13, 14].contains(code.length)) return false;
  final digits = code.split('').map(int.parse).toList();
  final check = digits.removeLast();
  // Desde la derecha, los dígitos alternan peso 3 y 1.
  var sum = 0;
  final reversed = digits.reversed.toList();
  for (var i = 0; i < reversed.length; i++) {
    sum += reversed[i] * (i.isEven ? 3 : 1);
  }
  return (10 - (sum % 10)) % 10 == check;
}
