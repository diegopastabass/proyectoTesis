# Plan de implementación — Módulo de Nutrición (prototipo)

> Proyecto de título: *Solución tecnológica para el registro, cruce de datos y análisis del entrenamiento concurrente y la nutrición en deportistas aficionados.*
> Fecha: 2026-10-21 · Estado: propuesta para revisión

---

## 1. Resumen

Este documento define un prototipo web del **módulo de nutrición** que sirve para dos cosas a la vez:

1. Entregar una primera versión usable del registro de comidas.
2. Descubrir qué piezas son realmente necesarias y cuáles sobran antes de construir el MVP completo (fuerza + cardio + cruce de datos).

El stack pedido es **React + Vite + Tailwind** en el frontend y **Firebase** como backend y persistencia. Para el procesamiento de listas en lenguaje natural se propone una **comparación de 3–4 prototipos** (reglas, embeddings locales, LLM gratuito), no una sola decisión tomada de antemano.

### Decisiones propuestas (requieren tu confirmación)

| # | Decisión | Propuesta | Alternativa |
|---|----------|-----------|-------------|
| D1 | Frontend | React 18/19 + Vite + Tailwind + **PWA** instalable | Ya alineado con el plan futuro de React Native (lógica en `src/core` sin dependencias de React) |
| D2 | Backend / persistencia | **Firestore + Firebase Auth + Hosting** (plan Spark) | Blaze si se necesitan Cloud Functions con claves secretas |
| D3 | Acceso al LLM | **Firebase AI Logic** (Gemini Developer API) llamado desde el cliente, protegido con **App Check** | Cloud Function como proxy (requiere Blaze) para usar Groq/OpenRouter con claves ocultas |
| D4 | Base de alimentos | Semilla curada en JSON versionado + importación a Firestore; los alimentos nuevos los crea el usuario | Open Food Facts en vivo (ver licencia en §8) |
| D5 | Color principal | **Aqua** de Gruvbox (`#8ec07c`) como "cyan" + gradiente aqua→azul (`#8ec07c → #83a598`) | Gruvbox no tiene un cyan con ese nombre; `aqua` es el equivalente más cercano. Confírmalo. |
| D6 | Puntaje | Puntaje 0–100 por rangos min/max de kcal, proteína, carbohidratos y grasa, con pesos configurables | Ver §6 |

---

## 2. Alcance del prototipo de nutrición

**Incluye**

- Autenticación básica (correo/Google) y perfil con objetivos diarios por rango (min/max).
- Buscador de alimentos y registro manual con gramos o porciones (RF-08 de la tesis).
- Registro de comidas por **lista en lenguaje natural** (requisito 1), con descomposición en ítems, resolución contra la base y cálculo de macros.
- **Registro de alimento faltante** cuando no hay coincidencia o la confianza es baja (requisito 2).
- **Puntaje diario** de cumplimiento de objetivos (requisito 3).
- **Recetas** con ingredientes y cálculo de macros por porción; reconocimiento por nombre al escribirlas en la lista (requisito 4).
- Pantalla de diario del día con barras de progreso, UI Gruvbox, botones pequeños con íconos.

**No incluye (queda para después, pero se deja el modelo preparado)**

- Fotos de comida con visión artificial (RF-04).
- Cruce con fuerza y cardio, fatiga cruzada (otros módulos).
- Feed social y escalado de recetas comunitarias (RF-05, RF-09).
- Integración con Apple Health / Health Connect.
- Versión React Native.

**Criterio de éxito del prototipo** (medible, ver §10): ≥ 85 % de ítems de una lista de prueba resueltos correctamente, error de gramos ≤ 15 % en los ítems resueltos, y ninguna comida registrada sin posibilidad de corregirla.

---

## 3. Arquitectura

