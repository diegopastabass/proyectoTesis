# Configuración de latexmk: compila main.tex -> main.pdf (biber se ejecuta solo)
$pdf_mode = 1;                       # pdflatex
$pdflatex = 'pdflatex -interaction=nonstopmode -halt-on-error -synctex=1 %O %S';
$bibtex_use = 2;                     # limpiar .bbl solo con -C
$out_dir = '.';
$pvc_view_file_via_temporary = 0;
$preview_continuous_mode = 0;        # no abrir visor automáticamente
