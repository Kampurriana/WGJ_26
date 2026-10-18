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

Se montan como una sola pegatina (`Logo.REF_RECTS`): juntas como en la composición de las artistas,
con los bordes blancos fundidos, una silueta blanca común detrás y una sombra. Cada una se mueve por su
cuenta, despacio (la moneda da una vuelta, el texto se mece, el cerdito da un saltito y al caer «SAID»
se aplasta un pelín), sin que ningún dibujo tape a otro. Sale encima del menú de inicio y arriba de los créditos. Si faltara alguna, saldría el nombre
del juego en letra.
