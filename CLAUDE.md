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
| Ver los tests en ROJO (defectos provocados en copias) | `python3 -I tools/mutantes.py . build/mutantes "$GODOT"` → todos `ROJO BIEN` (~30 min, en segundo plano y sin tocar código mientras: copia el proyecto); `SOLO=M17` para uno |
| Medir si la luz quema (sobre capturas 1280×720) | `bash tools/capture.sh build/fondo.png 0 0 --solo-fondo` y `python3 -I tools/medir_luz.py build/captura.png --fondo build/fondo.png` → `quemado` < 2 % (el fondo ya no es liso: sin `--fondo` no mide) |
| Mirar el menú de inicio | `bash tools/capture.sh build/menu.png 10 menu --capture-after=5` (resuelve el título y abre el menú); páginas: `--menu-page=opciones\|elegir\|creditos`; pausa: `bash tools/capture.sh build/pausa.png 0 0 --menu-page=pausa` |
| Mirar una pieza en mano o el zoom | `bash tools/capture.sh build/mano.png 0 0 --hold=480,520` · `bash tools/capture.sh build/zoom.png 6 0 --zoom=14,700,300 --capture-after=5` |
| Regenerar el nivel de muestra | `"$GODOT" --headless --path . --script res://tools/build_sample_level.gd` |
| Regenerar el cofre del título | `"$GODOT" --headless --path . --script res://tools/build_title_level.gd` (escribe el modelo `levels/provisional/menu_provisional.glb` y `levels/menu_titulo.tscn`; después, `check.sh` lo importa). Hay que rehacerlo si cambia el nombre del juego |
| Regenerar la habitación japonesa | `"$GODOT" --headless --path . --script res://tools/build_room_level.gd` (pisa `levels/level_01_habitacion.tscn`) |
| Abrir el juego para jugar | `"$GODOT" --path .` |
| Abrir el editor | `"$GODOT" --path . -e` |

**Definición de terminado** para cualquier cambio: `CHECK OK` + una captura mirada (si el cambio
se ve) + commit. Sin las tres, no está hecho.

## Mapa del código

