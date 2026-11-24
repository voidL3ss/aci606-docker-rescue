#!/usr/bin/env bash
# P-07 — Validación en entorno limpio (Codespace nuevo o clon recién hecho).
#
# Reproduce la prueba final de la pauta: levantar el sistema con un único comando
# Docker Compose, sin .env ni datos previos, y comprobar que los tres servicios
# quedan operativos y se comunican. Cada paso guarda su salida en evidencia/P-07-*.txt.
#
# Uso (desde cualquier carpeta del repo):
#   bash scripts/p07-validacion-limpia.sh
#
# Variables opcionales:
#   FRONTEND_PORT   puerto del host donde se publica el frontend (por defecto 8080)
#   EVID_DIR        carpeta de salida (por defecto evidencia/)
#
# El script NO borra nada: si detecta un .env o un volumen previo del proyecto,
# se detiene y explica cómo limpiar.

set -euo pipefail

cd "$(dirname "$0")/.."
EVID_DIR="${EVID_DIR:-evidencia}"
PORT="${FRONTEND_PORT:-8080}"
BASE="http://localhost:${PORT}"
mkdir -p "$EVID_DIR"

# Imprime el comando y lo ejecuta, para que la evidencia muestre qué se corrió.
run() { echo "\$ $*"; "$@"; echo; }

paso() { echo; echo "==> $1"; }

# --- 0. Precondiciones: el entorno tiene que estar limpio -------------------
PROYECTO="$(docker compose config --no-path-resolution | awk '/^name:/ {print $2; exit}')"

if [[ -e .env ]]; then
  echo "ERROR: existe un .env. La prueba debe hacerse sin él (compose.yaml trae valores por defecto)."
  echo "       Muévalo temporalmente:  mv .env .env.bak"
  exit 1
fi
if [[ -n "$(docker compose ps -aq)" ]]; then
  echo "ERROR: ya hay contenedores del proyecto '${PROYECTO}'. Ejecute: docker compose down -v"
  exit 1
fi
if docker volume inspect "${PROYECTO}_pgdata" >/dev/null 2>&1; then
  echo "ERROR: el volumen ${PROYECTO}_pgdata ya existe (no es un arranque limpio)."
  echo "       ⚠️ Para borrarlo (elimina los datos): docker compose down -v"
  exit 1
fi

paso "P-07-1: entorno de partida"
{
  run date -Iseconds
  run git log -1 --oneline
  run git status --short
  run docker version --format 'Docker Engine {{.Server.Version}}'
  run docker compose version
  echo "\$ ls -la .env"; ls -la .env 2>&1 || true; echo
  run docker volume ls --filter "name=${PROYECTO}_"
} 2>&1 | tee "$EVID_DIR/P-07-entorno.txt"

paso "P-07-2: arranque con un único comando"
{
  run docker compose up --build -d --wait
} 2>&1 | tee "$EVID_DIR/P-07-up.txt"

paso "P-07-3: estado de los servicios"
{
  run docker compose ps
  for c in $(docker compose ps -q); do
    docker inspect "$c" --format '{{.Name}}  health={{.State.Health.Status}}  restarts={{.RestartCount}}'
  done
} 2>&1 | tee "$EVID_DIR/P-07-ps.txt"

paso "P-07-4: frontend y API a través de Nginx"
{
  echo "\$ curl -sS -i ${BASE}/ | head -n 12"
  curl -sS -i --fail-with-body "${BASE}/" | head -n 12; echo
  run curl -sS -i --fail-with-body "${BASE}/api/health"
} 2>&1 | tee "$EVID_DIR/P-07-health.txt"

paso "P-07-5: escritura y lectura de datos (frontend -> backend -> db)"
{
  run curl -sS -i --fail-with-body -X POST "${BASE}/api/items" \
      -H 'Content-Type: application/json' -d '{"name":"p07-codespace-limpio"}'
  run curl -sS --fail-with-body "${BASE}/api/items"
  echo '$ docker compose exec -T db sh -c '\''psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT id, name FROM items ORDER BY id;"'\'''
  docker compose exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT id, name FROM items ORDER BY id;"'
} 2>&1 | tee "$EVID_DIR/P-07-datos.txt"

paso "P-07-6: configuración sensible fuera del repositorio"
{
  echo "\$ git ls-files | grep -E '(^|/)\\.env\$' || echo '.env no está versionado'"
  git ls-files | grep -E '(^|/)\.env$' || echo ".env no está versionado"
  echo
  run git check-ignore -v .env
} 2>&1 | tee "$EVID_DIR/P-07-env-no-versionado.txt"

echo
echo "✅ P-07 completada. Evidencia en ${EVID_DIR}/P-07-*.txt"
