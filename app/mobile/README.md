# NutriApp (Asistente Deportivo) — app iOS (Flutter)

> "NutriApp" es el nombre interno por ahora; el logo de la nutria está en `assets/branding/` y en los íconos de iOS ([../docs/recordatorios-y-programas.md](../docs/recordatorios-y-programas.md)).

Versión nativa para iPhone del prototipo web (`../src`). Partió con las mismas funciones (Nutrición y Fuerza completas; Cardio, con rutas GPS desde el 28-10-2026, ver [../docs/modulo-cardio.md](../docs/modulo-cardio.md)) y los mismos documentos de Firestore; desde el 28-10-2026 la web está en desuso y la app suma funciones propias (copiar comidas, racha, calendario de actividad y perfil corporal, ver [../docs/actividad-y-perfil.md](../docs/actividad-y-perfil.md)). Está preparada para usar funciones del sistema: Apple Salud (pasos, frecuencia cardiaca, entrenamientos del reloj), podómetro y ubicación. La arquitectura está en [../docs/arquitectura-flutter.md](../docs/arquitectura-flutter.md).

**Stack:** Flutter 3.47 · Dart 3.13 · Riverpod 3 · go_router · Firebase (Auth, Firestore) · mobile_scanner (códigos de barras).

## Requisitos

| Herramienta | Estado | Cómo |
|---|---|---|
| Flutter SDK | Instalado (`brew install --cask flutter`) | `flutter --version` |
| CocoaPods | Instalado (`brew install cocoapods`) | Lo usa Flutter si un plugin no trae Swift Package |
| **Xcode** | **Falta** | App Store → Xcode (requiere tu Apple ID). Luego ver abajo |

Después de instalar Xcode, una sola vez:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

```bash
sudo xcodebuild -runFirstLaunch
```

```bash
xcodebuild -downloadPlatform iOS
```

```bash
flutter doctor
```

`flutter doctor` debe mostrar Xcode en verde (Android y Chrome no son necesarios).

## Ejecutar

Todo desde esta carpeta (`mobile/`).

```bash
flutter pub get
```

| Modo | Comando | Para qué |
|---|---|---|
| Demostración | `flutter run` | Datos en memoria con un usuario de prueba. No necesita red ni Firebase |
| Emulador de Firebase | `flutter run --dart-define-from-file=env/emulator.json` | Mismo emulador que la web (`npm run emulators` en la raíz). El simulador de iOS llega al computador por `127.0.0.1` |
| Firebase real | `flutter run --dart-define-from-file=env/firebase.json` | Copia `env/firebase.example.json` como `env/firebase.json` y complétalo (ver abajo) |

Para abrir el simulador antes de ejecutar:

```bash
open -a Simulator
```

### En un iPhone físico

1. Abre `ios/Runner.xcworkspace` en Xcode → target **Runner** → *Signing & Capabilities* → elige tu equipo (un Apple ID gratuito sirve para instalar en tu propio teléfono; TestFlight y la App Store requieren el Apple Developer Program).
2. Si el identificador `cl.asistentedeportivo.asistenteDeportivo` está tomado, cámbialo ahí mismo (*Bundle Identifier*).
3. En el iPhone: *Ajustes → Privacidad y seguridad → Modo de desarrollador*.
4. Conecta el teléfono y ejecuta `flutter run` eligiendo el dispositivo.

### Instalarla para abrirla desde la pantalla de inicio

En modo *debug* (`flutter run`), iOS solo deja abrir la app con el depurador conectado. Para usarla como una app normal se instala en modo *release* (compilada y firmada con el mismo equipo):

```bash
sh tool/install_iphone.sh
```

Usa `env/firebase.json` si existe (si no, el modo demostración); se le puede pasar otro archivo (`sh tool/install_iphone.sh env/memory.json`) o pedir el modo profile (`MODE=profile sh tool/install_iphone.sh`). Actualiza la app sin desinstalarla, así que se conservan la sesión y los datos locales. Con un Apple ID gratuito la firma dura 7 días: después basta con volver a ejecutar el script.

## Conectar con el proyecto real de Firebase

