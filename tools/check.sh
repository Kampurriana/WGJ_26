#!/usr/bin/env bash
# Comprobación completa del proyecto: importar + test de humo.
# El veredicto sale del LOG (marca "SMOKE OK" y cero errores de script), no solo del código de
# salida: Godot puede salir con 0 habiendo fallado un script.
#   bash tools/check.sh            (usa $GODOT o "godot" del PATH)
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."
G="${GODOT:-godot}"
if ! command -v "$G" >/dev/null 2>&1 && [ ! -x "$G" ]; then
	echo "CHECK NO MEDIDO: no encuentro Godot ('$G'). Pon la ruta en la variable GODOT."
	exit 3
fi
mkdir -p build
LOG="build/check.log"
rm -f "$LOG"
"$G" --headless --path . --import >"$LOG" 2>&1
IMPORT_RC=$?
"$G" --headless --path . res://tests/smoke_test.tscn >>"$LOG" 2>&1
RC=$?
ERRORS=$(grep -cE "SCRIPT ERROR|Parse Error|^ERROR:|^FALLO" "$LOG")
WARNINGS=$(grep -cE "^WARNING:" "$LOG")
if grep -q "^SMOKE OK" "$LOG" && [ "$ERRORS" -eq 0 ] && [ "$RC" -eq 0 ] && [ "$IMPORT_RC" -eq 0 ]; then
	echo "CHECK OK ($(grep -c '^OK ' "$LOG") comprobaciones, $WARNINGS avisos) - log: $LOG"
	exit 0
fi
echo "CHECK FALLO (import=$IMPORT_RC test=$RC errores=$ERRORS avisos=$WARNINGS) - log completo: $LOG"
grep -nE -A3 "SCRIPT ERROR|Parse Error|^ERROR:|^FALLO|SMOKE" "$LOG" | head -60
exit 1
