# Guion de la presentación de la solución

**Duración estimada:** entre 20 y 22 minutos, sin contar preguntas.

**Archivos:** `presentacion_solucion.html` (con animaciones) y `presentacion_solucion_sin_animaciones.html`. Las grabaciones de la app van en la carpeta `demos` (ver `demos/LEEME.md`).

**Cómo usarlo:** cada lámina tiene el tiempo aproximado, lo que conviene decir (en tus palabras, puedes cambiarlo) y una idea clave. Si tienes menos de 15 minutos, acorta las láminas 4, 18, 20 y 22. Al hacer clic en un diagrama de procesos se abre en grande, y se cierra con Esc o con otro clic.

---

## Lámina 1: Portada (30 s)

Buenos días. Soy Diego Vilches y hoy les voy a presentar la solución de mi proyecto de título: qué hace la aplicación, cómo lo hace y por qué vale la pena construirla.

**Idea clave:** hoy el foco es la solución, no solo el problema.

---

## Lámina 2: Índice (20 s)

Son cinco partes. El problema, visto desde quien recién empieza. La solución y sus procesos. Seis demostraciones de la app en uso. La arquitectura. Y al final, la oportunidad de negocio.

**Idea clave:** del dolor del novato a la solución que se puede construir.

---

## Lámina 3: Querer empezar (1 min)

Casi todos queremos empezar a hacer deporte en algún momento. Algunos por salud, otros por cómo se ven, y otros simplemente para dejar una vida sedentaria. Pero en Chile solo 1 de cada 3 adultos hace actividad física de forma regular.

Querer empezar es fácil. Lo difícil es saber cómo, y no rendirse en el camino.

**Idea clave:** las ganas existen, lo que falta es cómo.

---

## Lámina 4: Por dónde empezar (1 min)

El problema no es la falta de información. Al contrario, sobra. Pero está repartida entre YouTube, Instagram y varias aplicaciones. Está hecha para millones de personas, no para tu nivel ni para los días que tienes. Y no siempre es confiable: un estudio encontró que solo 1 de 9 blogs de influencers populares alcanzó el puntaje mínimo de credibilidad. Además, todo lo que encuentras lo tienes que copiar a mano.

Y esto importa, porque la guía de un programa y la confianza en uno mismo son factores que ayudan a mantener el entrenamiento.

**Idea clave:** falta una guía personalizada.

---

## Lámina 5: Los tropiezos (1 min 15 s)

Y cuando la persona por fin parte, aparecen los tropiezos. Hay cuatro muy comunes.

La fatiga cruzada: hace piernas pesadas el lunes y una salida larga en bicicleta el martes, y una disciplina le quita a la otra. Las lesiones en el gimnasio, que se asocian a subir el peso o el volumen más rápido de lo que el cuerpo está acostumbrado. Comer mal para lo que entrena, con el mismo plato un día de descanso que después de tres horas en bicicleta. Y el sobreentrenamiento, donde entrenar más ya no sirve y el progreso se estanca.

El resultado es frustración, dolor y, muchas veces, abandono. Y ninguna aplicación lo ve, porque cada una mira solo una parte.

**Idea clave:** el novato no falla por falta de ganas, falla porque nadie cruza sus datos.

---

## Lámina 6: Novato y experto (1 min)

Por eso la aplicación está pensada para el que empieza: le da un plan según su nivel, rutinas de personas que elige seguir, avisos antes de que la fatiga se acumule, y le basta con el celular.

Pero también sirve al atleta híbrido con más experiencia: lee su reloj y su ciclocomputador, cruza fuerza, cardio y comidas, ajusta sus metas de comida a cada sesión y le permite compartir lo que hace.

Funciona con lo que cada uno tenga. Con solo el celular, con un reloj o con un ciclocomputador. Mientras más datos, más precisas las sugerencias.

**Idea clave:** pensada para el novato, útil para el experto.

---

## Lámina 7: Cada tropiezo tiene una respuesta (1 min)

Esta tabla resume la solución. A cada tropiezo le corresponde una función y un caso de uso. Si no sabe por dónde empezar, recibe un plan. Si tiene tres apps, registra todo en una. Si sube la carga muy rápido, la app la mide igual en fuerza y en cardio. Si acumula fatiga, recibe un aviso. Si come mal, sus metas cambian con el entrenamiento. Y si la información es genérica, la red social le deja agregar lo que le sirve con un botón.

En todos los casos la app registra, cruza y sugiere. Pero la decisión es del usuario.

