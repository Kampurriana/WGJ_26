# Woodo Jam — reglas para Claude (único programador)

> **¿Eres un Claude nuevo en este proyecto?** Antes de nada lee `docs/TRASPASO.md`: estado actual,
> cómo arrancar, decisiones ya tomadas, lo pendiente y con quién trabajas.

Juego de puzle de dioramas en 3D, clon mecánico de **Woodo** (Tiny Monks Tales, 2026), para una
game jam de 48 h. Claude escribe y prueba TODO el código; las artistas solo aportan arte en
`assets/`. Diseño de referencia: `docs/GDD-WOODO.md`; aspecto (luz, fondo, partículas, cámara):
`docs/ANALISIS-WOODO.md`. Lecciones de método: `docs/LECCIONES.md`.

## Stack (verificado)

- **Godot 4.7.2 stable**, GDScript tipado, renderer **Compatibility** (`gl_compatibility`): es el
  único que exporta a Web (itch.io). No cambiarlo sin decidirlo con el equipo.
- Ventana base 1280×720, `stretch canvas_items / expand`.
- Sin plugins ni addons. Sin C#.
- La ruta del ejecutable de Godot va en la variable de entorno `GODOT` (en Windows, el
  `*_console.exe`, que es el que escribe en la terminal).
- En sesiones de Claude Code **en la nube**, `.claude/hooks/session-start.sh` instala Godot 4.7.2
  (Linux, con SHA512 comprobado) y exporta `GODOT` al arrancar. En un PC local no hace nada.

## Comandos (todos probados)

| Para qué | Comando |
|---|---|
| Comprobación completa (importar + test de humo) | `bash tools/check.sh` → tiene que decir `CHECK OK` |
| Mirar el juego (captura real con ventana) | `bash tools/capture.sh build/captura.png 4 0` (4 piezas solas, nivel 0) y abrir el PNG |
| Lo mismo en la nube (Linux sin pantalla) | `xvfb-run -a -s "-screen 0 1280x720x24" bash tools/capture.sh build/captura.png 4 0` |
| Ver los tests en ROJO (defectos provocados en copias) | `python3 -I -u tools/mutantes.py . build/mutantes "$GODOT"` → todos `ROJO BIEN` (135, ~1 min cada uno: con `PARALELO=3` van tres a la vez, cada copia con su propio `user://`; en segundo plano y sin tocar código mientras: copia el proyecto; en la nube, esperar con un turno en marcha, trampa 44); `SOLO=M17` para uno, `DESDE=`/`HASTA=` para una parte |
| Medir si la luz quema (sobre capturas 1280×720) | `bash tools/capture.sh build/fondo.png 0 0 --solo-fondo` y `python3 -I tools/medir_luz.py build/captura.png --fondo build/fondo.png` → `quemado` < 2 % (el fondo ya no es liso: sin `--fondo` no mide) |
| Mirar el menú de inicio | `bash tools/capture.sh build/menu.png 30 menu --capture-after=12` (resuelve el título y abre el menú); páginas: `--menu-page=opciones\|logros\|creditos`; pausa: `bash tools/capture.sh build/pausa.png 0 0 --menu-page=pausa`; el álbum de dibujos: `bash tools/capture.sh build/album.png 0 0 --f9 --menu-page=dibujos --capture-after=3` (sin `--f9`, vacío) |
| Mirar el desván entero (F9) | `bash tools/capture.sh build/f9.png 0 0 --f9 --capture-after=7` |
| Mirar los momentos del desván | `--solve=11 --capture-after=8` (hucha), `--solve=56 --capture-after=30` (espejo), `--solve=57 --capture-after=41.7` (la hucha del final: la moneda y su fantasma a medio gesto) |
| Mirar otro fondo | `... --fondo=C,M` (C = color, M = motivo: índices de `ui/fondos.gd`), p. ej. `bash tools/capture.sh build/f.png 30 menu --capture-after=13 --fondo=1,1` (rosa con corazones) |
| Recalcular los colores del fondo | `xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --resolution 1280x720 --script res://tools/calibrar_fondo.gd` → líneas para `Fondos.COLORES` (si cambia el tonemap o el resplandor) |
| Mirar los créditos del final | `bash tools/capture.sh build/creditos.png 0 0 --creditos --capture-after=12` |
| Mirar el primer plano de un dibujo encontrado | `bash tools/capture.sh build/dibujo.png 0 0 --inspeccion --capture-after=3` |
| Mirar una pieza en mano o el zoom | `bash tools/capture.sh build/mano.png 0 0 --hold=480,520` · `bash tools/capture.sh build/zoom.png 6 0 --zoom=14,700,300 --capture-after=5` |
| Regenerar el nivel de muestra | `"$GODOT" --headless --path . --script res://tools/build_sample_level.gd` |
| Regenerar el cerdito del título | `"$GODOT" --headless --path . --script res://tools/build_title_level.gd` (escribe el modelo `levels/provisional/menu_provisional.glb` y `levels/menu_titulo.tscn`; después, `check.sh` lo importa). Hay que rehacerlo si cambia el nombre del juego |
| Regenerar el desván (el diorama principal) | `"$GODOT" --headless --path . --script res://tools/build_attic_level.gd` (escribe `levels/provisional/desvan_provisional.tscn` y `levels/level_01_desvan.tscn`) |
| Regenerar la habitación japonesa | `"$GODOT" --headless --path . --script res://tools/build_room_level.gd` (pisa `levels/level_01_habitacion.tscn`; ya no se juega) |
| Revisar el arte importado (`assets/kit/`) | `"$GODOT" --headless --path . --script res://tools/revisar_kit.gd` → cada modelo con sus piezas, medidas, triángulos, UV y material; `REVISION OK` |
| Crear los materiales del kit (una carpeta de `assets/kit/texturas/` = un `M_<x>.tres`) | `"$GODOT" --headless --path . --script res://tools/materiales_kit.gd` y después `check.sh` (reimporta) |
| Mirar los assets en la **preview** (aparte del juego, misma luz/cámara/enfoque que el desván) | `xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --resolution 1280x720 res://preview/preview_assets.tscn -- --capture=build/preview.png [--vista=diorama] [--yaw=40] [--zoom=2.4] [--luz=inicio]`; en el editor, F6 sobre la escena (Tab: catálogo / diorama) |
| Rehacer el **tileset** del kit (una escena por pieza en `assets/kit/piezas/`, para montar a mano) | `"$GODOT" --headless --path . --script res://tools/piezas_kit.gd` → `PIEZAS OK` (después de `materiales_kit.gd` si llegan texturas) |
| Regenerar el diorama de prueba **desde cero** (pisa lo movido a mano) | `"$GODOT" --headless --path . --script res://tools/build_diorama_kit.gd -- --forzar` (sin `--forzar` no pisa `preview/diorama_kit.tscn`) |
| Abrir el juego para jugar | `"$GODOT" --path .` |
| Abrir el editor | `"$GODOT" --path . -e` |

