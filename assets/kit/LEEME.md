# assets/kit — el arte de las artistas, importado

Viene de la carpeta compartida de Drive **jam** (descargado el 17-oct-2026; puesto al día el 18-oct con
`Pack06`, `Pack07`, `Pack08`, `SM_ComodaC` y el blocking `Blocking3.fbx`). Misma estructura que allí,
para que sea fácil poner al día:

| Aquí | En Drive | Qué es |
|---|---|---|
| `modelos/<Carpeta>/SM_*.fbx` | `Assets/<Carpeta>/` | Piezas sueltas, una por fichero, con su nombre bueno |
| `paquetes/*.fbx` | `Texturas/*.fbx` | Varias piezas en un fichero (los que se mandaron a texturizar) |
| `texturas/<Conjunto>/T_<Conjunto>_{BC,ARM,Normal}.png` | `TexturasFinales/<Conjunto>/` | Texturas finales |
| `materiales/M_<Conjunto>.tres` | — | Material de cada conjunto (lo genera `tools/materiales_kit.gd`) |
| `materiales/estilo/tono.tres`, `mezcla.tres` | — | El estilo cozy de todo el kit (ver abajo) |
| `dibujos/t_draw_*` | `2D/` | Dibujos 2D |
| `referencia/Blocking3.fbx` | `jam/Blocking3.fbx` | La escena de las artistas (el blocking de 3ds Max): de ella sale el diorama de prueba |

## Convenciones (las de Unreal, como las exportan)

- Modelos en **metros**, eje Y arriba (3ds Max exporta así en FBX; Godot los lee bien).
- `T_<x>_BC` color, `T_<x>_ARM` empaquetada (R = oclusión, G = rugosidad, B = metálico),
  `T_<x>_Normal` normales **DirectX** (se importan con el verde invertido).
- Una pieza lleva el material de un conjunto si su nombre lo contiene (`SM_DeskA` → `Desk`).

## Importación (optimizada para la web)

- Texturas de 3D: comprimidas en VRAM con mipmaps; la de normales, como normal map.
- Dibujos 2D: con pérdida (WebP, calidad 0,85) y como mucho 1024 px de lado. Si llegan enormes se
  guardan reducidos a 2048 px de lado en JPG (`t_draw_04` venía en 8455 × 12911).

## Lo que falta (a fecha de importación)

- Las piezas sueltas de menos de ~36 KB no se pudieron bajar una a una (el conector de Drive las
  devuelve en línea). Las que existen en un paquete se cogen de ahí: `Pack02.fbx`, `Pack03.fbx`
  (nombres buenos) y `FloorCeilingPlanksCajonesqueFaltan.fbx`, `Boxes.fbx` (tapas de las cajas),
  pero estos dos traen los **nombres por defecto de 3ds Max** (`CeilingSupport014`, `SB020`,
  `Object006`...), no los `SM_` buenos.
- No están en ningún paquete: `SM_DeskB` (el tercer cajón del escritorio: en el desván se repite
  `SM_DeskC` mientras tanto), `SM_CeilingSupportVertical`, `SM_SkirtingBoardBack`,
  `SM_SkirtingBoardTop`, `SM_CeilingSupportSmallPillars`, `SM_CeilingSupporDiagonal`.
- `Desk.fbx` (de `Texturas/`) no se ha traído: son las partes sueltas que luego se unieron en
  `SM_DeskA/C/D` (mismas mallas).
- Texturas finales (18-oct, `TexturasFinales/` de Drive; no se usan las de `CON_LINEART/`): `Desk`
  (escritorio y cajones), `Boxes` (cajas y tapas), `LampStool` (lámpara y taburete), `Pack01` (suelo,
  zócalo, correas, pilar; 2048 px) y `Pack_02` (techo y postes). Qué piezas pinta cada una:
  `CONJUNTOS` en `tools/piezas_kit.gd`. **Sin texturas todavía** (color provisional): `Pack03`
  (paredes, ventana, zócalos de arriba), la cómoda, la tele, el burro, el MP3, el jarrón y los
  pinceles (`Pack04`/`Pack05`) y el `CoverDesk`.
