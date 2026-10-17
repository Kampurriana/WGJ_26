#!/usr/bin/env bash
# Prepara las grabaciones de voz para el juego (guion v2, "Implementación de voces"): cada fichero
# de la carpeta de entrada, ya nombrado con su clave de data/narracion_es.json (pieza_peluche.mp3,
# pieza_mp3_a.wav...), sale en assets/audio/voz/<clave>.ogg:
#   - entero: NO se recorta nada (recortar el silencio de una grabación tan baja se comía el final
#     de la última palabra: "los audios se cortan al final"), y lleva 0,4 s más de cola;
#   - con una ganancia fija hasta -16 LUFS y un limitador suave para que los picos no saturen
#     (las grabaciones llegan a volúmenes muy distintos: de -36 a -28 LUFS);
#   - mono, 48 kHz, Ogg Vorbis.
# Después: bash tools/check.sh (importa) y, si la frase va en trozos, ajustar sus "marcas"
# (ffmpeg -i assets/audio/voz/<clave>.ogg -af silencedetect=n=-45dB:d=0.25 -f null - dice las pausas).
# Uso: bash tools/preparar_voces.sh carpeta_con_las_grabaciones
set -euo pipefail
IN="${1:?carpeta con las grabaciones}"
OUT="assets/audio/voz"
TARGET=-16
mkdir -p "$OUT"
for f in "$IN"/*.{mp3,wav,ogg,m4a}; do
	[ -f "$f" ] || continue
	key="$(basename "${f%.*}")"
	lufs=$(ffmpeg -hide_banner -nostats -i "$f" -af ebur128 -f null - 2>&1 | grep -E '^\s+I:' | tail -1 | awk '{print $2}')
	gain=$(python3 -I -c "print(round($TARGET - ($lufs), 2))")
	ffmpeg -hide_banner -loglevel error -y -i "$f" \
		-af "volume=${gain}dB,apad=pad_dur=0.4,alimiter=limit=0.82:attack=5:release=80:level=disabled" \
		-ac 1 -ar 48000 -c:a libvorbis -q:a 6 "$OUT/$key.ogg"
	echo "$key.ogg  $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/$key.ogg") s  (+${gain} dB)"
done