**Definición de terminado** para cualquier cambio: `CHECK OK` + una captura mirada (si el cambio
se ve) + commit. Sin las tres, no está hecho.

## Mapa del código

| Fichero | Qué hace |
|---|---|
| `scenes/main.gd` | Monta cámara, arrastre, HUD, efectos, menús, créditos, mando, luz y el fundido desde negro; desde el menú, **fundido a negro** al darle a Jugar (`blackout_to_level`, sexta nota). Orden (cuarta nota): cerdito del título con sus frases → menú **sin frases** (sale cuando el cerdito acaba de hablar) → niveles de `data/levels.json` → al acabar el último, fundido y **créditos** (`roll_credits`) → menú; guarda progreso; args `--level[=menu] --menu-page --solve --capture --solo-fondo --f9 --creditos --inspeccion` (con `--solve` solo suena la frase de la última pieza, y los primeros planos de dibujos se cierran solos) |
| `iluminacion/*.tscn` + `rig_luz.gd` | La luz en tiempo real (`docs/ILUMINACION.md`): raíz `RigLuz` (gira con la cámara, va de fría a cálida con el progreso), `Ambiente` con fondo por capa, `Sol` con sombras, `Contraluz`, `Fondo` (pastel con un motivo en filas diagonales que se desplaza, `fondo.gdshader`; sus colores los pone `main.gd` con `ui/fondos.gd`, lo que eligió el jugador) y `Vineta` (degradado largo del oscuro del tono del fondo, `Fondos.dark`; no negra). `main.gd` pone la del nivel (`Diorama.iluminacion`) o `luz_por_defecto.tscn`, y activa `use_hdr_2d` (sin él el fondo no pasa de gris) |
| `assets/kit/` + `preview/` | El arte de las artistas traído de Drive (`assets/kit/LEEME.md`: qué es cada carpeta, convenciones T_/SM_ de Unreal, lo que falta). `preview/preview_assets.tscn`: **escena aparte** (no es del juego) con la luz, la cámara y el enfoque del desván y dos vistas (Tab): el **catálogo** de todas las piezas a tamaño real y el **diorama de prueba** (`preview/diorama_kit.tscn`, **se edita a mano** en el editor: cada pieza es una instancia de su escena del tileset `assets/kit/piezas/<Pieza>.scn` y se mueve/gira/duplica sin escalar): un rincón del desván montado solo con el kit siguiendo la referencia de 3ds Max de las artistas (faldón con cabios y correas, hastial con ventana redonda, pilares, suelo en L, muebles). Ninguna pieza se redimensiona: cada una con la transformación de su `.fbx`; solo se colocan y giran. Las que no tienen textura llevan un color provisional compartido por grupo (`assets/kit/materiales/provisional/*.tres`, retocable) |
| `ui/fondos.gd` | Los fondos que elige el jugador (Opciones): 5 pasteles (como se ven y ya corregidos para el tonemap, `tools/calibrar_fondo.gd`) y 4 motivos (estrellas, corazones, lunares, liso). `Fondos.apply(material, tonemapped, color, motivo)`; `Fondos.dark(color)`: su oscuro (viñeta y foco de los momentos) |
| `core/efectos.gd` | Partículas (CPUParticles3D) que escuchan a `Events`: polvo en la luz, serrín + chispas + anillo al encajar, soplo al recoger, chispas de pista, luces cálidas al completar, un destello de vez en cuando en los dibujos escondidos que esperan. Texturas en código o en `assets/texturas/particulas/` |
| `shaders/madera_cruda.gdshader` | La capa de madera sin pintar (veta de tablón) que cubre el diorama; la pintura son esferas que crecen desde cada pieza (`Diorama._add_paint`) |
| `levels/level_01_desvan.tscn` | **El nivel jugable**: el desván de la historia (`docs/GUION.md`), en 5 secciones `S_` (suelo de 18 tablones + estructura + hucha, infancia, adolescencia, adultez, el final), 69 piezas, muebles con cosas guardadas, 4 dibujos escondidos (`C_`: la casa, Ana y Lurdes —debajo de la cama—, el monstruo y el gato de las artistas, `assets/kit/dibujos/`, con su imagen y su color dominante en el metadato `color`) y su cuerda (`T_dibujos`, una pinza por dibujo). El cuarto dibujo (la niña bailarina con su abuela, `t_draw_03.png`) no se colecciona: es la pieza `P_dibujo` de la pared de la infancia («las niñas no pintan monstruos»); la imagen va en el material de la malla, no en `material_override` (el hueco lo vacía al colocar). El escritorio (`P_escritorio`) y sus tres cajones son los del kit (`SM_DeskA` + `SM_DeskC`/`SM_DeskD`, material `M_Desk`): el `.fbx` se instancia (en el `.tscn` queda como referencia) y el material va en *surface override*; el cajón de arriba (`OD_cajon_escritorio`) guarda la solicitud. Solo el Diorama: carga `assets/modelos/desvan/desvan.glb` si existe o el provisional `levels/provisional/desvan_provisional.tscn` (figuras + props del pack). Lo genera `tools/build_attic_level.gd` |
| `levels/level_01_habitacion.tscn` | Ya no se juega (no está en `data/levels.json`): la habitación japonesa con el pack de props |
| `levels/level_00_muestra.tscn` | Ya no se juega (no está en `data/levels.json`): es el banco de pruebas del test, usa toda la convención de nombres |
| `levels/menu_titulo.tscn` | El puzle del título: **la hucha de cerdito** sobre un cojín, 21 piezas (cuerpo, patas, cara, lazo y 7 pegatinas, ninguna con luz; la del nombre del juego va en un cartel). Solo el Diorama: carga `assets/modelos/menu/menu.glb` si existe (artistas) o `levels/provisional/menu_provisional.glb` (lo genera `tools/build_title_level.gd`) |
| `core/diorama.gd` | Raíz de cada nivel. Carga su modelo (`modelo` / `modelo_provisional`), lee la convención de nombres y monta huecos, inventario, cajones, escondidos, sub-dioramas, pintura, pistas, final. Desbloqueo (`is_unlocked`: sección abierta + `__after` + `__clave`; al arrastrar laten las siluetas donde va, salvo las piezas repetidas, como los tablones: encontrarles el sitio es el reto; al soltar una repetida **se ponen todas las iguales**, una tras otra: `twins_of`, `_show_placed`), las piezas de una sección salen cuando se callan sus frases (`_reveal_when_quiet`: antes si se pasan con clics), secciones (`_check_sections` → pausa/frases → `_open_when_free` (espera si `hold_sections`: el espejo) → `_open_pending` → `_reveal_pending`), qué mueble llama la atención (`_refresh`), `fundido_final`. **Dibujos escondidos** (`C_`): `collectible_ready`, `find_collectible` → mientras se mira de cerca se queda quieto (`hold_collectible`) y al soltarlo (`release_collectible`) vuela a la siguiente pinza de la cuerda (`_hang`); el `__con-x` se encuentra solo al acabar su momento |
| `core/section.gd` | Una sección `S_`: sus piezas, su decorado (oculto y sin colisión hasta abrirse), sus luces de zona. Un acto cerrado no se ve nada |
| `core/name_rules.gd` | La convención `P_ H_ OD_ OR_ Z_ S_ C_ T_` + tokens `__after-x`, `__reward-x`, `__con-x`... (ver `docs/ARTE-PIPELINE.md`) |
| `core/piece_slot.gd` | Un hueco: la **versión blanca** de la pieza (shader `shaders/ghost.gdshader`: opaca e iluminada, como en Woodo) hasta que se coloca. `shown` = su acto está abierto (al abrirse se materializa con una trama); blanca si ya se puede poner, gris si espera a otra; sus luces, apagadas hasta colocarla (se encienden con fundido) |
| `core/momentos.gd` | Los momentos de la historia (niveles con `momentos = true`): primer plano (`DioramaCamera.close_up`: avanza desde la vista del jugador, sin dar vueltas; los objetos planos de pared, de frente), lo que tapa el plano se desvanece (`_hide_occluders`; lo que toca al objeto, como el cuadro del caballete, no), bandas de cine, foco (`shaders/foco.gdshader`: el oscuro del tono del fondo, muy degradado), enfoque al objeto; **el objeto quieto** (sin gestos); clic = siguiente frase. `__reflejo` (el espejo: de frente, todo a negro, silueta en la luna; al acabar, **transición** a negro si viene el final) y `__ofrecida` (el final: corte a la hucha sola sobre su baúl, de tres cuartos y un poco desde arriba, **escena acogedora**: foco que parpadea, contraluz, motas, fondo `shaders/acogedor.gdshader`; en orden: sus frases → en cuanto se callan, la moneda y una **moneda fantasma** (`shaders/fantasma.gdshader`) que enseña en bucle el gesto de meterla → el jugador la coge (la fantasma se va; vuelve si la suelta lejos) y la **arrastra** a la ranura, que la atrae; al entrar, golpe de luz, chispas y destello en pantalla) |
| `core/enfoque.gd` | Postproceso de enfoque de cine (`shaders/desenfoque.gdshader`): todo un poco desdibujado y más fuera de la zona de foco; el foco va al centro de la pantalla (el zoom lleva allí la zona que se acerca), a la mano al arrastrar y al objeto en los momentos (cambio de foco suave). Capa 0; momentos en la 1; interfaz en la 2 |
| `core/interactable.gd` | Lo que se pulsa: cajón, puerta o tapa (`__x`), escondido, sub-diorama (colisión calculada sola). "Atención": brillo (`shaders/brillo.gdshader`) + contorno dorado (`shaders/borde.gdshader`) + un pequeño movimiento cada 2,4 s. Un `H_` sabe su `container` (cajón padre o puerta hermana) |
| `core/visuals.gd` | Cajas AABB, copia limpia de piezas, capa de madera cruda (`material_overlay`), superficies |
| `camera/diorama_camera.gd` | Cámara fija (sin desplazar), todo con muelles amortiguados (`_spring`) y una "respiración" lentísima de cámara de cine (que se para en los primeros planos): giro dentro de los límites del nivel con inercia, zoom con tope hacia el cursor que lleva esa zona al centro (`ZOOM_CENTER_PULL`) y vuelve al encuadre al alejar; entrada al nivel (`intro`), primeros planos no muy cerca (`close_up`, `CLOSE_UP_*`), pista que gira y acerca, acercamiento suave al colocar (`nudge`, muelle aparte), encuadre de cada sección (`frame_box`), vaivén al completar (`showcase`); mano sobre lo que se puede tocar; pellizco, mando |
| `ui/hud.gd` | Disposición pulida con la referencia (Ooblets): arriba a la izquierda la **tarjeta de tarea** (zona, qué toca —primero poner, luego buscar— y barra "5 / 12", `_update_task`); arriba a la derecha el **contador de dibujos** ("0 / 4" desde el principio) con la bandeja debajo; abajo, subtítulos en el centro y **consejos como avisos** abajo a la derecha (entran deslizándose); Menú y Pista con su tecla abajo a la izquierda. Bandeja de piezas (derecha, flotante, dos columnas, scroll, agrupada por acto; enseña TODAS las piezas, las bloqueadas con candado y su porqué en un bocadillo; se aparta al arrastrar dejando su borde; se recoge al completar; se aparta en los momentos), pista con recarga, Volver, Menú (pausa), subtítulos (crecen hacia arriba), rótulo de **nuevo capítulo** a toda pantalla al abrir un acto (CAPÍTULO II / Adolescencia, con línea y aparición), consejos (esperan a que se vaya el rótulo y a que acabe un primer plano), contador de dibujos bajo el título, lo recogido (`H_`) **vuela** desde el objeto hasta su ficha (`_fly_to_tray`), fin de nivel (arriba; no en `fundido_final`) |
| `ui/inspeccion.gd` | Sexta nota: al encontrar un dibujo, su **primer plano para inspeccionarlo** con la disposición del aviso de "badge" de la referencia: título grande ("¡UN DIBUJO!"), su nombre en una cápsula montada encima, el dibujo en 3D en un visor (`SubViewport` con su mundo; se mece y se gira arrastrando), barra con su texto y "2 DE 4" con puntos; suena su voz, `dibujo_encontrado_<n>`, una por dibujo en el orden en que salen, y el botón grande "¡A LA CUERDA!" (llega a los 0,7 s; también Intro/Espacio/Esc). Fondo: oscuro del tono del fondo con halo y rayos (`shaders/inspeccion.gdshader`). Capa 4 |
| `ui/creditos.gd` | Créditos del final: el fondo pastel que eligió el jugador, el nombre del juego, los dibujos encontrados (`ui/dibujo_icono.gd`) y `data/creditos_es.txt` subiendo despacio; el último renglón se queda y funde a negro; un clic o Esc los acaba; `finished` → menú |
| `ui/main_menu.gd` | Menú de inicio: Jugar/Continuar, Opciones, Logros, Créditos (`data/creditos_es.txt`), Salir (no en Web). **Sin selector de nivel**: el juego es un solo diorama, el desván |
| `ui/pause_menu.gd` | Pausa (Esc): Reanudar, **Dibujos** (el álbum, como el libro de la referencia: a la izquierda una casilla por dibujo con su imagen —los que faltan en silueta con "?"—, a la derecha el elegido en grande con su nombre y texto), Opciones, Menú principal, Salir |
| `ui/options_panel.gd` | Opciones **por pestañas** (`show_tab`): Fondo (muestras de color y motivo), Sonido (volúmenes, subtítulos), Juego (cámara, pantalla completa, pista automática, borrar progreso) |
| `ui/ui_theme.gd` | Aspecto de toda la interfaz en código (madera y papel); `ui/theme.tres` manda si existe |
| `ui/inventory_item.gd` | Ficha con vista 3D que **gira con la cámara** (orientación = la del hueco); bloqueada: gris, candado, vista dibujada una vez (`UPDATE_ONCE`), tiembla al tocarla |
| `ui/drag_controller.gd` | Arrastrar del panel al 3D, imán, soltar = encajar o rechazar. La pieza en mano nunca atraviesa nada: su caja viaja por el rayo del cursor y choca con las superficies (`Visuals.add_surface`, capa 2) |
| `input/gamepad_cursor.gd` | Stick izq. = puntero, A = clic (mando sin código aparte) |
| `autoload/*` | `Events` (bus de señales), `Settings` (opciones en `user://ajustes.cfg` + buses Musica/Efectos/Voz), `GameState` (estado + progreso en `user://progreso.cfg`), `InputSetup` (controles en código), `Narrator` (frases en cola, nunca se pisan; una clave puede ser una lista; `{"frases": []}` = solo la voz, sin subtítulo; `skip`; nombres de las piezas de `data/piezas_es.json`), `Sfx` |
| `tests/smoke_test.gd` | Juega como un jugador: el cerdito del título (asset .glb, pegatinas, nombre, luz), menú, la muestra entera con pausa, vuelta al menú, y cada nivel de `data/levels.json` (carga, cada pieza con su modelo, se completa); además la pieza en mano no atraviesa nada, la cámara (límites, inercia, pista), la pintura, la luz (gira con la cámara, despierta con el progreso, sombras ajustadas), las partículas, `escala_luces`, el narrador, y la historia del desván entera (secciones en orden, uno a uno, clave al final, muebles que brillan con contorno dorado, la bandeja que espera entre secciones, cámara antes que la inscripción, flash, el final, fundido), actos cerrados ocultos y siluetas blancas opacas, el enfoque, el rótulo de capítulo, la bandeja (candados, por qué, se aparta), los momentos (hucha, lo que tapa se esconde, el dibujo de frente, espejo de frente y a negro, el final: corte a la hucha sola y moneda arrastrada), el atajo F9; y de la cuarta nota: primeros planos quietos, el menú sin frases, los créditos al acabar y vuelta al menú, los dibujos de las artistas (baúl cerrado/abierto, after, vuelo a la pinza, logro, contador, consejo, destellos, el de la cámara al acabar su momento, F9 los cuelga), el espejo que espera y su transición, la escena acogedora del final, la moneda quieta y su golpe de luz; y de la quinta nota: la estrella del cerdito sin luz, sin partículas al pasar al menú, HDR 2D, el fondo elegido en Opciones (color, liso, corazones, créditos), lo recogido vuela a la bandeja, el zoom lleva la zona al centro con el enfoque allí, el suelo de tablones (largos que no entran en huecos medianos, sin latir), el cuadro del caballete no se esconde, la luz de la lámpara; y de la sexta nota: un tablón pone todos los iguales (uno tras otro), el final (primero las frases, la moneda en cuanto se callan, la fantasma que va a la ranura en bucle, se va al coger la moneda y vuelve si se suelta lejos), el fundido a negro al darle a Jugar, la viñeta y el foco del tono del fondo, el primer plano no pegado, la inspección de los dibujos (se abre al encontrarlo, título/nombre/«1 DE 4», el botón llega tarde, se gira arrastrando, al cerrar vuela a la cuerda, Esc la cierra sin pausa); y del pulido de la UI: la tarjeta de tarea (dónde está, qué pide, primero poner y luego buscar), el contador arriba a la derecha con la bandeja debajo, los consejos abajo a la derecha, el álbum de la pausa, las opciones por pestañas; y de los assets: los dibujos de las artistas (4 coleccionables con su imagen y el de la pared, que se sigue viendo al colocarlo), el escritorio y los cajones del kit, el tileset y el diorama de prueba de la preview (instancias, sin escalar), las voces, la música, el kit; el menú sin selector de nivel; las texturas finales del kit; las voces del 18-oct (una por dibujo; voz sin subtítulo); 268 comprobaciones. Usa sus propios ficheros `user://test_*.cfg` |

