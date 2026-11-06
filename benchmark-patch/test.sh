#!/usr/bin/env bash
# Round-trip every fixture through a fresh SysON instance and validate the exports.
#
# Usage: benchmark-patch/test.sh
# Env:   IMAGE (default: syson-benchmark:v2026.9.6-bp1)
#        SYSML_OTS (path to a sysml-ots checkout; its sysmlenv and tools/validate_sysml.py
#        run the OMG Pilot validator)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/.out"
COMPOSE=(docker compose -f "$HERE/docker-compose.test.yml")
: "${SYSML_OTS:?set SYSML_OTS to the sysml-ots checkout}"

"${COMPOSE[@]}" down -v >/dev/null 2>&1 || true
"${COMPOSE[@]}" up -d >/dev/null 2>&1
trap '"${COMPOSE[@]}" down -v >/dev/null 2>&1' EXIT
for _ in $(seq 1 60); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8083/)" = 200 ] && break
  sleep 3
done

rm -rf "$OUT" && mkdir -p "$OUT"
python3 "$HERE/roundtrip.py" http://localhost:8083 syson-benchmark-test-database-1 "$OUT" "$HERE"/fixtures/*.sysml
status=0
PATH="$SYSML_OTS/sysmlenv/bin:$PATH" JAVA_HOME="$SYSML_OTS/sysmlenv/lib/jvm" \
  python "$SYSML_OTS/tools/validate_sysml.py" "$OUT"/*.export.sysml || status=1
python3 "$HERE/check_expect.py" "$HERE/fixtures" "$OUT" || status=1
exit $status
