# Iluminación: cómo está hecha la luz y cómo se ajusta

**De momento la luz la llevamos nosotros** (Claude y quien lleva el proyecto), en la rama
`programacion`. Si más adelante alguien del equipo se encarga de ella, vuelve a tener su rama
`iluminacion` y esta carpeta pasa a ser suya (ver `GIT-Y-RAMAS.md`).

La luz es **en tiempo real** (nada horneado). El **fondo es pastel** (quinta nota: "que no sea
negro"), con un motivo que se repite en diagonal y se desplaza despacio; el **jugador elige** su
color y su motivo en Opciones (`ui/fondos.gd`). Por qué así y de dónde sale cada idea:
`ANALISIS-WOODO.md`.

| Fichero | Qué es |
|---|---|
| `luz_por_defecto.tscn` | La luz de todos los niveles que no tengan una propia |
| `menu.tscn` | La luz del cerdito del título (y del menú) |
| `desvan.tscn` | La luz del desván: empieza más oscura ("el desván a oscuras") y se calienta al montarlo |
| `desvan_tarde.tscn` | La del desván oficial: la tarde de verano (con `core/luz_ventana.gd`, el sol que entra por la ventana) |
| `rig_luz.gd` | El script de la raíz de cada escena de luz (lo que la hace "en tiempo real") |
| `fondo.gdshader` | El fondo: un pastel con un halo más claro detrás del diorama y un motivo (estrellas, corazones, lunares o liso) en filas diagonales que se desplazan. Sus colores los pone el juego según lo que eligió el jugador (`ui/fondos.gd`); los de la escena son los del azul |
| `vineta.gdshader` | La viñeta: oscurece las esquinas con un degradado largo, **del tono del fondo** (no negra, sexta nota): su color lo pone el juego, el oscuro del fondo elegido (`Fondos.dark`) |

## Qué hay dentro de una escena de luz

- **`Iluminacion`** (la raíz, con `rig_luz.gd`). En el Inspector:
  - *Seguir Camara* (0 a 1): 1 = la luz gira con la cámara. Al girar el diorama las sombras se
    mueven sobre él y el lado que miras siempre está bien iluminado. 0 = luz fija en el mundo.
  - *Color Inicio / Energia Inicio*: la luz principal con el diorama **sin montar** (fría, tenue:
    escena "congelada").
  - *Color Final / Energia Final*: con el diorama **completo** (cálida, plena). En medio, según
    las piezas puestas.
  - *Segundos Cambio*: lo que tarda en ponerse al día después de cada pieza.
- **`Ambiente`** (WorldEnvironment) → su `Environment`:
  - *Background → Mode: Canvas*: el fondo es la capa `Fondo` (no lo cambies a Color: se perdería
    el degradado).
  - *Ambient Light → Color / Energy*: la luz que llega a todas partes (aclara las sombras).
  - *Tonemap*: AgX. *Glow*: activado, hace brillar faroles, lámparas y chispas.
- **`Sol`** (DirectionalLight3D): la luz principal, con sombras. Su color y energía los pone el
  script (los de inicio/final de arriba): cambiarlos aquí no sirve.
- **`Contraluz`** (DirectionalLight3D, sin sombras): desde detrás, fría. Recorta el diorama
  contra el fondo.
- **`Fondo` → `Degradado`**: en *Material → Shader Parameters*: *Centro* y *Radio* del halo, el
  motivo (*Tam Forma* = separación, *Tam Figura*, *Velocidad*, *Angulo Patron* = 45º, *Giro*). Los
  **colores** los pone el juego (los que elija el jugador): cambiarlos aquí no sirve. Para cambiar
  o añadir un color de la lista, `ui/fondos.gd` + `tools/calibrar_fondo.gd` (ver "Cuidado").
- **`Vineta` → `Sombra`**: *Fuerza* (0 = sin viñeta) y *Suavidad*. El *Color* lo pone el juego (el
  oscuro del fondo elegido): cambiarlo aquí no sirve.

## Sombras (por qué ya no salen pixeladas)

Medido el 16-oct-2026 con recortes ampliados del borde de una sombra:
- La sombra del sol cubría **25 m** para un diorama de 5: la resolución se gastaba en aire y los
  bordes salían en escalera. Ahora el mapa de sombras **cubre solo lo que se ve** (distancia de la
  cámara + el diorama; `RigLuz.ajustar_sombra`, `margen_sombra`): al acercarte, más nítidas.
- *Shadow → Mode: Orthogonal* (un solo mapa) en vez de 4 cortes: con el alcance ajustado da bordes
  lisos.
- Mapa de sombras de **8192** en PC y **4096** en web (`project.godot`, `directional_shadow/size`).
- *Shadow → Blur* 2,5: borde suave, sin escalera.
- *Soft Shadow Filter Quality* no hace nada en Compatibility (probado): no tocarlo.

## Luces dentro de los modelos

- Una luz que cuelga de una pieza `P_` (el farol del título, la lámpara del escritorio) **está
  apagada mientras la pieza es silueta y se enciende con un fundido al colocarla**.
- La luz de una **zona** (la bombilla de cada sección `S_` del desván) se enciende con un fundido
  cuando se abre su sección. Así "la luz avanza" por el desván según el guion.
- Las demás luces del decorado están siempre encendidas.
- Las artistas pueden poner luces en Blender: el `.glb` las trae (ver `ARTE-PIPELINE.md`).

## Cómo trabajar

1. **Godot:** abre `preview/preview_assets.tscn` y pulsa F6 (Tab: el diorama de prueba): la misma luz,
   cámara y enfoque que el desván. En el editor no gira con la cámara ni cambia con el progreso: eso
   solo pasa jugando. (`probar_luz.tscn`, con la habitación japonesa, se borró el 18-oct.)
2. **Para cambiar la luz**: pulsa el icono de claqueta junto a `Iluminacion` (abre
   `luz_por_defecto.tscn`), cambia valores y guarda (**Ctrl+S**).
3. **F5** para verla de verdad: con la madera cruda, la pintura, las siluetas y las partículas.
4. **Pide a Claude que la mida** ("mide la luz"): captura del juego + captura del fondo solo, y
   comprueba que nada sale quemado. Comandos:
   ```
   bash tools/capture.sh build/c.png 6 0 --capture-after=5
   bash tools/capture.sh build/fondo.png 0 0 --solo-fondo
   python3 -I tools/medir_luz.py build/c.png --fondo build/fondo.png
   ```
   `quemado` tiene que salir por debajo del 2 %. Medido el 16-oct-2026: 0,0 % en la habitación
   (sin montar, a medias y completa) y en el cerdito del título.

## Luz propia para un nivel

Clic derecho en `luz_por_defecto.tscn` → *Duplicate* → llámala como el nivel. Ajústala y pide a
Claude que se la asigne (propiedad `Iluminacion` del nivel).

## Cuidado

- Renderer **Compatibility** (el único que funciona en el navegador): SSAO, SSR, SDFGI, niebla
  volumétrica y profundidad de campo no hacen nada. Sí funcionan: sombras de todas las luces,
  glow y el fondo por capa.
- **El fondo pasa por el tonemap**: un color sale distinto en el juego que en el selector (medido:
  0,17 se ve como 0,07). Y sin HDR en 2D el lienzo se corta en 1,0: el fondo no pasaba de un gris
  apagado (208/255). Por eso `main.gd` activa `use_hdr_2d` y los colores del fondo del 3D van
  calculados (por encima de 1) con `tools/calibrar_fondo.gd`, que los busca midiendo píxeles con la luz
  **y el postproceso de cine** (que dora las luces: sin contarlo, el azul salía gris y cálido), para cada
  escena de luz con fondo, y los deja en `data/fondo_calibrado.json`:
  `xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --resolution 320x180 --script res://tools/calibrar_fondo.gd`.
  Repetirlo si cambian el tonemap, el resplandor o los ajustes de una luz, el etalonaje de
  `shaders/desenfoque.gdshader` o un color, o si se añade una escena de luz.
- **Que no queme** (quinta nota): bombillas de zona a 0,8, lámpara del escritorio a 1,1, resplandor
  (*Glow*) a 0,4 y sol final del desván a 0,65; los focos de los momentos, a 1,2. Medido con recortes
  de las zonas calientes (techo sobre la bombilla: de 6 % a 0 % de píxeles al límite; mesa: de 11 %
  a 5 %).
- **Cada luz con sombra cuesta una pasada más** de dibujo en Compatibility. Las luces de las piezas
  van sin sombra a propósito; si se añade una con sombra, medir que el navegador lo aguanta.
- **No guardes escenas de otras carpetas** (`levels/`, `scenes/`...) con el editor abierto mientras
  Claude trabaja: el editor puede pisar sus cambios.
