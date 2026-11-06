# Nutri — prototipo del módulo de nutrición

Prototipo web para probar qué funciones del módulo de nutrición sirven y cuáles sobran. Es parte del proyecto de título *Solución tecnológica para el registro, cruce de datos y análisis del entrenamiento concurrente y la nutrición en deportistas aficionados*. El plan completo está en [docs/plan-modulo-nutricion.md](docs/plan-modulo-nutricion.md).

La app tiene un menú con tres módulos: **Nutrición** y **Fuerza** (funcionales) y **Cardio** ("En desarrollo"). Documentación de cada módulo: [docs/modulo-nutricion.md](docs/modulo-nutricion.md) y [docs/modulo-fuerza.md](docs/modulo-fuerza.md) (incluye la investigación sobre bases de ejercicios).

**Stack:** React 19 + Vite + TypeScript + Tailwind v4 · Firebase (Auth con Google, Firestore, Hosting) · Fuse.js · lucide-react.

**App para iPhone:** en [mobile/](mobile/README.md) hay una versión nativa en Flutter con las mismas funciones y los mismos datos de Firestore, preparada para Apple Salud, podómetro y ubicación ([arquitectura](docs/arquitectura-flutter.md)).

## Qué hace

| Función | Dónde |
|---|---|
| Registrar varios alimentos en lenguaje natural ("Arroz 100g", "1 Tomate mediano", "Huevos x3") | Registrar |
| Crear un alimento cuando no está en el catálogo, sin salir del registro | Registrar → Crear |
| Rango min/max diario de kcal, proteína, carbohidratos, grasa y fibra, con puntaje 0–100 y pesos ajustables | Objetivos y Diario |
| Recetas por ingredientes, reconocidas por nombre en la lista ("Pollo al limón 2 porciones") | Recetas |
| Catálogo público de alimentos (con fibra y equivalencias en gramos) e importación de una semilla de 76 alimentos | Alimentos |
| Código de barras por alimento: escanearlo con la cámara o escribirlo, y autocompletar con Open Food Facts | Alimentos → Nuevo |
| Escanear un producto ya guardado para sumarlo al registro (solo ajustas la porción) | Registrar |
| Meta corporal (perder, mantener o ganar), registro de peso y gráfica con tendencia y fecha estimada | Progreso |

### Cómo se interpreta una lista (prototipo P1: reglas + Fuse.js, sin IA)

1. **Parser por reglas** (`src/core/parser/ruleParser.ts`): separa líneas y extrae cantidad, unidad y tamaño. Soporta `100g`, `1,5 kg`, `x3`, `3x`, `1/2`, `1 1/2`, `medio`, `un par de`, `2 tazas de`, `cda`, `scoop`, `pequeño/mediano/grande`, y marca como supuesta una cantidad vaga ("un poco de aceite").
2. **Matcher** (`src/core/matcher.ts`): primero coincidencia exacta por nombre o alias (también en singular). Después Fuse.js recupera candidatos y se ordenan por similitud de tokens (F1 con tolerancia a errores de tipeo).
3. **Cantidad → gramos** (`src/core/quantity.ts`): usa las porciones de cada alimento (unidad, mediano, taza…) y, si no existen, porciones genéricas (taza 240 ml, cda 15 ml…).
4. **Estado de cada ítem:** `ok` (confianza ≥ 85 %), `revisar` (confianza media, coincidencia ambigua o cantidad supuesta) o `falta` (< 60 %: hay que crearlo o buscarlo).

Los macros siempre salen del catálogo con aritmética determinista. La lógica de `src/core` no depende de React ni de Firebase, para reutilizarla en React Native.

## Puesta en marcha

```bash
npm install
```

### Opción A: con el emulador local (sin proyecto de Firebase)

Requiere **Java 21 o superior** para el Emulator Suite. En Arch puedes apuntar a otro JDK sin cambiar el del sistema:

```bash
JAVA_HOME=/usr/lib/jvm/java-21-openjdk PATH=/usr/lib/jvm/java-21-openjdk/bin:$PATH npm run emulators
```

En otra terminal:

```bash
npm run dev:emu
```

El login con Google abre la ventana simulada del emulador ("Add new account" → "Auto-generate user information"). La interfaz del emulador queda en http://127.0.0.1:4000. Los datos se borran al detener el emulador.

### Opción B: con un proyecto real de Firebase