| Fichero | Qué hace |
|---|---|
| `scenes/main.gd` | Monta cámara, arrastre, HUD, efectos, menús, mando, luz y el fundido desde negro. Arranca en el cofre del título → menú → niveles de `data/levels.json`; guarda progreso; args `--level[=menu] --menu-page --solve --capture --solo-fondo` |
| `iluminacion/*.tscn` + `rig_luz.gd` | La luz en tiempo real (`docs/ILUMINACION.md`): raíz `RigLuz` (gira con la cámara, va de fría a cálida con el progreso), `Ambiente` con fondo por capa, `Sol` con sombras, `Contraluz`, `Fondo` (degradado oscuro, `fondo.gdshader`) y `Vineta`. `main.gd` pone la del nivel (`Diorama.iluminacion`) o `luz_por_defecto.tscn` |
| `core/efectos.gd` | Partículas (CPUParticles3D) que escuchan a `Events`: polvo en la luz, serrín + chispas + anillo al encajar, soplo al recoger, chispas de pista, hojas al completar. Texturas en código o en `assets/texturas/particulas/` |
| `shaders/madera_cruda.gdshader` | La capa de madera sin pintar (veta de tablón) que cubre el diorama; la pintura son esferas que crecen desde cada pieza (`Diorama._add_paint`) |
| `levels/level_01_habitacion.tscn` | **El nivel jugable**: habitación japonesa con los 16 modelos del pack de props (MIT), 17 huecos, cajón con el boli escondido, rincón de la mesa baja que da el cuaderno. Lo genera `tools/build_room_level.gd` |
| `levels/level_00_muestra.tscn` | Ya no se juega (no está en `data/levels.json`): es el banco de pruebas del test, usa toda la convención de nombres |
| `levels/menu_titulo.tscn` | El cofre del título, como en Woodo: las letras del nombre (una pieza cada una) + paisaje pequeño. Solo el Diorama: carga `assets/modelos/menu/menu.glb` si existe (artistas) o `levels/provisional/menu_provisional.glb` (lo genera `tools/build_title_level.gd`) |
| `core/diorama.gd` | Raíz de cada nivel. Carga su modelo (`modelo` / `modelo_provisional`), lee la convención de nombres y monta huecos, inventario, cajones, escondidos, sub-dioramas, pintura, orden, pistas, final; `progress()` |
| `core/name_rules.gd` | La convención `P_ H_ OD_ OR_ Z_` + tokens `__after-x`, `__reward-x` (ver `docs/ARTE-PIPELINE.md`) |
| `core/piece_slot.gd` | Un hueco: silueta blanca (shader `shaders/ghost.gdshader`) hasta que se coloca; sus luces, apagadas hasta entonces (se encienden con fundido) |
| `core/interactable.gd` | Lo que se pulsa: cajón, puerta, escondido, sub-diorama (colisión calculada sola) |
| `core/visuals.gd` | Cajas AABB, copia limpia de piezas, capa de madera cruda (`material_overlay`), superficies |
| `camera/diorama_camera.gd` | Cámara fija (sin desplazar): giro dentro de los límites del nivel (`Diorama.camera_yaw_min_deg`...) con inercia, zoom con tope hacia el cursor que vuelve al encuadre al alejar; entrada al nivel (`intro`), pista que gira y acerca, empujón al encajar (`kick`), vaivén al completar (`showcase`); pellizco, mando |
| `ui/hud.gd` | Bandeja de piezas (derecha, dos columnas, scroll; se recoge al completar), pista con recarga, Volver, Menú (pausa), subtítulos, fin de nivel (arriba) |
| `ui/main_menu.gd` | Menú de inicio: Jugar/Continuar, Elegir diorama, Opciones, Créditos (`data/creditos_es.txt`), Salir (no en Web) |
| `ui/pause_menu.gd` | Pausa (Esc): Reanudar, Opciones, Menú principal, Salir |
| `ui/options_panel.gd` | Opciones (volúmenes, subtítulos, pantalla completa, cámara, pista automática, borrar progreso) |
| `ui/ui_theme.gd` | Aspecto de toda la interfaz en código (madera y papel); `ui/theme.tres` manda si existe |
| `ui/inventory_item.gd` | Ficha con vista 3D que **gira con la cámara** (orientación = la del hueco) |
| `ui/drag_controller.gd` | Arrastrar del panel al 3D, imán, soltar = encajar o rechazar. La pieza en mano nunca atraviesa nada: su caja viaja por el rayo del cursor y choca con las superficies (`Visuals.add_surface`, capa 2) |
| `input/gamepad_cursor.gd` | Stick izq. = puntero, A = clic (mando sin código aparte) |
| `autoload/*` | `Events` (bus de señales), `Settings` (opciones en `user://ajustes.cfg` + buses Musica/Efectos/Voz), `GameState` (estado + progreso en `user://progreso.cfg`), `InputSetup` (controles en código), `Narrator`, `Sfx` |
| `tests/smoke_test.gd` | Juega como un jugador: cofre del título (asset .glb, letras, luces), menú, la muestra entera con pausa, vuelta al menú, y cada nivel de `data/levels.json` (carga, cada pieza con su modelo, se completa); además la pieza en mano no atraviesa nada, la cámara (límites, inercia, pista), la pintura, la luz (gira con la cámara, despierta con el progreso) y las partículas, `escala_luces`; 108 comprobaciones. Usa sus propios ficheros `user://test_*.cfg` |

Reglas de arquitectura: los sistemas se hablan por `Events`; la UI se construye en código (un
`.tscn` hecho a mano es frágil y da conflictos); **todo lo jugable se define por nombres en el
modelo de las artistas**, no por escenas editadas a mano. **El arte se cambia dejando el fichero
en su sitio**: un nivel nuevo = escena con `core/diorama.gd` en la raíz y la ruta del `.glb` en
`modelo` (o el `.glb` dentro) + línea en `data/levels.json`.

## Modo prototipo (antes de entregar, cambiarlo)

`GameState.RESET_ON_START = true`: cada Play empieza con el puzle del título y todos los niveles sin
hacer (no se lee ni se guarda el progreso; las Opciones sí). Para la build de entrega: `false`.

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

## Pendiente de verificar con el juego real (ver GDD)

Lo marcado como *supuesto* en `docs/GDD-WOODO.md` se ha deducido de reseñas, no visto. Si alguien
del equipo tiene el juego, una partida de 10 minutos con este GDD delante cierra esas dudas.