Reglas de arquitectura: los sistemas se hablan por `Events`; la UI se construye en código (un
`.tscn` hecho a mano es frágil y da conflictos); **todo lo jugable se define por nombres en el
modelo de las artistas**, no por escenas editadas a mano. **El arte se cambia dejando el fichero
en su sitio**: un nivel nuevo = escena con `core/diorama.gd` en la raíz y la ruta del `.glb` en
`modelo` (o el `.glb` dentro) + línea en `data/levels.json`.

## Modo prototipo (antes de entregar, cambiarlo)

`GameState.RESET_ON_START = true`: cada Play empieza con el puzle del título y todos los niveles sin
hacer (no se lee ni se guarda el progreso; las Opciones sí). Para la build de entrega: `false`.

`GameState.DEBUG_SHORTCUTS = true`: **F9 monta el diorama entero de golpe** (todas las zonas,
cada pieza, los dibujos en su cuerda, sin frases; se queda a la vista con el panel de fin, sin fundido). Para mirar el
dressing o probar el final sin colocar 51 piezas. Para la build de entrega: `false`.

## Cómo trabajo aquí

- **Autonomía:** si está claro y dentro del juego, se hace y se informa en pasado. Al equipo solo
  le llegan decisiones de diseño reales, bloqueos y lo que necesito de las artistas.
