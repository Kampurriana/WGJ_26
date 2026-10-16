# Traspaso: para el Claude que sigue con el proyecto

Escrito por el Claude que montó el proyecto (16-oct-2026) y puesto al día por el segundo Claude
(mismo día, tras el "aspecto de Woodo"). Léelo entero antes de tocar nada, después `CLAUDE.md`
(reglas, comandos, trampas) y `docs/LECCIONES.md`. Todo lo que digo aquí está comprobado salvo
donde pone **sin probar**.

## 1. Cómo arrancar (primeros 10 minutos)

1. **Godot 4.7.2.**
   - En una sesión de Claude Code **en la nube**: el hook `.claude/hooks/session-start.sh` lo instala
     solo en `/opt/godot/4.7.2/` y exporta `GODOT`. Comprueba con `echo $GODOT` y
     `"$GODOT" --headless --version` → `4.7.2.stable.official…`. Si `GODOT` está vacío, ejecuta el
     hook a mano: `CLAUDE_CODE_REMOTE=true bash .claude/hooks/session-start.sh` y
     `export GODOT=/opt/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64`. Pasa siempre que el repo
     se añade a la sesión después de arrancar (el hook no llega a correr). Entonces `GODOT` no
     se conserva entre comandos: ponlo delante de cada uno (`export GODOT=… && bash tools/check.sh`).
   - El clon de la nube es superficial y solo sigue `main`. Para ver las otras ramas:
     `git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*' && git fetch --depth=50 origin`.
   - En el **PC de la persona (Windows)**: Godot portátil, descomprimido de
     https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip
     (p. ej. en `C:\Tools\Godot\4.7.2\`), y la ruta a su `*_console.exe` en `.claude/settings.local.json` → `{ "env": { "GODOT": "C:/…/Godot_v4.7.2-stable_win64_console.exe" } }`.
2. `bash tools/check.sh` → tiene que decir **`CHECK OK (158 comprobaciones, 12 avisos)`** (~80 s).
   Los 12 avisos son sonidos que aún no existen (`assets/audio/...`): normal.
3. Mirar el juego: en la nube no hay pantalla, se usa Xvfb:
   `xvfb-run -a -s "-screen 0 1280x720x24" bash tools/capture.sh build/c.png 0 0` → `CAPTURA OK … (1280x720)`
   y abrir el PNG con la herramienta de leer ficheros. En Windows, sin `xvfb-run`.
4. `git switch programacion && git pull --ff-only` y a trabajar ahí (§3).

Si el paso 2 o 3 no sale así, **no sigas**: diagnostica con `build/check.log` / `build/capture.log`.

## 2. Estado del juego (16-oct-2026, junta "Cerdito, bandeja y momentos" en `main` y en las 3 ramas)

- **El diorama principal es el desván de la historia** (`docs/GUION.md`, a partir del guion de
  Manu con sus cambios): `levels/level_01_desvan.tscn`. Se monta por **secciones** (`S_`): primero
  paredes y tejado (la hucha cierra esa fase), luego **infancia, adolescencia y adultez** (tres
  zonas integradas en el mismo desván) y el epílogo. **Todo se ve desde el principio en modo
  fantasma**, cada acto de su color (rosa, azul, verde) y con un letrero flotante con su nombre;
  al abrirse un acto, su decorado se vuelve de verdad y se enciende su bombilla. Los muebles que
  guardan algo **brillan (contorno dorado) y se mueven**. Provisional (figuras + props del pack);
  el de las artistas irá en `assets/modelos/desvan/desvan.glb`.
- **Momentos de la historia** (`core/momentos.gd`): al colocar un objeto con frase, la cámara se le
  acerca despacio, entran bandas de cine y un foco, el objeto hace su gesto (la bailarina gira, la
  nutria se achucha...) y suena su frase; clic = siguiente frase. **El espejo**: cámara de frente,
  todo a negro menos él, y en la luna aparece la silueta de ella, que se va con "¿Dónde estoy yo?".
  **El epílogo**: primer plano de la hucha mientras se dicen sus frases; la moneda aparece
  flotando y un clic la mete; después, fundido a negro.
- **Bandeja** (derecha, flotante, más estrecha): enseña **todas** las piezas que faltan, agrupadas
  por acto; las que aún no van, grises y con candado, y al pasar el ratón o tocarlas dice por qué
  ("Es de «II · Adolescencia»…", "Antes tiene que estar la cumbrera."). Al coger una pieza **se
  aparta** (queda su borde: soltar ahí = no poner nada) y se puede colocar lo que tapaba.
- **Aspecto (`docs/ANALISIS-WOODO.md`):** fondo oscuro con halo y viñeta; luz en tiempo real que
  gira con la cámara y va de fría a cálida al montar; **sombras nítidas** (alcance ajustado a lo
  que se ve, mapa ortogonal, 8192 en PC); el diorama empieza en **madera cruda** y la **pintura se
  extiende** desde cada pieza; partículas (polvo, serrín, chispas, anillo, **luces cálidas** al
  completar, ya sin hojas); cámara con **muelles** (nada brusco), entrada, inercia, pista que
  acerca, **acercamiento suave al colocar**, encuadre de cada sección y vaivén al completar.
- **Arranque:** el puzle del título es **la hucha de cerdito** de la protagonista, sobre un cojín:
  21 piezas (cuerpo, 4 patas, hocico, orejas, ojos, cola, ranura, coloretes, lazo y 7
  **pegatinas**: estrella que brilla en la oscuridad, corazón, flor, luna, rayo, arcoíris y la del
  nombre del juego en un cartel). Es **un `.glb`** (`levels/provisional/menu_provisional.glb`,
  generado por `tools/build_title_level.gd`); si existe `assets/modelos/menu/menu.glb`, se usa ese. Al
  resolverlo sale el **menú** a la izquierda: Jugar/Continuar, Elegir diorama, Opciones, Créditos,
  Salir (no en Web). **Pausa** con Esc o el botón Menú.
- `levels/level_01_habitacion.tscn` ("La habitación de estudio", con el pack *Modern Japanese Home
  Props Lite*, MIT) **ya no se juega**: el desván usa algunos de esos props (escritorio, silla,
  lámpara, altavoz, libros, taza, reloj). Se puede borrar si nadie la quiere.
- `levels/level_00_muestra.tscn` ya **no se juega**: es el banco de pruebas del test.
- **Luz:** en escenas editables `iluminacion/*.tscn` (`docs/ILUMINACION.md`). La lámpara del
  escritorio y los faroles se encienden al colocarlos. Medido: quemado 0,0 % (`tools/medir_luz.py`
  con `--fondo`). **Medido con llvmpipe: confirmar en una GPU real.**
- **Cámara:** fija (sin desplazar), giro dentro de límites por nivel, zoom con tope hacia el cursor.
- **Pieza en mano:** nunca atraviesa paredes, suelo ni muebles (colisiones en capa 2).
- **Modo prototipo:** `GameState.RESET_ON_START = true` → cada Play empieza de cero.
- **Atajo de prueba F9:** monta el diorama entero de golpe y se queda a la vista
  (`GameState.DEBUG_SHORTCUTS`).

## 3. Ramas y cómo se trabaja con el equipo

Ramas fijas por área (pedido del equipo): `arte` (artistas, solo `assets/`), `iluminacion` (quien
lleve la luz, solo `iluminacion/`), `programacion` (Claude), `main` (solo Claude, juntando las otras
tras `CHECK OK` + captura). Después de cada junta, **poner al día las tres ramas con `main`**.
Comandos exactos en `docs/GIT-Y-RAMAS.md`. No crear ramas `arte/...` etc. (choca con la rama `arte`).

Ciclo de cada cambio: rama `programacion` → cambio → `bash tools/check.sh` → test nuevo si es una
mecánica (y su mutante en `tools/mutantes.py`, visto en ROJO) → captura mirada → commit con
`git commit -F build/msg.txt` → push → juntar en `main` → check en `main` → push → poner al día ramas.

Antes de juntar `arte` o `iluminacion`: `git diff --stat main...origin/<rama>` tiene que tocar solo su
carpeta. Si no, parar y preguntar.

## 4. La persona y el equipo

- Habla **español**. Es quien lleva el proyecto; no es programador y Git le cuesta: las
  instrucciones, **paso a paso, botón a botón, en GitHub Desktop**, cortas, cabiendo en un móvil.
  Prefiere que **lo hagas tú** ("hazlo tú, te doy permiso a todo"): autonomía total dentro del juego;
  confirma solo lo irreversible o lo que sale fuera.
- Su PC: Windows, proyecto en `C:\WGJ_26`, GitHub Desktop, Godot 4.7.2. Para ver cambios: cerrar Godot →
  Fetch origin → Pull origin → abrir Godot → F5. (Si Godot está abierto al hacer Pull de un cambio en
  `project.godot`, el editor puede pisarlo: decírselo cuando toques `project.godot`.)
- Repo: **`Kampurriana/WGJ_26`**, **público**. Dos chicas nuevas (artistas): evafernandez3d@gmail.com e
  ines.jacksonma@gmail.com. **Ya están invitadas** (confirmado el 16-oct). No sé sus usuarios de GitHub.
- **La luz la llevamos nosotros** (Claude + la persona), en `programacion` (decidido el 16-oct).

## 5. Decisiones ya tomadas (no volver a discutirlas)

- Clon mecánico de Woodo; menú desbloqueado con un puzle (pedido; no encontrado en fuentes).
- Luz: sol 0,55, ambiente 0,35, sombras 0,8, AgX, fondo (0.86, 0.80, 0.72). Medido, no a ojo.
- Cámara sin desplazamiento, giro limitado, **zoom hacia el cursor** (decisión mía; se le ofreció
  cambiarlo a zoom solo al centro si lo prefiere — está en `DioramaCamera._zoom`).
- La pieza en mano no atraviesa nada (también en el tramo del imán).
- Cada Play empieza de cero mientras se prototipa (**antes de entregar: `RESET_ON_START = false`
  y `DEBUG_SHORTCUTS = false`**, que quita el F9).
- **Feedback del 16-oct (nota a mano + guion PDF), ya hecho:** luz más tipo Unreal y sombras sin
  pixelar; diorama en 3 secciones (infancia, adolescencia, adultez) integradas pero que se montan
  por orden; se empieza por paredes y tejado y la historia se desbloquea por partes; partículas sin
  hojas (cozy); movimiento de cámara al colocar suave; dressing lleno; muebles que brillan para
  enseñar que se abren; peluche = **nutria**; caja de música **de la abuela** (y a mamá le pasó lo
  mismo con el ballet); en la adolescencia, **primero la cámara y luego la inscripción** (la
  inscripción cierra el acto; el flash sale al colocar la cámara). "Ventana abierta con luz entrando"
  estaba tachado: no se hizo.
- **Feedback del 16-oct, segunda nota:** bandeja que tape menos y que se aparte al coger una pieza
  ("déjame ponerlo detrás"); todas las siluetas en modo fantasma desde el principio, con los actos
  diferenciados; la bandeja enseña todas las piezas, las bloqueadas marcadas (dibujo y texto); el
  puzle del título es **el cerdito**, de unas 20 piezas, sobre todo pegatinas; primer plano de la
  hucha con los diálogos y la moneda (y el fade out); el espejo de frente, fondo negro y su
  diálogo; secuencias con personalidad; jugabilidad orientativa y pausada.
- Ramas fijas por área (§3).
- El juego se llama **"Woodo Jam"** (confirmado el 16-oct; la persona lo escribió "woodoo jam" al
  confirmar que no cambia).
- **Luz en tiempo real y fondo oscuro** (pedido). Que la luz **gire con la cámara** y que vaya de
  fría a cálida con el progreso fue decisión mía: se cambia en el Inspector (`seguir_camara`,
  colores/energías de inicio y final), sin código.
- El título es **la hucha de cerdito** (pedido en la segunda nota; antes era un cofre con las letras
  del nombre, como el de Woodo). El nombre del juego va en una pegatina, en el cartel. El arte se
  cambia **dejando el `.glb` en su sitio** (`Diorama.modelo`), nunca editando escenas.
- La escena empieza en **madera sin pintar** (Woodo), ya no en arcilla blanca.

## 6. Pendiente (por orden de prioridad)

1. **Exportar a Web (sin probar).** El plan de la jam obliga a hacerlo pronto. Faltan las plantillas de
   exportación de Godot 4.7.2 y `export_presets.cfg`. **Peso:** el pack de props son 332 MB (~230 MB los
   modelos que usa la habitación; texturas grandes dentro de cada `.glb`): hay que reducir texturas
   (p. ej. import con compresión/tamaño máximo en los `.import`, o reexportar a 1024 px) y quitar del
   export lo que no se use (`demo/`, `scenes/` del pack).
   Ojo también al **rendimiento en navegador** de lo nuevo: la capa de madera es una pasada
   transparente más por malla, el contraluz otra, y las partículas son de CPU. Medir FPS.
2. **Probar en una GPU real** la luz y las sombras (todo se midió con render por software) y el
   rendimiento del desván (51 piezas, 3 luces de zona, capa de madera) en navegador.
3. **Confirmar el aspecto con el juego de verdad**: la lista de 8 preguntas de
   `docs/ANALISIS-WOODO.md` §4 (fondo, partículas, cámara al completar...). Cada respuesta es
   ajustar valores, no un sistema nuevo.
4. Créditos con nombres reales (`data/creditos_es.txt`).
5. Sonidos y música: no hay ninguno (`assets/audio/...`; nombres en `autoload/sfx.gd`; los que
   pide el juego salen como avisos en `build/check.log`: `snap`, `reject`, `momento`, `brillo`...).
   La caja de música debería sonar durante su momento y apagarse al cerrar la infancia (guion).
   Los momentos ganarían mucho con un sonido por objeto (`momento_<id>`, sin hacer).
6. El cerdito del título y el desván son provisionales: cuando lleguen los `.glb` de las artistas,
   dejarlos en su sitio (`docs/ARTE-PIPELINE.md`) y mirar capturas (sobre todo con 0 piezas
   puestas: toda pieza tiene que verse como silueta). Si piden una plantilla `.glb` del desván para
   Blender, generarla desde el provisional.
7. **Mando sin probar** (no hay mando en la nube).
8. Si hacen falta más dioramas: escena con `core/diorama.gd` y su `.glb` en `modelo` + línea en
   `data/levels.json`; el test prueba solo cada nivel de esa lista.

## 7. Cosas que ya me costaron tiempo (y cómo se resolvieron)

Todas están también en `CLAUDE.md` → "Trampas". Las que más pueden repetirse:
- **Acceso a GitHub desde la nube:** la sesión solo ve los repos conectados. Si un push da 403 "Claude
  doesn't have GitHub access", la persona tiene que instalar la app de Claude en el repo
  (github.com/apps/claude/installations/select_target). La sesión **no puede** invitar colaboradores ni
  usar la búsqueda de usuarios de GitHub (el proxy lo bloquea): eso lo hace la persona en la web.
- `gh` funciona para endpoints `repos/Kampurriana/WGJ_26/...` (REST); GraphQL no (usa `gh api`).
- La persona copió el pack de props a otra carpeta: sus escenas tenían rutas `res://` fijas y salían
  vacías **sin que el check fallara**. Corregido; el test ya comprueba que cada hueco tiene malla.
- Siluetas tapadas por la arcilla (orden de transparencias): `Visuals.GHOST_RENDER_PRIORITY`.
- Luz quemada: lo que manda es la energía, no el tonemap. Medir con `tools/medir_luz.py`.
- `main.gd` va en `PROCESS_MODE_ALWAYS`: todo hijo nuevo que sea "juego" se pone PAUSABLE a mano.
- Escribir ficheros con la herramienta de ficheros, no con heredocs; commits con `-F fichero`.
- Las sustituciones por script deben afirmar cuántas hicieron (así se hizo todo: "N de N").
- **Desde la nube no se pueden abrir webs** (WebFetch falla; Steam está bloqueado por la red):
  solo funciona el buscador. Lo de Woodo sale de extractos del buscador; no se ha visto ningún vídeo.
- Escenas de luz generadas por código: los parámetros de shader sin valor se guardan como `null`
  y salen negros (`CLAUDE.md`, trampas 16-19).

## 8. Herramientas de verificación

| Qué | Cómo |
|---|---|
| Todo el test | `bash tools/check.sh` → `CHECK OK (158 …)` |
| Ver los tests en rojo | `python3 -I -u tools/mutantes.py . build/mutantes "$GODOT"` → 67 × `ROJO BIEN` (~1 h: córrelo en segundo plano y no toques código mientras, que copia el proyecto en cada pasada) |
| Captura de cualquier pantalla | `tools/capture.sh` (opciones en `scenes/main.gd`: `--level=menu`, `--menu-page=`, `--solve=`, `--hold=X,Y`, `--zoom=K,X,Y`, `--solo-fondo`, `--f9`). Momentos del desván: `--solve=11` (hucha), `--solve=57 --capture-after=27` (espejo), `--solve=58 --capture-after=30` (epílogo) |
| Medir si la luz quema | `bash tools/capture.sh build/fondo.png 0 0 --solo-fondo` y `python3 -I tools/medir_luz.py build/c.png --fondo build/fondo.png` |
| Regenerar niveles | `"$GODOT" --headless --path . --script res://tools/build_room_level.gd` (y `build_title_level.gd`, `build_sample_level.gd`) |
