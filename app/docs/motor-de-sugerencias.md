# Funciones viables con Firestore y motor de sugerencias local

> Plan del 09-11-2026. **Fases 1 y 2 implementadas el mismo día** (ver §3 y §4). El prototipo sigue con **Firebase (Auth + Firestore) y la lógica en el teléfono** hasta la versión definitiva del MVP; la migración a la arquitectura de la tesis (NestJS + MongoDB) se hará entonces. Este documento no modifica la tesis (`main.tex`): ordena qué se puede construir ya y cómo armar un motor de sugerencias sin IA.

## 1. Qué se puede construir ya

La regla para decidir: si la función necesita **una clave secreta, validar un pago o actuar cuando el teléfono no está abierto**, necesita un servidor. Todo lo demás se puede hacer con Firestore, las reglas de seguridad y `core/`.

### 1.1 Viables sin servidor (de pantalla de diseño a real)

| Caso de uso | Qué falta | Notas |
|---|---|---|
| CU-26 Términos y aviso legal | Guardar `consent { termsVersion, grantedAt, dataProcessing }` en `users/{uid}` y redirigir en `router.dart` hasta aceptar | RNF-17. La versión vigente puede ser una constante en la app |
| ~~CU-12 Cuestionario y plan semanal~~ | Hecho: fase 1 del motor (§3) | — |
| ~~CU-05 Fatiga y alertas~~ | Hecho: fase 2 del motor (§4), con notificaciones locales | En el MVP el aviso pasa a FCM desde el servidor; la regla es la misma |
| CU-18 Metas del día según el entrenamiento | Metas dinámicas (§2.5) | `core/body/energy.dart` ya estima el gasto (Mifflin-St Jeor) |
| CU-19 Progreso en un solo lugar | Línea de tiempo diaria/mensual con los tres módulos | `activityProvider` ya junta los días |
| CU-20 Cómo me sentí | Campo `feeling` en la sesión de fuerza, la ruta y la entrada del diario | Hoy vive en `SimState` |
| CU-17 Cardio sin GPS | Guardar una `CardioActivity` sin ruta (disciplina, duración, distancia opcional, RPE) | Entra a la carga como cualquier ruta |
| CU-03 Sesiones del reloj | Leer entrenamientos de HealthKit (`health`: tipo, duración, distancia, energía, pulso medio) | Corre en el teléfono; la tesis también lo hace en el teléfono. Con pulso, el RPE se estima por zonas |
| CU-04 Archivo `.fit` | Leerlo **en el teléfono** con un parser en Dart y guardar el resumen + la ruta reducida (como el GPS) | Sin S3 ni Lambda en el prototipo. Hay que elegir y probar el paquete antes de comprometerse |
| CU-08 Receta ajustada a mis metas | Escalar las porciones a lo que falta del día (RNF-06: un solo factor para todos los ingredientes) | Matemática pura; sirve con recetas propias aunque no exista la comunidad |
| CU-21 Mis datos | Exportar a JSON (ya está `share_plus`) y borrar la cuenta (borrado de `users/{uid}/**` desde el cliente + `user.delete()`) | Aceptable para el prototipo; en el MVP lo hace el servidor |
| CU-02 Fuerza con mis palabras | Parser **por reglas** ("sentadilla 3x10 80 kg") como el de comidas, sin IA | Mismo enfoque que el prototipo P1 de nutrición |
| Comidas frecuentes | Plantillas de comida (requisito específico de nutrición) | `core/nutrition/copy.dart` ya repite comidas |

### 1.2 Viables con cuidado (reglas de Firestore)

| Caso de uso | Cómo | Límite |
|---|---|---|
| CU-09, 13, 14, 22, 23 Red social básica (sin fotos) | `posts/{id}` con `authorId` y `visibility`, `follows/{seguidor_seguido}`, `reports/{id}`. Las reglas validan al autor y, para `followers`, que exista el documento de seguimiento | El muro con `authorId in [...]` acepta hasta 30 ids por consulta (se divide en varias). La tesis deja las fotos fuera del prototipo (cap. 4), así que no hace falta Storage |
| CU-10, 11 Panel de administración | Conectar `src/admin` a Firestore. Rol en un documento `admins/{uid}` que las reglas consultan | Sin servidor no queda un registro de moderación a prueba de manipulación |

### 1.3 Necesitan servidor (se quedan simuladas)