- **Ciclo corto:** cambio pequeño → `bash tools/check.sh` → captura si se ve → commit. Cada 1–2 h
  algo jugable en `main`.
- **Un test nuevo por mecánica nueva** en `tests/smoke_test.gd`, y verlo en ROJO una vez (meter el
  defecto a propósito en una copia) antes de fiarse de su verde.
- **Mirar, no solo consultar:** un test verde no dice si se ve bien. Captura y mírala.
- Si un arreglo falla 2–3 veces: parar y rediagnosticar con trazas, no iterar a ciegas.

## Git (ver `docs/GIT-Y-RAMAS.md`)

- Ramas fijas por área: `arte` (artistas, solo `assets/`), `iluminacion` (luz), `programacion`
  (yo). `main` solo la toco yo, juntando esas ramas: siempre arranca y pasa `CHECK OK`.
- Yo trabajo en `programacion`. Para juntar: `git merge origin/<rama>` en `main` → check +
  captura → push → **poner al día las tres ramas con `main`** (los comandos, en `docs/GIT-Y-RAMAS.md`).
- Antes de juntar `arte`: `git diff --stat main...origin/arte` tiene que ser solo `assets/`; y
  `iluminacion`, solo `iluminacion/`.
- **La luz la llevamos de momento nosotros** (decidido el 16-oct-2026): `iluminacion/` se toca en
  `programacion`. Si vuelve a haber alguien de luz, la carpeta vuelve a ser suya (rama
  `iluminacion`; no editarla si puede tener el editor abierto, trampa 7).
