# Carga de entrenamiento (prototipo v4, primera parte)

> Estado al 28-10-2026. App iOS (Flutter). Es la base del cruce de datos de la tesis (R03, R06 y RNF-03): cada sesión de fuerza y de cardio tiene una carga en la misma unidad, y la app calcula la carga aguda (ATL) y crónica (CTL). Las alertas de fatiga cruzada y las metas de alimentación según el entrenamiento se construyen sobre esto en la versión siguiente.

## 1. Esfuerzo percibido (RPE) de la sesión

Se usa la escala **CR-10 de Foster** (1–10), que sirve igual para pesas y para cardio.

| Valor | Etiqueta |
|---|---|
| 1 | Muy, muy suave |
| 2 | Suave |
| 3 | Moderado |
| 4 | Algo duro |
| 5–6 | Duro |
| 7–8 | Muy duro |
| 9 | Casi máximo |
| 10 | Máximo |

| Dónde se pide | Cómo |
|---|---|
| Fuerza → **Terminar** | Hoja "¿Qué tan duro fue el entrenamiento?": un toque elige y guarda. **Guardar sin indicar** guarda igual; cerrar la hoja vuelve a la sesión sin terminarla. La hora de término es la del toque en Terminar |
| Cardio → **Guardar actividad** | Tarjeta "¿Qué tan dura fue?" (opcional) |
| Detalle de un entrenamiento o de una ruta | Tarjeta **Esfuerzo**: tocarla permite indicarlo o cambiarlo después (sirve también para las sesiones anteriores a esta versión) |

**Dónde se guarda:** campo `rpe` (entero 1–10, ausente si no se indicó).
- `users/{uid}/workouts/{id}`
- `users/{uid}/activities/{id}`, y en el teléfono (`index.json`)

`firestore.rules` no cambia.

## 2. Carga de una sesión

**Carga = RPE × minutos**, en unidades arbitrarias (UA) (método sRPE de Foster et al., 2001). Ejemplos: 60 min de pesas a 7 = 420 UA; 45 min de carrera a 8 = 360 UA.

| | Minutos | Si no hay RPE |
|---|---|---|
| Fuerza | Inicio a término, con un tope de 180 min (una sesión olvidada abierta no suma horas) | RPE 6, el valor típico de una sesión de pesas |
| Cardio | Tiempo total sin las pausas manuales | Se estima por el MET de la velocidad media: RPE ≈ MET / 2 + 1, entre 2 y 8. En trekking, subir 300 m o más por hora suma 1 |

- Las cargas sin RPE quedan marcadas como **estimadas**. La tesis lo llama "indicador de confianza".
- El detalle de cada sesión muestra la tarjeta **Carga**, con "Esfuerzo × minutos" o "Estimada".

## 3. Carga aguda, crónica y balance

| Indicador | Cálculo | Lectura |
|---|---|---|
| ATL (aguda) | Media móvil exponencial de la carga diaria, constante de 7 días | Fatiga reciente |
| CTL (crónica) | Igual, con constante de 42 días | Lo que el cuerpo está acostumbrado a hacer |
| TSB (balance) | CTL − ATL | Negativo = acumulando fatiga |
| Razón ATL/CTL | ATL / CTL | Cambio brusco de carga |

- **Fórmula:** cada día, `x ← x + (carga − x) · (1 − e^(−1/τ))`, con τ = 7 o 42. Es el modelo de Banister que usa el PMC de TrainingPeaks.
- **Por disciplina:** se calcula para fuerza, para cardio y para el total. Así se puede saber, por ejemplo, que la fatiga reciente viene del cardio antes de una sesión de pierna.
- **Días sin entrenar:** cuentan con carga 0 (la fatiga baja).
- **Historial mínimo:** la serie es confiable desde **28 días** después de la primera sesión. Antes, la CTL todavía está subiendo y la razón sale inflada. La pantalla deberá avisarlo (CU-05, curso alterno "faltan datos").

### Zonas de la razón ATL/CTL (Gabbett, 2016)

| Razón | Zona |
|---|---|
| < 0,8 | Por debajo de lo habitual |
| 0,8–1,3 | Habitual |
| 1,3–1,5 | Aumento brusco |
| > 1,5 | Aumento muy brusco (más riesgo de lesión) |

- El umbral de las alertas (por defecto 1,3) será configurable, como pide la tesis.
- La razón tiene críticas en la literatura (Impellizzeri et al., 2020). Se presenta como una señal de apoyo, nunca como diagnóstico.

## 4. Código

- **Lógica:** `lib/core/training/load.dart` (Dart puro).
  - `strengthSessionLoad`, `cardioSessionLoad` y `estimateCardioRpe`.
  - `LoadState` (ATL, CTL, TSB y razón) y `ratioZone`.
  - `loadSeries` y `trainingLoad`: serie diaria por disciplina.
- **Interfaz:** `lib/ui/rpe.dart` (`RpePicker`, `askSessionRpe` y `formatLoad`).

## 5. Pruebas

- `test/core/training_load_test.dart`:
  - Carga con y sin RPE, y tope de la sesión olvidada.
  - RPE estimado por velocidad y por subida.
  - ATL y CTL de una sesión y con carga constante (convergen a esa carga).
  - Una semana con el doble de carga sube la razón a ≈1,42 (zona alta).
  - Serie diaria con días de descanso y sesiones futuras ignoradas.
  - Historial mínimo.
  - El RPE se guarda y se lee en fuerza y en cardio.
- `test/app_smoke_test.dart`:
  - Terminar un entrenamiento eligiendo 7 y cambiarlo a 5 desde el detalle.
  - Cerrar la hoja no termina la sesión.
  - "Guardar sin indicar" deja la carga estimada.
  - Guardar una ruta con esfuerzo 6.

## 6. Siguiente paso

1. Pantalla de carga: gráfico de ATL y CTL por disciplina, con el aviso de historial insuficiente.
2. **Alerta de fatiga cruzada.** Se dispara si la razón supera el umbral y hay una sesión de la otra disciplina en las próximas 24 horas. Para fuerza se usan los días de `trainingPlan`; falta planificar los días de cardio. Se avisa con una notificación local.
3. **Metas de alimentación según la carga.** Sumar las calorías de la sesión al objetivo del día y subir los carbohidratos (g/kg) en los días de carga alta.
