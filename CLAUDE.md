# Woodo Jam — reglas para Claude (único programador)

Juego de puzle de dioramas en 3D, clon mecánico de **Woodo** (Tiny Monks Tales, 2026), para una
game jam de 48 h. Claude escribe y prueba TODO el código; las artistas solo aportan arte en
`assets/`. Diseño de referencia: `docs/GDD-WOODO.md`. Lecciones de método: `docs/LECCIONES.md`.

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
| Medir si la luz quema (sobre capturas 1280×720) | `python3 -I tools/medir_luz.py build/captura.png` → `quemado` < 2 % |
| Regenerar el nivel de muestra | `"$GODOT" --headless --path . --script res://tools/build_sample_level.gd` |
| Abrir el juego para jugar | `"$GODOT" --path .` |
| Abrir el editor | `"$GODOT" --path . -e` |

**Definición de terminado** para cualquier cambio: `CHECK OK` + una captura mirada (si el cambio
se ve) + commit. Sin las tres, no está hecho.

## Mapa del código

| Fichero | Qué hace |
|---|---|
| `scenes/main.gd` | Monta cámara, arrastre, HUD, mando, luz; carga niveles de `data/levels.json`; args `--level --solve --capture` |
| `core/diorama.gd` | Raíz de cada nivel. Lee la convención de nombres y monta huecos, inventario, cajones, escondidos, sub-dioramas, color, orden, pistas, final |
| `core/name_rules.gd` | La convención `P_ H_ OD_ OR_ Z_` + tokens `__after-x`, `__reward-x` (ver `docs/ARTE-PIPELINE.md`) |
| `core/piece_slot.gd` | Un hueco: silueta blanca (shader `shaders/ghost.gdshader`) hasta que se coloca |
| `core/interactable.gd` | Lo que se pulsa: cajón, puerta, escondido, sub-diorama (colisión calculada sola) |
| `core/visuals.gd` | Cajas AABB, copia limpia de piezas, capa "arcilla" blanca (`material_overlay`) |
| `camera/diorama_camera.gd` | Órbita tipo plataforma giratoria, zoom con límites, desplazamiento, pellizco, mando |
| `ui/hud.gd` | Panel de piezas (derecha, scroll), pista con recarga, Volver, subtítulos, fin de nivel |
| `ui/inventory_item.gd` | Ficha con vista 3D que **gira con la cámara** (orientación = la del hueco) |
| `ui/drag_controller.gd` | Arrastrar del panel al 3D, imán, soltar = encajar o rechazar |
| `input/gamepad_cursor.gd` | Stick izq. = puntero, A = clic (mando sin código aparte) |
| `autoload/*` | `Events` (bus de señales), `GameState`, `InputSetup` (controles en código), `Narrator`, `Sfx` |
| `tests/smoke_test.gd` | Juega el nivel 0 entero con eventos reales; 24 comprobaciones |

Reglas de arquitectura: los sistemas se hablan por `Events`; la UI se construye en código (un
`.tscn` hecho a mano es frágil y da conflictos); **todo lo jugable se define por nombres en el
modelo de las artistas**, no por escenas editadas a mano. Un nivel nuevo = escena con
`core/diorama.gd` en la raíz + el `.glb` dentro + línea en `data/levels.json`.

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

- `main` siempre arranca y pasa `CHECK OK`. Yo trabajo en `codigo/<tema>` y fusiono a `main`.
- Las artistas suben a `arte/<nombre>-<cosa>` por PR; **yo** reviso, integro el arte en las escenas,
  paso el check y fusiono.
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
    encima de ~0,8 la arcilla y los colores claros se recortan. Ajustar la luz en
    `scenes/main.gd` (constantes arriba de `_build_environment`) con captura +
    `tools/medir_luz.py`, nunca a ojo. Medido con render por software (llvmpipe): confirmar en
    una GPU real.

## Pendiente de verificar con el juego real (ver GDD)

Lo marcado como *supuesto* en `docs/GDD-WOODO.md` se ha deducido de reseñas, no visto. Si alguien
del equipo tiene el juego, una partida de 10 minutos con este GDD delante cierra esas dudas.