- No crear ramas `arte/...`, `iluminacion/...` ni `programacion/...`: Git no deja una rama y una
  "carpeta" de ramas con el mismo nombre.
- **Nunca `git add -A` ni `git add .`**: se añade por nombre lo que he tocado. Si aparece un fichero
  que no reconozco, es de otra persona: mirarlo antes de nada.
- Mensajes de commit con acentos, comillas o acentos graves: `git commit -F fichero.txt`
  (escrito con la herramienta de ficheros), nunca `-m "…"`: la shell se come los acentos graves.
- Se commitean los `.uid` y `.import` que genera Godot. `.godot/` y `build/` nunca.

## Trampas de Godot medidas en ESTE proyecto

1. **Godot sale con código 0 aunque un script reviente.** El veredicto lo da el log (`check.sh`
   exige `SMOKE OK` y cero `ERROR`/`SCRIPT ERROR`). Primera corrida: rc=0 con 108 errores.
2. **Sin ventana (`--headless`) el tamaño de ventana es 0×0** y Godot escala los eventos ×0,05. En
   tests, los eventos de ratón van con `get_viewport().push_input(e, true)` (coordenadas locales).
3. **Un contenedor maqueta a sus hijos un fotograma después.** Leer la posición de un Control
   recién creado da (0,0): esperar 2 fotogramas antes de usar `get_global_rect()`.
