#!/usr/bin/env python3
"""Toma las capturas de la sección "Diseño de Interfaces de Usuario" de la tesis.

Abre cada pantalla directamente por su ruta en un simulador de iPhone, en modo
demostración y sin tocar la pantalla (ver `CaptureRequest` en lib/app/config.dart).

Primero se compila para el simulador:

    flutter build ios --simulator --debug --dart-define-from-file=env/memory.json

Y se ejecuta desde mobile/:

    python3 tool/capture_screens.py                → todas
    python3 tool/capture_screens.py cu05 cu18      → solo las que empiezan así
    python3 tool/capture_screens.py --list         → lista sin capturar

Para las pantallas que necesitan tocar algo (entrenamiento en curso, grabación):

    python3 tool/capture_screens.py --open /fuerza --go   → abre en modo de capturas
    python3 tool/capture_screens.py --snap cu01_entreno   → guarda lo que se ve
    python3 tool/capture_screens.py --close               → vuelve al arranque normal

Las imágenes se reducen a 640 px de ancho (JPEG) para que el PDF no crezca de más.
"""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

DEVICE = os.environ.get("DEVICE", "iPhone 18 Pro")
BUNDLE = "cl.asistentedeportivo.asistenteDeportivo"
APP = Path("build/ios/iphonesimulator/Runner.app")
OUT = Path("../../figuras/interfaces")
TIMEOUT_SECONDS = 240

# (archivo, ruta, opciones). go=True: pestaña del marco; scroll: desplazamiento inicial en puntos.
SHOTS = [
    ("cu01_inicio", "/fuerza", {"go": True}),
    ("cu01_detalle", "/fuerza/historial/demo-w2", {}),
    ("cu02_escribir", "/ia/fuerza?estado=texto", {}),
    ("cu02_revision", "/ia/fuerza?estado=revision", {}),
    ("cu03_permiso", "/cardio/reloj", {}),
    ("cu03_sesiones", "/cardio/reloj?estado=conectado", {}),
    ("cu04_elegir", "/cardio/archivo", {}),
    ("cu04_error", "/cardio/archivo?estado=error", {}),
    ("cu04_resumen", "/cardio/archivo?estado=resumen", {}),
    ("cu05_resumen", "/carga", {}),
    ("cu05_alerta", "/carga/alerta", {}),
    ("cu05_faltan", "/carga?estado=faltan", {}),
    ("cu06_diario", "/", {"go": True}),
    ("cu06_registrar", "/registrar?ejemplo=lista", {"go": True}),
    ("cu06_catalogo", "/alimentos", {"go": True}),
    ("cu07_camara", "/ia/foto", {}),
    ("cu07_analizando", "/ia/foto?estado=analizando", {}),
    ("cu07_revision", "/ia/foto?estado=revision", {}),
    ("cu08_receta", "/comunidad/post/p2", {}),
    ("cu08_ajuste", "/comunidad/post/p2/receta", {}),
    ("cu08_metas", "/comunidad/post/p2/receta?estado=metas", {}),
    ("cu09_sesion", "/comunidad/publicar?ejemplo=1", {}),
    ("cu09_ruta", "/comunidad/publicar?ejemplo=1&tipo=ruta", {}),
    ("cu12_cuestionario1", "/bienvenida/cuestionario?ejemplo=1", {}),
    ("cu12_cuestionario2", "/bienvenida/cuestionario?paso=1&ejemplo=1", {}),
    ("cu12_cuestionario3", "/bienvenida/cuestionario?paso=2&ejemplo=1", {}),
    ("cu12_plan", "/bienvenida/plan", {}),
    ("cu13_publicacion", "/comunidad/post/p1", {}),
    ("cu13_agregar", "/comunidad/post/p1/agregar", {}),
    ("cu13_listo", "/comunidad/post/p1/agregar?estado=listo", {}),
    ("cu14_buscar", "/comunidad/buscar", {"go": True}),
    ("cu14_perfil", "/comunidad/usuario/camila", {}),
    ("cu15_escaner", "/escaner", {}),
    ("cu15_porcion", "/registrar?ejemplo=escaneo", {"go": True}),
    ("cu16_escribir", "/ia/comida?estado=texto", {}),
    ("cu16_revision", "/ia/comida?estado=revision", {}),
    ("cu17_inicio", "/cardio", {"go": True}),
    ("cu17_manual", "/cardio/manual?ejemplo=1", {}),
    ("cu18_entreno", "/metas", {}),
    ("cu18_descanso", "/metas?dia=descanso", {}),
    ("cu19_calendario", "/actividad", {}),
    ("cu19_carga", "/carga", {"scroll": 330}),
    ("cu19_progreso", "/progreso", {"go": True}),
    ("cu20_sesion", "/fuerza/historial/demo-w2?nota=Me%20molest%C3%B3%20un%20poco%20el%20hombro%20en%20la%20%C3%BAltima%20serie.", {"scroll": 300}),
    ("cu20_comida", "/diario/comida/almuerzo?ejemplo=1", {}),
    ("cu21_ajustes", "/ajustes", {}),
    ("cu21_datos", "/ajustes/datos", {}),
    ("cu21_eliminar", "/ajustes/datos/eliminar?ejemplo=1", {}),
    ("cu22_motivo", "/comunidad/post/p1/reportar?motivo=1", {}),
    ("cu22_listo", "/comunidad/post/p1/reportar?estado=listo", {}),
    ("cu23_muro", "/comunidad", {"go": True}),
    ("cu23_ruta", "/comunidad/post/p3", {}),
    ("cu24_planes", "/premium", {}),
    ("cu24_activo", "/premium?estado=activo", {}),
    ("cu25_activa", "/premium/suscripcion", {}),
    ("cu25_cancelada", "/premium/suscripcion?estado=cancelada", {}),
    ("cu26_terminos", "/bienvenida/terminos?estado=listo", {}),
    ("cu26_rechazo", "/bienvenida/terminos?estado=rechazo", {"scroll": 300}),
]


