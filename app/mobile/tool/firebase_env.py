#!/usr/bin/env python3
"""Configura la app iOS para el proyecto real de Firebase desde GoogleService-Info.plist.

1. Escribe env/firebase.json (para `flutter run --dart-define-from-file=env/firebase.json`).
2. Registra en ios/Runner/Info.plist los esquemas de URL que necesita el ingreso con
   Google (vuelta desde la hoja de Safari): REVERSED_CLIENT_ID y el Encoded App ID.

Ninguno de estos valores es secreto (son los mismos que la configuración web), pero
env/firebase.json y GoogleService-Info.plist no se versionan.

Uso, desde mobile/:  python3 tool/firebase_env.py [ruta/a/GoogleService-Info.plist]
"""
import json
import plistlib
import sys
from pathlib import Path

MOBILE = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]) if len(sys.argv) > 1 else MOBILE / "ios" / "Runner" / "GoogleService-Info.plist"
ENV = MOBILE / "env" / "firebase.json"
INFO = MOBILE / "ios" / "Runner" / "Info.plist"
URL_TYPE_NAME = "Firebase Google Sign-In"


def main() -> None:
    g = plistlib.loads(SOURCE.read_bytes())
    for key in ("API_KEY", "GOOGLE_APP_ID", "GCM_SENDER_ID", "PROJECT_ID", "BUNDLE_ID"):
        if not g.get(key):
            sys.exit(f"Falta {key} en {SOURCE.name}")
    if not g.get("CLIENT_ID"):
        sys.exit("El plist no trae CLIENT_ID: habilita Google en Authentication y vuelve a descargarlo.")

    env = {
        "BACKEND": "firebase",
        "FIREBASE_API_KEY": g["API_KEY"],
        "FIREBASE_APP_ID": g["GOOGLE_APP_ID"],
        "FIREBASE_MESSAGING_SENDER_ID": g["GCM_SENDER_ID"],
        "FIREBASE_PROJECT_ID": g["PROJECT_ID"],
        "FIREBASE_STORAGE_BUCKET": g.get("STORAGE_BUCKET", ""),
        "FIREBASE_IOS_BUNDLE_ID": g["BUNDLE_ID"],
        "FIREBASE_IOS_CLIENT_ID": g["CLIENT_ID"],
        "FIREBASE_AUTH_DOMAIN": f"{g['PROJECT_ID']}.firebaseapp.com",
    }
    ENV.write_text(json.dumps(env, indent=2) + "\n", encoding="utf-8")

    # Firebase vuelve a la app por el REVERSED_CLIENT_ID (o, sin él, por el Encoded App ID).
    schemes = [g["REVERSED_CLIENT_ID"], "app-" + g["GOOGLE_APP_ID"].replace(":", "-")]
    info = plistlib.loads(INFO.read_bytes())
    others = [t for t in info.get("CFBundleURLTypes", []) if t.get("CFBundleURLName") != URL_TYPE_NAME]
    info["CFBundleURLTypes"] = others + [
        {"CFBundleTypeRole": "Editor", "CFBundleURLName": URL_TYPE_NAME, "CFBundleURLSchemes": schemes}
    ]
    INFO.write_bytes(plistlib.dumps(info))

    print(f"Listo: {ENV.relative_to(MOBILE)} y esquemas de URL en Info.plist (proyecto {g['PROJECT_ID']}).")
    print("Ejecuta: flutter run --dart-define-from-file=env/firebase.json")


if __name__ == "__main__":
    main()