**Idea clave:** registrar, cruzar y sugerir. Tú decides.

---

## Lámina 8: Procesos de negocio (45 s)

Antes de ver la app, estos son los cinco procesos que entregan valor al atleta, dibujados con carriles al estilo BPMN. Cada carril es un participante, como el atleta, la aplicación o el reloj, y cada rombo es una decisión. Cubren el cardio y la fatiga, las comidas, la comunidad, la fuerza y el plan sugerido. Voy a mostrar dos en detalle.

Si alguien quiere ver otro, se puede abrir en grande con un clic.

**Idea clave:** cinco procesos, de ellos salen los requerimientos y los casos de uso.

---

## Lámina 9: Proceso 5, perfil y plan sugerido (1 min)

El primero es el camino del que empieza. Crea su cuenta y responde un cuestionario. La app calcula su nivel y su orientación y le sugiere un plan semanal. El atleta lo acepta, lo cambia o lo ignora. Luego entrena y registra, y al final de la semana la app revisa lo que cumplió y qué tan duro lo sintió, y propone un plan más liviano, igual o más exigente.

El ciclo se repite cada semana, así que el plan va aprendiendo con la persona.

**Idea clave:** un plan que se ajusta con lo que el atleta hace.

---

## Lámina 10: Proceso 1, cardio y fatiga cruzada (1 min 15 s)

Este es el proceso central. Una sesión de cardio puede llegar por varios caminos: sola desde el reloj, o subiendo un archivo .fit, grabando con el GPS o anotándola a mano. Esa es la primera decisión del diagrama.

Venga de donde venga, la app calcula su carga y la cruza con las sesiones de fuerza y las comidas de los últimos días, y actualiza las metas del día. Luego viene la segunda decisión: si hay riesgo de fatiga o poco descanso, envía una alerta con una sugerencia.

Fíjense en la tarea 8. Está en el carril del atleta, porque él decide si ajusta su entrenamiento. La app no cambia nada por su cuenta.

**Idea clave:** registrar, cruzar y sugerir, visto como proceso.

---

## Lámina 11: Casos de uso (45 s)

De esos procesos salen 27 casos de uso, agrupados por módulo. Hay tres actores principales: el atleta básico con el plan gratuito, el atleta híbrido con premium y el administrador. Y dos actores de apoyo: la app de salud del teléfono y el asistente de inteligencia artificial.

Los marcados en amarillo son los que vamos a ver funcionando ahora, en seis demostraciones.

**Idea clave:** 27 casos de uso, vamos a ver los más importantes.

---

## Lámina 12: Plan semanal, CU-12 (1 min)

*(Deja correr el video y narra encima.)*

Aquí el usuario responde el cuestionario en tres pasos: experiencia y objetivo, días y equipo, y datos personales. Con eso la app define su nivel y su orientación, y le sugiere un plan con las sesiones separadas para que se recupere. Puede aceptarlo, cambiarlo o dejarlo para después.

Esto responde directamente a «no sé por dónde empezar».

**Idea clave:** el primer paso ya viene resuelto.

---

## Lámina 13: Registro de fuerza, CU-01 (1 min)

Este caso ya funciona en el prototipo. El usuario empieza una rutina, anota el peso y las repeticiones de cada serie, y al terminar indica qué tan duro lo sintió, de 1 a 10. La app calcula la carga como minutos por esfuerzo percibido.

Esa regla es la misma para fuerza y para cardio, y es lo que permite sumarlas. En premium, además, puede contar su sesión con sus palabras y la IA la ordena.

**Idea clave:** una sola regla para medir fuerza y cardio.

---

## Lámina 14: Registro de cardio, CU-17 (1 min)

Con solo el celular, el usuario elige la disciplina, graba con un toque y ve el tiempo, la distancia y el mapa. Al terminar indica qué tan dura la sintió. La carga queda en la misma unidad que la de fuerza.

Si tiene reloj, la sesión llega sola desde la app de salud del teléfono. Si tiene ciclocomputador, sube el .fit y ve potencia y cadencia.

**Idea clave:** el cansancio del cardio y de las pesas por fin se suma.

---

## Lámina 15: Fatiga cruzada, CU-05 (1 min 15 s)

Esta es la función más importante. Cada sesión se cruza con las demás y con las comidas. La app compara la carga de la última semana con la de las últimas seis. Avisa en dos casos: cuando la carga semanal supera 1,3 veces lo habitual y al día siguiente toca una sesión exigente de la otra disciplina, o cuando dejó menos de 6 horas entre una sesión de fuerza y una de cardio.

