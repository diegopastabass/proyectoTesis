# Copiar comidas, racha, calendario y perfil corporal

> Estado al 28-10-2026. Funciones agregadas a la app iOS (Flutter). La versión web (`src/`) quedó en desuso y no las tiene.

## 1. Copiar comidas de otro día

Pensado para dietas en que se repite el mismo desayuno o almuerzo varios días seguidos.

| Dónde | Qué hace |
|---|---|
| Diario → tarjeta **Repetir de ayer** | Aparece si el día anterior tiene comidas que el día visto aún no tiene. Cada comida se copia con **Copiar**; si hay varias, también **Copiar todo**. La fila desaparece al copiarla |
| Diario → botón **Copiar de otro día** (ícono de copiar) | Hoja para elegir el día de origen (por defecto el anterior) y marcar qué comidas copiar |

- Se copian el alimento o la receta, los gramos, las porciones y el tipo de comida.
- **Los macros se recalculan con el catálogo actual**: si un alimento se corrigió después, la copia queda bien. Si el alimento o la receta ya no existen, se usan los macros guardados.
- Las recetas se copian por porciones; si el registro no las tiene, por peso.
- Lógica: `lib/core/nutrition/copy.dart` (`copyEntries`, `mealsToRepeat`).

## 2. Resumen por día

Para saber qué días tienen comidas sin leer el diario día por día, cada registro actualiza `users/{uid}/days/{fecha}` en la misma escritura:

| Campo | Contenido |
|---|---|
| `entries` | Cantidad de registros (`FieldValue.increment`) |
| `kcal` | Suma de calorías de los registros (para estimar el gasto real) |
| `onTime` | `true` si algo se registró ese día o el siguiente. Nunca vuelve a `false` |

- Al borrar un registro se resta su conteo y sus calorías.
- Los entrenamientos de fuerza no necesitan resumen: ya se cargan completos y tienen `date` y `finishedAt`.
- **Migración:** los días registrados antes de esta versión no tenían documento. La primera vez que se abre la app con una cuenta, `ensureDayIndex` revisa los últimos 400 días (~400 lecturas, una sola vez) y crea los resúmenes con `onTime: true`. Al terminar marca `dayIndexVersion: 1` en `users/{uid}`. Si falla (sin red), se reintenta en la próxima apertura.
- `firestore.rules` no cambia: todo está bajo `users/{uid}/**`.

## 3. Racha de uso

| Regla | Detalle |
|---|---|
| Qué suma | Un día suma si tiene al menos una comida o un entrenamiento registrado **a tiempo**. Cardio se sumará cuando exista el módulo |
| A tiempo | El mismo día o el siguiente: anotar hoy el almuerzo de ayer cuenta; rellenar la semana pasada se ve en el calendario pero no suma |
| Hoy | No corta la racha mientras no termine |
| Protector | Una falta por semana (lunes a domingo) no corta la racha. El día protegido mantiene la racha pero no suma. Dos faltas en la misma semana la cortan |
| Días de descanso | Hasta 3 días de la semana elegidos (por ejemplo, sábado y domingo). Sin registro mantienen la racha sin sumar ni gastar el protector; con registro suman como cualquier día. Esos días no hay recordatorios de comidas ni de racha. Se guardan en `users/{uid}.streakRestDays` (lista, 1 = lunes … 7 = domingo) y se aplican a toda la historia |
| Hitos | 5 días, 7 (una semana), 10, 30 (un mes) y luego cada 30 días |
| Aviso | Al alcanzar un hito aparece una celebración. Se avisa solo si el hito se alcanzó hoy o ayer, una vez por racha. El último hito celebrado se guarda en `users/{uid}.streakCelebrated` (`{ start, milestone }`), así no se repite en otro dispositivo |

- La racha de uso (días) es distinta de "semanas seguidas" del módulo de Fuerza, que sigue igual.
- Lógica: `lib/core/activity/streak.dart` (`computeStreak`, `milestoneToCelebrate`).

## 4. Calendario de actividad

