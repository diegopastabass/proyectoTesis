#!/usr/bin/env python3
"""Copia los datos compartidos de la versión web (src/data) a mobile/assets/data.

- foods.seed.json y exercises.json se copian tal cual.
- exercisesEs.ts (objeto de TypeScript) se convierte a exercises_es.json.

Uso, desde la raíz del repositorio:  python3 mobile/tool/sync_assets.py
"""
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "src" / "data"
DST = ROOT / "mobile" / "assets" / "data"

ENTRY = re.compile(
    r"^\s*(?:'([^']+)'|([A-Za-z0-9_\-]+)):\s*\{\s*name:\s*'((?:[^'\\]|\\.)*)'"
    r"(?:,\s*aliases:\s*\[([^\]]*)\])?\s*\},?\s*$"
)
SKIP = ("//", "/**", "*", "export", "}")


def convert_names(path: Path) -> dict:
    names, unmatched = {}, []
    for line in path.read_text(encoding="utf-8").splitlines():
        text = line.strip()
        if not text or text.startswith(SKIP):
            continue
        m = ENTRY.match(line)
        if not m:
            unmatched.append(text)
            continue
        entry = {"name": m.group(3)}
        if m.group(4) is not None:
            entry["aliases"] = re.findall(r"'((?:[^'\\]|\\.)*)'", m.group(4))
        names[m.group(1) or m.group(2)] = entry
    if unmatched:
        sys.exit("Líneas no reconocidas en exercisesEs.ts:\n" + "\n".join(unmatched))
    return names


def main() -> None:
    DST.mkdir(parents=True, exist_ok=True)
    for name in ("foods.seed.json", "exercises.json"):
        shutil.copyfile(SRC / name, DST / name)
    names = convert_names(SRC / "exercisesEs.ts")
    (DST / "exercises_es.json").write_text(json.dumps(names, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"Listo: semilla, catálogo y {len(names)} nombres en español copiados a {DST.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