El aviso trae una sugerencia concreta, como bajar un 10 por ciento el peso de pierna. Y el usuario elige si la sigue o mantiene su plan.

Aclara que la carga ya se calcula con los registros reales y que la alerta del video es un ejemplo.

**Idea clave:** avisa antes, no después.

---

## Lámina 16: Nutrición, CU-15 y CU-18 (1 min)

El usuario escanea el código de barras de un producto y ajusta la porción. La comida se suma a su diario. Y sus metas del día cambian según el entrenamiento: con una sesión de pierna en la tarde suben las calorías y los carbohidratos, y en un día de descanso son otras. También le sugiere qué comer antes y después de entrenar.

Además puede buscar en la lista y, en premium, registrar con una foto o con sus palabras. Son metas y sugerencias, no dietas.

**Idea clave:** comer según lo que se entrena hoy.

---

## Lámina 17: Comunidad, CU-23 y CU-13 (1 min)

En el muro el usuario ve lo que publican las personas que sigue. Abre una rutina, ve quién la creó y pulsa «Agregar a mis rutinas». Queda una copia en su módulo de fuerza, lista para usar y conectada al cruce de datos. Con las recetas, las porciones se ajustan a lo que le falta comer ese día. Y al publicar una ruta, se ocultan el inicio y el final para no mostrar dónde vive.

**Idea clave:** contenido que se puede usar, no solo mirar.

---

## Lámina 18: Otras pantallas (30 s)

Estas son otras pantallas del prototipo: la comida con foto, la fuerza con palabras, el archivo .fit, la carga en el tiempo, publicar una ruta y el plan premium. Todas se construyeron en Flutter y están en el capítulo 7.

**Idea clave:** cada caso de uso tiene su pantalla.

---

## Lámina 19: Arquitectura en tres capas (1 min)

Ahora, cómo se construye. Es un modelo cliente y servidor en tres capas. Arriba, la presentación: la app en Flutter, la app de salud del teléfono y el panel web del administrador. Al medio, el procesamiento en la nube: una API en NestJS que calcula la fatiga, las metas y el plan, un lector de archivos .fit y la base de datos MongoDB. Abajo, los servicios externos que no construimos: Gemini, Open Food Facts, Firebase, S3 con CloudFront y las tiendas.

Una regla importante: solo la API tiene las claves de esos servicios.

**Idea clave:** tres capas, y la lógica vive en el servidor.

---

## Lámina 20: Por qué estas piezas (1 min 15 s)

Flutter, porque con un solo código funciona igual en Android e iOS y puede leer Health Connect y Apple Health. NestJS, porque ordena el servidor en módulos y revisa cada dato antes de guardarlo. MongoDB, porque una sesión puede tener tres ejercicios y otra siete, y cada una se guarda como un documento sin cambiar la estructura. Fargate y Lambda, porque no hay que administrar servidores y el lector de .fit solo se enciende cuando llega un archivo. Gemini, para entender fotos y textos, siempre llamado desde el servidor. Y S3 con CloudFront, para que las fotos no pasen por la API.

**Idea clave:** cada pieza tiene una razón.

---

## Lámina 21: Infraestructura (1 min)

La infraestructura está en AWS, en São Paulo, que es la región más cercana con todos estos servicios. La base de datos se conecta por una red privada, porque guarda datos de salud.

Se dimensionó para 1.500 usuarios: unos 600 activos al día, 24.000 llamadas a la API y hasta 10 por segundo en los momentos de más uso. Al cuarto año la base de datos llegaría a unos 20 GB. Todo esto cuesta unos 188 dólares al mes, calculado con precios reales. Y hay tres ambientes: desarrollo en mi computador, QA que se enciende solo para probar, y producción.

**Idea clave:** pequeña, segura y con costo conocido.

---

## Lámina 22: Integraciones (45 s)

Dependemos de seis servicios externos, y cada uno tiene un plan si falla. Si no hay reloj, se registra con GPS o a mano. Si la IA no responde, se ofrece el registro manual. Si la alerta no llega al teléfono, queda en el resumen de la app. La idea es que una falla externa nunca impida registrar.

Además, las claves viven solo en el servidor, los datos de salud se piden con permiso y se pueden borrar, y el pago ocurre en la tienda.

**Idea clave:** si algo falla, el usuario sigue registrando.

---

## Lámina 23: El mercado (45 s)