4. **`global_transform` fuera del árbol da error** (`!is_inside_tree()`). Para copias sin añadir,
   transformaciones locales encadenadas (`Visuals.local_aabb`).
5. **Nodos fuera del árbol que nadie libera = fuga** (los prototipos de pieza). Se liberan en
   `NOTIFICATION_PREDELETE` del Diorama.
6. **Tras añadir o renombrar un `class_name`**, correr el import (`check.sh` ya lo hace) para que
   se regenere `.godot/global_script_class_cache.cfg`.
7. **Si el editor está abierto con una escena que yo edito en disco**, el editor la pisa al
   guardar. Los `.tscn` y `project.godot` se tocan con el editor cerrado o avisando.
8. **Reimportar un `.glb` borra lo que se haya editado DENTRO de la escena importada.** La lógica
   vive en la escena del nivel que lo contiene, nunca dentro del `.glb`.
9. El panel 3D del inventario usa un `SubViewport` por ficha: con más de ~30 fichas visibles,
   medir FPS antes de añadir más.
10. **La luz quemaba la escena** (93 % del diorama en blanco recortado al empezar, medido). En
    este renderer cambiar de tonemap (Filmic/AgX/lineal) apenas mueve el resultado; lo que
    manda es la energía: una cara de arriba recibe `SUN_ENERGY·0,77 + AMBIENT_ENERGY`, y por
    encima de ~0,8 la arcilla y los colores claros se recortan. La luz está en
    `iluminacion/luz_por_defecto.tscn` (y `menu.tscn`); medir con captura +
    `tools/medir_luz.py`, nunca a ojo. Medido con render por software (llvmpipe): confirmar en
    una GPU real.