1. En la consola de Firebase del proyecto que ya usa la web: *Configuración del proyecto → Agregar app → iOS*, con el bundle id `cl.asistentedeportivo.asistenteDeportivo`. *Authentication → Google* debe estar habilitado **antes** de descargar el plist (así trae `CLIENT_ID`).
2. Deja el `GoogleService-Info.plist` en `ios/Runner/` (no se versiona) y ejecuta:

   ```bash
   python3 tool/firebase_env.py
   ```

   Escribe `env/firebase.json` y registra en `Info.plist` los esquemas de URL por los que vuelve el ingreso con Google (`REVERSED_CLIENT_ID` y el Encoded App ID).
3. Ejecuta con `flutter run --dart-define-from-file=env/firebase.json`. El ingreso usa `signInWithProvider(GoogleAuthProvider())`, que abre Google en una hoja segura de Safari; la sesión queda guardada en el teléfono.
4. Las reglas de `../firestore.rules` no cambian: todo lo propio de la app vive bajo `users/{uid}`.

## Apple Salud (pasos)

El Diario muestra los pasos del día y de la semana leídos de Apple Salud (`lib/platform/health/healthkit_health_service.dart`, paquete `health`). La capacidad HealthKit está en `ios/Runner/Runner.entitlements` y los textos de permiso en `Info.plist`. iOS no informa si el usuario negó la lectura: si todo sale en 0, revisar *Salud → perfil → Apps → Asistente*. En el simulador funciona, pero solo con datos que se agreguen a mano en la app Salud.

## Pruebas y verificación

```bash
flutter analyze
```

```bash
flutter test
```

- `test/core/`: port de las pruebas de la web (`src/core/__tests__`). La lógica de Dart da los mismos resultados que la de TypeScript.
- `test/app_smoke_test.dart`: arranca la app con el backend en memoria a tamaño de iPhone, recorre todas las pantallas y hace los flujos de registrar una lista y terminar un entrenamiento. Falla ante cualquier excepción o desborde de diseño.

Sin Xcode también se puede revisar la interfaz en el navegador (no es el objetivo de la app, pero sirve para mirar pantallas):

```bash
flutter build web && python3 -m http.server 8091 --directory build/web
```

## Pantallas de diseño y capturas de la tesis

En modo demostración aparecen además las pantallas de diseño de los casos de uso que todavía no tienen backend: comunidad, IA, reloj y archivos `.fit`, alertas de fatiga, metas del día, cuestionario inicial, términos, privacidad y suscripción. Usan datos simulados (`lib/data/simulated/`, `lib/app/sim_providers.dart`) y sus rutas están en `_previewPaths` (`lib/app/router.dart`): **con Firebase real no se muestran**.

Las capturas de `figuras/interfaces/` se toman en un simulador sin tocar la pantalla:

```bash
flutter build ios --simulator --debug --dart-define-from-file=env/memory.json
```

```bash
python3 tool/capture_screens.py
```

La app abre cada pantalla por su ruta y avisa cuando ya se dibujó. El entrenamiento en curso y la grabación con GPS requieren tocar la pantalla: se usan `--open`, `--snap` y `--close` (ver el encabezado del script).

## Datos compartidos con la web

`assets/data/` partió como copia de `../src/data` (semilla de alimentos, catálogo de ejercicios y nombres en español). Con la web en desuso, `assets/data/exercises_es.json` ya tiene nombres propios de la app (ejercicios de los programas sugeridos): **no ejecutes `tool/sync_assets.py`** sin revisar el resultado, porque los sobrescribiría. Para traer cambios de la web:

```bash
python3 tool/sync_assets.py
```

## Estructura

```
lib/
  core/        lógica pura en Dart (sin Flutter ni Firebase): nutrition/, strength/, cardio/, training/ (carga), body/, activity/, common/
  data/        contratos (repositories.dart) e implementaciones: firebase/, memory/, remote/ (HTTP), local/, assets/
  platform/    funciones del sistema: health/ (Apple Salud), location/, motion/ (podómetro), capability.dart
  app/         arranque, configuración, tema, rutas, shell y proveedores de estado (Riverpod)
  features/    pantallas: nutrition/, strength/, cardio/, settings/, auth/
  ui/          componentes y formatos compartidos (gráfico de tendencia, anillo de puntaje, barras de macros…)
env/           configuración por entorno para --dart-define-from-file
tool/          sync_assets.py
```
