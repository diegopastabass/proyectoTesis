/// Instrucciones (prompts) y esquemas JSON de cada función del asistente.
///
/// El modelo siempre responde JSON con estos esquemas (salida estructurada de la
/// API de Gemini, `responseJsonSchema`): así no hay que interpretar texto libre y
/// la respuesta se valida al leerla (`ai_models.dart`). Nunca se envían datos que
/// identifiquen a la persona, solo la foto o el texto (integración I-2 de la tesis).
library;

/// Una tarea para el modelo: qué hacer, con qué esquema responder y qué se le manda.
class AiTask {
  const AiTask({required this.system, required this.schema, required this.prompt});

  /// Instrucciones del sistema (rol y reglas).
  final String system;

  /// Esquema JSON de la respuesta.
  final Map<String, dynamic> schema;

  /// Texto del usuario o indicación que acompaña a la imagen.
  final String prompt;
}

const _num = {'type': 'number'};
const _str = {'type': 'string'};

const _foodSchema = {
  'type': 'object',
  'properties': {
    'nombre': {'type': 'string', 'description': 'Nombre del alimento en español de Chile, simple y genérico (p. ej. "arroz blanco cocido")'},
    'gramos': {'type': 'number', 'description': 'Gramos estimados de la porción consumida'},
    'confianza': {'type': 'number', 'description': 'Seguridad de 0 a 100 sobre el alimento y la cantidad'},
    'kcal': _num,
    'proteina': {'type': 'number', 'description': 'Gramos de proteína de la porción'},
    'carbohidratos': {'type': 'number', 'description': 'Gramos de carbohidratos de la porción'},
    'grasa': {'type': 'number', 'description': 'Gramos de grasa de la porción'},
    'fibra': {'type': 'number', 'description': 'Gramos de fibra de la porción'},
  },
  'required': ['nombre', 'gramos', 'confianza', 'kcal', 'proteina', 'carbohidratos', 'grasa'],
};

const mealSchema = {
  'type': 'object',
  'properties': {
    'alimentos': {'type': 'array', 'items': _foodSchema},
    'nota': {'type': 'string', 'description': 'Aviso breve si algo impide estimar bien; vacío si no hay'},
  },
  'required': ['alimentos'],
};

const _foodRules = '''
Reglas:
- Separa cada alimento por su cuenta (arroz, pollo y ensalada son tres alimentos).
- Usa nombres genéricos en español de Chile, como aparecerían en una tabla de alimentos (no marcas ni nombres de platos).
- Estima los gramos de lo que efectivamente se come, con porciones habituales en Chile.
- Los macronutrientes son de la porción estimada, no por 100 g.
- La confianza (0 a 100) baja si la cantidad o el alimento son dudosos (salsas, aceite, frituras, porciones ocultas).
- No inventes alimentos que no estén en la foto o en el texto.''';

const _nutritionistRole =
    'Eres un asistente de registro de comidas para deportistas aficionados en Chile. Estimas alimentos y cantidades; '
    'no das consejos médicos ni de dieta.';

AiTask mealFromPhotoTask() => const AiTask(
  system: '$_nutritionistRole\n$_foodRules\n- Si la foto no muestra comida, devuelve la lista vacía y explícalo en "nota".',
  schema: mealSchema,
  prompt: '¿Qué alimentos hay en este plato y cuánto de cada uno?',
);

AiTask mealFromTextTask(String text) => AiTask(
  system: '$_nutritionistRole\n$_foodRules\n- Si el texto indica una cantidad, respétala; si no, usa una porción habitual.',
  schema: mealSchema,
  prompt: 'Lo que comí: $text',
);

const _macrosSchema = {
  'type': 'object',
  'properties': {'kcal': _num, 'proteina': _num, 'carbohidratos': _num, 'grasa': _num, 'fibra': _num},
};

const labelSchema = {
  'type': 'object',
  'properties': {
    'nombre': {'type': 'string', 'description': 'Nombre del producto si se lee en el envase; vacío si no'},
    'marca': _str,
    'gramosPorcion': {'type': 'number', 'description': 'Gramos (o ml) de una porción según la etiqueta'},
    'por100g': _macrosSchema,
    'porPorcion': _macrosSchema,
  },
};

AiTask labelTask() => const AiTask(
  system:
      'Lees tablas de información nutricional de envases de alimentos (formato chileno: "100 g" y "1 porción"). '
      'Copia los valores tal como están impresos, sin estimar. Si la energía viene en kJ y en kcal, usa kcal. '
      'Llena "por100g" con la columna de 100 g o 100 ml y "porPorcion" con la de la porción. Deja vacío lo que no se lea.',
  schema: labelSchema,
  prompt: 'Lee la tabla nutricional de esta foto.',
);

