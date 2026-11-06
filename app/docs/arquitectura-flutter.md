# Arquitectura de la app iOS (Flutter)

> Escrito el 2026-10-27 junto con la primera versión de `mobile/`. Complementa [plan-version-nativa.md](plan-version-nativa.md), que comparaba Capacitor, React Native y Flutter; la tesis ya contemplaba Flutter (RF-01) y esa es la ruta elegida.

## 1. Capas

```
features/  (pantallas)          ─┐
ui/        (componentes)         │  dependen de ↓
app/       (estado: Riverpod)   ─┘
   │                 │
data/ (repositorios)   platform/ (funciones del sistema)
   │                 │
core/  (lógica pura en Dart: sin Flutter, sin Firebase, sin HealthKit)
```

| Capa | Qué contiene | Regla |
|---|---|---|
| `core/` | Parser de listas, matcher, cantidades, macros, puntaje, recetas, progreso corporal, fuerza (series, 1RM, insights, calendario), cardio (métricas de la ruta), carga de entrenamiento (RPE, ATL/CTL; ver [carga-de-entrenamiento.md](carga-de-entrenamiento.md)) y modelos de actividad | No importa Flutter ni paquetes de plataforma. Se prueba con `flutter test test/core` |
| `data/` | Interfaces en `repositories.dart` e implementaciones: Firestore, memoria, HTTP (Open Food Facts), almacenamiento local y assets | Las pantallas nunca usan Firebase directamente |
| `platform/` | Una interfaz por función del sistema (`HealthService`, `LocationService`, `PedometerService`) y `platform_providers.dart`, que elige la implementación | Las pantallas nunca llaman a HealthKit ni a CoreLocation |
| `app/` | Configuración (`config.dart`), proveedores Riverpod (`providers.dart`), rutas (`router.dart`), marco con módulos (`shell.dart`) y tema Gruvbox | Las escrituras pasan por `NutritionActions` / `StrengthActions` |
| `features/` | Pantallas por módulo | Solo leen proveedores y llaman acciones |

## 2. Decisiones

- **Datos heredados de la web.** `data/firebase/firebase_backend.dart` partió de las rutas y campos de `src/services/*.ts` (`foods`, `recipes`, `users/{uid}/days/{fecha}/entries`, `weights`, `routines`, `workouts`, `exercises`). Desde el 28-10-2026 la web está en desuso y la app agrega datos que la web no escribe: el resumen por día `users/{uid}/days/{fecha}` y los campos `body`, `streakCelebrated` y `dayIndexVersion` del perfil ([actividad-y-perfil.md](actividad-y-perfil.md)). `firestore.rules` no cambia.
- **Lógica portada, no reescrita.** `core/` es un port uno a uno de `src/core`, con sus pruebas. La única diferencia: Fuse.js no existe en Dart, así que el matcher calcula la similitud por tokens (la misma F1 de la web) sobre todo el catálogo. Con cientos o pocos miles de alimentos es instantáneo y devuelve un superconjunto de los candidatos de Fuse.
- **Backend intercambiable.** `--dart-define BACKEND=memory|emulator|firebase`. El modo memoria permite usar la app sin red (demostraciones, pruebas de usabilidad y pruebas automáticas).
- **Riverpod** para el estado: los streams de Firestore se exponen como `StreamProvider`, se combinan en `nutritionDataProvider` / `strengthDataProvider`, y en las pruebas se sobrescribe `backendProvider`.
- **Sesión de fuerza en el dispositivo** (`SharedPreferences`), como `localStorage` en la web: sobrevive a cerrar la app.
- **iOS 15+**, exigido por Firebase. Swift Package Manager activado (Flutter 3.47).

## 2.1 Diseño (patrones de iOS)

Desde el 28-10-2026 la interfaz sigue los patrones de iOS y los principios de *Designing Fluid Interfaces* (WWDC 2018), con la paleta Gruvbox y el aqua como color principal. El código vive en `app/theme.dart` (tema y `Motion`), `ui/widgets.dart` (componentes) y `app/shell.dart` (marco).

| Patrón | Cómo |
|---|---|
| Fondo agrupado | `canvas` de fondo y tarjetas `card` encima, con esquinas continuas (`RoundedSuperellipseBorder`) |
| Barras translúcidas | La barra superior y la de pestañas desenfocan el contenido que pasa por debajo (`GlassBar`); `PageBody` deja el espacio con el padding que entrega el `Scaffold` |
| Pestañas de iOS | Ícono y nombre siempre visibles y color en la elegida; las secciones cambian con un fundido breve |
| Navegación | Transiciones de iOS (deslizamiento y gesto para volver desde el borde) en todas las plataformas |
| Toque | Sin la onda de Material: lo tocable se ilumina y se achica al presionar (`Pressable`) y vuelve con un resorte |
| Movimiento | Resortes con los parámetros de Apple, amortiguación y respuesta: `Motion.standard` sin rebote para la interfaz y `Motion.bouncy` solo para celebraciones y gestos con impulso. Los bloques de cada pantalla entran escalonados (`Entrance`) |
| Controles | Segmentados deslizantes (`AppSegmented`), interruptores, alertas y ruedas de fecha y hora nativas (`pickDate`, `pickTime`) |
| Tipografía | Fuente del sistema; tracking negativo en títulos grandes y cercano a cero en el texto |
| Hápticos | Solo en momentos con significado: elegir una opción, iniciar o pausar una grabación, guardar, errores y la celebración de un hito |
| Accesibilidad | Con "Reducir movimiento" de iOS, las entradas y los cambios se funden sin desplazarse ni rebotar (`Motion.reduced`) |

