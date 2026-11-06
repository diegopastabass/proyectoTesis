# Recordatorios, programas sugeridos y marca NutriApp

> Estado al 28-10-2026. App iOS (Flutter). Complementa [actividad-y-perfil.md](actividad-y-perfil.md).

## 1. Recordatorios (notificaciones locales)

Se configuran en **Ajustes → Notificaciones** (ruta `/notificaciones`). También se llega desde el calendario de actividad y desde la tarjeta del programa en Fuerza.

| Aviso | Cuándo suena | Al tocarlo |
|---|---|---|
| Comidas (desayuno, almuerzo, once, cena, snack; cada una con su hora) | Si esa comida aún no está registrada ese día | Registrar, con la fecha y la comida ya elegidas |
| Hoy toca entrenar | Los días de entrenamiento, si aún no hay sesión ese día. Si se sigue un programa, dice qué rutina toca | Fuerza |
| Racha en riesgo | Si hay racha y ese día aún no suma ("Tu racha de 12 días está en riesgo") | Calendario de actividad |

- **Cómo funcionan:** las notificaciones locales no pueden revisar los datos al momento de sonar. Por eso la app programa los avisos de los próximos 7 días y los vuelve a calcular cada vez que cambia algo y cada vez que vuelve a primer plano. Registrar el almuerzo quita el aviso del almuerzo de hoy, y entrenar quita el de entrenamiento. iOS admite 64 avisos pendientes; el máximo posible aquí es 49.
- **Permiso:** se pide al activar el primer recordatorio, o con **Permitir** en la pantalla. Si se negó, la pantalla lleva a Ajustes de iOS.
- **Dónde se guarda:**
  - Qué avisos y a qué hora: en el dispositivo (`SharedPreferences`).
  - Días de entrenamiento: en la cuenta (`users/{uid}.trainingPlan.weekdays`), compartidos con la pantalla de Fuerza.
- **"Activar los recordatorios sugeridos":** almuerzo 15:00, cena 21:30, entrenamiento 18:00 y racha 21:00. Si no había días elegidos, propone lunes, miércoles y viernes.
- **Código:**
  - Planificación (lógica pura, con pruebas): `lib/core/activity/reminders.dart`.
  - Servicio: `lib/platform/notifications/` (paquete `flutter_local_notifications`, zona horaria con `timezone` y `flutter_timezone`).
  - Sincronización y toques: `lib/app/notification_host.dart`.
  - En iOS, `AppDelegate.swift` asigna el delegado de `UNUserNotificationCenter`, para mostrar los avisos con la app abierta y recibir los toques.

## 2. Programas sugeridos

**Fuerza → "¿No sabes qué entrenar?"** (ruta `/fuerza/programas`) abre un cuestionario. Las sugerencias se actualizan con cada respuesta.

| Pregunta | Opciones |
|---|---|
| Días de fuerza por semana | 2 a 6 |
| Experiencia | Menos de 6 meses · 6 meses a 2 años · Más de 2 años |
| Objetivo | Fuerza · Músculo · Fuerza y músculo · Rendir en un deporte de resistencia |
| Tiempo por sesión | Hasta 45 · hasta 60 · 90 min o más |
| Equipo | Gimnasio · Mancuernas y banco · Peso corporal |
| Días de cardio y tipo | 0 a 6 o más · Correr, bicicleta, natación, mixto |

### Catálogo (`lib/core/strength/programs.dart`)

Plantillas propias, basadas en estructuras ampliamente recomendadas; no son copias de programas comerciales.

| Programa | Días | Nivel | Para |
|---|---|---|---|
| Cuerpo completo | 2 | Todos | Poco tiempo o mucho cardio |
| Fuerza para resistencia | 2 | Todos | Corredores, ciclistas y triatletas (cargas altas, una pierna, saltos) |
| Cuerpo completo (progresión lineal) | 3 | Principiante | Ganar fuerza rápido los primeros meses |
| Fuerza por niveles (estilo GZCLP) | 3 (rota 4 rutinas) | Principiante a intermedio | Seguir progresando en fuerza |
| Torso / Pierna | 4 | Principiante a intermedio | Fuerza y músculo equilibrados |
| Torso / Pierna + Empuje / Tirón / Pierna | 5 | Intermedio a avanzado | Más volumen |
| Empuje / Tirón / Pierna × 2 | 6 | Intermedio a avanzado | Músculo, con poco cardio |
| Mancuernas en casa | 3 | Principiante a intermedio | Sin gimnasio |
| Peso corporal | 3 | Principiante a intermedio | Casa o viaje (con barra de dominadas) |

