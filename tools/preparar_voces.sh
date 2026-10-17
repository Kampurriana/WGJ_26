#!/usr/bin/env bash
# Prepara las grabaciones de voz para el juego (guion v2, "Implementación de voces"): cada fichero
# de la carpeta de entrada, ya nombrado con su clave de data/narracion_es.json (pieza_peluche.mp3,
# pieza_mp3_a.wav...), sale en assets/audio/voz/<clave>.ogg:
#   - sin silencio al principio y con 0,3 s de cola,
#   - igualado a -16 LUFS (pico real -1,5 dB): las grabaciones llegan a volúmenes muy distintos,
#   - mono, 48 kHz, Ogg Vorbis.
# Después: bash tools/check.sh (importa) y, si la frase va en trozos, ajustar sus "marcas"
# (ffmpeg -i assets/audio/voz/<clave>.ogg -af silencedetect=n=-45dB:d=0.25 -f null - dice las pausas).
# Uso: bash tools/preparar_voces.sh carpeta_con_las_grabaciones
set -euo pipefail
IN="${1:?carpeta con las grabaciones}"
OUT="assets/audio/voz"
mkdir -p "$OUT"
TRIM="silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.02"
for f in "$IN"/*.{mp3,wav,ogg,m4a}; do
	[ -f "$f" ] || continue
	key="$(basename "${f%.*}")"
	# Primera pasada: medir; segunda: igualar con esas medidas (lineal si se puede).
	m=$(ffmpeg -hide_banner -nostats -i "$f" -af "$TRIM,areverse,$TRIM,areverse,loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json" -f null - 2>&1 | sed -n '/^{/,/^}/p')
	get() { echo "$m" | python3 -I -c "import json,sys; print(json.load(sys.stdin)['$1'])"; }
	ffmpeg -hide_banner -loglevel error -y -i "$f" -af "$TRIM,areverse,$TRIM,areverse,loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=$(get input_i):measured_TP=$(get input_tp):measured_LRA=$(get input_lra):measured_thresh=$(get input_thresh):offset=$(get target_offset),apad=pad_dur=0.3" \
		-ac 1 -ar 48000 -c:a libvorbis -q:a 5 "$OUT/$key.ogg"
	echo "$key.ogg  $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/$key.ogg") s"
done
