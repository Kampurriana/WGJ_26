"""Mide dónde HABLA cada grabación de assets/audio/voz/ (los tramos con voz, entre pausas) y lo deja en
data/voces_tiempos.json: {"pieza_caballete": [[0.0, 1.44], [2.11, 5.33], ...], ...} (segundos).

El Narrador lo usa para que el subtítulo vaya al ritmo de la voz: el texto se escribe mientras habla y
se para en las pausas, y una frase partida cambia de trozo en una pausa (si no lleva "marcas" a mano).
Volver a correrlo cada vez que cambie una voz (después de tools/preparar_voces.sh); el test avisa si
falta alguna.

Uso: python3 -I tools/tiempos_voces.py   (desde la raíz del proyecto; necesita ffmpeg)
"""
import json
import os
import re
import subprocess
import sys

VOZ = "assets/audio/voz"
SALIDA = "data/voces_tiempos.json"
UMBRAL_DB = -38     # por debajo, silencio (las voces van a -16 LUFS)
PAUSA_MIN = 0.2     # un silencio más corto no es una pausa (s)
TRAMO_MIN = 0.08    # un tramo de voz más corto es un ruido (s)


def duracion(ruta):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", ruta],
                         capture_output=True, text=True, check=True).stdout
    return float(out.strip())


def tramos(ruta):
    total = duracion(ruta)
    log = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", ruta, "-af",
                          "silencedetect=n=%ddB:d=%s" % (UMBRAL_DB, PAUSA_MIN), "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    silencios = []
    inicio = None
    for linea in log.splitlines():
        m = re.search(r"silence_start: (-?[0-9.]+)", linea)
        if m:
            inicio = max(0.0, float(m.group(1)))
        m = re.search(r"silence_end: ([0-9.]+)", linea)
        if m and inicio is not None:
            silencios.append((inicio, float(m.group(1))))
            inicio = None
    if inicio is not None:                       # acaba en silencio (la cola de preparar_voces)
        silencios.append((inicio, total))
    habla = []
    t = 0.0
    for a, b in silencios:
        if a - t >= TRAMO_MIN:
            habla.append([round(t, 2), round(a, 2)])
        t = b
    if total - t >= TRAMO_MIN:
        habla.append([round(t, 2), round(total, 2)])
    return habla


def main():
    if not os.path.isdir(VOZ):
        sys.exit("Correrlo desde la raíz del proyecto (no encuentro %s)" % VOZ)
    datos = {}
    for nombre in sorted(os.listdir(VOZ)):
        base, ext = os.path.splitext(nombre)
        if ext.lower() not in (".ogg", ".wav", ".mp3"):
            continue
        datos[base] = tramos(os.path.join(VOZ, nombre))
        print("%-26s %2d tramos" % (base, len(datos[base])))
    with open(SALIDA, "w", encoding="utf-8") as f:
        f.write("{\n")
        claves = list(datos)
        for i, k in enumerate(claves):
            f.write('\t"%s": %s%s\n' % (k, json.dumps(datos[k]), "," if i < len(claves) - 1 else ""))
        f.write("}\n")
    print("VOCES OK (%d) -> %s" % (len(datos), SALIDA))


if __name__ == "__main__":
    main()