```
┌─────────────────────────── Cliente (PWA) ───────────────────────────┐
│ React + Vite + Tailwind (tema Gruvbox)                              │
│  ├─ UI: Diario, Buscador, Lista NL, Recetas, Objetivos              │
│  ├─ src/core/  ← lógica pura (macros, puntaje, parser, matching)    │
│  │               sin React: reutilizable en React Native             │
│  └─ src/services/ ← adaptadores: Firestore, AI provider, catálogo   │
└───────────────┬───────────────────────────┬─────────────────────────┘
                │ Firestore SDK            │ Firebase AI Logic (App Check)
┌───────────────▼──────────────┐   ┌───────▼──────────────────────────┐
│ Firestore                    │   │ Gemini 2.5 Flash-Lite (free tier)│
│  foods, recipes, users,      │   │  - Paso 1: texto → JSON de ítems │
│  days/entries, parseRuns     │   │  - Paso 2: elegir entre         │
│ Firebase Auth                │   │    candidatos (opcional)         │
└──────────────────────────────┘   └──────────────────────────────────┘
```

**Principio clave:** el LLM **nunca** decide macros. Solo transforma texto en ítems estructurados y, si es necesario, elige entre candidatos que ya existen en la base. Los macros siempre salen de la base de datos con aritmética determinista. Esto reduce alucinaciones y permite auditar cada cifra.

**Abstracción del proveedor de IA:** una interfaz `NutritionParser` con implementaciones `RuleParser`, `EmbeddingParser` y `LLMParser`. Así cambiar de Gemini a Groq u OpenRouter es un cambio de adaptador, no de arquitectura.

---

## 4. Modelo de datos (Firestore)

```
users/{uid}
  displayName, createdAt
  goals: {
    kcal:    { min, max },
    protein: { min, max },   // g
    carbs:   { min, max },   // g
    fat:     { min, max },   // g
    weights: { kcal, protein, carbs, fat }   // suma = 1
  }

foods/{foodId}
  name, normalizedName, aliases[], brand?
  per100g: { kcal, protein, carbs, fat, fiber? }
  portions: [{ name: "unidad" | "mediano" | "taza", grams }]
  source: { type: "USDA" | "OFF" | "CHILE_TABLE" | "USER" | "MANUAL", ref?, license }
  verified: boolean, createdBy, createdAt

recipes/{recipeId}
  ownerId, name, normalizedName, aliases[]
  servings
  ingredients: [{ foodId, grams }]
  macrosPerServing: { kcal, protein, carbs, fat }   // recalculado al guardar
  visibility: "PRIVATE"   // PUBLIC queda para el módulo social

users/{uid}/days/{YYYY-MM-DD}/entries/{entryId}
  kind: "food" | "recipe"
  foodId | recipeId | null          // null = alimento no reconocido
  customName?                       // texto usado si no hay foodId
  grams, servings?
  macros: { kcal, protein, carbs, fat }   // snapshot al momento del registro
  rawInput?, parseRunId?, createdAt

parseRuns/{runId}                    // solo para evaluación del prototipo
  uid, rawText, provider, model, output, latencyMs, tokens, createdAt
```

**Notas**

- **Snapshot de macros en cada entrada:** si después se corrige la base de datos, el histórico no cambia. Importante para la tesis.
- Los `macros` de una entrada se calculan una sola vez y se guardan; el diario del día solo suma.
- `parseRuns` existe para medir el prototipo. Se puede quitar al terminar la evaluación si no aporta.

### Reglas de seguridad (esquema)

- `users/{uid}` y sus subcolecciones: lectura y escritura solo para `request.auth.uid == uid`.
- `foods`: lectura para usuarios autenticados; escritura para autenticados; los alimentos con `verified: false` se marcan visualmente.
- `recipes` privadas: solo el dueño.

---

## 5. Flujo del registro por lista en lenguaje natural

```
Texto libre
  │
  ▼
[1] Normalización   → quitar tildes, minúsculas, separar por líneas o comas
  │
  ▼
[2] Extracción      → por ítem: { raw, query, quantity, unit }
  │                   (reglas, o LLM con esquema JSON)
  ▼
[3] Recetas         → ¿query coincide con una receta del usuario? → usar receta
  │
  ▼
[4] Matching        → coincidencia exacta normalizada → fuzzy (Fuse.js) → embeddings
  │                   devuelve top-5 candidatos con score
  ▼
[5] Desambiguación  → si score ≥ umbral: aceptar
  │                   si no: LLM elige entre candidatos (o "ninguno")
  ▼
[6] Conversión      → unidad → gramos (tabla portions del alimento)
  │                   "1 tomate mediano" → 120 g; "x3" huevos → 3 × 50 g
  ▼
[7] Cálculo         → macros = per100g × grams / 100 (determinista)
  │
  ▼
[8] Revisión        → el usuario ve la lista con confianza por ítem y edita
  │
  ▼
[9] Guardar         → entradas en el diario; ítems sin match → "Crear alimento"
```