### Cómo se elige

- **Equipo:** filtro duro. Un programa de gimnasio no se sugiere a quien solo tiene mancuernas.
- **Días:** solo programas con los días pedidos o uno menos, nunca más.
  - Con 4 o 5 días de cardio, máximo 3 días de fuerza.
  - Con 6 o más días de cardio, máximo 2.
  - Un principiante, máximo 4.
- **Puntaje:** suman los días exactos, el nivel, el objetivo (más si el programa es específico para ese objetivo), el tiempo por sesión, la compatibilidad con mucho cardio y el equipo exacto.
- **Resultado:** se muestran los 3 mejores, cada uno con sus razones.
- **Consejos de entrenamiento concurrente** según las respuestas:
  - Separar fuerza y cardio al menos 6 horas, o cardio primero si van el mismo día.
  - Evitar pierna pesada el día antes de la sesión clave de cardio.
  - Comer lo suficiente.

### Usar un programa

- Crea sus rutinas con series de calentamiento y rangos de repeticiones.
- Guarda `users/{uid}.trainingPlan` con:
  - `programId` y `routineIds` (orden de rotación);
  - `weekdays` (sugeridos según los días: 2 → L y J; 3 → L, X y V; 4 → L, M, J y V…);
  - `startDate`.
- En Fuerza aparece la tarjeta **Tu programa**:
  - El botón **Toca: Torso A** muestra la rutina siguiente a la última del programa que se hizo.
  - Los días del programa quedan marcados en la semana.
  - Menú con: días y recordatorios, cambiar de programa, dejar el programa. Al dejarlo, las rutinas se conservan.

## 3. Rango de repeticiones y progresión sugerida

- **Rutinas:** una serie puede tener un rango. En el editor se escribe `8-12` en REPS (`5-5` para repeticiones fijas con progresión). En Firestore se guarda como `reps` (mínimo) y `repsMax` (tope).
- **En la sesión:** cada ejercicio muestra "Objetivo: 8–12 reps por serie".
- **Doble progresión:** si la última vez todas las series efectivas llegaron al tope con peso, aparece el aviso "sube a 62,5 kg y vuelve a 8 reps" y las sugerencias de la tabla ya traen ese peso.
- **Cuánto subir:**

  | Ejercicio | Aumento |
  |---|---|
  | Básicos de pierna con barra | 5 kg |
  | Con mancuernas | 2 kg (cada una) |
  | El resto | 2,5 kg |

- **"Actualizar rutina"** al terminar una sesión conserva los rangos y actualiza solo el peso.
- **Código:** `progressionKg`, `progressionStep`, `parseRepsRange` en `lib/core/strength/session.dart`.

## 4. Marca: NutriApp

- **Nombre interno:** "NutriApp", todavía no oficial. Aparece en el ícono de la pantalla de inicio (`CFBundleDisplayName`), en el ingreso y en el título de la app.
- **Logo:** la nutria.
  - `assets/branding/logo.png`, sobre un disco oscuro, para que se vea igual en tema claro y oscuro. Lo usa `AppLogo`, en el encabezado y en el ingreso.
  - Ícono de iOS: la nutria sobre fondo `#282828` (el fondo oscuro de la app), sin transparencia, como exige Apple. Está en todos los tamaños de `AppIcon.appiconset`.
  - Pantalla de arranque: el logo sobre fondo oscuro.
  - Versión web: favicon e íconos.
- **Para cambiar el logo:**
  1. Reemplazar la imagen original.
  2. Regenerar `assets/branding/logo.png`, `AppIcon.appiconset/*.png`, `LaunchImage*.png` y `web/icons/*`.
  3. Desinstalar la app del iPhone antes de reinstalarla: iOS guarda el ícono anterior en caché.

## 5. Pruebas

- `test/core/reminders_test.dart`: qué avisos se programan según la hora, lo registrado, los días de entrenamiento y la racha; plan de entrenamiento y rutina que toca.
- `test/core/programs_test.dart`:
  - Todos los ejercicios de los programas existen en el catálogo y tienen nombre en español.
  - Sugerencias por perfil y consejos.
  - Rangos y doble progresión.
- `test/app_smoke_test.dart`:
  - Elegir un programa y ver la rutina que toca con su objetivo de repeticiones.
  - Programar recordatorios con un servicio simulado, abrir la pantalla de un aviso tocado y cancelar todo al desactivarlos.
