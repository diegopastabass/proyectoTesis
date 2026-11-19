# IA con Gemini en el prototipo

> Investigación del 16-11-2026. **Las 5 funciones quedaron implementadas el mismo día** (ver §6). Las cifras de cuotas y precios cambian seguido: confirmarlas en la página de límites de AI Studio del propio proyecto antes de comprometerse. Donde un dato viene de fuentes secundarias, se indica.

## 1. Qué incluye cada plan

| Plan | ¿Trae cuota o créditos para la API? | Qué sirve |
|---|---|---|
| **Plan de estudiante** (fuera de EE. UU.: un año de Google AI Plus gratis) | **No.** Cubre la app Gemini y los servicios de Google, no la API | — |
| **Google AI Plus** | **No.** La tabla de Google empieza los créditos mensuales en AI Pro | — |
| Google AI Pro / Ultra | Sí: créditos mensuales del Developer Program (USD 10 en Pro) para la API en AI Studio, que hay que activar y que piden vincular facturación y prepagar | — |
| **Nivel gratuito de la API** (independiente de cualquier suscripción) | Sí: se crea una clave en Google AI Studio, sin tarjeta | **Esto es lo que se puede usar** |

En resumen, la cuenta Plus o de estudiante **no aporta nada a la API**, pero la API tiene su propio nivel gratuito, que basta para un prototipo con un usuario.

### Nivel gratuito: lo que se sabe

- **Modelos gratis:** Gemini 3.8 Flash, 3.6 Flash, 3.5 Flash-Lite, 3.1 Flash-Lite y otros Flash anteriores ("Free of charge" en la página oficial de precios). Los modelos Pro no tienen nivel gratuito (o casi nada).
- **Límites:** son **por proyecto** (no por clave) y se reinician a medianoche del Pacífico. Google ya no los publica en su página general: se ven en la página de límites de AI Studio. Lecturas recientes de terceros (sep–oct 2026) indican unas **20 solicitudes al día y 5 por minuto para Flash** y unas **500 al día para Flash-Lite**. Para un prototipo de un usuario, Flash alcanza para unas cuantas fotos al día y Flash-Lite para el resto.
- **Qué funciones de la API se pueden usar gratis:** generación de texto, entrada de imágenes, audio, video y PDF, **salida estructurada con esquema JSON** (clave para no tener que interpretar texto libre) y llamadas a funciones. **La búsqueda con Google (grounding) no está en el nivel gratuito** de los modelos 3.x.
- **Condición importante:** en el nivel gratuito, **Google puede usar lo que se envía para mejorar sus productos**. Para el prototipo basta con no mandar datos que identifiquen a la persona (ya lo pide la tesis en la integración I-2) y avisarlo en la pantalla. Para el MVP, con datos de salud de usuarios reales (Ley 19.628), hay que pasar al nivel pago, que no usa los datos así.
- **Precio pago de referencia** (por si se supera el gratuito): Flash USD 0,75 por millón de tokens de entrada y USD 3,75 de salida hasta el 31-12-2026; Flash-Lite 3.1 USD 0,25 y USD 1,50. Una foto de comida cuesta del orden de una décima de centavo de dólar.

## 2. Cómo conectarlo sin servidor

La tesis pide que la clave nunca vaya en la app (RNF-04, I-2). Con la arquitectura del prototipo (Firebase y lógica en el teléfono) hay dos caminos:

| Camino | Cómo | Para qué |
|---|---|---|
| **Firebase AI Logic** (recomendado) | Paquete `firebase_ai` con el proveedor Gemini Developer API. Firebase guarda la clave; la app se identifica con **App Check** (App Attest en iPhone). Se activa en la consola de Firebase del proyecto que ya usa la app | Firebase real. Es el equivalente sin servidor al backend de la tesis: si se cambia de proveedor, cambia solo esta pieza |
| Clave en `--dart-define` | Llamada HTTP directa a la API | Solo pruebas personales: la clave se puede extraer del teléfono |

En el modo demostración y en las pruebas automáticas se usaría una implementación falsa (como hoy `sim_data.dart`), detrás de una interfaz `AiService` en `lib/platform/` o `lib/data/`, igual que el resto de los servicios.