- **CU-07 y CU-16 con IA (Gemini):** la clave no puede ir en la app. Si más adelante se quiere probar la IA sin backend propio, Firebase AI Logic llama a Gemini desde el cliente sin exponer la clave (con App Check); es una decisión aparte.
- **CU-24 y 25 Premium:** validar la compra con la tienda y recibir sus avisos exige un servidor.
- **Alertas enviadas cuando la app está cerrada:** las notificaciones locales solo se programan con la app abierta. Basta para el prototipo, porque la alerta se recalcula al abrirla.

### 1.4 Funciones prácticas para el usuario (en la línea de kg/lb)

| Función | Valor | Esfuerzo |
|---|---|---|
| ~~Kilos y libras por máquina, aviso al terminar, calculadora de discos~~ | Hecho (09-11-2026, ver [modulo-fuerza.md](modulo-fuerza.md) §2.2.1) | — |
| **Nota por ejercicio que se recuerda** ("asiento en 4, agarre ancho") | Complementa la unidad por máquina: la próxima vez aparece sola | Bajo: campo `note` en el ejercicio de la sesión |
| **Series de calentamiento sugeridas** (barra → 40/60/80 % del peso de trabajo) | Ahorra pensar en cada ejercicio con barra; usa la calculadora de discos | Bajo |
| **Tabla de porcentajes del 1RM** en la ficha del ejercicio | Para programas por porcentaje | Bajo (ya existe el 1RM estimado) |
| **Ritmo y predicción de tiempos** (fórmula de Riegel) en cardio | "Si corres 5 km en 25 min, 10 km ≈ 52 min" | Bajo |
| **Unidad de distancia km/mi** en cardio | El motor de unidades ya tiene las conversiones (`core/common/units.dart`) | Bajo |
| **Registro rápido de calorías y macros** sin buscar alimento | Para comidas fuera de casa | Bajo |
| **Superseries** | Muy pedida en apps de fuerza | Medio (cambia la sesión y el descanso) |

## 2. Motor de sugerencias local

### 2.1 Por qué sin IA

Las decisiones que pide la tesis (R03, R05, R13, RNF-03, RNF-06, RNF-14) son **reglas con respaldo bibliográfico y umbrales conocidos**: clasificar el nivel, elegir una plantilla, comparar la carga aguda con la crónica, revisar horas entre sesiones y ajustar los macros por kg de peso. Un modelo de lenguaje no agrega precisión a esas reglas y sí agrega costo, latencia, dependencia de la red y respuestas difíciles de explicar o probar. Las reglas, en cambio:

- dan siempre el mismo resultado con los mismos datos, y se pueden probar con casos de valor conocido (la Tabla de validación pide, por ejemplo, 60 min con RPE 7 = 420 UA);
- se pueden explicar ("te lo sugerimos porque tu carga de la semana es 1,4 veces lo habitual");
- funcionan sin conexión, igual que el resto de la lógica de `core/`;
- se pueden trasladar al backend del MVP sin cambios de criterio (es la misma lógica que la tesis ubica en el motor de fatiga y planificación).

La IA queda para lo que de verdad la necesita: entender fotos y texto libre.

### 2.2 Arquitectura

```
core/suggestions/            lógica pura (sin Flutter ni Firebase), probada con flutter test
  profile.dart               perfil declarado + observado → nivel y orientación
  weekly_plan.dart           plantillas por nivel × orientación → semana de fuerza y cardio
  alerts.dart                reglas de fatiga cruzada e interferencia
  nutrition_targets.dart     metas del día según el entrenamiento y horario de comidas
  weekly_review.dart         ajuste semanal (adherencia, RPE medio, razón ATL/CTL)
  suggestion.dart            tipo común Suggestion
app/suggestion_providers.dart   arma el contexto desde los proveedores existentes
features/…                     muestran las sugerencias (inicio, carga, metas, plan)
```

Un solo punto de entrada, sin estado:

```dart
List<Suggestion> suggest(SuggestionContext ctx);

class Suggestion {
  final String id;            // estable, para no repetir una sugerencia descartada
  final SuggestionKind kind;  // alerta de fatiga, separación, comida, plan, meta…
  final Severity severity;    // info, aviso, importante
  final String title, text;
  final List<Reason> why;     // cada razón con el dato que la disparó y su fuente
  final SuggestionAction? action; // aplicar el cambio al plan, ir a la pantalla…
}
```

