# Módulo de cardio (primera versión)

> Estado al 28-10-2026. App iOS (Flutter). Rutas de running, ciclismo y trekking con el GPS del teléfono. Los wearables (Apple Watch vía HealthKit) quedan para una versión siguiente.

## 1. Qué hace

| Pantalla | Ruta | Para qué |
|---|---|---|
| Grabar | `/cardio` | Elegir disciplina y tocar el botón central **Iniciar** |
| Grabación | `/cardio/grabar` (pantalla completa) | Tiempo, métricas de la disciplina y mapa en vivo; pausar, reanudar y terminar |
| Guardar | `/cardio/guardar` | Título, descripción y disciplina; guardar, seguir grabando o descartar |
| Historial | `/cardio/historial` | Resumen de la semana y actividades con miniatura de la ruta y estado del respaldo |
| Detalle | `/cardio/historial/:id` | Mapa, métricas, perfil de altura y parciales por kilómetro; editar, cambiar disciplina, eliminar |
| Imagen para historias | `/cardio/historial/:id/exportar` | PNG de 1080 × 1920 con la ruta en verde y las métricas; se comparte con el menú de iOS |

### Fricción mínima al empezar

- **Un toque para empezar:** el botón **Iniciar** graba de inmediato. Si es la primera vez, iOS pide el permiso de ubicación en ese mismo toque.
- **Sin selección extra:** la disciplina queda preseleccionada (la última usada), sin cuenta regresiva ni formularios.
- **GPS precalentado:** mientras está abierta la pantalla Grabar, el GPS ya busca señal y muestra la precisión ("GPS listo · ±5 m"), así el primer punto llega enseguida. Solo funciona con la app a la vista: al salir de la app (sin grabar) se apaga, para no gastar batería ni dejar el indicador de ubicación activo.
- **Teléfono bloqueado:** la grabación sigue con la pantalla apagada (modo de fondo `location`, con el indicador azul de iOS) y se puede minimizar para usar el resto de la app.
- **App cerrada:** la grabación se escribe en el teléfono cada 10 segundos y en cada pausa. Si iOS cierra la app, al abrirla la grabación sigue con un tramo nuevo, sin una línea recta por el tramo sin datos.
- **Disciplina cambiable:** se puede cambiar en cualquier momento, ya sea grabando, al guardar o en el detalle. Los datos de la ruta son los mismos; cambian las métricas que se muestran y las calorías.

## 2. Métricas por disciplina

Investigación: además de lo pedido (ritmo, distancia, tiempo y desnivel en running; tiempo, distancia, desnivel y velocidad media en ciclismo; tiempo, distancia y desnivel en trekking), estas son las métricas que suelen mostrar Strava, Garmin y Komoot y que el GPS del teléfono puede calcular con confianza:

| Métrica | Running | Ciclismo | Trekking | Notas |
|---|:-:|:-:|:-:|---|
| Distancia | ✓ | ✓ | ✓ | Suma del haversine entre puntos válidos |
| Tiempo en movimiento | ✓ | ✓ | ✓ | Sin detenciones (bajo 0,5 m/s); el ritmo y la velocidad media usan este tiempo |
| Tiempo total | ✓ | | ✓ | Sin las pausas manuales; en trekking es el más relevante (incluye descansos) |
| Ritmo medio (min/km) | ✓ | | | En vivo también el ritmo actual (velocidad Doppler del GPS) |
| Velocidad media y máxima | | ✓ | | En vivo, la velocidad actual |
| Desnivel positivo | ✓ | ✓ | ✓ | Altura suavizada (promedio de 5 puntos) y umbral de 4 m para no sumar ruido |
| Desnivel negativo | | | ✓ | |
| Altura máxima | | | ✓ | En vivo, la altura actual |
| Ascenso por hora (m/h) | | | ✓ | Ritmo de subida, útil para planificar cerros |
| Parciales por kilómetro | ✓ | ✓ (km/h) | ✓ | Con el desnivel de cada kilómetro |
| Perfil de altura | ✓ | ✓ | ✓ | |
| Calorías estimadas | ✓ | ✓ | ✓ | MET × peso × horas en movimiento; MET según la velocidad (2024 Adult Compendium of Physical Activities). Requiere un peso registrado |

Para versiones siguientes, que necesitan sensores o más datos:

- **Frecuencia cardiaca y zonas:** Apple Watch o banda, vía HealthKit.
- **Cadencia:** de carrera con el podómetro del teléfono; de pedaleo, con un sensor.
- **Potencia en bici:** requiere un potenciómetro.
- **Ritmo ajustado por pendiente (GAP).**
- **VAM en subidas.**
- **Carga de entrenamiento** (esfuerzo × duración): para cruzar cardio y fuerza en la semana del atleta híbrido.
- **Altura con el barómetro del iPhone:** más precisa que la del GPS.

## 3. Calidad del GPS

- **Puntos descartados:**
  - Precisión peor que 30 m.
  - Tiempos repetidos.
  - Saltos imposibles (más de 180 km/h).