En el MVP la llamada pasa al backend (NestJS) sin cambiar las pantallas ni el formato de la respuesta.

## 3. Funciones que se pueden implementar

Ordenadas por valor para el usuario y para la tesis. Todas usan salida estructurada (JSON con esquema) y **el usuario siempre revisa antes de guardar**. Si la confianza es menor a 70 %, se pide revisar con más cuidado, como exige el requisito de nutrición.

| # | Función | Caso de uso | Modelo | Cómo funciona |
|---|---|---|---|---|
| 1 | **Comida con una foto** | CU-07 (hoy simulado) | Flash | Foto → lista de alimentos con gramos estimados y confianza. Cada alimento se cruza con el catálogo (`Matcher`) y los macros salen del catálogo, no del modelo, igual que en la lista por reglas. Lo que no está en el catálogo queda "por revisar" |
| 2 | **Foto de la tabla nutricional** | CU-15 (complemento) | Flash-Lite | Cuando un producto no está en Open Food Facts, una foto de la etiqueta completa el formulario del alimento: macros por 100 g, porción y fibra. Es lectura de texto, así que el modelo liviano basta y la precisión es alta |
| 3 | **Contar la sesión de fuerza con mis palabras** | CU-02 (hoy simulado) | Flash-Lite | "Sentadilla 3x8 con 80, luego banca 4 series de 10 con 60" → ejercicios del catálogo, series, repeticiones y kg (respeta kg/lb). Lo que no se reconoce se elige de la lista |
| 4 | **Comida con mis palabras, cuando las reglas no alcanzan** | CU-16 | Flash-Lite | El parser por reglas sigue siendo lo primero (gratis, sin red, instantáneo). Solo las líneas que quedan como "falta" o "revisar" se mandan al modelo, para entender frases libres ("un plato de porotos con riendas") |
| 5 | **Instrucciones de ejercicios en español** | Ficha del ejercicio | Flash-Lite | El catálogo trae las instrucciones en inglés. Se traducen la primera vez que se abre un ejercicio y se guardan, así que cada ejercicio cuesta una sola llamada |
| 6 | Receta desde un texto pegado | CU-27 (ayuda) | Flash-Lite | Pegar una receta de internet → ingredientes con cantidades, ya cruzados con el catálogo |

**Qué no conviene hacer con IA:** las alertas de fatiga, el plan semanal y las metas. Son reglas con fuente y resultados que se pueden probar (fases 1 a 3 del motor), y la tesis las ubica en el motor de fatiga, no en el servicio de IA. Un "resumen en lenguaje natural" de la semana sería opcional y de poco valor frente a su costo en cuota.

**Propuesta de orden:** primero la 1 (es la función que más distingue a la tesis y hoy está simulada) y la 2 (barata y muy útil en el día a día). Después la 3 y la 4, que comparten el esquema "texto → estructura → cruce con el catálogo". La 5 queda como mejora de fondo.

**Cuota para un día normal** (un usuario): 3 a 5 fotos de comida (Flash, dentro de las ~20 diarias) y algunas decenas de llamadas a Flash-Lite. Si una llamada falla por cuota o sin red, la pantalla ofrece el registro manual de siempre (curso alterno de la tesis).

## 4. Lo que hace falta del lado del usuario

1. En la consola de Firebase del proyecto: **AI Logic → empezar → Gemini Developer API**, y activar **App Check** con App Attest para la app de iOS (y el proveedor de depuración para el simulador).
2. Revisar en AI Studio, página de límites, cuántas solicitudes diarias tiene el proyecto para Flash y Flash-Lite.

## 5. La música que no vuelve tras la alarma del descanso