`SuggestionContext` se arma con lo que ya existe en Riverpod: perfil corporal, pesos, sesiones de fuerza, rutas de cardio, diario, plan de entrenamiento y la serie de carga (`core/training/load.dart`). Las sugerencias aceptadas o descartadas se guardan en `users/{uid}/suggestions/{id}` y cada ajuste del plan en `users/{uid}/planChanges/{id}` con su razón (RNF-14: "para que el usuario pueda ver por qué cambió").

### 2.3 Perfil y plan semanal (R13, RNF-14)

**Cuestionario (máx. 10 preguntas):** experiencia, objetivo, días disponibles, minutos por sesión, equipamiento, disciplinas de cardio y días de cardio, edad, sexo, estatura y peso. `ProgramAnswers` ya cubre 7 de ellas.

**Clasificación:**

| Eje | Regla inicial |
|---|---|
| Nivel | Declarado (< 6 meses, 6 meses–2 años, > 2 años) y corregido con lo observado: con 8 semanas de registro, la constancia y la carga crónica pueden subirlo o bajarlo un nivel |
| Orientación | Fuerza si los días de cardio ≤ 1 y el objetivo es fuerza o músculo; resistencia si los días de cardio ≥ los de fuerza o el objetivo es rendir en su deporte; si no, equilibrada |

**Plantillas (3 niveles × 3 orientaciones = 9):** cada una define cuántos días de fuerza (tomados de `programs.dart`), cuántas sesiones de cardio y de qué tipo (suave/larga/intervalos) y cuántos minutos. Reglas para ubicarlas en la semana, del entrenamiento concurrente:

- separar fuerza y cardio al menos 6 h (mejor 6–8 h) o hacerlos en días distintos (`fisiologiadelejercicio`, `aptavs2025concurrente`);
- no poner pierna pesada el día antes de la sesión larga de cardio ni justo después de los intervalos;
- cada músculo al menos 2 veces por semana (ya aplicado en `programs.dart`);
- con mucho cardio, menos días y menos volumen de pierna en fuerza.

### 2.4 Alertas de fatiga e interferencia (R03, RNF-03)

| Regla | Disparo | Fuente |
|---|---|---|
| Fatiga cruzada | Razón ATL/CTL total > 1,3 (configurable) **y** el plan tiene una sesión de la otra disciplina en las próximas 24 h. Solo con ≥ 28 días de historial | `gabbett2016training`, `williams2017better`; señal de apoyo según `impellizzeri2020acute` |
| Poca separación | Una sesión de fuerza y una de cardio con < 6 h entre el fin de una y el inicio de la otra | Tabla de definiciones operativas (cap. 3) |
| Patrón repetido | Fuerza → cardio (o al revés) con poca separación en 2 o más días seguidos → sugerir reordenar la semana | R03 |
| Déficit sostenido | La ingesta de los últimos 7 días está más de un 20 % (umbral a ajustar) bajo el gasto estimado → se menciona como factor que retrasa la recuperación | R03; gasto de `energy.dart` |
| RPE estimado | Si las sesiones de la ventana tienen RPE estimado, la alerta lo dice y baja su severidad | RNF-03 (indicador de confianza) |

Qué hace falta en los datos: la **hora** de las comidas (hoy solo hay fecha y momento del día; `createdAt` es la hora en que se anotó) y las **sesiones planificadas de cardio** dentro del plan.

### 2.5 Metas del día y horario de comidas (R05, RNF-06)

- **Calorías:** gasto en reposo (Mifflin-St Jeor, `mifflin1990new`) × factor de actividad sin entrenamiento + energía de las sesiones del día (MET × peso × horas, como ya hace cardio) en vez de un factor fijo semanal.
- **Proteína:** 1,6–2,2 g/kg (ya se usa en `energy.dart`, con la recomendación de la ISSN).
- **Carbohidratos según la carga del día:** rangos por g/kg crecientes con la duración e intensidad del cardio (día de descanso o solo fuerza, cardio moderado de ~1 h, sesiones largas). Los valores exactos deben salir de una posición de consenso de nutrición deportiva (ACSM/ISSN) que **todavía no está en la bibliografía de la tesis**: agregarla antes de usar los números.
- **Grasa:** el resto, sin bajar del 20 % de las calorías.
- **Horario:** carbohidratos 2–3 h antes del cardio y proteína dentro de las 2 h después de la fuerza (cap. 5). Se muestra como sugerencia, nunca como prescripción (DFL 725, Ley 20.584).

### 2.6 Ajuste semanal (RNF-14)