### Esquema de salida del LLM (paso 2)

```json
{
  "items": [
    {
      "raw": "Huevos x3",
      "query": "huevo",
      "quantity": 3,
      "unit": "unidad",
      "notes": null
    }
  ]
}
```

Se usa salida estructurada (JSON Schema) para evitar parseo frágil. Prompt corto, con 3–5 ejemplos de la propia tesis y de nombres chilenos (*marraqueta, palta, porotos, charquicán*).

### Cuándo se llama al LLM

Solo para ítems que las reglas no resuelven con confianza. Esto reduce llamadas y consumo de cuota gratuita. La medición de cuántas llamadas se evitan es un resultado útil para la tesis.

---

## 6. Puntaje de cumplimiento

Para cada macro *m* con rango `[min, max]` y valor real `v`:

```
s_m = 100                                  si  min ≤ v ≤ max
s_m = max(0, 100 × (1 − (min − v) / min))  si  v < min
s_m = max(0, 100 × (1 − (v − max) / max))  si  v > max
```

Puntaje total:

```
Score = Σ (w_m × s_m)     con  Σ w_m = 1
```

Pesos por defecto (propuesta, configurables por usuario): kcal 0.40 · proteína 0.25 · carbohidratos 0.20 · grasa 0.15.

**Por qué así:** es simple de explicar en la tesis, no castiga de forma abrupta por estar apenas fuera del rango y los pesos se pueden ajustar. **Estos valores son una hipótesis a validar**; no tienen respaldo bibliográfico todavía. Conviene dejarlo explícito en el documento.

Casos de prueba unitarios: rango dentro (100), 10 % bajo el mínimo, 50 % sobre el máximo, valor 0, rango con mínimo 0.

---

## 7. Recetas

1. El usuario define nombre, porciones e ingredientes (buscador de alimentos + gramos).
2. Al guardar, se calculan `macrosPerServing = Σ macros_ingrediente / servings`.
3. En la lista NL, el paso [3] busca primero recetas del usuario por nombre normalizado y alias. Si coincide, la entrada usa la receta con `servings` (o gramos) indicados.
4. Si una receta tiene ingredientes sin `foodId` válido, no se puede guardar: se fuerza a resolverlos antes.

Esto cumple el requisito 4: al escribir "Pollo al limón" en la lista, el sistema reconoce la receta y suma sus macros por ingredientes.

---

## 8. Fuentes de datos de alimentos

| Fuente | Licencia | Acceso | Uso propuesto | Observaciones |
|--------|----------|--------|---------------|---------------|
| **USDA FoodData Central** | CC0 (dominio público) | API con clave gratuita (api.data.gov) | Base principal de macros por 100 g (datos en inglés) | Límite por IP y hora; la clave `DEMO_KEY` es muy restrictiva. Hay que traducir nombres. Fuentes sobre el límite no coinciden: confirmar en la documentación. |
| **Open Food Facts** | ODbL (atribución + compartir igual) | API pública, sin clave; exige `User-Agent` propio | Productos envasados, con código de barras | Si la base combinada se distribuye, la ODbL aplica a la base completa. Para una tesis no hay problema; para publicar la app, revisar. |
| **Tabla de composición química de alimentos chilenos** (Universidad de Chile, 1990) | Acceso abierto en el repositorio | PDF | Referencia para alimentos chilenos (marraqueta, porotos, etc.) | **Desactualizada.** El Minsal indica que Chile necesita una tabla nacional actualizada (proyecto FAO TCP/RLA/3107). Citar con esa salvedad. |
| **Etiquetas nutricionales / curación manual** | — | Manual | Alimentos locales sin dato oficial | Registrar siempre el origen en `source` |

**Semilla inicial propuesta:** ~150 alimentos (≈ 80 de USDA traducidos y revisados, ≈ 40 chilenos o de supermercado locales, ≈ 30 básicos de entrenamiento como avena, arroz, pollo, plátano, papa, pan). Cada ítem con `verified: true` solo si se revisó a mano.