- Al llegar texturas nuevas: dejarlas en `texturas/<Conjunto>/`, `tools/materiales_kit.gd`, importar
  (`check.sh` o `godot --import`) y `tools/piezas_kit.gd` (el diorama de prueba las coge solo).
- 18-oct: **no hay texturas nuevas** desde las de `TexturasFinales/` (comprobado fichero a fichero: mismos
  tamaños). Siguen sin textura `Pack03`, la cómoda, la tele, `Pack04`/`05` y lo nuevo de `Pack06`-`08`.
- `SM_ComodaC` ya está (18-oct; se bajó entera). Falta `SM_DeskB`: en el escritorio se repite `SM_DeskC`.
- Del 18-oct: `Pack06` (`SM_MusicBox`, `SM_PolaroidA..D`: las fotos), `Pack07` (`SN_Hat` = `SM_Hat`,
  `SM_Polaroid` = la cámara, `SM_Lights` = **un tramo** de la cuerda de bombillitas con una bombilla,
  `SM_LitterBox` y la
  hucha en piezas `SM_PigA..L`, que el tileset monta en `SM_Pig`), `Pack08` (`SM_Caballete`, `SM_CatBed`,
  `SM_Mirror`, `SM_Rug`). Las piezas de menos de ~36 KB (cerdito, espejo, arenero) salen de los paquetes,
  que traen los nombres buenos.
- `modelos/Cuerda/` (18-oct, pasadas por chat): `SM_cuerda.fbx` (un tramo de cuerda sola = pieza
  `SM_Cuerda`) y `SM_bombilla.fbx` (una bombilla con su casquillo = `SM_Bombilla`). Ojo: `SM_bombilla.fbx`
  trae la escena entera de 3ds Max (el blocking y más cosas); de él solo se coge la malla `bombilla`
  (`SOLO` en `tools/piezas_kit.gd`). La carpeta no entra en la build (solo es para la preview).
- El MP3 de `Pack05` viene despiezado (para texturizar): el tileset coge el **MP3 montado** de la
  referencia (`MONTADAS` en `tools/piezas_kit.gd`).
- En el blocking hay un remate de 1,38 m arriba del hastial (`SB17`) que no está en el kit: no se pone.
- `Pack04.fbx` y `Pack05.fbx` traen nombres de 3ds Max: `Box072` = burro, `TV05`/`TV01` = la tele
  (está suelta como `SM_TV`), `CoverDesk`, `Vase001` = jarrón, `Cylinder025-027` = pinceles,
  `MP301...` = el MP3 en trozos (el tileset los junta en `SM_MP3`).

## En uso en el juego

- El escritorio del desván (`P_escritorio`) es `SM_DeskA`, con sus tres cajones en la columna de la
  derecha (`SM_DeskC`, `SM_DeskD` del paquete, `SM_DeskC`) y `M_Desk`. Lo monta
  `tools/build_attic_level.gd` (`_kit`): el `.fbx` se instancia y el material va en *surface
  override*; si se cambia el fichero aquí, el desván lo coge al regenerarlo.

Para traerlo todo con sus nombres: un `.zip` de la carpeta en Drive (se baja entero de una vez).

## Comprobar

- `godot --headless --path . --script res://tools/revisar_kit.gd`: cada modelo, sus piezas, medidas,
  triángulos, UV y material; y las texturas.
- `godot --path . res://preview/preview_assets.tscn` (o F6 en el editor): la **preview** aparte, con
  la luz, la cámara y el postproceso del desván. Tab cambia entre el catálogo y el **diorama de
  prueba** (`preview/diorama_kit.tscn`, la arquitectura de la referencia de las artistas montada con
  sus piezas, sin redimensionar ninguna).

