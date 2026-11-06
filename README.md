# Proyecto de Tesis 2026

Documento de tesis para Ingeniería Civil en Computación e Informática (Universidad Mayor).

**Título:** Solución tecnológica para el registro, cruce de datos y análisis del entrenamiento concurrente y la nutrición en deportistas aficionados.

## Estructura del repositorio

```
.
├── main.tex          Documento principal. Compila desde aquí.
├── capitulos/        Capítulos del documento (00 a 07), incluidos desde main.tex
├── bibliografia/     Referencias bibliográficas (fonts.bib)
├── figuras/          Imágenes usadas en el documento, por grupo (interfaces/ son capturas de la app)
├── diagramas/        Código fuente PlantUML (.puml) y estilos (.iuml) de las figuras
├── anexos/           Material de respaldo: costos y normativas
├── recursos/         Logos, plantillas, presentación y ejemplos
├── referencias/      Artículos y textos de apoyo
├── borradores/       Versiones anteriores y material de trabajo que no entra al documento
└── app/              Prototipo: app Flutter (app/mobile), web y panel de administración
```

## Compilación

Desde la raíz del repositorio:

```bash
latexmk -pdf main.tex
```

`latexmk` ejecuta `biber` automáticamente para la bibliografía.

Si el `biber` de TeX Live falla con un error de `lipo` (ocurrió en un Mac con Apple Silicon), se puede usar el de Homebrew, que es compatible con el `biblatex` de TeX Live 2026:

```bash
latexmk -pdf -e '$biber="/opt/homebrew/bin/biber %O %S";' main.tex
```

## Notas

- Los archivos auxiliares de LaTeX (`.aux`, `.log`, `.bbl`, etc.) están ignorados en `.gitignore`.
- Las capturas de `figuras/interfaces/` se regeneran con `app/mobile/tool/capture_screens.py` (app) y `app/scripts/capture_admin.swift` (panel).
- Para regenerar una figura, renderizar el `.puml` correspondiente de `diagramas/` y dejar el PNG en la carpeta equivalente de `figuras/`.