En Chile entre 4,5 y 5 millones de adultos hacen actividad física. Entre 180 y 250 mil hacen entrenamiento concurrente con un smartphone. Para ser conservador, trabajé con 1.500 usuarios, menos del 1 por ciento. La tendencia va en alza: Hyrox pasó de 650 a 650 mil competidores entre 2017 y 2024. Y hay espacio para crecer, porque 2 de cada 3 adultos todavía no entrena de forma regular.

**Idea clave:** la base de 1.500 usuarios es conservadora.

---

## Lámina 24: Modelo freemium (1 min)

El modelo es freemium. Gratis, el usuario tiene el plan semanal, el registro manual, el código de barras y su progreso. Es justo lo que necesita quien empieza. Premium cuesta 7.990 pesos al mes y suma el reloj, el .fit, la IA, el cruce de datos con alertas y metas, y la red social.

De esos 7.990 pesos, al quitar el IVA y la comisión de la tienda llegan 5.707. Eso da 68.486 pesos al año por suscriptor.

**Idea clave:** el novato entra gratis, el que quiere más paga.

---

## Lámina 25: Factibilidad (1 min)

La inversión inicial es de 16,2 millones de pesos y el costo de operar es de unos 4,5 millones al año. Con esos números, el proyecto se sostiene con 159 suscriptores premium. Eso da una TIR del 15 por ciento y la inversión se recupera en 2,85 años.

159 suscriptores son un 10,6 por ciento de una base de 1.500 usuarios. Es exigente, pero baja a 8,8 por ciento con 1.800 usuarios y a 3,2 por ciento con 5.000.

Aclara que esto ya descuenta el IVA, la comisión y el impuesto a la renta, y que no incluye marketing.

**Idea clave:** 159 suscriptores para que el proyecto se pague.

---

## Lámina 26: Cierre (30 s)

Para cerrar: la mayoría quiere empezar, pero tropieza en el camino. Esta aplicación busca que empiece bien y no se rinda, registrando, cruzando sus datos y sugiriendo. Y siempre, la decisión final es suya.

Muchas gracias. Quedo atento a sus preguntas.

**Idea clave:** empezar bien, y no rendirse en el camino.

---

## Preguntas probables

**¿Los dolores del novato vienen de una encuesta?**
No. Se basan en la literatura y en el análisis de las aplicaciones existentes. Por eso la tesis dice que deben confirmarse con usuarios reales en las evaluaciones del prototipo.

**¿La app evita las lesiones?**
No las puede evitar ni las diagnostica. Avisa cuando la carga sube mucho más rápido de lo habitual, que es una señal asociada a más lesiones, y la persona decide. El umbral de 1,3 es un punto de partida que se ajustará con el prototipo, porque esa medida tiene críticas en la literatura.

**¿Por qué el índice necesita 28 días?**
Porque la carga crónica todavía no se estabiliza. Antes de eso, la app avisa que faltan datos.

**¿Por qué el diagrama dice «al estilo BPMN»?**
Los procesos se dibujaron con carriles en PlantUML, que no tiene BPMN completo. Siguen la misma idea: carriles por participante, inicio, fin, tareas numeradas y decisiones.

**¿Por qué MongoDB y no PostgreSQL?**
Los datos de entrenamiento tienen estructura variable. En MongoDB cada sesión es un documento y no hay que cambiar la estructura de la base. Además tiene colecciones de series temporales para los puntos GPS.

**¿Por qué São Paulo y no Estados Unidos?**
Es la región de AWS más cercana con todos los servicios que se usan, lo que reduce el tiempo de respuesta en Chile.

**¿Por qué la app no llama directo a Gemini?**
Para no dejar la clave en el teléfono, donde se puede extraer, y para controlar cuánto se gasta por usuario.

**¿Qué está funcionando hoy y qué es simulado?**
El registro de fuerza, la búsqueda de comidas, el código de barras y las recetas funcionan con su lógica real. El cálculo de la carga, el GPS, las metas y el plan funcionan en parte. La foto de comida, la lectura del reloj, la red social y los pagos todavía muestran datos simulados, porque falta conectar sus servicios.

**¿Por qué cambió el punto de equilibrio respecto de la presentación anterior?**
Al dimensionar la infraestructura con precios reales de AWS en São Paulo y descontar el IVA, la comisión de las tiendas y el impuesto a la renta, el número subió de 100 a 159 suscriptores.

**¿Qué pasa si el usuario no tiene reloj?**
Usa el GPS del teléfono o anota la sesión, e indica su esfuerzo con el RPE. Las sugerencias son menos precisas, pero la app sigue funcionando.