Cada lunes (o al abrir la app la primera vez en la semana) se revisa la semana anterior:

| Condición | Sugerencia |
|---|---|
| Adherencia < 60 % de las sesiones sugeridas | Bajar una sesión o acortar las sesiones |
| RPE medio ≥ 8,5, o razón ATL/CTL > 1,3 | Semana de descarga: −20 a −30 % del volumen |
| Adherencia ≥ 90 %, RPE medio ≤ 7 y razón 0,8–1,3 durante 2 semanas | Subir un poco: +1 serie por músculo o +10 % de minutos de cardio |
| Lo demás | Mantener |

La sugerencia nunca cambia el plan sola: el usuario la acepta o la ignora, y el cambio queda registrado con su razón.

### 2.7 Fases sugeridas

1. ~~**Perfil y plan:** cuestionario real (reemplaza la pantalla de diseño), clasificación y plan semanal con fuerza y cardio. Hace real CU-12.~~ Hecho (§3).
2. ~~**Alertas:** reglas de §2.4, la hora de las comidas y las notificaciones locales. Hace real CU-05.~~ Hecho (§4); la hora de las comidas pasa a la fase 3, que es donde la usan las reglas de horario.
3. **Metas dinámicas:** §2.5 en la pantalla de metas del día. Hace real CU-18.
4. **Ajuste semanal:** §2.6 con el historial de cambios.
5. **Recetas ajustadas:** escalar recetas propias a lo que falta del día (CU-08).

Cada fase termina con pruebas de valor conocido en `test/core/`, que sirven además como evidencia para el objetivo 5 de la tesis (cálculo de la carga, alerta con datos de los tres módulos, metas según el entrenamiento).

## 3. Fase 1 implementada: perfil y plan semanal (09-11-2026)

### Qué hace

- **Cuestionario** (`/bienvenida/cuestionario`, 3 pasos, 10 preguntas): experiencia, objetivo (fuerza, músculo, **fuerza y resistencia por igual**, rendir en su deporte o bajar de peso), días por semana sumando fuerza y cardio (2 a 7), minutos por sesión, equipamiento, deportes de resistencia (running, ciclismo, trekking o ninguno), edad, estatura, peso y sexo. Parte con lo que ya se sabe: el cuestionario anterior, el perfil corporal y el último peso.
- **Se guarda** en `users/{uid}.athlete`. La edad, la estatura y el sexo van al perfil corporal (`body`) y el peso al registro de peso, donde ya los usa el gasto calórico. Si la edad no calza con la fecha de nacimiento guardada, se aproxima (se corrige en Ajustes › Perfil corporal).
- **Plan semanal** (`/bienvenida/plan`): nivel y orientación, una fila por día con sus sesiones (fuerza con su rutina; cardio con disciplina, intensidad y minutos), la carga planificada en UA y **"¿Por qué este plan?"**, con cada razón y su fuente.
- **Aceptar** guarda el plan en `users/{uid}.weeklyPlan`, deja el programa de fuerza con los días de fuerza del plan (recordatorios y "Toca: …" de siempre) y crea sus rutinas. Si ya se sigue ese programa, reutiliza las rutinas en vez de duplicarlas.
- **Fuerza** muestra "Hoy en tu plan" (o lo próximo si hoy es descanso) y marca en la semana también los días de cardio. **Ajustes** tiene "Mi plan semanal".
- Funciona igual con Firebase real: estas rutas ya no son pantallas de diseño (solo los términos siguen siéndolo).

### Cómo decide (`lib/core/suggestions/`)

| Archivo | Qué hace |
|---|---|
| `profile.dart` | `AthleteProfile` (respuestas) y `classify()`: nivel = experiencia declarada; orientación: sin deportes de resistencia → fuerza; objetivo fuerza o músculo → fuerza (cardio de complemento: 1 o 2 sesiones); rendir en su deporte → resistencia (2 de fuerza, o 1 con 2 días); híbrido o bajar de peso → equilibrada (la mitad de los días para fuerza, entre 2 y 4) |
| `weekly_plan.dart` | `buildWeeklyPlan()`: elige el programa de fuerza (`recommendPrograms`, prefiriendo uno de gimnasio si casi empata), arma el cardio y busca la mejor semana |
| `reason.dart` | `Reason` (texto + fuente) y `Sources` (claves de `bibliografia/fonts.bib`) |