## 3. Funciones del sistema: cómo integrar cada una

El esqueleto existe para todas: interfaces, modelos (`core/activity/models.dart`), proveedores y la pantalla **Ajustes → Integraciones del sistema**, que muestra el estado de cada una ("Próximamente" mientras no haya implementación nativa; Apple Salud ya está conectada). Integrar una función es escribir una clase y elegirla en `platform_providers.dart`; ninguna pantalla existente cambia.

### Apple Salud (pasos, frecuencia cardiaca, entrenamientos del Apple Watch)

**Estado (2026-10-27): pasos integrados.** `HealthKitHealthService` lee el total diario de pasos y la frecuencia cardiaca; el Diario muestra una tarjeta de pasos (`features/activity/steps_card.dart`). Falta convertir los entrenamientos (`sessions`) y guardar los totales en Firestore (puntos 6 y 7). Probado con un Apple ID gratuito: la capacidad HealthKit se firma sin el programa de pago.

1. `flutter pub add health` y crear `platform/health/healthkit_health_service.dart` con `class HealthKitHealthService implements HealthService`.
2. Pasos: pedir el total **agregado por día** (el paquete usa `HKStatisticsCollectionQuery`, que descuenta duplicados entre iPhone y reloj).
3. En `ios/Runner/Info.plist`: `NSHealthShareUsageDescription` (y `NSHealthUpdateUsageDescription` si se escribirá).
4. En Xcode: *Signing & Capabilities → + Capability → HealthKit* (crea `Runner.entitlements`). Los equipos gratuitos de Apple ID pueden tener límites con esta capacidad; para TestFlight se necesita el Apple Developer Program.
5. En `platform_providers.dart`: `healthServiceProvider` devuelve `HealthKitHealthService()` en iOS.
6. Guardar el total del día en `users/{uid}/days/{fecha}` como `{ steps, source: 'healthkit' }` (con `merge`: ese documento ya guarda el resumen del diario), y volver a leer los últimos días al abrir la app (el reloj sincroniza tarde).
7. Interfaz: HealthKit no informa si el usuario negó la lectura (devuelve vacío). Mostrar "0 pasos" con una explicación y un acceso a Ajustes.

### Ubicación (rutas de cardio)

**Estado (28-10-2026): integrada** con `geolocator` en `platform/location/geolocator_location_service.dart` (modo de fondo `location`, permiso "Al usar la app"). El módulo de cardio está en [modulo-cardio.md](modulo-cardio.md). Pasos originales:

1. `flutter pub add geolocator`; implementar `LocationService` (`current()`, `track()`).
2. `Info.plist`: `NSLocationWhenInUseUsageDescription`; para registrar con la pantalla apagada, también `NSLocationAlwaysAndWhenInUseUsageDescription` y `UIBackgroundModes` → `location`.
3. La distancia y el ritmo se calculan en `core/` a partir de `GeoPoint`, para probarlos sin GPS.

### Podómetro en vivo

1. `flutter pub add pedometer` (CoreMotion); implementar `PedometerService.stepsSince()`.
2. `Info.plist`: `NSMotionUsageDescription`.
3. Para totales diarios históricos usar Apple Salud, no el podómetro.

### Notificaciones locales

Integradas (28-10-2026): `flutter_local_notifications` con zona horaria (`timezone`, `flutter_timezone`). Interfaz `NotificationService` en `platform/notifications/`, elegida en `platform_providers.dart` (en la web y en las pruebas, `UnavailableNotificationService`). La planificación es lógica pura en `core/activity/reminders.dart`; `app/notification_host.dart` reprograma los avisos cuando cambian los datos o la app vuelve a primer plano. Detalle en [recordatorios-y-programas.md](recordatorios-y-programas.md).

### Cámara

Ya en uso: `mobile_scanner` (Apple Vision en iOS) para códigos EAN/UPC, con `NSCameraUsageDescription` en `Info.plist`. El simulador no tiene cámara: la pantalla permite escribir el código.

## 4. Diferencias conocidas con la web

| Tema | Web | iOS |
|---|---|---|
| Ingreso | `signInWithPopup` | `signInWithProvider` (ventana web segura); en el emulador, cuenta anónima |
| Búsqueda difusa | Fuse.js + similitud por tokens | Solo similitud por tokens (mismos puntajes) |
| Navegación | Barra de módulos y barra de secciones | Igual, con gesto de volver de iOS en los detalles |
| Lector de códigos | `BarcodeDetector` / `zxing-wasm` | `mobile_scanner` nativo |

## 5. Pendiente

- Compilar y probar en el simulador y en un iPhone: requiere instalar Xcode (ver `mobile/README.md`).
- ~~Íconos de la app y pantalla de inicio propios~~: listos con el logo de NutriApp (28-10-2026).
- Política de privacidad antes de pedir datos de salud.
- ~~Módulo de Cardio~~: primera versión con GPS lista ([modulo-cardio.md](modulo-cardio.md)); falta leer los entrenamientos del Apple Watch con `HealthService`.