**Unidades:** tabla `portions` por alimento (huevo = 50 g, tomate mediano ≈ 120 g, etc.). Los valores vienen de fuentes de pesos típicos y se marcan como aproximados.

---

## 9. Interfaz (Gruvbox + Tailwind)

### Paleta (modo oscuro por defecto; modo claro como segunda opción)

| Token | Oscuro | Claro | Uso |
|-------|--------|-------|-----|
| `bg` | `#282828` | `#fbf1c7` | Fondo |
| `surface` | `#3c3836` | `#ebdbb2` | Tarjetas |
| `border` | `#504945` | `#d5c4a1` | Bordes |
| `fg` | `#ebdbb2` | `#3c3836` | Texto |
| `muted` | `#a89984` | `#7c6f64` | Texto secundario |
| `primary` | `#8ec07c` (aqua) | `#689d6a` | Acciones principales |
| `primary-2` | `#83a598` (blue) | `#458588` | Fin del gradiente |
| `success` | `#b8bb26` | `#79740e` | Puntaje alto |
| `warning` | `#fabd2f` | `#b57614` | Puntaje medio |
| `danger` | `#fb4934` | `#9d0006` | Puntaje bajo, errores |

Gradiente principal: `linear-gradient(135deg, #8ec07c, #83a598)`.

Se definen como tokens en `tailwind.config` y en variables CSS (`:root`) para poder cambiar de tema sin tocar componentes.

### Componentes

- **Botones pequeños** (`h-8 px-2`) con ícono y `aria-label` obligatorio. Íconos con `lucide-react` (ligero, con tree-shaking). El texto solo aparece en el menú o como `title` (tooltip).
- Barras de progreso por macro con color según el puntaje.
- Lista NL con filas editables; cada ítem muestra un indicador de confianza (color + ícono) y botón para corregir.
- "Crear alimento" aparece automáticamente cuando un ítem no tiene coincidencia.
- Diseño móvil primero (la app final es móvil).

---

## 10. Prototipos y experimentos

Esta es la parte que responde a "qué necesito realmente". Se construyen cuatro variantes del paso de extracción y matching con el mismo conjunto de prueba.

| Prototipo | Descripción | Costo | Dependencia de red |
|-----------|-------------|-------|--------------------|
| **P1 · Reglas** | Expresiones regulares para cantidad y unidad + Fuse.js sobre nombres y alias | $0 | No |
| **P2 · Embeddings locales** | P1 + búsqueda semántica con un modelo multilingüe ejecutado en el navegador (transformers.js) | $0 | No (tras la primera descarga) |
| **P3 · LLM gratuito (Gemini)** | Extracción con Gemini 2.5 Flash-Lite vía Firebase AI Logic + elección entre candidatos | $0 en cuota gratuita | Sí |
| **P4 · LLM alternativo** | Mismo P3 con Groq u OpenRouter (modelos gratuitos) | $0 en cuota gratuita | Sí |

### Conjunto de prueba

- 60–80 líneas escritas a mano, con etiquetas: alimento esperado, cantidad, unidad, macros esperados.
- Incluye los ejemplos de la tesis (*Arroz 100g, 1 Tomate mediano, Huevos x3, Atún 150g*), ambigüedades (*un poco de aceite*, *pan*), nombres chilenos y errores de tipeo.
- Se separa en 50 % desarrollo y 50 % evaluación para no ajustar el prompt sobre el mismo conjunto.

### Métricas

- Precisión y recall de extracción de ítems.
- % de ítems resueltos correctamente sin intervención del usuario.
- Error absoluto en gramos y en kcal.
- Latencia p50 / p95.
- Llamadas externas por registro (para estimar cuota).
- Tasa de errores por límite de cuota (429).

### Decisión

Se elige el prototipo con mejor balance entre precisión, latencia y costo. Si P1 o P2 alcanzan el criterio de éxito, **el LLM no se incluye en el MVP**, lo que simplifica la arquitectura y elimina la dependencia de terceros. Esto es un resultado válido para la tesis.

---

## 11. Modelos de lenguaje: investigación de opciones gratuitas o económicas

> **Advertencia:** las cifras de cuotas provienen de blogs de terceros que se contradicen entre sí. Los números de abajo son orientativos. Antes de decidir, verificar cada uno en la consola del proveedor. Fecha de la consulta: octubre 2026.