1. Crea un proyecto en la consola de Firebase y una app web.
2. Activa **Authentication → Google** y crea una base **Firestore**.
3. Copia `.env.example` como `.env.local` y completa los valores de la app web.
4. Publica las reglas de seguridad: `npx firebase deploy --only firestore:rules --project <tu-proyecto>`.
5. Inicia `npm run dev`, ingresa con Google y en **Alimentos** importa el catálogo base.

## Scripts

| Script | Uso |
|---|---|
| `npm run dev` / `npm run dev:emu` | Servidor de desarrollo (proyecto real / emulador) |
| `npm run emulators` | Emuladores de Auth y Firestore |
| `npm test` | Pruebas unitarias de `src/core` (Vitest) |
| `npm run build` | Typecheck + build de producción |
| `npm run lint` | oxlint |
| `npm run deploy` | Build y despliegue a Firebase Hosting + reglas |

## Estructura

```
src/
  core/        lógica pura: parser, matcher, cantidades, macros, puntaje, recetas, strength/ (+ __tests__)
  services/    adaptadores de Firebase (auth, foods, recipes, diary, profile, body, strength)
  app/         proveedores (sesión, datos, avisos), layout, login y módulos (modules.ts)
  features/    pantallas: diary, log, foods, recipes, goals, progress, barcode, strength, coming-soon
  ui/          componentes reutilizables (IconButton, MacroBar, ScoreRing…)
  data/        semilla de alimentos (foods.seed.json) y catálogo de ejercicios (exercises.json, exercisesEs.ts)
scripts/       build-exercises.mjs: regenera el catálogo de ejercicios desde free-exercise-db
firestore.rules  reglas: catálogo público, recetas y diario privados
```

## Códigos de barras

- **Lector:** usa el `BarcodeDetector` nativo del navegador cuando existe (Chrome en Android) y, si no, `zxing-wasm` (iOS Safari, Firefox), que se descarga solo al abrir la cámara. Lee EAN-13, EAN-8, UPC-A y UPC-E y valida el dígito verificador. La cámara exige **HTTPS** (o `localhost`); en Firebase Hosting funciona sin cambios.
- **Open Food Facts:** al ingresar un código se pueden traer nombre, marca y macros desde la API pública. Los datos son comunitarios y **pueden estar incompletos o ser incorrectos**: el formulario los muestra para que los compares con la etiqueta antes de guardar. Se rellenan solo los campos vacíos.
- **Licencia:** los datos de Open Food Facts son ODbL (atribución y compartir igual). Los alimentos importados quedan marcados con `source.type = "OFF"`; si publicas la app o la base, revisa esa licencia.
- **Límite de uso:** la API permite unas 15 lecturas de producto por minuto por IP; como las consultas salen del navegador de cada usuario, el límite es por usuario.

## Progreso corporal

Un registro de peso por día (guardar el mismo día lo reemplaza) en `users/{uid}/weights/{YYYY-MM-DD}` y la meta en `users/{uid}.bodyGoal`. La tendencia es una regresión lineal de las últimas 4 semanas; la fecha estimada solo aparece si esa tendencia va hacia la meta. Es una proyección simple, no una recomendación médica.

## Equivalencias de un alimento

Al crear un alimento, las *equivalencias* indican cuánto pesa cada medida para que la lista entienda frases como "Huevos x3" (`1 unidad = 50 g`) o "2 tazas de arroz" (`1 taza = 158 g`). Se agregan tocando la medida (unidad, mediano, taza, cda, rebanada…) y escribiendo los gramos. La medida `ml` es solo para líquidos y guarda la densidad (1 ml de agua = 1 g). Sin equivalencias, el alimento solo se entiende en gramos.

## Datos de Firestore

- `foods/{id}`: catálogo público. Cualquier usuario autenticado lo lee y agrega alimentos; solo el creador edita o borra.
- `recipes/{id}`: recetas privadas (`ownerId`).
- `users/{uid}`: objetivos (`goals`), y `users/{uid}/days/{YYYY-MM-DD}/entries/{id}` para el diario. Cada entrada guarda un snapshot de sus macros.

## Advertencias

- **La fibra de la semilla también es aproximada.** Los alimentos importados antes de existir la fibra se completan con el botón del catálogo en **Alimentos** (solo los que creaste tú).
- **Los valores de la semilla son aproximados** (basados en USDA FoodData Central y etiquetas locales) y están marcados como no verificados. Conviene revisarlos antes de usarlos en pruebas formales.
- El puntaje (100 dentro del rango, caída lineal fuera de él) es una hipótesis de diseño, no una fórmula validada.
