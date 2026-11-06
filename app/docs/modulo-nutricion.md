# Módulo de nutrición: qué hace hoy

> Estado al 22-10-2026. Describe lo que el prototipo **ya hace**, no lo planificado. El plan y las decisiones de diseño están en [plan-modulo-nutricion.md](plan-modulo-nutricion.md).

La aplicación tiene tres módulos: **Nutrición**, **Fuerza** y **Cardio**. Nutrición y Fuerza funcionan ([modulo-fuerza.md](modulo-fuerza.md)); Cardio muestra una pantalla "En desarrollo". Este documento cubre Nutrición y, al final, el menú entre módulos.

## Índice

1. [Resumen](#1-resumen)
2. [Acceso y sesión](#2-acceso-y-sesión)
3. [Pantallas del módulo](#3-pantallas-del-módulo)
4. [Diario](#4-diario)
5. [Registrar comidas con una lista](#5-registrar-comidas-con-una-lista)
6. [Cómo se interpreta la lista](#6-cómo-se-interpreta-la-lista)
7. [Catálogo de alimentos](#7-catálogo-de-alimentos)
8. [Códigos de barras y Open Food Facts](#8-códigos-de-barras-y-open-food-facts)
9. [Recetas](#9-recetas)
10. [Objetivos diarios y puntaje](#10-objetivos-diarios-y-puntaje)
11. [Progreso corporal](#11-progreso-corporal)
12. [Interfaz y accesibilidad](#12-interfaz-y-accesibilidad)
13. [Datos y seguridad](#13-datos-y-seguridad)
14. [Pruebas automáticas](#14-pruebas-automáticas)
15. [Límites conocidos](#15-límites-conocidos)
16. [Navegación entre módulos](#16-navegación-entre-módulos)

---

## 1. Resumen

| Capacidad | Pantalla | Ruta |
|---|---|---|
| Ver el día: puntaje 0–100, macros contra objetivos y comidas registradas | Diario | `/` |
| Registrar varios alimentos escribiendo una lista ("Arroz 100g, Huevos x3") | Registrar | `/registrar` |
| Escanear un producto para sumarlo al registro | Registrar | `/registrar` |
| Crear un alimento que falta sin salir del registro | Registrar → Crear | `/registrar` |
| Buscar, crear y editar alimentos del catálogo público | Alimentos | `/alimentos` |
| Importar el catálogo base (76 alimentos) | Alimentos | `/alimentos` |
| Leer un código de barras y traer los datos desde Open Food Facts | Alimentos → Nuevo | `/alimentos` |
| Crear recetas por ingredientes y registrarlas por nombre | Recetas | `/recetas`, `/recetas/:id` |
| Definir rangos min/max de kcal, proteína, carbohidratos, grasa y fibra, y sus pesos en el puntaje | Objetivos | `/objetivos` |
| Definir una meta corporal, registrar el peso y ver la tendencia | Progreso | `/progreso` |

Los macros siempre salen del catálogo con aritmética determinista: no se usa IA para calcular ni para interpretar texto (prototipo **P1**: reglas + Fuse.js).

**Macros que maneja el módulo:** calorías (kcal), proteína (g), carbohidratos (g), grasa (g) y fibra (g).

---

## 2. Acceso y sesión

- **Ingreso solo con Google** (Firebase Authentication). Si se cierra la ventana emergente no se muestra error.
- **Sin configuración de Firebase** (faltan variables en `.env.local`) la app muestra una pantalla con los pasos para configurarla, en vez de fallar.
- **Modo emulador** (`npm run dev:emu`): la app se conecta a los emuladores locales de Auth y Firestore, muestra una etiqueta "emulador" en el encabezado y el ingreso con Google es simulado.
- **Cerrar sesión** desde el ícono del encabezado.
- Al entrar se cargan en tiempo real el catálogo, las recetas del usuario y sus objetivos; cualquier cambio (incluso desde otro dispositivo) se refleja sin recargar.

---

## 3. Pantallas del módulo

La barra inferior (solo visible dentro de Nutrición) tiene seis secciones, todas con ícono y nombre accesible:

| Ícono | Sección | Para qué |
|---|---|---|
| Calendario | Diario | Resumen del día |
| Lista con + | Registrar | Agregar comidas |
| Manzana | Alimentos | Catálogo |
| Gorro de chef | Recetas | Recetas propias |
| Gráfica | Progreso | Peso y meta corporal |
| Diana | Objetivos diarios | Rangos y pesos del puntaje |

La fecha elegida en Diario y Registrar queda en la URL (`?d=AAAA-MM-DD`), así que se puede recargar o compartir el enlace sin perder el día. Sin parámetro, se usa hoy.

---

## 4. Diario

- **Navegación por días:** día anterior, día siguiente e "Ir a hoy" (aparece solo cuando no estás en hoy).
- **Puntaje del día** en un anillo de 0 a 100 que se anima al cargar. Color según nivel: bueno (≥ 85), medio (≥ 60) o bajo (< 60). Si el día está vacío muestra "–".
- **Barras por macro:** consumo actual, zona objetivo (min–max) marcada en la barra y el puntaje de cada macro (en pantallas anchas). El valor se resalta con el color del macro cuando está fuera de rango.
- **Comidas agrupadas** en desayuno, almuerzo, once, cena y snack, cada una con su subtotal de macros. Solo aparecen las comidas que tienen registros.
- **Cada registro** muestra nombre, gramos, porciones (si es receta), macros y un ícono de chef si es receta.
- **Eliminar** un registro con el ícono de papelera.
- **Botón para registrar** que abre Registrar en la misma fecha.
- Cada registro guarda una **copia de sus macros** al momento de guardarse: si después se edita el alimento, los días pasados no cambian.
- **Repetir comidas:** la tarjeta "Repetir de ayer" y el botón "Copiar de otro día" copian comidas con los macros del catálogo actual ([actividad-y-perfil.md](actividad-y-perfil.md)).

---

## 5. Registrar comidas con una lista

1. **Elegir fecha y comida.** La comida se propone según la hora: antes de las 11 desayuno, antes de las 16 almuerzo, antes de las 20 once y después cena (se puede cambiar; snack nunca se propone).
2. **Escribir o pegar la lista**, un alimento por línea (también sirven `;` y `,`). Ejemplo:
   ```
   Arroz 100g
   1 Tomate mediano
   Huevos x3
   Atún 150g
   ```
3. **Analizar** con el botón o con `Ctrl+Enter`. Si el campo está vacío se analiza el ejemplo, para probar el flujo rápido.
4. **Revisar el resultado.** Cada línea muestra el texto original, el alimento o receta reconocido, la confianza (%), los gramos, cómo se calcularon (p. ej. "3 × unidad (50 g)") y sus macros. Cada ítem queda en uno de tres estados:

   | Estado | Ícono | Cuándo |
   |---|---|---|
   | Reconocido | ✓ verde | Confianza ≥ 85 %, sin ambigüedad y cantidad explícita |
   | Revisar | ! amarillo | Confianza entre 60 % y 85 %, dos candidatos casi empatados (diferencia ≤ 3 puntos) o cantidad supuesta |
   | Falta | ? rojo | Confianza < 60 %: el alimento no está en el catálogo |

5. **Corregir lo que haga falta:**
   - Tocar el nombre reconocido abre un **buscador** de alimentos y recetas para cambiar la coincidencia (lo elegido a mano queda como reconocido).
   - **Editar los gramos** directamente; los macros se recalculan y el ítem pasa a reconocido.
   - **Quitar** un ítem de la lista.
   - En los faltantes: **buscar** en el catálogo o **crear** el alimento ahí mismo; al guardarlo se asigna al ítem sin esperar a que llegue al catálogo.
6. **Escanear un código de barras** (botón junto a Analizar):
   - Si el producto ya está en el catálogo, se agrega con su porción por defecto para ajustar los gramos.
   - Si no está, se abre el formulario de alimento con el código y se busca en Open Food Facts automáticamente; al guardarlo se agrega a la lista.
   - Los ítems escaneados se conservan aunque se vuelva a analizar el texto.
7. **Guardar.** El pie muestra el total de macros y el conteo "ok · revisar · faltan". No se puede guardar mientras quede algún faltante. Las entradas se guardan juntas (escritura en lote), respetan el orden de la lista y la app vuelve al Diario de esa fecha.

---

## 6. Cómo se interpreta la lista

El código está en `src/core` y no depende de React ni de Firebase.

### 6.1 Separar y leer cada línea (`core/parser/ruleParser.ts`)

- **Separadores:** salto de línea, `;` y comas que no sean decimales (`1,5 kg` no se corta). Se quitan viñetas (`-`, `*`, `•`, `·`, `2)`).
- **Cantidades:** enteros y decimales con punto o coma (`1,5`), fracciones (`1/2`), mixtos (`1 1/2`), multiplicadores (`x3`, `3x`, `3 x`), "un par de" (= 2) y números en palabras (`un`, `una`, `medio`, `dos` … `diez`, `doce`) **solo al inicio** de la línea, para no romper nombres como "torta tres leches".
- **Unidades reconocidas:**

  | Unidad | Escrituras aceptadas |
  |---|---|
  | g | g, gr, grs, gramo(s); kg, kilo(s) (× 1000) |
  | ml | ml, cc, mililitro(s); l, lt, litro(s) (× 1000) |
  | unidad | unidad(es), u, ud(s), und, pieza(s) |
  | porción | porción(es), plato(s) |
  | taza, vaso | taza(s), vaso(s) |
  | cda / cdta | cucharada(s), cda(s) / cucharadita(s), cdta(s), cdita(s) |
  | rebanada | rebanada, lámina, lonja, tajada, rodaja (y plurales) |
  | lata, scoop | lata(s); scoop(s), medida(s) |

- **Tamaños:** pequeño/a, chico/a, mediano/a, grande(s).
- **Cantidades vagas** ("un poco de", "poquito", "algo", "porcioncita"): la cantidad se marca como supuesta y el ítem queda en **revisar**.
- **Número sin unidad:** desde 20 se interpreta como gramos ("arroz 150" = 150 g); bajo 20, como unidades ("huevos 3").
- Se quitan conectores al borde ("de", "con", "la"…), tildes y signos. Si solo queda la cantidad, la línea se descarta.

### 6.2 Buscar en el catálogo (`core/matcher.ts`)

1. **Coincidencia exacta** con el nombre o un alias del alimento o receta, también en singular aproximado del español (tomates → tomate, panes → pan, nueces → nuez). Confianza 100 %.
2. Si no hay exacta, **Fuse.js** recupera candidatos (umbral 0.45, sin importar tildes), buscando la frase completa y cada palabra de 3 o más letras.
3. Los candidatos se **ordenan por similitud de palabras**: F1 entre cuántas palabras de la consulta cubre el término y viceversa, con tolerancia a errores de tipeo (Levenshtein, similitud ≥ 0.75 por palabra). Así "pan" contra "pan marraqueta" da 67 %: coincide pero queda para revisar.
4. A igual confianza ganan las **recetas** y luego los nombres más cortos.

### 6.3 Pasar la cantidad a gramos (`core/quantity.ts`)

Para un alimento, en este orden:

1. `g` → tal cual. `ml` → ml × densidad del alimento (1 si no tiene).
2. Tamaño escrito ("mediano") → la porción con ese nombre.
3. Unidad escrita ("taza") → la porción con ese nombre.
4. Sin unidad o "unidad" → la porción por defecto: unidad, mediano, porción o la primera definida.
5. Si el alimento no define esa porción, **porciones genéricas**: taza 240 ml, vaso 200 ml, cda 15 ml, cdta 5 ml (por la densidad) y scoop 30 g. Queda como supuesta.
6. Si nada calza: **100 g supuestos**.

Para una receta: por **porciones** ("Pollo al limón 2 porciones", 1 si no se indica) o por **peso** ("300 g", proporcional al total de la receta).

---

## 7. Catálogo de alimentos

- **Catálogo público:** todos los usuarios ven los mismos alimentos y cualquiera puede agregar. Solo quien creó un alimento puede editarlo.
- **Lista** ordenada alfabéticamente (máximo 150 filas visibles) con nombre, marca, macros por 100 g y equivalencias. Íconos: código de barras, verificado, creado por ti o por otro usuario.
- **Búsqueda** con el mismo buscador tolerante de la lista. Si escribes solo dígitos (4 o más), busca por **código de barras**.
- **Catálogo base:** botón para importar 76 alimentos comunes (valores aproximados de USDA FoodData Central y etiquetas locales, marcados como no verificados). Solo importa los que faltan. Si tus alimentos importados antes no tenían fibra, el mismo botón la completa. Se deshabilita cuando no queda nada pendiente.
- **Crear o editar un alimento** (formulario):
  - Nombre (obligatorio, hasta 120 caracteres), marca y alias separados por coma (p. ej. "palta, aguacate").
  - **Valores por 100 g** de las cinco variables. La fibra es opcional (0 si se deja vacía).
  - Si faltan las kcal se **calculan con Atwater** (4/4/9) desde proteína, carbohidratos y grasa; también hay un botón para hacerlo a mano.
  - **Aviso** si las kcal escritas no calzan con los macros (diferencia mayor a 25 kcal y al 20 %).
  - Validaciones: ningún valor negativo y proteína + carbohidratos + grasa ≤ 100 g por 100 g.
  - **Equivalencias en gramos** para que la lista entienda medidas: unidad, pequeño, mediano, grande, taza, vaso, cda, cdta, rebanada, lata, scoop, porción y ml (densidad, solo líquidos). Se agregan tocando la medida.
  - Código de barras (ver sección siguiente).

---

## 8. Códigos de barras y Open Food Facts

- **Lector con la cámara:** usa el `BarcodeDetector` del navegador si existe (Chrome en Android) y, si no, `zxing-wasm` (iOS Safari, Firefox), que se descarga solo al abrir la cámara. Prefiere la cámara trasera, lee cada 200 ms y vibra al detectar.
- **Formatos:** EAN-13, EAN-8, UPC-A y UPC-E. Se valida el dígito verificador y UPC-A se normaliza a EAN-13 (se antepone un 0).
- **Escritura manual** del código en el mismo lector si la cámara no está disponible.
- **Mensajes claros** cuando no hay permiso, no hay cámara, está ocupada o la conexión no es HTTPS.
- **Aviso de duplicado** si ya existe otro alimento con el mismo código.
- **Open Food Facts:** con un código válido se traen nombre (en español si existe), marca, macros por 100 g (convierte kJ a kcal si hace falta) y la porción de la etiqueta. Solo **se rellenan los campos vacíos** y se muestra un enlace a la ficha para compararla con la etiqueta. El alimento queda marcado con origen OFF y licencia ODbL.
- Límites: ~15 consultas por minuto por usuario; tiempo de espera de 8 s; si la API no responde se informa sin bloquear el formulario.

---

## 9. Recetas

- **Recetas privadas** de cada usuario, ordenadas por nombre, con porciones, número de ingredientes y macros por porción.
- **Editor:**
  - Nombre (es como la reconocerá la lista), porciones y alias.
  - Ingredientes elegidos del catálogo (solo alimentos, no otras recetas) con sus gramos, y macros por ingrediente.
  - Si un ingrediente no existe, se crea ahí mismo.
  - Totales de la receta (gramos y macros) y por porción.
  - Solo se guarda con nombre, porciones > 0, al menos un ingrediente, todos con gramos > 0 y ninguno eliminado del catálogo.
  - Eliminar receta con confirmación.
- **Recálculo automático:** al cargar el catálogo, los macros de cada receta se recalculan desde sus ingredientes, así reflejan correcciones del catálogo (si falta un ingrediente se conserva lo guardado).
- **En la lista** se reconocen por nombre o alias: "Pollo al limón 2 porciones" o "Pollo al limón 300 g".

---

## 10. Objetivos diarios y puntaje

- **Rangos min–max** por macro. Valores por defecto:

  | Macro | Rango | Peso |
  |---|---|---|
  | kcal | 2200–2600 | 40 |
  | Proteína | 120–160 g | 25 |
  | Carbohidratos | 220–320 g | 20 |
  | Grasa | 60–90 g | 15 |
  | Fibra | 25–40 g | 10 |

- **Pesos ajustables** (0 a 100, de 5 en 5) que se normalizan para sumar 100 %; se muestra el porcentaje real de cada macro.
- Validación: mínimo ≥ 0 y máximo ≥ mínimo. Botón para restaurar los valores por defecto.
- **Puntaje de un macro:** 100 dentro del rango (bordes incluidos). Bajo el mínimo cae en proporción a lo que falta respecto del mínimo; sobre el máximo, en proporción a lo que sobra respecto del máximo; nunca baja de 0.
- **Puntaje del día:** promedio ponderado de los cinco puntajes con los pesos normalizados (si todos los pesos son 0, se reparten por igual).
- Es una **hipótesis de diseño**, no una fórmula validada.

---

## 11. Progreso corporal

- **Meta:** perder peso, mantener o ganar masa muscular, con peso objetivo (20–400 kg; opcional para mantener) y fecha desde la que se mide. Avisa si el objetivo va en la dirección contraria al último peso (p. ej. "perder" con una meta mayor).
- **Registro de peso:** uno por día; registrar otra vez el mismo día lo reemplaza (se avisa antes). Fecha hasta hoy.
- **Gráfica** de peso con períodos de 30 días, 90 días o todo, línea de la meta, detalle al pasar el dedo o el mouse y navegación con flechas del teclado.
- **Indicadores:**
  - Peso actual y su fecha.
  - Cambio desde el inicio de la meta, con ✓ si va hacia la meta o aviso si se aleja (para mantener, ✓ si el cambio es ≤ 1 kg).
  - Ritmo en kg por semana: regresión lineal de las últimas 4 semanas.
  - Kilos que faltan para la meta.
  - Fecha estimada de llegada: solo si la tendencia va hacia la meta y la fecha cae dentro de 3 años.
  - Porcentaje logrado con barra de avance (solo perder o ganar).
- **Historial** de los últimos 60 registros con la diferencia contra el anterior y opción de eliminar.
- Es una proyección simple, no una recomendación médica.

---

## 12. Interfaz y accesibilidad

- **Paleta Gruvbox** con aqua como color principal (gradiente aqua → azul). Tema oscuro por defecto y tema claro; la elección se recuerda en el navegador.
- **Botones pequeños con íconos**, cada uno con nombre accesible y tooltip; texto visible solo en acciones principales (Analizar, Guardar, Crear).
- **Pensada para móvil:** ancho máximo de 2xl, barra inferior fija, respeta las zonas seguras de iPhone y evita el zoom de iOS al enfocar campos.
- **Animaciones** de entrada, contadores y barras; se desactivan si el sistema pide reducir el movimiento.
- **Avisos** (toasts) para confirmaciones y errores; los errores de conexión con Firestore aparecen arriba de la pantalla.
- **Ventanas modales** que se cierran con Escape (solo la de más arriba si hay varias).
- Estados nunca indicados solo por color: siempre hay ícono o texto.

---

## 13. Datos y seguridad

### Firestore

| Ruta | Contenido | Quién accede |
|---|---|---|
| `foods/{id}` | Alimento: nombre, alias, marca, código, macros por 100 g, porciones, densidad, origen, verificado, creador | Lee cualquier usuario autenticado; crea cualquiera (como creador); edita o borra solo el creador |
| `recipes/{id}` | Receta: dueño, nombre, alias, porciones, ingredientes, totales y por porción | Solo el dueño |
| `users/{uid}` | Objetivos (`goals`) y meta corporal (`bodyGoal`) | Solo el usuario |
| `users/{uid}/days/{AAAA-MM-DD}/entries/{id}` | Registro del diario con copia de macros, comida, texto original y orden | Solo el usuario |
| `users/{uid}/weights/{AAAA-MM-DD}` | Peso del día | Solo el usuario |

Las reglas (`firestore.rules`) validan además nombre (1–120 caracteres), hasta 20 alias y 20 porciones, código de hasta 14 dígitos y macros numéricos no negativos. Hay que republicarlas cuando cambian.

### Origen de los datos de un alimento

`MANUAL` (catálogo base), `USER` (creado por un usuario), `OFF` (Open Food Facts, ODbL). Los tipos `USDA` y `CHILE_TABLE` están previstos pero no se usan todavía.

---

## 14. Pruebas automáticas

`npm test` ejecuta 65 pruebas (Vitest) sobre `src/core`:

| Archivo | Cubre |
|---|---|
| `ruleParser.test.ts` | Separación de ítems, cantidades, unidades, fracciones y la lista de ejemplo de la tesis |
| `resolve.test.ts` | Búsqueda (alias, plural, errores de tipeo), estados ok/revisar/falta, porciones genéricas, recetas y corrección de gramos |
| `score.test.ts` | Puntaje por macro y del día, pesos y Atwater |
| `macros.test.ts` | Fibra en datos antiguos, escalado y suma |
| `progress.test.ts` | Tendencia, porcentaje, fecha estimada y casos sin datos |
| `barcode.test.ts` | Validación GTIN y lectura de productos de Open Food Facts |

Las pantallas no tienen pruebas automáticas.

---

## 15. Límites conocidos

- **Registros del diario:** solo se pueden eliminar; no se editan los gramos ni se cambian de comida después de guardar.
- **Alimentos:** no se pueden eliminar desde la app (las reglas lo permiten al creador, pero no hay botón). Los de otros usuarios no se pueden corregir.
- **Recetas:** no admiten otras recetas como ingrediente ni se comparten.
- **Interpretación sin IA:** frases complejas o con varios alimentos en una línea ("arroz con pollo y ensalada") pueden necesitar corrección manual. Los prototipos con embeddings o LLM (P2–P4) siguen pendientes.
- **Sin modo sin conexión** ni historial o reportes de varios días más allá de navegar el diario.
- **Valores aproximados:** el catálogo base (incluida la fibra) no está verificado y Open Food Facts puede traer errores.
- **Puntaje y proyección de peso** son hipótesis de diseño.
- Sin fotos de comida, sin integración con Apple Health / Health Connect y sin cruce con fuerza o cardio.

---

## 16. Navegación entre módulos

- El encabezado tiene un **selector de módulos** con tres íconos: Nutrición (ensalada), Fuerza (pesa) y Cardio (corazón con pulso). El módulo activo se resalta con el gradiente y muestra su nombre; los demás muestran solo el ícono con tooltip.
- Los módulos aún no disponibles llevan un **punto amarillo** y su tooltip dice "en desarrollo".
- **Cardio** (`/cardio`) muestra una tarjeta con la franja "En desarrollo", un ícono de obras, una descripción breve y un botón para volver a Nutrición.
- Cada módulo tiene su propia barra inferior de secciones (Nutrición: seis; Fuerza: Entrenar, Historial, Progreso y Ejercicios).
- Las rutas de Nutrición siguen en la raíz (`/`, `/registrar`, …) para no romper enlaces existentes; Fuerza vive bajo `/fuerza`. La lista de módulos está en `src/app/modules.ts` y las secciones de cada uno en `src/app/Layout.tsx`.