| Opción | Tipo | Modelos sugeridos | Cuota gratuita (orientativa) | Pros | Contras |
|--------|------|-------------------|------------------------------|------|---------|
| **Google Gemini API** (vía Firebase AI Logic) | Nube, gratuita con límites | Gemini 2.5 Flash-Lite, Gemini 2.5 Flash | Flash-Lite: ~15 RPM, ~250k TPM, ~1.000 RPD según tabla de Google (verificar en AI Studio) | Integración directa con Firebase; salida JSON estructurada; App Check protege la clave | El nivel gratuito no es para uso comercial y puede usar los datos para mejorar productos (revisar términos); límites cambiaron en 2026; Gemini 1.5 Flash ya no está disponible |
| **Groq** | Nube, gratuita | Llama 3.1 8B, Llama 3.3 70B, Qwen3 32B, gpt-oss-120b | Típicamente ~30 RPM; cifras de RPD contradictorias | Muy rápido; sin tarjeta de crédito | Requiere función de nube para no exponer la clave; modelos cambian con el tiempo |
| **OpenRouter** | Agregador | Modelos con sufijo `:free` (Qwen3 Coder, gpt-oss, Gemma, Nemotron, etc.) | ~20 RPM; 200 RPD, o 1.000 RPD con recarga de US$ 10 (fuentes distintas) | Una sola API para comparar muchos modelos; ideal para el bake-off | Los modelos gratuitos rotan sin aviso y se saturan en horas punta; calidad variable |
| **Mistral (plan gratuito)** | Nube | Mistral Small / Ministral | Sin verificar | Europeo, buena calidad en español | No verificado en esta investigación |
| **Modelo local (Ollama)** | Local, $0 | Qwen2.5 3B/7B, Llama 3.2 3B, Gemma | Sin límites | Sin costo ni datos fuera del equipo; útil para evaluación | No sirve para una app desplegada; requiere equipo con RAM/GPU |
| **Embeddings en navegador (transformers.js)** | Local en el cliente, $0 | Modelo multilingüe MiniLM u otro de Hugging Face | Sin límites | "Predictivo" real, sin API ni claves; funciona offline tras la descarga | Descarga inicial pesada (decenas de MB); menos flexible que un LLM para entender frases |
| **Reglas + Fuse.js** | Determinista, $0 | — | — | Cero costo y cero latencia; fácil de auditar | Menos tolerante a frases libres |

### Recomendación

1. **Empezar con P1 (reglas + Fuse.js).** Es lo más barato y sirve de línea base. Probablemente resuelva la mayoría de las líneas del ejemplo.
2. **Probar P2 (embeddings en navegador)** como alternativa "predictiva" sin costo.
3. **Usar Gemini 2.5 Flash-Lite vía Firebase AI Logic (P3)** como LLM principal para casos ambiguos, porque evita un servidor propio y encaja con Firebase.
4. **Usar OpenRouter (P4)** solo para comparar modelos en el bake-off, no en producción.

Costo estimado en el peor caso: pocas llamadas por usuario por día (cada registro usa un LLM solo para ítems ambiguos), por lo que el nivel gratuito alcanza para un prototipo. Verificar con la consola antes de depender de ello.

### Riesgos de usar un LLM con datos de salud

- Los textos de comida son datos de salud en sentido amplio. Enviar solo la línea de texto, nunca el correo, el nombre ni el UID.
- Revisar los términos del nivel gratuito: si los datos pueden usarse para entrenar, dejarlo explícito en la tesis o usar un nivel de pago.
- La normativa de datos personales que ya revisas (carpeta `normativas`) exige informar el tratamiento al usuario y darle opción de borrar sus datos.

---

## 12. Fases y cronograma sugerido

> El objetivo general de la tesis fija el cierre antes de diciembre de 2026. Quedan unas 6 semanas desde hoy, así que el cronograma es ajustado. Conviene recortar alcance antes que la calidad de la evaluación.

