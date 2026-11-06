#!/bin/sh
# Compila en modo release y lo instala en el iPhone conectado, para abrir la app
# desde la pantalla de inicio sin `flutter run` (en debug, iOS solo deja abrirla
# con el depurador conectado).
#
# Uso, desde mobile/:
#   sh tool/install_iphone.sh                 → con env/firebase.json si existe; si no, demostración
#   sh tool/install_iphone.sh env/memory.json → con otra configuración
#   MODE=profile sh tool/install_iphone.sh    → modo profile (permite medir rendimiento con DevTools)
set -e
cd "$(dirname "$0")/.."

MODE="${MODE:-release}"
ENV_FILE="${1:-env/firebase.json}"
[ -f "$ENV_FILE" ] || ENV_FILE="env/memory.json"

# Primer iPhone físico conectado (excluye simuladores).
DEVICE="${DEVICE:-$(flutter devices --machine 2>/dev/null | python3 -I -c '
import json, sys
for d in json.load(sys.stdin):
    if d.get("targetPlatform") == "ios" and not d.get("emulator"):
        print(d["id"]); break
')}"
[ -n "$DEVICE" ] || { echo "No hay un iPhone conectado y desbloqueado."; exit 1; }

echo "Compilando en modo $MODE con $ENV_FILE para el dispositivo $DEVICE…"
flutter build ios "--$MODE" --dart-define-from-file="$ENV_FILE"
# devicectl actualiza la app sin desinstalarla (flutter install la borra y se pierden
# los datos locales, como la sesión de fuerza en curso).
xcrun devicectl device install app --device "$DEVICE" build/ios/iphoneos/Runner.app
echo "Listo: abre «Asistente» desde la pantalla de inicio del iPhone."