- **Qué pasa:** la alarma la hace sonar el sistema (AlarmKit), no la app. El sistema pausa la música y, al apagar la alarma, la app de música debería retomarla. Muchos usuarios reportan que **lo mismo pasa con el temporizador del reloj de iPhone**: la música queda en pausa tras apagarlo, con Apple Music y Spotify, y en iOS 26.1 hay más reportes. No es algo del código de NutriApp.
- **Qué se puede hacer desde la app:** con AlarmKit, nada. Tanto el sonido como la interrupción del audio son del sistema; la app solo elige qué sonido usar, y eso no cambia si la música se retoma.
- **Alternativa posible**, si llegara a molestar: una opción en Ajustes, "Al terminar el descanso: **alarma** (suena en silencio, pausa la música) o **aviso breve** (no corta la música)". El aviso breve dejaría la cuenta en la isla dinámica con una actividad en vivo propia (ActivityKit, sin AlarmKit) y avisaría con una notificación con sonido, que solo baja el volumen de la música un instante. Costo: una segunda actividad en vivo en la extensión y su lógica de pausa y cancelación. Queda anotado; por ahora no se implementa.

## Fuentes

- Precios oficiales: <https://aistudio.google.com/docs/pricing>
- Límites y niveles oficiales: <https://aistudio.google.com/docs/rate-limits>
- Créditos de los planes de Google AI en AI Studio: <https://aistudio.google.com/learn/use-google-ai-plan-credits-in-ai-studio>
- Planes de Google AI: <https://one.google.com/about/google-ai-plans/>
- Firebase AI Logic: <https://firebase.google.com/docs/ai-logic/get-started>
- Plan de estudiante (secundaria): <https://creditforstartups.com/students/gemini-student>, <https://www.layer3labs.io/guides/gemini-pricing>
- Límites del nivel gratuito medidos por terceros: <https://imisofts.com/blog/gemini-api-free-tier-limits/>, <https://www.aifreeapi.com/en/posts/google-gemini-api-free-tier>
- Música tras alarmas y temporizadores: <https://discussions.apple.com/thread/254564997>, <https://discussions.apple.com/thread/253861674>, <https://discussions.apple.com/thread/256201717>

## 6. Implementación (16-11-2026)

### Dónde va la clave

1. Crea **`mobile/env/gemini.json`** (git lo ignora: no se sube al repositorio) con este contenido:
   ```json
   {
     "GEMINI_API_KEY": "TU_CLAVE",
     "GEMINI_MODEL": "gemini-3.5-flash-lite"
   }
   ```
2. Pega la clave de Google AI Studio en `"GEMINI_API_KEY"`. El modelo por defecto es `gemini-3.5-flash-lite`; se cambia en `"GEMINI_MODEL"`.
3. Ejecuta sumando ese archivo al de siempre:
   - `flutter run --dart-define-from-file=env/memory.json --dart-define-from-file=env/gemini.json` (demostración con Gemini real), o
   - `sh tool/install_iphone.sh`, que lo suma solo si existe.
4. En **Ajustes › Asistente de IA** debe decir "Conectado a Gemini (gemini-3.5-flash-lite)".

Sin clave: en el modo demostración el asistente responde ejemplos fijos (sirve para las capturas y las pruebas); con Firebase real, las funciones avisan que falta configurarlo y ofrecen el registro manual.

**Seguridad:** la clave queda dentro de la app compilada. Sirve para tu teléfono, no para repartir la app. Conviene restringirla en la consola de Google Cloud (*APIs y servicios › Credenciales › la clave › Restricciones de aplicaciones › Apps de iOS*) al identificador `cl.asistentedeportivo.asistenteDeportivo`: la app envía ese identificador en cada llamada. Para el MVP, la llamada pasa a Firebase AI Logic o al backend y solo cambia `GeminiAiService`.

### Las cinco funciones