def simctl(*args, env=None):
    return subprocess.run(["xcrun", "simctl", *args], check=True, capture_output=True, text=True, env=env)


def snap(name):
    """Captura en PNG y la reduce a JPEG: a 4 por fila impresas sobra con 640 px de ancho."""
    raw = OUT / f"{name}.png"
    simctl("io", DEVICE, "screenshot", "--type=png", str(raw))
    subprocess.run(["sips", "-Z", "1392", "-s", "format", "jpeg", "-s", "formatOptions", "82", str(raw), "--out", str(OUT / f"{name}.jpg")], check=True, capture_output=True)
    raw.unlink()


def paths():
    temp = Path(simctl("get_app_container", DEVICE, BUNDLE, "data").stdout.strip()) / "tmp"
    return temp / "nutri_capture.json", temp / "nutri_ready"


def launch(route, go=False, scroll=None):
    """Abre una pantalla en modo de capturas y espera a que la app avise que está lista."""
    request, ready = paths()
    ready.unlink(missing_ok=True)
    # La app lee el pedido al arrancar (Dart no ve las variables de entorno en iOS).
    request.write_text(json.dumps({"route": route, "go": go, "scroll": scroll}))
    subprocess.run(["xcrun", "simctl", "terminate", DEVICE, BUNDLE], capture_output=True)
    simctl("launch", DEVICE, BUNDLE)
    # El arranque en debug es lento y variable: no sirve esperar un tiempo fijo.
    started = time.time()
    while not ready.exists():
        if time.time() - started > TIMEOUT_SECONDS:
            sys.exit(f"{route}: la app no avisó en {TIMEOUT_SECONDS} s; no se tomó la captura.")
        time.sleep(0.25)
    return time.time() - started


def main():
    args = sys.argv[1:]
    if args[:1] == ["--open"]:
        launch(args[1], go="--go" in args)
        return
    if args[:1] == ["--snap"]:
        OUT.mkdir(parents=True, exist_ok=True)
        snap(args[1])
        return
    if args[:1] == ["--close"]:
        for f in paths():
            f.unlink(missing_ok=True)
        return
    shots = [s for s in SHOTS if not args or any(s[0].startswith(a) for a in args)]
    if "--list" in args:
        for name, route, _ in SHOTS:
            print(f"{name:24} {route}")
        return
    OUT.mkdir(parents=True, exist_ok=True)
    simctl("bootstatus", DEVICE, "-b")
    # Instalación limpia: sin permisos ni preferencias de ejecuciones anteriores.
    subprocess.run(["xcrun", "simctl", "uninstall", DEVICE, BUNDLE], capture_output=True)
    simctl("install", DEVICE, str(APP))
    # Barra de estado limpia y tema claro, para que todas las capturas sean iguales.
    simctl("status_bar", DEVICE, "override", "--time", "9:41", "--batteryState", "charged", "--batteryLevel", "100", "--cellularBars", "4", "--wifiBars", "3")
    simctl("ui", DEVICE, "appearance", "light")
    for name, route, opts in shots:
        seconds = launch(route, go=bool(opts.get("go")), scroll=opts.get("scroll"))
        snap(name)
        print(f"{name}  ({seconds:.0f} s)", flush=True)
    # Sin el pedido, la app vuelve a abrir normalmente.
    for f in paths():
        f.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
