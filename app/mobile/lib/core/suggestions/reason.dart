/// Razón de una sugerencia del motor: qué dato la disparó y en qué se apoya.
///
/// Toda sugerencia debe poder explicarse ("te lo sugerimos porque…"): así el
/// usuario entiende la decisión y la puede ignorar, y cada regla se puede revisar
/// contra su fuente (RNF-14: registrar por qué cambió el plan).
library;

class Reason {
  const Reason(this.text, {this.source});

  factory Reason.fromMap(Object? data) {
    final m = data is Map ? data : const {};
    return Reason(m['text'] as String? ?? '', source: m['source'] as String?);
  }

  /// Explicación para el usuario, en una frase.
  final String text;

  /// Clave de la bibliografía de la tesis (`bibliografia/fonts.bib`), "Tabla de
  /// definiciones operativas" o "Decisión de diseño". null si es un dato del usuario.
  final String? source;

  Map<String, dynamic> toMap() => {'text': text, 'source': ?source};

  @override
  bool operator ==(Object other) => other is Reason && other.text == text && other.source == source;

  @override
  int get hashCode => Object.hash(text, source);

  @override
  String toString() => source == null ? text : '$text [$source]';
}

/// Qué hizo el usuario con una sugerencia o alerta.
enum ResponseKind {
  /// La sigue (por ejemplo, baja la carga de la sesión).
  followed,

  /// Mantiene lo que tenía planeado.
  kept,

  /// La descarta sin más.
  dismissed,
}

/// Respuesta guardada (`users/{uid}/suggestions/{id}`): la alerta no vuelve a
/// aparecer y queda el registro de qué se sugirió y qué se decidió (RNF-14).
class SuggestionResponse {
  const SuggestionResponse({required this.id, required this.kind, required this.response, required this.date, this.title = ''});

  factory SuggestionResponse.fromMap(String id, Map<String, dynamic> m) => SuggestionResponse(
        id: id,
        kind: m['kind'] as String? ?? '',
        response: ResponseKind.values.where((r) => r.name == m['response']).firstOrNull ?? ResponseKind.dismissed,
        date: m['date'] as String? ?? '',
        title: m['title'] as String? ?? '',
      );

  final String id;

  /// Tipo de alerta (`AlertKind.name`).
  final String kind;
  final ResponseKind response;

  /// Día en que se respondió (YYYY-MM-DD).
  final String date;

  /// Título de la alerta, para el historial.
  final String title;

  Map<String, dynamic> toMap() => {'kind': kind, 'response': response.name, 'date': date, 'title': title};
}

/// Fuentes que usa el motor (claves de `bibliografia/fonts.bib`).
abstract final class Sources {
  /// Umbrella review de entrenamiento concurrente: separar las sesiones y ordenarlas.
  static const concurrent = 'fisiologiadelejercicio';

  /// Interferencia AMPK/mTOR y recomendaciones prácticas de separación.
  static const interference = 'aptavs2025concurrente';

  /// Carga de la sesión = RPE × minutos.
  static const sessionRpe = 'foster2001monitoring';

  /// Session-RPE en fuerza.
  static const strengthRpe = 'day2004monitoring';

  /// Ecuación de Mifflin-St Jeor (gasto en reposo).
  static const mifflin = 'mifflin1990new';

  /// Constancia y adherencia en el entrenamiento de fuerza.
  static const adherence = 'rhodes2017resistance';

  /// Personalización y cambio de conducta en apps móviles.
  static const personalization = 'tong2021personalized';

  /// Reglas propias del proyecto (umbrales a ajustar con las evaluaciones del prototipo).
  static const design = 'Decisión de diseño';

  /// Nombre corto de cada fuente, para mostrarlo bajo la razón.
  static String label(String source) => switch (source) {
        concurrent => 'Revisión de metaanálisis sobre entrenamiento concurrente',
        interference => 'Guía de entrenamiento concurrente',
        sessionRpe => 'Foster et al., 2001 (carga por RPE de la sesión)',
        strengthRpe => 'Day et al., 2004 (RPE en fuerza)',
        mifflin => 'Mifflin et al., 1990',
        adherence => 'Rhodes et al., 2017 (adherencia a la fuerza)',
        personalization => 'Tong et al., 2021 (personalización)',
        design => 'Regla del prototipo, a ajustar con las pruebas',
        _ => source,
      };
}
