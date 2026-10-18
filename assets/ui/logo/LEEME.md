# El logo (se monta en motor: `ui/logo.gd`)

Cuatro piezas, una imagen por pieza, PNG con fondo transparente y recortadas a su dibujo:

| Fichero | Pieza |
|---|---|
| `logo_moneda.png` | la moneda |
| `logo_what.png` | «what I never» |
| `logo_said.png` | «SAID» |
| `logo_cerdito.png` | el cerdito |

Vienen de Drive (`2D/`: `t_logo`, el texto con las dos líneas; `t_coin_logo`; `t_pig_logo`) y se
preparan con `python3 -I tools/partir_logo.py carpeta_bajada assets/ui/logo`: parte el texto en sus
dos líneas por el color (cada una con su borde blanco entero), recorta y reduce. Si cambian en Drive,
bajarlas y repetir.

Cada una se coloca en su caja de la referencia de maquetación (`Logo.REF_RECTS`) sin deformarse y se
mueve por su cuenta (la moneda gira, «what I never» se mece, «SAID» respira, el cerdito da saltitos)
sin tapar a las demás. Sale encima del menú de inicio y arriba de los créditos. Si faltara alguna, saldría el nombre
del juego en letra.