const strengthSchema = {
  'type': 'object',
  'properties': {
    'ejercicios': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'escrito': {'type': 'string', 'description': 'El ejercicio tal como lo escribió la persona'},
          'nombre': {'type': 'string', 'description': 'Nombre del ejercicio en español'},
          'nombreIngles': {'type': 'string', 'description': 'Nombre más común en inglés (p. ej. "Barbell Squat", "Romanian Deadlift")'},
          'unidad': {
            'type': 'string',
            'enum': ['kg', 'lb'],
            'description': 'Unidad del peso; kg si no se dice',
          },
          'series': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'repeticiones': _num,
                'peso': {'type': 'number', 'description': 'Peso usado; omitir si es peso corporal'},
                'calentamiento': {'type': 'boolean'},
              },
              'required': ['repeticiones'],
            },
          },
        },
        'required': ['escrito', 'nombre', 'nombreIngles', 'series'],
      },
    },
  },
  'required': ['ejercicios'],
};

AiTask strengthTask(String text) => AiTask(
  system:
      'Ordenas sesiones de fuerza contadas con palabras. '
      'Reglas:\n'
      '- Una entrada por ejercicio, en el orden en que se contaron.\n'
      '- "4x8 con 80" o "4 series de 8 con 80" son cuatro series de 8 repeticiones con 80.\n'
      '- Si cada serie tuvo pesos o repeticiones distintas, respétalos uno por uno.\n'
      '- "Kilos" o "kg" es kg; "libras" o "lb" es lb.\n'
      '- No inventes ejercicios ni series que no se mencionen.',
  schema: strengthSchema,
  prompt: text,
);

const stepsSchema = {
  'type': 'object',
  'properties': {
    'pasos': {'type': 'array', 'items': _str},
  },
  'required': ['pasos'],
};

AiTask translateStepsTask(String exercise, List<String> steps) => AiTask(
  system:
      'Traduces instrucciones de ejercicios de fuerza del inglés al español neutro, claro y breve, '
      'con vocabulario de gimnasio usado en Chile. Mantén la misma cantidad de pasos y el mismo orden.',
  schema: stepsSchema,
  prompt: 'Ejercicio: $exercise\n${[for (var i = 0; i < steps.length; i++) '${i + 1}. ${steps[i]}'].join('\n')}',
);

const fatigueSchema = {
  'type': 'object',
  'properties': {
    'titular': {'type': 'string', 'description': 'Una frase corta con el estado de la semana'},
    'resumen': {'type': 'string', 'description': 'Dos o tres frases que expliquen la situación con las cifras entregadas'},
    'claves': {
      'type': 'array',
      'items': {'type': 'string'},
      'maxItems': 3,
      'description': 'Hasta tres puntos breves: de dónde viene la carga, qué viene en el plan, qué tan confiable es el cálculo',
    },
    'sugerencia': {'type': 'string', 'description': 'Una sugerencia concreta y prudente para los próximos días'},
  },
  'required': ['titular', 'resumen', 'claves', 'sugerencia'],
};

/// Explicar la fatiga cruzada con los datos del motor (JSON en `brief`).
AiTask fatigueSummaryTask(String briefJson) => AiTask(
      system: 'Eres un asistente para deportistas aficionados que combinan fuerza y resistencia (entrenamiento concurrente). '
          'Explicas, en español de Chile y tuteando, cómo va su fatiga cruzada a partir de datos ya calculados por la app. '
          'Conceptos: la carga de cada sesión es el esfuerzo percibido (RPE de 1 a 10) por los minutos, en unidades arbitrarias; '
          'la carga aguda resume la última semana y la crónica las últimas seis; su razón compara ambas '
          '(0,8 a 1,3 es lo habitual, sobre 1,3 un aumento brusco, sobre 1,5 muy brusco).\n'
          'Reglas:\n'
          '- Usa solo los datos entregados. No inventes cifras, sesiones ni fechas, y redondea al explicar.\n'
          '- Si el historial no es suficiente (menos de 28 días), dilo: la razón todavía no es confiable; habla de la carga de la semana.\n'
          '- Si hay alertas del motor, tu sugerencia debe ir en la misma línea; nunca las contradigas.\n'
          '- Si muchas sesiones tienen el RPE estimado, menciónalo y sugiere anotar el esfuerzo al terminar.\n'
          '- Si hay déficit calórico, puedes mencionarlo como factor de recuperación, sin dar dietas.\n'
          '- Es una señal de apoyo, no un diagnóstico: no hables de lesiones ni de enfermedades, ni prescribas.\n'
          '- Sé breve y concreto.',
      schema: fatigueSchema,
      prompt: 'Datos de mi entrenamiento:\n$briefJson',
    );
