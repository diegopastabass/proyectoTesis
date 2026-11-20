# Grabaciones de la app para la presentación

Deja aquí las grabaciones con estos nombres exactos. La presentación busca primero el `.mp4` y, si no existe, el `.gif`. Mientras no haya grabación, muestra la captura de la tesis con el aviso "Grabación pendiente".

| Archivo (sin extensión) | Lámina | Qué grabar | Duración sugerida |
|---|---|---|---|
| `cu12_plan` | Plan semanal (CU-12) | Responder los tres pasos del cuestionario y llegar al plan semanal. Terminar pulsando "Aceptar el plan". | 15 a 20 s |
| `cu01_fuerza` | Registro de fuerza (CU-01) | Empezar una rutina guardada, anotar dos o tres series, terminar, indicar el RPE y mostrar el resumen con la carga. | 15 a 20 s |
| `cu17_cardio` | Registro de cardio (CU-17) | Elegir ciclismo o running, grabar unos segundos con el mapa, detener, indicar qué tan dura se sintió y guardar. | 15 s |
| `cu05_fatiga` | Fatiga cruzada (CU-05) | Abrir el resumen de carga, entrar a la alerta y pulsar "Seguir la sugerencia" o "Mantener mi plan". | 10 a 15 s |
| `cu18_nutricion` | Nutrición (CU-15 y CU-18) | Escanear o escribir un código de barras, ajustar la porción, guardar y abrir "Metas de hoy", cambiando entre "Con entrenamiento" y "Descanso". | 20 s |
| `cu13_comunidad` | Comunidad (CU-23 y CU-13) | Recorrer el muro, abrir una rutina publicada, pulsar "Agregar a mis rutinas" y ver la confirmación. | 15 s |

## Recomendaciones

- Graba en el simulador de iPhone o en el teléfono en vertical. El marco espera una pantalla de proporción parecida a 640 × 1392.
- Si puedes, usa `.mp4` en vez de `.gif`. Pesa mucho menos, se ve más nítido y la presentación lo reinicia cada vez que entras a la lámina. Los dos formatos funcionan.
- Para pasar un `.mov` del simulador a `.mp4` sin sonido:

  ```bash
  ffmpeg -i grabacion.mov -an -vf "scale=640:-2" -c:v libx264 -crf 26 -pix_fmt yuv420p cu12_plan.mp4
  ```

- Si prefieres GIF:

  ```bash
  ffmpeg -i grabacion.mov -vf "fps=15,scale=480:-1:flags=lanczos" -loop 0 cu12_plan.gif
  ```

- Las pantallas que muestran datos simulados (comunidad, alerta de fatiga) se pueden grabar igual. En la lámina ya se indica su estado en el prototipo.