**Cardio:** casi todo suave; los principiantes no hacen intervalos; con 2 o más sesiones hay una larga y, desde intermedio, una de intervalos. La larga usa trekking, ciclismo o running (en ese orden, según lo que practique), y los intervalos, running o ciclismo. Duraciones: suave = el tiempo por sesión (30 a 60 min; 40 si recién empieza), intervalos = 45 min, larga según disciplina y nivel (running 50/75/90, ciclismo 90/120/150, trekking 120/180/240 min) sin pasar del doble del tiempo por sesión. RPE planificado: suave 3, larga 4, intervalos 7, fuerza 6 (principiante) o 7.

**Ubicación en la semana:** se prueban todas las semanas posibles (días de fuerza, con qué rutina parte la rotación y días de cada sesión de cardio, sin pasar de los días disponibles) y se queda la que suma menos penalizaciones:

| Regla | Penalización |
|---|---|
| Pierna pesada el día antes de la sesión larga o de intervalos | 6 |
| Pierna pesada el mismo día que la larga o los intervalos | 5 |
| Fuerza y cardio el mismo día (se permite, separados 6 h) | 4 |
| Pierna pesada dos días seguidos | 3 |
| Intervalos pegados a la sesión larga | 3 |
| Pierna pesada el día después de los intervalos | 2 |
| Sesión larga fuera del fin de semana | 2 |
| Cada día seguido entrenando después del tercero (del segundo si recién empieza) | 1 |

Una rutina es "pesada de pierna" si al menos un tercio de sus series efectivas son de pierna (sentadillas, pesos muertos, prensa, zancadas, curl y extensión de pierna, gemelos, hip thrust, saltos). La semana se trata como circular (el domingo sigue al lunes). Si una regla no se puede cumplir con los días disponibles, la razón lo dice ("si llegas cansado, baja la carga de las piernas ese día").

### Pruebas

`test/core/suggestions_test.dart` (16 pruebas): clasificación por orientación, intensidades del cardio, rutinas con pierna, el plan del perfil de ejemplo (sin pierna antes de lo exigente, larga el fin de semana), determinismo, guardado, y **240 perfiles combinados** (objetivo × días × deportes × nivel × equipo) que deben cumplir siempre: sesiones de cada tipo según la clasificación, no más días que los disponibles, a lo más una sesión de cada tipo por día, a lo más una de intervalos y una larga, sin intervalos para principiantes y carga planificada correcta. `test/app_smoke_test.dart` recorre el cuestionario, acepta el plan y revisa que no se dupliquen las rutinas.

### Límites y lo que sigue

- El nivel es el declarado: corregirlo con lo observado (constancia, carga crónica) es parte del ajuste semanal (fase 4).
- La regla "casi todo suave" es una decisión de diseño; si se quiere respaldar con la distribución polarizada de la intensidad, hay que agregar esa fuente a la bibliografía.
- El plan no se puede editar día por día todavía: se cambian las respuestas o el programa de fuerza.
- La rotación de rutinas sigue a la última sesión hecha (`nextRoutineId`), no al día de la semana: si se salta una sesión, la rutina de ese día puede cambiar.
- El plan guardado (`weeklyPlan`) ya tiene lo que necesita la fase 2: qué sesión de cada disciplina hay en las próximas 24 horas.

## 4. Fase 2 implementada: alertas de fatiga (09-11-2026)

### Qué hace

- **Fuerza** muestra arriba la alerta más importante, y la entrada **"Carga de entrenamiento"** (ya no es pantalla de diseño) lleva un contador de alertas.
- **Carga de entrenamiento** (`/carga`): la carga real de fuerza y cardio, las alertas vigentes y **"Avisar desde"**, el umbral configurable (1,2 · **1,3 sugerido** · 1,4 · 1,5), que se guarda en el teléfono.
- **Detalle de la alerta** (`/carga/alerta/{id}`): cómo se vería la notificación, qué pasó, **qué te sugerimos** y **qué notamos**, cada razón con su fuente. Con una sesión del plan de por medio se responde **"Seguir la sugerencia"** o **"Mantener mi plan"**; si no, **"Entendido"**. La respuesta se guarda en `users/{uid}/suggestions/{id}` (tipo, respuesta, fecha y título): la alerta no vuelve a aparecer y queda el registro de qué se sugirió y qué se decidió (RNF-14).
- **`/carga/alerta`** sin id muestra una **alerta de ejemplo** calculada por el motor con datos simulados (`core/suggestions/examples.dart`), marcada como ejemplo: sirve para conocerla y para las capturas del documento.
- **Aviso en el teléfono:** las alertas de fatiga cruzada sin responder se programan como notificación local el día de la sesión, 2 horas antes de la hora de entrenar de los recordatorios (no antes de las 8:00). Vienen activadas y se apagan en Ajustes › Notificaciones › "Alertas de fatiga". Se recalculan al registrar algo y al volver a abrir la app.