- **Filtro de distancia de 3 m:** evita sumar el temblor del GPS estando detenido.
- **Velocidad Doppler:** se usa la del GPS (más estable) para la velocidad máxima y la actual.
- **Lógica:** toda está en `lib/core/cardio/` (Dart puro, con pruebas). En vivo y al guardar se recorre la ruta con el mismo acumulador, así los números no cambian al terminar.

## 4. Guardado sin internet y respaldo

| Dónde | Qué |
|---|---|
| Teléfono (fuente de verdad) | `Application Support/cardio/{uid}/`: `index.json` (resúmenes y borradas pendientes), `tracks/{id}.json` (ruta completa) y `recording.json` (grabación en curso). Escritura atómica (archivo temporal + renombrar) |
| Firestore (respaldo) | `users/{uid}/activities/{id}`: resumen (disciplina, título, descripción, fechas, métricas, polilínea simplificada, `updatedAt`). `users/{uid}/activities/{id}/track/{n}`: la ruta en trozos de 2000 puntos (polilínea codificada, alturas a 0,1 m y segundos desde el inicio). Cada documento queda muy por debajo de 1 MB |

### Sincronización

`CardioActivitiesController.sync()` se ejecuta al abrir la app, al volver a primer plano y después de cada cambio:

1. **Borradas:** borra en la nube lo eliminado en el teléfono. Una marca local evita que se vuelva a bajar.
2. **Pendientes:** sube lo pendiente. Repetir la subida no duplica, porque se usa el mismo id. Sin internet, Firestore guarda la escritura y la envía al reconectarse; la actividad sigue marcada como pendiente (nube con flecha) hasta que el servidor la confirma.
3. **Faltantes:** baja lo que falta en el teléfono (por ejemplo, en un teléfono nuevo) y las ediciones más recientes hechas en otro dispositivo.

`firestore.rules` no cambia: todo está bajo `users/{uid}/**`.

## 5. Imagen para historias

- **Formato:** PNG de 1080 × 1920 (9:16).
- **Contenido:** la ruta en verde (`#7ED957`, con sombra para fotos claras), disciplina y fecha, tres métricas principales y el logo de NutriApp.

  | Disciplina | Métricas |
  |---|---|
  | Running | Distancia, ritmo y tiempo |
  | Ciclismo | Distancia, velocidad media y desnivel |
  | Trekking | Distancia, desnivel y tiempo |

- **Fondo:** transparente (para pegarla sobre una foto en Instagram) u oscuro.
- **Compartir:** **Compartir** abre el menú de iOS (Instagram, "Guardar imagen", mensajes…), con `share_plus`.

## 6. Fotos: pendiente

Firestore no sirve para guardar fotos: el límite es de 1 MB por documento y no está pensado para archivos. Lo correcto es **Cloud Storage for Firebase**, pero desde fines de 2024 sus buckets exigen el plan **Blaze** (pago por uso, con una cuota gratuita). La pantalla Guardar muestra el espacio reservado para la próxima versión.

Hay dos caminos posibles:

- **Pasar el proyecto a Blaze** y subir las fotos a Storage, con la misma estrategia de cola sin internet.
- **Guardarlas solo en el teléfono:** sin respaldo, pero sin costo.

## 7. Mapa

- **Proveedor:** `flutter_map` con teselas de OpenStreetMap. La licencia exige mostrar la atribución: va como un "© OpenStreetMap" pequeño en la esquina inferior derecha (abre la página de derechos al tocarlo), sin el texto de flutter_map.
- **Sin internet:** se ve igual la ruta en verde sobre fondo liso, porque grabar no depende del mapa.
- **Antes de publicar la app:** la política de uso de las teselas de OpenStreetMap no permite el uso intensivo desde una app distribuida. Hay que cambiar a un proveedor con plan para apps (MapTiler, Stadia, Mapbox) o a Apple Maps; basta cambiar la URL en `RouteMap`.

## 8. Integraciones

- **Racha y calendario:** una ruta suma a la racha como una comida o un entrenamiento. El calendario de actividad tiene el filtro Cardio y muestra las rutas del día.
- **Permisos:** `Info.plist` tiene `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription` y `UIBackgroundModes: location`. Basta el permiso "Al usar la app".
- **HealthKit (futuro):** `ActivitySession` y `HealthService` ya existen para leer los entrenamientos del Apple Watch. Las sesiones del reloj se podrán convertir en `CardioActivity`, con la misma lógica de métricas.

## 9. Pruebas

- `test/core/cardio_test.dart`:
  - Haversine, polilínea (ejemplo oficial de Google) y simplificación.
  - Métricas: distancia, tiempo en movimiento, parciales, pausas, desnivel con ruido y filtro de puntos.
  - Grabación que sobrevive a cerrar la app.
  - Ruta repartida en documentos y reconstruida.
  - Perfil de altura y calorías.
- `test/app_smoke_test.dart`:
  - Grabar con un GPS simulado, cambiar a ciclismo en plena grabación, pausar, terminar, guardar con título y ver el respaldo y la racha.
  - Bajar las actividades desde la nube a un teléfono vacío.
  - Recuperar una grabación al reiniciar.
  - Abrir el detalle y la imagen para historias.