| Función | Dónde | Cómo |
|---|---|---|
| Comida con foto (CU-07) | Registrar › **Con foto** | Cámara o galería (reducida a 1080 px en JPEG) → alimentos con gramos y confianza → cruce con el catálogo: si el alimento está, los macros salen del catálogo; si no, los del modelo, marcados "estimado por el asistente". Lo que tenga confianza < 70 % muestra "?" y hay que confirmarlo (o cambiar los gramos) para guardar. Se elige la comida del día y se guarda con `rawInput = "IA: foto"` |
| Tabla nutricional | Alimentos › Nuevo › botón de **etiqueta** junto al código de barras | Foto de la etiqueta → nombre, marca, porción y valores por 100 g (si solo trae la porción, se convierte). Completa solo los campos vacíos, como Open Food Facts |
| Sesión de fuerza con palabras (CU-02) | Fuerza › **Contar mi sesión** | Texto → ejercicios, series, peso (kg o lb) y repeticiones → cruce local con el catálogo (nombre en inglés y en español). Lo no reconocido se elige de la lista. Al continuar se abre como entrenamiento con todo marcado: se revisa y se guarda con "Terminar" (con su esfuerzo, para la carga) |
| Comida con palabras (CU-16) | Registrar › **Con palabras** | Primero la lista por reglas (gratis, sin red): lo que entiende con seguridad se toma del catálogo. Solo lo demás va al modelo. Misma revisión que la foto, con `rawInput = "IA: texto"` |
| Instrucciones en español | Ficha del ejercicio › Instrucciones | Se traducen la primera vez y se guardan en el teléfono (una llamada por ejercicio). "Ver original" muestra el inglés |

### Código

| Archivo | Qué hace |
|---|---|
| `lib/core/ai/prompts.dart` | Instrucciones y esquemas JSON de cada función (respuesta estructurada) |
| `lib/core/ai/ai_models.dart` | Lectura tolerante de las respuestas (comida, etiqueta, fuerza, pasos) |
| `lib/core/ai/estimate.dart` | Cruce de los alimentos con el catálogo, revisión bajo 70 %, gramos editables, reglas primero |
| `lib/core/ai/strength_import.dart` | Cruce de los ejercicios con el catálogo y armado del entrenamiento |
| `lib/data/ai/` | `AiService` (interfaz), `GeminiAiService` (HTTP a `generateContent` con `responseJsonSchema`, razonamiento mínimo, errores de cuota, clave y bloqueo) y `DemoAiService` |
| `lib/features/ai/` | Pantallas y selector de foto (`image_picker`) |

Los errores se traducen a mensajes claros (cuota agotada, sin conexión, clave inválida, contenido bloqueado) y siempre dejan la salida al registro manual.

### Pruebas

`test/core/ai_test.dart` (13): lectura de las respuestas, cruce con el catálogo (macros del catálogo, del modelo, revisión bajo 70 %, reglas primero), sesión contada en kg y lb, y el cliente con respuestas simuladas (cuerpo de la solicitud, encabezados, cuota, clave, bloqueo, reintento sin razonamiento, partes de razonamiento). `test/app_smoke_test.dart`: comida con foto hasta el diario, sesión contada eligiendo el ejercicio que falta, y etiqueta que completa el formulario. **Las llamadas reales a Gemini se prueban cuando esté la clave**: el formato sigue la referencia oficial de `generateContent`.

## 7. Explicación de la fatiga cruzada (16-11-2026)

En **Carga y fatiga cruzada** (desde Fuerza o Cardio), la tarjeta **"Lo que dice el asistente"** explica con palabras cómo va la semana: un titular, dos o tres frases, hasta tres puntos clave y una sugerencia.

- **El asistente no calcula nada.** Recibe un resumen con las cifras del motor (`fatigueBrief` en `lib/core/training/fatigue_view.dart`): días de historial, razón aguda/crónica y su zona, carga aguda y crónica total y por disciplina, la carga de cada día de las últimas dos semanas, las sesiones de la semana (tipo, minutos, RPE y si fue estimado), las próximas sesiones del plan, las alertas del motor y el déficit calórico si lo hay. No lleva nombres ni datos personales.
- **Reglas de la instrucción:** usar solo esos datos y no inventar cifras; si hay menos de 28 días, decir que la razón aún no es confiable; ir en la misma línea de las alertas del motor y nunca contradecirlas; mencionar el RPE estimado; no hablar de lesiones ni prescribir.
- **Cuota:** la explicación se guarda en el teléfono con una firma de los datos y se reutiliza mientras no cambien (una sesión nueva o una alerta nueva la renuevan). El botón ↻ la pide de nuevo.
- Esto **ajusta lo que decía la §3**: las alertas y el plan siguen siendo reglas; la IA solo las pone en palabras.
