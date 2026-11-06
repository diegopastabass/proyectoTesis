# Módulo de fuerza

> Estado al 23-10-2026. Primera versión funcional del módulo: rutinas, registro de sesiones, historial y progreso.

## 1. Base de datos de ejercicios: investigación

**Pregunta:** ¿existe una base de ejercicios con animaciones que podamos usar, o hay que crearlas desde cero?

**Respuesta:** no hace falta crearlas. Se usa **free-exercise-db** (dominio público), que trae dos fotos por ejercicio (posición inicial y final) con el mismo encuadre; alternándolas con un fundido se obtiene una animación simple. Las bases con GIF de verdad tienen licencias que no sirven para guardar ni redistribuir el contenido.

| Opción | Contenido | Licencia | Veredicto |
|---|---|---|---|
| [free-exercise-db](https://github.com/yuhonas/free-exercise-db) | 876 ejercicios en JSON (músculos, equipo, nivel, instrucciones en inglés) y 2 fotos por ejercicio (873 de 876) | Unlicense (dominio público) | **Elegida.** Se puede incluir en la app, modificar y publicar sin pedir permiso |
| [ExerciseDB / AscendAPI](https://github.com/exercisedb/exercisedb-api) | 1.500 ejercicios con GIF en la versión gratuita (11.000+ en la de pago) | Código AGPL; el contenido es propiedad de AscendAPI. Sus [términos de uso](https://exercisedb.notion.site/ExerciseDB-API-Terms-of-Use-226983b728ca8090bf7be79564e4b356) dan una licencia revocable y prohíben guardar los datos o GIF | Descartada: depender de su API y no poder guardar nada es un riesgo para el proyecto |
| [wger](https://wger.readthedocs.io/) | ~930 ejercicios con traducciones (incluido español), pocas imágenes y algunos videos | Datos Creative Commons (CC-BY-SA) con autor y licencia por registro | Alternativa futura para **nombres en español**; exige atribución y compartir igual |
| Crear las animaciones | Ilustraciones o videos propios | Propia | Costoso; solo tiene sentido para un grupo pequeño de ejercicios clave más adelante |

### Cómo se integró

- `scripts/build-exercises.mjs` descarga el catálogo desde un **commit fijo** (`f00c92c…`), deja solo los campos útiles y omite estiramientos y cardio: **739 ejercicios** en `src/data/exercises.json` (165 KB, 15 KB comprimido). Se carga aparte, solo al entrar al módulo.
- **Imágenes:** se sirven desde jsDelivr (CDN de GitHub) apuntando al mismo commit, así no cambian solas. Cada foto pesa ~70 KB. Si se publica la app, conviene copiarlas a Firebase Hosting o reducirlas.
- **Instrucciones:** están en inglés y se piden al CDN solo cuando el usuario toca "Instrucciones".
- **Español:** `src/data/exercisesEs.ts` traduce los nombres de 106 ejercicios comunes (press de banca, sentadilla, peso muerto, jalón al pecho, remo…) y agrega alias ("pec deck", "estocadas", "press francés"). Los demás aparecen en inglés. Músculos, equipo y grupos están traducidos.
- **Ejercicios propios:** el usuario puede crear los suyos (nombre, músculo principal y equipo). Son privados y no tienen imagen.

---

## 2. Qué hace el módulo

| Capacidad | Pantalla | Ruta |
|---|---|---|
| Ver la semana, la racha y las rutinas; empezar una rutina o un entrenamiento libre | Entrenar | `/fuerza` |
| Crear y editar rutinas con ejercicios y series | Rutina | `/fuerza/rutinas/:id` |
| Registrar la sesión en curso (tabla SERIE · ANTERIOR · KG · REPS · ✓) | Sesión | `/fuerza/entrenar` |
| Ver los entrenamientos por mes | Historial | `/fuerza/historial` |
| Resumen de una sesión: peso total, comparación y avances | Detalle | `/fuerza/historial/:id` |
| Mapa de calor, curva de peso total por rutina y progreso por ejercicio | Progreso | `/fuerza/progreso` |
| Catálogo con búsqueda y filtros; ficha con animación, curva e historial | Ejercicios | `/fuerza/ejercicios`, `/fuerza/ejercicios/:id` |

### 2.1 Rutinas (plantillas)

- Una rutina tiene un **nombre libre** ("Rutina de pecho", "Pierna A") y una lista de ejercicios, cada uno con sus series: `[ejercicio: {serie 1: {reps, kg}, serie 2: …}, …]`.
- Cada serie es de un **tipo**. Las opciones de la serie (tipo, agregar drop set, quitar) están en un solo lugar: el botón `⋯` al final de la fila o tocando su etiqueta. Así cada fila queda limpia.

  | Etiqueta | Tipo | ¿Cuenta como efectiva? |
  |---|---|---|
  | `C` (amarillo) | Calentamiento | No |
  | `1`, `2`, `3`… | Efectiva | Sí |
  | `F` (rojo) | Al fallo | Sí |
  | `↳D` | Drop set: bajar el peso y seguir sin descansar | Suma volumen, pero es parte de la serie anterior (no suma una serie más) |

- **Agregar drop set** inserta la bajada justo después de la serie (y de sus drops), con ~20 % menos peso como sugerencia (redondeado a 2,5 kg).
- Cada ejercicio tiene su **descanso entre series** (por defecto 1:30; se puede desactivar). Se ve y cambia en el botón ⏱ bajo el nombre del ejercicio. Al agregar un ejercicio se propone el descanso de la última vez.

- Los kilos y repeticiones de la rutina son opcionales (sirven de objetivo).
- Al agregar un ejercicio que ya hiciste, se copia la estructura de series de la última vez; si no, se crean 3 series.
- Los ejercicios se reordenan con flechas y se quitan con la papelera.
- **Guardar y empezar** lleva directo a la sesión.

### 2.2 Sesión en curso

- Se empieza desde una rutina (se precarga) o **libre** (vacía).
- La tabla es como la de la imagen de referencia: **SERIE · ANTERIOR · KG · REPS · ✓**.
  - **ANTERIOR** muestra lo que hiciste en esa misma serie la última vez que hiciste el ejercicio (calentamientos con calentamientos, drops con drops y efectivas con efectivas). Tocarla copia esos valores.
  - Los campos vacíos muestran como sugerencia lo de la última vez o, si no hay registro, lo de la rutina.
  - **✓** marca la serie como hecha (fila verde). Si los campos están vacíos, se completan con la sugerencia; sin repeticiones no se puede marcar.
- **Descanso:** al marcar una serie empieza la cuenta regresiva del descanso del ejercicio, en una barra flotante con −15 / +15 s y **Saltar**. Al terminar vibra y llega un aviso (sirve con el teléfono bloqueado; el permiso de notificaciones se pide la primera vez). Entre una serie y su drop set no hay descanso. La cuenta también se ve en el botón flotante desde otras pantallas.
- Se pueden agregar o quitar series y ejercicios, cambiar el nombre de la sesión y ver cómo se hace cada ejercicio (animación).
- Arriba se ven el **cronómetro**, el **peso total** acumulado y las series hechas.
- La sesión se guarda en el dispositivo mientras dura: **sobrevive a recargar o cerrar la pestaña**. Desde otras pantallas del módulo aparece un botón flotante para volver a ella.
- **Terminar** (arriba y al final de la lista, donde se llega tras la última serie) guarda solo las series marcadas (avisa si quedan sin marcar). **Descartar** pide confirmación.

### 2.3 Al terminar: resumen y avances

- **Peso total levantado** de la sesión: suma de kg × repeticiones de todas las series efectivas (el calentamiento no cuenta, para no inflar el número). Se compara con la última vez que hiciste la misma rutina (+/− %).
- Series, repeticiones y duración.
- **Tus avances**: mensajes de motivación calculados comparando solo con sesiones anteriores. Se muestran hasta 6, ordenados por relevancia:

  | Tipo | Ejemplo |
  |---|---|
  | Récord de peso | "Nuevo récord en Press de banca con barra: 57,5 kg × 8." |
  | Subida de peso | "Subiste el peso en Sentadilla: 80 kg (antes 77,5 kg)." |
  | Más repeticiones | "Más repeticiones en Curl con 12 kg: 10 (antes 8)." |
  | Mejor 1RM estimado | "Mejor 1RM estimado en Remo con barra: 72,5 kg." |
  | Más series | "Hoy hiciste 2 series más de Aperturas que la última vez (la semana pasada)." |
  | Más volumen | "Volumen total 8 % mayor que la última vez que hiciste Rutina de pecho." |
  | Constancia | "Llevas 4 semanas seguidas entrenando." / "Ya llevas 3 entrenamientos esta semana, más que en toda la semana pasada (2)." |
  | Hitos | "¡Completaste tu entrenamiento número 25!" |
  | Novedades | "Primera vez registrando Hip thrust con barra." |

  Solo se destacan avances: lo que bajó se ve en el resumen, sin mensajes negativos.
- **Actualizar rutina:** si la sesión vino de una rutina, un botón reemplaza la plantilla con los ejercicios, series y pesos de hoy.

### 2.4 Progreso

1. **Peso total por sesión:** curva del volumen de cada sesión, filtrable por rutina (por defecto la más frecuente; también "Todas"). Tocar un punto abre esa sesión.
2. **Curva por ejercicio** (ficha del ejercicio), con cuatro métricas: **1RM estimado** (fórmula de Epley: kg × (1 + reps/30)), **peso máximo**, **volumen** y **repeticiones máximas** (la única en ejercicios sin peso). Incluye mejores marcas e historial.
3. **Mapa de calor tipo calendario** (semanas de lunes a domingo) que muestra qué días entrenaste: gris sin entrenar, verde claro 1 sesión, verde 2 o más. Se adapta al ancho (≈ 4 meses en el teléfono, ~9 en escritorio). Tocar un día abre esa sesión.
4. **Indicadores:** días entrenados este mes, racha de semanas seguidas (la semana actual no corta la racha si aún no entrenas) y total de sesiones.
5. En la lista de ejercicios: sesiones, mejor serie y cambio del 1RM estimado desde la primera vez.

---

## 3. Datos

| Ruta de Firestore | Contenido |
|---|---|
| `users/{uid}/routines/{id}` | `name`, `exercises: [{ exerciseId, sets: [{ type, kg, reps }] }]` |
| `users/{uid}/workouts/{id}` | `routineId` (o null), `name`, `date` (AAAA-MM-DD), `startedAt`, `finishedAt`, `exercises: [{ exerciseId, name, sets }]` |
| `users/{uid}/exercises/{id}` | Ejercicios propios: `name`, `primary`, `equipment` (su id en la app es `u:{id}`) |

- Todo es privado: lo cubre la regla existente de `users/{uid}/**` (no hubo que publicar reglas nuevas). Aún no se validan los campos de estas colecciones.
- Cada sesión guarda una copia del nombre del ejercicio, por si después se borra.
- La sesión en curso vive en `localStorage` (`fuerza-activa:{uid}`), no en Firestore.

## 4. Código

| Carpeta | Contenido |
|---|---|
| `src/core/strength/` | Lógica pura y probada: volumen y 1RM (`stats.ts`), sesión en curso (`session.ts`), calendario y rachas (`calendar.ts`), mensajes (`insights.ts`), catálogo y búsqueda (`catalog.ts`) |
| `src/services/strength.ts` | Firestore: rutinas, sesiones y ejercicios propios |
| `src/features/strength/` | Pantallas y componentes del módulo |
| `src/ui/TrendChart.tsx` | Gráfica de línea compartida (también la usa el peso corporal de Nutrición) |

Pruebas: `src/core/__tests__/strength.test.ts` (17 pruebas).

## 5. Límites y pendientes

- Nombres en español solo para 106 ejercicios; las instrucciones están en inglés (wger podría aportar traducciones).
- Las imágenes dependen de jsDelivr; para producción conviene alojarlas en Firebase Hosting.
- Sin temporizador de descanso, notas por ejercicio, superseries ni conversión a libras.
- Desde el 28-10-2026 hay programas sugeridos, rangos de repeticiones y progresión sugerida en la app iOS ([recordatorios-y-programas.md](recordatorios-y-programas.md)).
- Los ejercicios con peso corporal suman 0 kg al volumen (se siguen por repeticiones).
- Una sesión no se puede editar después de guardarla (solo eliminar).
- Sin cruce todavía con nutrición ni cardio.