### Reglas (`lib/core/suggestions/alerts.dart`)

| Alerta | Cuándo | Gravedad | Sugerencia |
|---|---|---|---|
| **Fatiga cruzada** | Razón ATL/CTL total sobre el umbral, al menos 28 días de historial y una sesión de la **otra** disciplina en las próximas 24 horas (lo que queda de hoy, si aún no se hizo, y mañana) según el plan aceptado. "La otra" es la contraria a la que más carga aguda tiene | Importante | Fuerza: bajar 10–20 % el peso o una serie por ejercicio, o moverla un día. Intervalos: cambiarlos por una sesión suave. Larga: acortarla 20–30 % y mantener un ritmo cómodo |
| **Aumento brusco** | Razón sobre el umbral, sin sesión de la otra disciplina cerca (o sin plan) | Aviso | Dejar la próxima sesión exigente para cuando se sienta recuperado |
| **Poca separación** | Fuerza y cardio con menos de 6 h entre el fin de una y el inicio de la otra (también si se superponen), en los últimos 3 días | Aviso | Separarlas 6 h o hacerlas en días distintos; si van juntas, primero la prioridad |
| **Patrón repetido** | Poca separación en 2 o más días seguidos de la última semana (reemplaza al aviso anterior) | Aviso | Reorganizar la semana |
| **Comer poco** | Ingesta media de los últimos 7 días (al menos 4 días anotados, sin contar hoy ni los días anotados a medias) más de un 20 % bajo el gasto estimado (con los registros o con Mifflin-St Jeor). Si hay fatiga cruzada, se suma como razón en vez de aparecer aparte (R03) | Informativa | Sumar una colación o una porción en los días de entrenamiento |

Si más de la mitad de las sesiones de la última semana tienen el RPE estimado, las alertas de carga bajan un nivel y lo dicen (RNF-03, indicador de confianza). Cada alerta tiene un id estable mientras la situación sea la misma (por ejemplo `fatiga-2026-11-10-strength`), para no repetir una ya respondida.

### Ejemplo de valor conocido

`exampleAlertContext()`: seis semanas de ciclismo de 60 min (RPE 4) día por medio y fuerza martes y viernes (60 min, RPE 6), y una última semana con 150, 90, 120 y 90 min de bici (RPE 6–7). La razón queda en 2,00, la fatiga viene del cardio, mañana el plan tiene pierna, y la alerta dice: *"Vienes con harta carga y mañana toca fuerza (Pierna A)"* con la sugerencia de bajar 10–20 % el peso. Es el caso que pide la tesis para el objetivo 5 (alerta generada con datos simulados).

### Pruebas

`test/core/alerts_test.dart` (17 pruebas): la alerta del ejemplo con su id y sus fuentes, el umbral configurable, el paso a "aumento brusco" sin sesión contraria o fuera de las 24 horas, la sesión de hoy si aún no se hizo, sin alerta con menos de 28 días, la baja de gravedad con RPE estimado, la separación (2 h, 6 h o más, hace más de 3 días, cardio primero, superpuestas), el patrón de días seguidos, el déficit (umbral, pocos días, sin gasto) y su suma a la fatiga cruzada, la hora del aviso y el guardado de la respuesta. `test/app_smoke_test.dart` registra una sesión de fuerza y una ruta con 2 h entre ellas, abre el aviso desde Fuerza, lo responde y comprueba que no vuelve a aparecer.

### Límites y lo que sigue

- "Seguir la sugerencia" queda registrado, pero todavía no ajusta solo los pesos de la sesión: mostrar el ajuste al empezar esa rutina es un buen siguiente paso.
- Las notificaciones locales solo se programan con la app abierta; con la app cerrada por días, la alerta se ve al volver a abrirla. En el MVP las enviaría el servidor con FCM.
- La hora de las comidas (para "carbohidratos 2–3 h antes del cardio" y "proteína dentro de 2 h después de la fuerza") se agrega en la fase 3, junto a las metas del día.
- El umbral del déficit (20 %) y los porcentajes de las sugerencias son decisiones de diseño a ajustar con las evaluaciones del prototipo.