- Se abre tocando la racha (🔥 N) en el encabezado o desde **Ajustes → Racha y calendario** (ruta `/actividad`).
- Tarjeta de racha: días seguidos, mejor racha, avance hacia el próximo hito, estado del protector de la semana y los días de descanso (se cambian con **Cambiar**).
- Vista mensual (lunes a domingo), con filtro **Todo / Nutrición / Fuerza** (Cardio aparece cuando su módulo esté listo):

  | Filtro | Día en verde | Además |
  |---|---|---|
  | Todo | Suma a la racha | Verde tenue = registrado tarde; escudo = falta cubierta por el protector; luna = día de descanso; puntos de color por módulo |
  | Un módulo | Tuvo registros de ese módulo | — |

- Tocar un día muestra sus registros: lleva al Diario de esa fecha o a cada entrenamiento.
- Lógica: `lib/core/activity/calendar.dart` (`buildActivity`, `monthWeeks`). Pantalla: `lib/features/activity/activity_page.dart`.

## 5. Perfil corporal y gasto calórico

Pantalla **Ajustes → Perfil corporal** (ruta `/perfil`; también desde **Objetivos → Calcular desde mi perfil**). Guarda en `users/{uid}.body`: `heightCm`, `birthDate`, `sex`, `activity`. El peso se toma del registro de Progreso; si se cambia en esta pantalla, se guarda como el peso de hoy.

### Dos estimaciones del gasto diario

| Estimación | Cálculo | Cuándo está disponible |
|---|---|---|
| Con la fórmula | Mifflin-St Jeor × factor de actividad (1,2 / 1,375 / 1,55 / 1,725 / 1,9). El factor incluye los entrenamientos | Con estatura, peso, fecha de nacimiento y sexo |
| Con tus registros | Ingesta promedio − pendiente del peso × 7700 kcal/kg, en las últimas 4 semanas (sin hoy) | Con 14 días registrados y al menos 3 pesajes que abarquen 14 días. Los días anotados a medias (bajo la mitad de la mediana) no se cuentan; resultados fuera de 1200–6000 kcal se descartan |

Mifflin-St Jeor es la ecuación que más veces queda dentro de ±10 % del gasto medido (Frankenfield et al., 2005), pero el error individual puede ser grande. Por eso, cuando hay datos suficientes, la sugerencia usa por defecto la estimación con los registros.

### Objetivos sugeridos

| Macro | Regla |
|---|---|
| Calorías | Gasto × 0,85 (bajar), × 1 (mantener) o × 1,10 (subir) según la meta corporal de Progreso; rango ±5 % |
| Proteína | 1,6–2,2 g/kg; 2,2–2,8 g/kg al bajar de peso (ISSN 2017) |
| Grasa | 20–30 % de las calorías |
| Carbohidratos | El resto, ±15 % |
| Fibra | 14 g cada 1000 kcal (mínimo 25 g), rango de 15 g |

**Aplicar a mis objetivos** reemplaza los rangos (pide confirmación). Los pesos del puntaje no cambian.

Lógica: `lib/core/body/energy.dart`.

## 6. Pruebas

- `test/core/activity_and_energy_test.dart`: copia de comidas, actividad por día, semanas del mes, racha y protector, hitos, Mifflin-St Jeor, gasto con registros y sugerencia de objetivos.
- `test/app_smoke_test.dart`: repetir el desayuno de ayer, abrir el detalle de un día del calendario, aplicar los objetivos del perfil y celebrar el hito de 5 días al registrar.
- El modo demostración trae desayuno y almuerzo de los últimos 12 días para mostrar la racha, el calendario y el copiado.

## 7. Pendiente

- ~~Notificación si aún no hay registros~~: lista, junto con los recordatorios de comidas y entrenamiento ([recordatorios-y-programas.md](recordatorios-y-programas.md)).
- Sumar cardio a la racha y al calendario cuando exista el módulo (basta con agregarlo en `buildActivity`).
- Factor de actividad sin entrenamientos + calorías de cada sesión, cuando cardio y Apple Salud entreguen el gasto de los entrenamientos.
