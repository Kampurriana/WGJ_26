# El logo (se monta en motor: `ui/logo.gd`)

Cuatro piezas, una imagen por pieza, PNG con fondo transparente y recortadas a su dibujo:

| Fichero | Pieza |
|---|---|
| `logo_moneda.png` | la moneda |
| `logo_what.png` | «what I never» |
| `logo_said.png` | «SAID» |
| `logo_cerdito.png` | el cerdito |

Cada una se coloca en su caja de la referencia de maquetación (`Logo.REF_RECTS`) sin deformarse y se
mueve por su cuenta (la moneda gira, «what I never» se mece, «SAID» respira, el cerdito da saltitos)
sin tapar a las demás. Sale encima del menú de inicio y arriba de los créditos. Mientras falte alguna,
sale el nombre del juego en letra.