| Fase | Entregable | Duración estimada |
|------|------------|-------------------|
| **0 · Base** | Repositorio git, proyecto Vite + Tailwind, tokens Gruvbox, proyecto Firebase, Auth, reglas de seguridad | 3 días |
| **1 · Catálogo** | Semilla de ~150 alimentos (JSON + script de carga), buscador por nombre y alias | 4 días |
| **2 · Diario manual** | Registro por gramos/porciones (RF-08), resumen diario, barras de progreso | 3 días |
| **3 · Objetivos y puntaje** | Pantalla de rangos min/max, cálculo de puntaje (§6) con pruebas unitarias | 3 días |
| **4 · Lista NL (P1)** | Parser por reglas + matching + revisión de ítems | 4 días |
| **5 · Faltantes** | Crear alimento desde el flujo de registro (requisito 2) | 2 días |
| **6 · Recetas** | CRUD de recetas, cálculo por porción, reconocimiento por nombre (requisito 4) | 4 días |
| **7 · Bake-off** | Conjunto de prueba, P2 a P4, métricas y decisión documentada | 5 días |
| **8 · Pulido** | Estados vacíos, errores, accesibilidad básica, modo claro | 2 días |
| **9 · Evaluación y tesis** | Resultados para el capítulo de pruebas; actualizar capítulos de diseño | 4 días |

Total: ~34 días de trabajo. Como el tiempo es limitado, las fases 7 y 8 se pueden recortar si hace falta.

---

## 13. Cambios necesarios en la tesis

La tesis describe una arquitectura distinta de la propuesta ahora. Conviene decidir si se documenta como un cambio justificado o se corrige:

| Tema | Tesis actual | Propuesta actual | Acción |
|------|--------------|------------------|--------|
| Frontend | Flutter | React + Vite + Tailwind (PWA) | Actualizar secciones de alternativas, diseño y despliegue |
| Backend | NestJS (BFF) | Firebase (sin servidor propio en el prototipo) | Explicar en la alternativa elegida y en la factibilidad técnica |
| Base de datos | PostgreSQL con JSONB | Firestore (documentos) | Actualizar modelo de datos (ERD y diccionario) |
| IA | Gemini 1.5 Pro u OpenAI | Gemini 2.5 Flash-Lite con comparación de alternativas | Actualizar y justificar con el bake-off |
| Costos | Gemini (uso anual) | Nivel gratuito en el prototipo | Recalcular el análisis costo-beneficio |

Esto sí cambia el capítulo de factibilidad y la tabla de costos del documento. Sugiero hacerlo al cerrar el prototipo, cuando haya resultados que lo respalden.

---

## 14. Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Cuota gratuita agotada o límites distintos a los publicados | Alta | Medio | Parser por reglas como base; LLM solo para ambiguos; cache de resultados |
| Clave de API expuesta en el cliente | Media | Alto | App Check obligatorio; límites por usuario; si no basta, migrar a Cloud Function |
| Alimentos incorrectos en la semilla | Media | Medio | Marcar `verified`; origen en `source`; revisión manual de la semilla |
| Modelos gratuitos retirados o cambiados | Media | Medio | Interfaz `NutritionParser` con varios adaptadores |
| Cronograma insuficiente | Alta | Alto | Priorizar fases 0–6; bake-off reducido |
| Dependencia de Firebase para la tesis (lock-in) | Baja | Medio | Lógica de negocio en `src/core`, sin imports de Firebase |

---

## 15. Próximos pasos

1. Confirmar las decisiones D1–D6 (§1) y el color "cyan" (aqua vs otro tono).
2. Crear el repositorio git y la estructura de carpetas (`src/core`, `src/services`, `src/features/nutricion`, `data/`).
3. Crear el proyecto de Firebase y probar que Firebase AI Logic responde con Gemini 2.5 Flash-Lite (verificar cuota en la consola).
4. Escribir el conjunto de prueba de 60–80 líneas con etiquetas (sin LLM, a mano).
5. Armar la semilla de alimentos (USDA + curación local).

---

## Preguntas abiertas

- ¿Autenticación con correo, Google, o ambos?
- ¿Se necesita modo offline en el prototipo, o basta con conexión?
- ¿Se aceptan alimentos creados por usuarios visibles para otros desde ya, o solo privados?
- ¿Se mantiene el puntaje con pesos fijos o se quiere que el usuario los ajuste desde el inicio?
- ¿Quieres que la tesis documente el cambio de stack (§13) o prefieres mantener la arquitectura original?
