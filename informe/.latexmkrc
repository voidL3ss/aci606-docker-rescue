# Compilar desde esta carpeta:  cd informe && latexmk
# Genera informe.pdf con XeLaTeX (necesario para fontspec + polyglossia en español).

$pdf_mode = 5;   # 5 = xelatex
$xelatex  = 'xelatex -interaction=nonstopmode -halt-on-error -file-line-error %O %S';
@default_files = ('informe.tex');

# Anexos generados a partir del repositorio (no se versionan, ver .gitignore):
#   historial.txt  -> historial de commits
#   evidencias.txt -> índice de archivos de evidencia
system("git log --reverse --date=short --format='%h  %ad  %s' > historial.txt 2>/dev/null");
system("ls -1 ../evidencia > evidencias.txt 2>/dev/null");