11. **`main.gd` corre en `PROCESS_MODE_ALWAYS`** (capturas, menús y mando siguen en pausa). Sus
    hijos HEREDAN eso: todo lo que sea "juego" (cámara, arrastre, HUD, el nivel) se pone
    `PROCESS_MODE_PAUSABLE` a mano. Un hijo nuevo sin ese ajuste no se para en la pausa.
12. **En un Theme, un tipo hereda los estilos de su clase padre**: `CheckButton` cogía la tablilla
    de madera de `Button` con texto oscuro encima (ilegible, visto en captura). Al dar estilo a un
    tipo base, revisar sus hijos (`CheckButton`, `CheckBox`, `OptionButton`, `MenuButton`...).
13. **`PackedStringArray` no tiene `any()`/`all()`** (los `Array` sí): bucle o `Array(...)`.
14. **Una silueta puede desaparecer detrás de la arcilla.** Las dos son transparentes y Godot
    las ordena por la distancia al CENTRO de su caja: una pared grande tiene el centro más cerca
    que la estantería pegada a ella, se pintaba después y la borraba entera (visto en captura de la
    habitación). Arreglo: `Visuals.GHOST_RENDER_PRIORITY`. Con modelos nuevos, mirar siempre una
    captura con 0 piezas puestas: toda pieza tiene que verse como silueta.
15. **Los packs de modelos traen rutas `res://` fijas.** Copiados a otra carpeta, sus escenas
    salen vacías sin dar error en el check. El test comprueba que cada hueco tiene malla.

16. **Un `ShaderMaterial` creado en código y guardado en un `.tscn` sin valores guarda los
    parámetros como `null`**, y en un shader de lienzo `null` es negro: el fondo salía negro puro
    (visto en captura). Al generar escenas de luz, dar valor explícito a cada parámetro.
17. **El fondo por capa (`Background → Canvas`) pasa por el tonemap del 3D**: un halo de 0,17 se
    veía a 0,07 (medido). Por eso los colores del fondo van más altos de lo que parece.
18. **`medir_luz.py` necesita `--fondo`** desde que el fondo es un degradado: compara contra una
    captura del fondo solo (`--solo-fondo`). Sin eso, no mide (y lo dice).
19. **Un `.glb` se puede generar desde Godot** (`GLTFDocument.append_from_scene` +
    `write_to_filesystem`) y vuelve a importarse con los nombres (`P_x__after-y`), las letras 3D
    (`TextMesh` → malla) y las luces. Así el título provisional pasa por el mismo camino que el
    arte de las artistas (probado ida y vuelta el 16-oct-2026).

20. **Dos `RefCounted` que se apuntan entre sí no se liberan nunca** (`Section.slots` ↔
    `PieceSlot.section`): 117 objetos y 53 materiales fugados al salir (visto en el log del check).
    El Diorama corta el ciclo en `NOTIFICATION_PREDELETE`.
21. **Un nodo oculto sigue chocando.** Ocultar un mueble (`visible = false`) no quita su colisión:
    la pieza en mano tropezaría con muebles invisibles. Se pone `collision_layer = 0` a sus
    `Superficie` (`Section.set_decor`).
22. **Sombras pixeladas = alcance de sombra demasiado grande**, no falta de tamaño de mapa:
    `directional_shadow_max_distance` 25 m para un diorama de 5 daba escalera; ajustado a lo que se
    ve + modo ortogonal, bordes lisos (medido con recortes ×4). `soft_shadow_filter_quality` no hace
    nada en Compatibility.
23. **Un ambiente de cielo (`ambient_light_source = SKY`) con ACES lavó el diorama** (luminancia
    196 frente a 140, 25 % saturado, sombras perdidas): descartado, medido con `medir_luz.py`.
24. **Un brillo que solo suma luz no se ve sobre madera clara** (el baúl "que brilla" parecía uno
    más en la captura). Lo que se lee de lejos es un **contorno** opaco: copia de la malla un poco
    más grande con `cull_front` (`shaders/borde.gdshader`). Y mirar que el mueble no quede detrás
    de una viga desde la cámara del nivel.
25. **Dos Godot del mismo proyecto a la vez comparten `user://`** (va por el nombre del proyecto,
    no por la carpeta): un check en una copia mientras corren los mutantes se pisaron el
    `user://test_progreso.cfg` y falló "completar el nivel queda guardado". No correr dos checks a
    la vez.
26. **Al colocar una pieza, durante 0,35 s mide 1,2 veces** (el saltito `Diorama._pop`). Lo que lea
    su tamaño o su transformación en ese instante sale mal: el reflejo del espejo salía corrido
    hacia arriba y un gesto habría dejado la pieza grande para siempre. Se mide pasado
    `Diorama.POP_TIME`.
27. **Godot pinta como cara de delante la de sentido horario** (medido: en un `BoxMesh`,
    `cross(v1-v0, v2-v0)·normal < 0`). Las pegatinas del cerdito se extruyen así.
