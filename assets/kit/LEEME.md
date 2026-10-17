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
- Solo el escritorio tiene texturas; lo demás se ve con el material gris por defecto.

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
  la luz, la cámara y el postproceso del desván.
