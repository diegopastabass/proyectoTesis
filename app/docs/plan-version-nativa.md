# Versión nativa (Android e iPhone) y lectura de pasos

> Investigación del 2026-10-22. Los plazos de trabajo son **estimaciones mías**, no datos de las fuentes. Las cifras de cuotas, precios y versiones deben confirmarse antes de comprometerse; donde no pude confirmar algo, lo marco.

## 1. Conclusión corta

- **Una web no puede leer pasos.** Ni Apple Salud (HealthKit) ni Health Connect de Android ofrecen una API web. Hace falta una app instalada con acceso nativo.
- **No necesitas reescribir la app.** La ruta más corta es **Capacitor**: envuelve tu app React/Vite actual en un contenedor nativo y le da acceso a HealthKit y Health Connect mediante plugins. React Native y Flutter también sirven, pero obligan a rehacer las pantallas (React Native) o todo el código (Flutter).
- **El mayor obstáculo no es el código, es iPhone:** compilar para iOS exige macOS y Xcode. Estás en Linux, así que hará falta un Mac prestado o un servicio de compilación en la nube, además de la cuenta de Apple (US$ 99 al año).
- **Android es viable desde tu equipo hoy.** Ya tienes el SDK de Android en el PATH.

## 2. Qué se necesita según la plataforma

### Android (Health Connect)