28. **El orden de las señales cuenta:** `Momentos` se conecta a `section_opened` antes que
    `main.gd`, así que el `frame_box` de `main` pisaba el primer plano del epílogo. Ahora `main` no
    encuadra si la cámara está en un momento. Ojo al añadir otro oyente que mueva la cámara.
29. **Con 50 fichas en la bandeja, cada una con su `SubViewport`:** las bloqueadas se dibujan una
    sola vez (`UPDATE_ONCE`) y no giran; solo las disponibles (pocas) se actualizan. Medir FPS en
    navegador (trampa 9).
30. **Recorrer con tipo un diccionario o array que tiene nodos ya liberados revienta**
    (`for v: VisualInstance3D in dict:` → "Trying to assign invalid previously freed instance").
    Recorrer sin tipo y comprobar `is_instance_valid` antes de usar (`Momentos._unisolate`).
31. **Dos `CanvasLayer` con el mismo `layer` no tienen un orden fiable:** el desenfoque (capa 0)
    se pintaba después de las bandas de cine y las emborronaba. Cada cosa en su capa: enfoque 0,
    momentos 1, interfaz 2, inspección de un dibujo 4, menú 5, pausa 8.
32. **`get_shader_parameter` de un parámetro que nunca se ha puesto devuelve `null`** (no el valor
    por defecto del shader): `float(null)` revienta. Dar valor a los parámetros al crear el material.
33. **La pausa entre secciones se calcula al poner la clave** (`Narrator.remaining()` en ese momento):
    si el momento de la clave dura más (el espejo, con su transición), la sección siguiente se abría
    ENCIMA. Ahora la pausa pasa por `_open_when_free`, que espera mientras `Diorama.hold_sections`
    (lo pone Momentos en el espejo). Un test que borre las frases no lo ve: llama a `_open_when_free`.
34. **El fondo de un mueble bajo no se ve desde la cámara del nivel** (pitch ~24°): el lado de delante
    del baúl tapaba el dibujo tumbado dentro (visto en captura). Lo de dentro, apoyado en el fondo o
    asomando; mirar siempre una captura desde la vista del jugador, no desde arriba.
35. **`Narrator.clear()` no quitaba el subtítulo** que estaba en pantalla (solo vaciaba la cola): el
    menú salía con una frase encima. Ahora `clear()` avisa con `skipped` si estaba hablando.
36. **Mutantes lentos:** con el desván entero, cada pasada de `check.sh` en una copia tarda ~3 min
    (el test espera en tiempo real); 99 seguidos no caben en una tarea de 2 h. `PARALELO=3` corre tres
    copias a la vez, cada una con `config/custom_user_dir_name` propio (si no, trampa 25). Y ojo:
    `pkill -f patrón` también mata la shell que lo lanza si su línea contiene el patrón.
37. **El fondo por capa no pasaba de un gris 208/255**: el lienzo 2D se corta en 1,0 antes del tonemap
    (AgX lleva 1,0 a ~0,82). Con `get_viewport().use_hdr_2d = true` (main.gd) el lienzo admite más de 1
    y sale el pastel; sus colores, calculados con `tools/calibrar_fondo.gd` (medido, no a ojo).
38. **Sin pantalla, la vista mide 1280×1280** (no 1280×720): una rejilla de puntos de pantalla en un
    test tiene que ir a la medida de `get_visible_rect()` (si no, solo mira la mitad de arriba).
39. **Con `--script` no hay autoloads**: un script que usen las herramientas (`ui/fondos.gd`) no puede
    nombrar `Settings`, `GameState`... (no compila). Que reciba los datos como parámetros.
40. **Un tween con una lambda que captura un nodo que se libera** da "Lambda capture at index 0 was
    freed" en cada paso. Capturar el id y buscar el nodo dentro (`Hud._fly_to_tray`).
41. **Sin pantalla, leer una textura de un viewport da error** (`get_image()` con el renderer de mentira):
    comprobar `DisplayServer.get_name() != "headless"` antes.
42. **Las manchas de pintura tienen tope** (`MAX_PINTURA` del shader de madera = `Visuals.MAX_PAINT`,
    128): con el suelo de tablones el desván pasó de 64 y salían avisos; subir los dos a la vez.
43. **Si el test no compila, Godot no se cierra** y `check.sh` se queda esperando para siempre (visto:
    un `Momentos.COIN_DELAY` que ya no existía). Si el check tarda más de ~5 min, mirar
    `build/check.log` (sale el `Parse Error`) y parar el Godot con su PID (no con `pkill -f`, trampa 36).
44. **En la nube, entre turnos la máquina se congela**: lo lanzado en segundo plano (mutantes) no
    avanza mientras no haya un turno en marcha, y los avisos de "terminado" pueden llegar sin que
    haya terminado. Para esperar: un bucle en primer plano de menos de 10 min que mire el registro
    (`build/mutantes_*.log`), repetido hasta que estén todos.

## Pendiente de verificar con el juego real (ver GDD)

Lo marcado como *supuesto* en `docs/GDD-WOODO.md` se ha deducido de reseñas, no visto. Si alguien
del equipo tiene el juego, una partida de 10 minutos con este GDD delante cierra esas dudas.
