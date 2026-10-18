"""Prepara las piezas del logo para el juego (ui/logo.gd), a partir de las de las artistas.

Entrada (carpeta): t_logo (el texto «what I never» + «SAID» en una imagen, con borde blanco de
pegatina), t_coin_logo (la moneda) y t_pig_logo (el cerdito), PNG con fondo transparente.
Salida (carpeta, p. ej. assets/ui/logo): logo_what.png, logo_said.png, logo_moneda.png y
logo_cerdito.png, recortadas a su dibujo y a un tamaño de sobra para la web.

El texto se parte en sus dos líneas por el color (verde = «what I never», rosa = «SAID»): cada píxel
es de la línea que tiene más cerca, y donde la otra estaba demasiado cerca (los bordes blancos de
las dos líneas se tocan) se redibuja el borde blanco propio con su grosor, para que quede redondo.
Uso: python3 -I tools/partir_logo.py carpeta_de_drive assets/ui/logo   (necesita Pillow y numpy)
"""
import os
import sys

import numpy as np
from PIL import Image

TEXT_SCALE = 0.24                            # el texto llega a 5697 px de ancho: a ~1100 por línea
COIN_WIDTH = 256
PIG_WIDTH = 640
N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
N8 = N4 + ((1, 1), (1, -1), (-1, 1), (-1, -1))


def shift(m, dy, dx):
    o = np.zeros_like(m)
    h, w = m.shape
    o[max(dy, 0):h + min(dy, 0), max(dx, 0):w + min(dx, 0)] = m[max(-dy, 0):h + min(-dy, 0), max(-dx, 0):w + min(-dx, 0)]
    return o


def distance(seed, steps):
    """Distancia aproximada a la semilla (octógono: 4 y 8 vecinos alternos), en px."""
    d = np.full(seed.shape, 999, np.float32)
    d[seed] = 0
    cur = seed.copy()
    for k in range(1, steps + 1):
        grown = cur.copy()
        for dy, dx in (N8 if k % 2 == 0 else N4):
            grown |= shift(cur, dy, dx)
        d[grown & ~cur] = k
        cur = grown
    return d


def split_text(path, out):
    txt = Image.open(path).convert("RGBA")
    txt = txt.resize((round(txt.width * TEXT_SCALE), round(txt.height * TEXT_SCALE)), Image.LANCZOS)
    px = np.asarray(txt).astype(np.int16)
    r, g, a = px[..., 0], px[..., 1], px[..., 3]
    solid = a > 128
    seeds = {"what": solid & (g > r + 12), "said": solid & (r > g + 25)}
    dist = {n: distance(sd, 400) for n, sd in seeds.items()}
    far = np.abs(dist["what"] - dist["said"]) > 150   # grosor del borde, donde la otra línea queda lejos
    border = int(max(np.percentile(dist[n][solid & far & (dist[n] < dist[o])], 99.5)
                     for n, o in (("what", "said"), ("said", "what"))))
    print("borde blanco: %d px" % border)
    for name, other in (("what", "said"), ("said", "what")):
        d, do = dist[name], dist[other]
        mine = d <= do
        extra = (~mine) & (d <= border + 1)
        arr = np.asarray(txt).copy()
        arr[~mine, 3] = 0
        arr[extra, 0:3] = 255
        arr[extra, 3] = (np.clip(border + 1.5 - d[extra], 0.0, 1.0) * 255).astype(np.uint8)
        im = Image.fromarray(arr, "RGBA")
        save(im.crop(im.getchannel("A").getbbox()), os.path.join(out, "logo_%s.png" % name))


def piece(path, width, dest):
    im = Image.open(path).convert("RGBA")
    im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 0 else 0).getbbox())
    if im.width > width:
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    save(im, dest)


def save(im, dest):
    im.save(dest, optimize=True)
    print("%s  %d x %d" % (os.path.basename(dest), im.width, im.height))


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    split_text(os.path.join(src, "t_logo"), out)
    piece(os.path.join(src, "t_coin_logo"), COIN_WIDTH, os.path.join(out, "logo_moneda.png"))
    piece(os.path.join(src, "t_pig_logo"), PIG_WIDTH, os.path.join(out, "logo_cerdito.png"))


if __name__ == "__main__":
    main()
