"""Mide cuánto se quema una captura del juego (solo la zona del diorama: sin bandeja, título ni fondo).

    python3 -I tools/medir_luz.py build/captura.png [otra.png ...] --fondo build/fondo.png

- El fondo es oscuro y con degradado (no un color plano): para saber qué píxeles son diorama hace
  falta una captura del FONDO SOLO, con la misma luz:
      bash tools/capture.sh build/fondo.png 0 <nivel> --solo-fondo
  Sin --fondo solo se puede medir si el fondo es un color plano (luces antiguas).
- quemado: % de píxeles del diorama con los tres canales >= 235 (blanco recortado, sin detalle).
  Es la medida que importa: con la luz buena sale < 2 %.
- saturado: % con algún canal >= 250. Sube con colores vivos (un naranja tiene el rojo a tope)
  sin estar quemados: no usarlo solo.
- luma / p95: luminancia media y percentil 95 (0-255) del diorama.
Necesita Pillow y numpy (están en la máquina de la nube; en Windows: pip install pillow numpy).
"""
import sys

import numpy as np
from PIL import Image

PANEL_X = 1020   # a partir de aquí, la bandeja de piezas (en 1280x720)

args = sys.argv[1:]
fondo = None
if "--fondo" in args:
    i = args.index("--fondo")
    fondo = np.asarray(Image.open(args[i + 1]).convert("RGB")).astype(np.int32)
    del args[i:i + 2]

for path in args:
    img = np.asarray(Image.open(path).convert("RGB")).astype(np.int32)
    h, w, _ = img.shape
    if (w, h) != (1280, 720) or (fondo is not None and fondo.shape != img.shape):
        print(f"{path}: {w}x{h} - medida no válida (las zonas están pensadas para 1280x720)")
        continue
    zona = img[70:600, 0:PANEL_X]
    if fondo is not None:
        mask = np.abs(zona - fondo[70:600, 0:PANEL_X]).sum(axis=2) > 24
    else:
        esquina, centro = img[100, 10], img[360, 10]
        if np.abs(esquina - centro).sum() > 12:
            print(f"{path}: el fondo no es un color plano - pasa --fondo (captura con --solo-fondo)")
            continue
        mask = np.abs(zona - esquina).sum(axis=2) > 12
    px = zona[mask]
    if len(px) == 0:
        print(f"{path}: SIN DIORAMA (todo es fondo) - medida no válida")
        continue
    luma = 0.2126 * px[:, 0] + 0.7152 * px[:, 1] + 0.0722 * px[:, 2]
    print(
        f"{path}: quemado={(px.min(axis=1) >= 235).mean() * 100:5.1f}%  "
        f"saturado={(px.max(axis=1) >= 250).mean() * 100:5.1f}%  "
        f"luma={luma.mean():5.1f}  p95={np.percentile(luma, 95):5.1f}  "
        f"(diorama={mask.mean() * 100:.0f}% de la zona)"
    )
