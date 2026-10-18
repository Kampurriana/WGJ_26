# assets/kit — el arte de las artistas, importado

Viene de la carpeta compartida de Drive **jam** (descargado el 17-oct-2026). Misma estructura que
allí, para que sea fácil poner al día:

| Aquí | En Drive | Qué es |
|---|---|---|
| `modelos/<Carpeta>/SM_*.fbx` | `Assets/<Carpeta>/` | Piezas sueltas, una por fichero, con su nombre bueno |
| `paquetes/*.fbx` | `Texturas/*.fbx` | Varias piezas en un fichero (los que se mandaron a texturizar) |
| `texturas/<Conjunto>/T_<Conjunto>_{BC,ARM,Normal}.png` | `TexturasFinales/<Conjunto>/` | Texturas finales |
| `materiales/M_<Conjunto>.tres` | — | Material de cada conjunto (lo genera `tools/materiales_kit.gd`) |
| `dibujos/t_draw_*` | `2D/` | Dibujos 2D |

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
- Solo el escritorio tiene texturas; lo demás se ve con el material gris por defecto. `T_Pack_01`
  (`TexturasFinales/Pack01`, la estructura) está en Drive pero pesa 4,8 / 9,7 / 24 MB: el conector de
  Drive no baja más de ~3 MB. Hace falta exportarlas a 2048 px (PNG o JPG de 1-3 MB cada una).
- Tampoco están `SM_ComodaC` (en línea, como las piezas pequeñas) ni `SM_DeskB`: en el diorama se
  repiten `SM_ComodaB` y `SM_DeskC`.
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

- `piezas/<Pieza>.scn`: una escena por pieza (66), hecha por `tools/piezas_kit.gd`. Raíz con escala 1 y
  el pivote abajo en el centro (se apoya en el suelo); dentro, la malla con la transformación de su
  `.fbx`. Las de nombre de 3ds Max se renombran (`Box072` = `SM_Burro`, `Object006..010` =
  `SM_CoverBoxA..E`, `Cylinder025..027` = `SM_BrushA..C`, `Vase001` = `SM_Vase`) y el MP3 y el pilar,
  que vienen en trozos, son una pieza.
- Material: el del kit (`materiales/M_<conjunto>.tres`) si la pieza tiene texturas; si no, un color
  provisional por grupo (`materiales/provisional/*.tres`), compartido: retocarlo cambia todas.
- `preview/diorama_kit.tscn` se abre en el editor y se monta arrastrando piezas desde
  `assets/kit/piezas/` (mover, girar, duplicar con Ctrl+D; **nunca escalar**). Para empezar de cero:
  `tools/build_diorama_kit.gd -- --forzar` (sin `--forzar` no pisa lo hecho a mano).
