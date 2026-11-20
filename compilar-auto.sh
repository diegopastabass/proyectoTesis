#!/bin/zsh
# Vigila los .tex/.bib y recompila main.pdf automáticamente al guardar.
# Uso: ./compilar-auto.sh   (Ctrl+C para detener)
cd "$(dirname "$0")" || exit 1
export PATH="/Library/TeX/texbin:$PATH"
exec latexmk -pvc -view=none main.tex