| Requisito | Detalle |
|---|---|
| Lectura de pasos | Permiso `android.permission.health.READ_STEPS` declarado en el manifiesto |
| Versiones | Android 14+: Health Connect viene integrado. Android 13 o menos: el usuario instala la app *Health Connect* desde Play Store. Se necesita Android 9 o superior ([requisitos](https://developer.android.com/health-and-fitness/health-connect/get-started)) |
| Quién escribe los pasos | Health Connect **almacena** datos, no cuenta pasos por sí mismo: alguna app (Samsung Health, Fitbit, Google Fit o la de tu reloj) debe escribirlos. Es mi conocimiento general, no lo confirmé en las fuentes |
| Historial | Solo se leen los últimos **30 días antes de otorgar el permiso**, salvo que se pida el permiso `READ_HEALTH_DATA_HISTORY` |
| Duplicados | La lectura **agregada** deduplica por prioridad entre apps; la lectura de registros crudos no ([explicación](https://sahha.ai/blog/deduplicating-health-data-across-wearables/), [documentación](https://developer.android.com/health-and-fitness/health-connect/aggregate-data)). Hay que usar siempre la agregada para sumar pasos |
| Política de privacidad | Obligatoria, con una pantalla que la muestre desde Health Connect |
| Publicar en Play | Completar el formulario de *Aplicaciones de salud* en Play Console, justificar cada tipo de dato y llenar la sección de seguridad de datos ([guía](https://developer.android.com/health-and-fitness/health-connect/publish)). Para probar en tu propio teléfono no necesitas publicar |
| Herramientas | Android Studio, JDK 21 (ya los tienes) y `compileSdk` 36 |

La antigua API de Google Fit está en retirada: dejó de aceptar desarrolladores nuevos en mayo de 2024 y su fecha de cierre no está clara ([9to5Google](https://9to5google.com/2024/05/04/google-fit-api-shutdown/)). No conviene construir sobre ella.

### iPhone (HealthKit)

| Requisito | Detalle |
|---|---|
| Compilar | macOS con Xcode. **No se puede en Linux.** Opciones: un Mac prestado, o servicios con Macs en la nube (Codemagic, Bitrise, Capawesome, EAS de Expo) que devuelven el `.ipa` ([Expo](https://expo.dev/articles/testing-and-previewing/test-ios-app-without-mac), [Capawesome](https://capawesome.io/solutions/build-without-mac/)). Instalar macOS en un PC no Apple viola la licencia de Apple |
| Cuenta Apple | Apple Developer Program, **US$ 99 al año**, necesario para TestFlight, la App Store y firmar desde la nube |
| Permisos | Activar la capacidad *HealthKit* y declarar `NSHealthShareUsageDescription` en `Info.plist` |
| Pruebas | En un iPhone real, ya sea por TestFlight o una instalación firmada |
| Privacidad de HealthKit | Si el usuario niega el permiso, la app **no se entera**: ve "0 pasos" igual que quien no ha caminado. Hay que explicarlo en la interfaz |
| Revisión de Apple | Estricta con datos de salud: pide solo lo necesario y mantén una política de privacidad (sección 5.1.3 de las pautas; no la revisé directamente) |
| Totales | Los totales de días pasados pueden cambiar cuando el Apple Watch sincroniza más tarde ([foro de Apple](https://developer.apple.com/forums/thread/696660)). Conviene volver a leer los últimos días al abrir la app |

## 3. Comparación de caminos

| | **Capacitor** (recomendado) | React Native (Expo) | Flutter |
|---|---|---|---|
| Qué se reutiliza | **Casi todo**: `src/core`, `src/services`, las pantallas y Tailwind | `src/core` y la lógica; las pantallas se reescriben con componentes nativos | Nada: se reescribe en Dart |
| Apariencia | La de tu web, dentro de un WebView | Componentes nativos | Motor gráfico propio |
| Pasos en Android | `@capgo/capacitor-health` 8.11 (MPL-2.0, actualizado el 15-oct-2026) | `react-native-health-connect` 4.1.3 (MIT, ago-2026) | `health` 13.3.2 |
| Pasos en iPhone | El mismo plugin de Capacitor | `@kingstinct/react-native-healthkit` 16.2 (MIT, oct-2026). Ojo: `react-native-health` no se actualiza desde oct-2024 | El mismo paquete `health` |
| Estimación de esfuerzo (mía) | 1 a 2 semanas para tener Android funcionando | 3 a 5 semanas | 5 semanas o más |
| Requisitos extra | Un Mac o compilación en la nube para iPhone | Build propio de desarrollo (no sirve Expo Go) y EAS Build para iPhone desde Linux | Un Mac o compilación en la nube |

Notas:

- La tesis ya contemplaba Flutter con Health Connect y HealthKit (RF-01). Este prototipo en Capacitor serviría para probar esa integración sin comprometer esa decisión.
- El plugin de Capawesome es de pago ("Insiders"); el de Capgo, que sí es gratuito, también ofrece suma de pasos por día y es el que recomiendo evaluar ([README](https://cdn.jsdelivr.net/npm/@capgo/capacitor-health@8.7.0/README.md)).
- Todos los plugins están a cargo de un proveedor pequeño o de una sola persona. Antes de depender de uno, revisa sus incidencias abiertas.

## 4. Qué habría que cambiar en esta app para Capacitor

1. **Inicio de sesión con Google.** `signInWithPopup` **no funciona** dentro del WebView de Capacitor ([foro](https://forum.ionicframework.com/t/firebase-auth-operation-not-supported-in-this-environment-with-capacitor/171865)). La solución habitual: `@capacitor-firebase/authentication` (8.5, Apache-2.0) hace el inicio nativo y devuelve un token que se pasa a `signInWithCredential`. Requiere `google-services.json` (Android, con la huella SHA-1 registrada en Firebase) y `GoogleService-Info.plist` (iPhone). En la web se mantiene el popup actual, elegido según la plataforma.
2. **Escáner de códigos de barras.** El actual debería funcionar en el WebView, pero iOS exige `NSCameraUsageDescription`. Lo mejor es cambiarlo en la versión nativa por `@capacitor-mlkit/barcode-scanning` (Apache-2.0): es más rápido y evita descargar 1 MB de WebAssembly. La web conserva el actual.
3. **Pasos.** Un servicio `StepsProvider` con dos implementaciones: manual (web) y nativa (Capacitor), elegida con `Capacitor.isNativePlatform()`.
4. **Distribución.** La app nativa lleva los archivos dentro del paquete: cada cambio exige una versión en las tiendas (o un servicio de actualización en vivo). La versión web en Firebase Hosting sigue funcionando igual.

## 5. Cómo se usarían los pasos dentro de la app

- Guardar un total por día: `users/{uid}/days/{fecha}` con `{ steps, source }` (`manual`, `healthkit` o `healthconnect`).
- Mostrarlo en el Diario junto a las calorías estimadas del movimiento.
- Opción del usuario para **sumar esas calorías a su meta del día**, de modo que el puntaje use el rango ajustado. Es el mismo enfoque de ajuste por gasto que la tesis atribuye a Fitia.
- La conversión de pasos a calorías depende del peso y de la zancada: el orden de magnitud suele ser de unas centésimas de kcal por paso, pero **no lo investigué en esta ronda**. Debe ser un factor configurable, con valor inicial a validar con bibliografía.

## 6. Plan sugerido (por fases)

| Fase | Qué se hace | Estimación (mía) |
|---|---|---|
| 0 | **Pasos manuales en la web actual**: campo diario, calorías estimadas y ajuste del puntaje. Valida la idea sin tocar lo nativo | 1 a 2 días |
| 1 | **Android con Capacitor**: proyecto nativo, inicio de sesión nativo, lectura de pasos con Health Connect; instalación por USB en tu teléfono | 3 a 5 días |
| 2 | **iPhone**: requiere acceso a un Mac o compilación en la nube, y la cuenta de Apple | depende de ese acceso |
| 3 | Escáner nativo, política de privacidad, pruebas internas en Play y TestFlight | 3 a 5 días |

Las fases 0 y 1 no dependen de pagar nada ni de un Mac.

## 7. Riesgos

| Riesgo | Mitigación |
|---|---|
| No hay acceso a un Mac ni presupuesto para compilar en la nube | Entregar primero Android; la fase 0 sirve para ambas plataformas |
| Revisión de salud en Play o Apple | Pedir solo pasos, redactar la política de privacidad desde el inicio |
| El usuario no tiene una app que escriba pasos en Health Connect | Detectarlo y mostrar un aviso con instrucciones |
| En iPhone, "0 pasos" puede ser un permiso negado | Mensaje explicativo y acceso directo a los ajustes |
| Plugin poco mantenido | Aislarlo detrás de `StepsProvider` para poder cambiarlo |
| Plazo de la tesis (cierre antes de diciembre de 2026) | Limitarse a las fases 0 y 1 si el tiempo aprieta |

## Fuentes principales

- [Health Connect: primeros pasos](https://developer.android.com/health-and-fitness/health-connect/get-started)
- [Publicar una app de salud en Google Play](https://developer.android.com/health-and-fitness/health-connect/publish)
- [Health Connect: lectura agregada](https://developer.android.com/health-and-fitness/health-connect/aggregate-data)
- [Capacitor: primeros pasos](https://capacitorjs.com/docs/getting-started)
- [@capgo/capacitor-health](https://cdn.jsdelivr.net/npm/@capgo/capacitor-health@8.7.0/README.md) y [anuncio del plugin de Capawesome](https://capawesome.io/blog/announcing-the-capacitor-health-plugin/)
- [react-native-health-connect](https://github.com/matinzd/react-native-health-connect/releases) y [paquete `health` de Flutter](https://pub.dev/documentation/health/latest/)
- [Compilar para iOS sin Mac (Expo)](https://expo.dev/articles/testing-and-previewing/test-ios-app-without-mac)