## Montar a mano (el tileset)

- `piezas/<Pieza>.scn`: una escena por pieza (86), hecha por `tools/piezas_kit.gd`. Raíz con escala 1 y
  el pivote abajo en el centro (se apoya en el suelo); dentro, la malla con la transformación de su
  `.fbx`. Las de nombre de 3ds Max se renombran (`Box072` = `SM_Burro`, `Object006..010` =
  `SM_CoverBoxA..E`, `Cylinder025..027` = `SM_BrushA..C`, `Vase001` = `SM_Vase`) y el MP3 y el pilar,
  que vienen en trozos, son una pieza.
- Material: el del kit (`materiales/M_<conjunto>.tres`) si la pieza tiene texturas; si no, un color
  provisional por grupo (`materiales/provisional/*.tres`), compartido: retocarlo cambia todas.
- Los dibujos de `dibujos/` también son piezas: `Dibujo_<fichero>`, un plano de 0,42 m de ancho con su
  imagen (el de la bailarina y su abuela es `Dibujo_t_draw_03`).
- `preview/diorama_kit.tscn` se abre en el editor y se monta arrastrando piezas desde
  `assets/kit/piezas/` (mover, girar, duplicar con Ctrl+D; **nunca escalar**). Para empezar de cero:
  `tools/build_diorama_kit.gd -- --forzar` (sin `--forzar` no pisa lo hecho a mano).
- **Cómo se monta** (18-oct): copia `referencia/Blocking3.fbx`. Cada objeto del blocking se empareja con
  la pieza del kit de su forma y se coloca ajustando su geometría a la del objeto (giro y posición; sin
  escalar). La tabla de lo emparejado sale al ejecutarlo (`-- --analizar` la enseña sin escribir nada).
  Lo que el blocking trae en trozos o con un modelo viejo se dice en `GRUPOS` / `A_MANO`. Después van los
  `ADORNOS` (más piezas del kit para llenar la escena: caja de música y hucha en la cómoda, polaroids,
  otra alfombra, otra lámpara, cajas, pinceles, el dibujo de la bailarina en el hastial) y las `CUERDAS`
  de bombillitas: tramos de `SM_Cuerda` punta con punta con 3 `SM_Bombilla` cada uno, a la misma
  distancia a lo largo de toda la cuerda (como la imagen de referencia del equipo), **apagadas, sin
  luces** (bajo la correa del faldón, en la pared lateral del entrante y en la del fondo; **esa última,
  alta y sin nada debajo, es el sitio para colgar los dibujos**). En el diorama, el blocking va girado 180° y centrado (fondo hacia -z, como el
  desván del juego).
- Si llega otro blocking: dejarlo en `referencia/`, cambiar `REFERENCIA` en `tools/build_diorama_kit.gd` y
  `tools/piezas_kit.gd`, y mirar la tabla (`-- --analizar`): lo que salga en `SIN PIEZA` va en `A_MANO`.

## El estilo cozy (18-oct)

Pedido: colores menos saturados y con menos contraste, el mismo estilo en todo. **Sin tocar las texturas
de las artistas**: cada material del kit (los `M_*.tres` y los provisionales) lleva una capa de detalle que
mezcla su color con un tono cálido (`materiales/estilo/tono.tres`) en la proporción de
`materiales/estilo/mezcla.tres` (su rojo: 0 = nada, 1 = todo el tono; ahora 0,38). Retocar esos dos
recursos en el Inspector cambia todo el kit a la vez. Además: reflejos más suaves y los colores
provisionales de una paleta apagada y cálida (`PALETA` en `tools/estilo_kit.gd`; nada brilla).
`tools/materiales_kit.gd` y `tools/piezas_kit.gd` lo ponen al crear; `tools/estilo_kit.gd` lo vuelve a
poner en todos (y deja `tono`/`mezcla` con sus valores de `TONO`/`MEZCLA`).
