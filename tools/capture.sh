#!/usr/bin/env bash
# Abre el juego en una ventana real, opcionalmente coloca K piezas solo, guarda una captura y sale.
# Es la forma de MIRAR el juego (un test en verde no dice si se ve bien).
#   bash tools/capture.sh [salida.png] [piezas_auto] [nivel] [más argumentos para main.gd...]
#   bash tools/capture.sh build/captura.png 4 0
#   bash tools/capture.sh build/menu.png 10 menu --menu-page=opciones --capture-after=5
#   (nivel "menu" = el menú de inicio; ver los argumentos en scenes/main.gd)
# Comprueba que la imagen sale al tamaño pedido: si no coincide, la captura no vale.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."
G="${GODOT:-godot}"
OUT="${1:-build/captura.png}"
SOLVE="${2:-0}"
LEVEL="${3:-0}"
W=1280
H=720
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
LOG="build/capture.log"
"$G" --path . --resolution ${W}x${H} -- --level="$LEVEL" --solve="$SOLVE" --capture="$OUT" "${@:4}" >"$LOG" 2>&1
LINE=$(grep -a "^CAPTURA" "$LOG" | head -n 1 | tr -d '\r')
FIRST="$OUT"
if [ ! -s "$OUT" ] && [ -s "${OUT%.png}_00.png" ]; then   # --capturas=N,S: ruta_00.png, ruta_01.png...
	FIRST="${OUT%.png}_00.png"
	OUT="${OUT%.png}_NN.png ($(grep -ac "^CAPTURA" "$LOG"))"
fi
if [ -z "$LINE" ] || [ ! -s "$FIRST" ]; then
	echo "CAPTURA FALLO: no se escribió $OUT (mira $LOG)"
	exit 1
fi
case "$LINE" in
	*" ${W}x${H} err=0") echo "CAPTURA OK $OUT (${W}x${H})" ;;
	*) echo "CAPTURA RARA: $LINE (pedí ${W}x${H}; con otro tamaño la imagen engaña)"; exit 1 ;;
esac
