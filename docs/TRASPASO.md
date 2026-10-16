# Traspaso: para el Claude que sigue con el proyecto

Escrito por el Claude que montó el proyecto (16-oct-2026), al pasar el trabajo a otra sesión. Léelo
entero antes de tocar nada, después `CLAUDE.md` (reglas, comandos, trampas) y `docs/LECCIONES.md`.
Todo lo que digo aquí está comprobado salvo donde pone **sin probar**.

## 1. Cómo arrancar (primeros 10 minutos)

1. **Godot 4.7.2.**
   - En una sesión de Claude Code **en la nube**: el hook `.claude/hooks/session-start.sh` lo instala
     solo en `/opt/godot/4.7.2/` y exporta `GODOT`. Comprueba con `echo $GODOT` y
     `"$GODOT" --headless --version` → `4.7.2.stable.official…`. Si `GODOT` está vacío, ejecuta el
     hook a mano: `CLAUDE_CODE_REMOTE=true bash .claude/hooks/session-start.sh` y
     `export GODOT=/opt/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64`.
   - En el **PC de la persona (Windows)**: Godot portátil, descomprimido de
     https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip
     (p. ej. en `C:\Tools\Godot\4.7.2\`), y la ruta a su `*_console.exe` en `.claude/settings.local.json` → `{ "env": { "GODOT": "C:/…/Godot_v4.7.2-stable_win64_console.exe" } }`.
2. `bash tools/check.sh` → tiene que decir **`CHECK OK (89 comprobaciones, 8 avisos)`**. Los 8 avisos
   son sonidos que aún no existen (`assets/audio/...`): normal.
3. Mirar el juego: en la nube no hay pantalla, se usa Xvfb:
   `xvfb-run -a -s "-screen 0 1280x720x24" bash tools/capture.sh build/c.png 0 0` → `CAPTURA OK … (1280x720)`
   y abrir el PNG con la herramienta de leer ficheros. En Windows, sin `xvfb-run`.
4. `git switch programacion && git pull --ff-only` y a trabajar ahí (§3).

Si el paso 2 o 3 no sale así, **no sigas**: diagnostica con `build/check.log` / `build/capture.log`.

## 2. Estado del juego (commit `2fa87f5` en `main` y en las 3 ramas)

- **Arranque:** diorama-puzle del título (`levels/menu_titulo.tscn`, 4 piezas: letrero con el nombre
  del proyecto, farol, árbol, banco). Al resolverlo sale el **menú** a la izquierda: Jugar/Continuar,
  Elegir diorama, Opciones, Créditos, Salir (no en Web). **Pausa** con Esc o el botón Menú.
- **Nivel jugable:** `levels/level_01_habitacion.tscn`, "La habitación de estudio": los 16 modelos del
  pack *Modern Japanese Home Props Lite* (MIT, en `assets/modelos/ModernJapaneseHomePropsLite/`),
  17 huecos, órdenes (`__after-escritorio`, `__after-estanteria`), boli escondido en un cajón (`OD_`+`H_`),
  rincón con zoom (`Z_rincon__reward-cuaderno`). Arquitectura con figuras simples (el pack no la trae).
  Se genera con `tools/build_room_level.gd` (pisa la escena: si alguien la edita a mano, se pierde).
- `levels/level_00_muestra.tscn` ya **no se juega**: es el banco de pruebas del test.
- **Luz:** en escenas editables `iluminacion/*.tscn` (guía para el equipo: `docs/ILUMINACION.md`).
  Valores medidos para que nada se queme (`tools/medir_luz.py`, quemado < 2 %).
- **Cámara:** fija (sin desplazar), giro dentro de límites por nivel, zoom con tope hacia el cursor.
- **Pieza en mano:** nunca atraviesa paredes, suelo ni muebles (colisiones en capa 2).
- **Modo prototipo:** `GameState.RESET_ON_START = true` → cada Play empieza de cero.

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
  ines.jacksonma@gmail.com. Se le dijo que las invite él desde la web (Settings → Collaborators → Add
  people); **sin confirmar** si lo hizo ni sus usuarios de GitHub. Falta saber quién lleva la luz.

## 5. Decisiones ya tomadas (no volver a discutirlas)

- Clon mecánico de Woodo; menú desbloqueado con un puzle (pedido; no encontrado en fuentes).
- Luz: sol 0,55, ambiente 0,35, sombras 0,8, AgX, fondo (0.86, 0.80, 0.72). Medido, no a ojo.
- Cámara sin desplazamiento, giro limitado, **zoom hacia el cursor** (decisión mía; se le ofreció
  cambiarlo a zoom solo al centro si lo prefiere — está en `DioramaCamera._zoom`).
- La pieza en mano no atraviesa nada (también en el tramo del imán).
- Cada Play empieza de cero mientras se prototipa (**antes de entregar: `RESET_ON_START = false`**).
- Ramas fijas por área (§3).

## 6. Pendiente (por orden de prioridad)

1. **Exportar a Web (sin probar).** El plan de la jam obliga a hacerlo pronto. Faltan las plantillas de
   exportación de Godot 4.7.2 y `export_presets.cfg`. **Peso:** el pack de props son 332 MB (~230 MB los
   modelos que usa la habitación; texturas grandes dentro de cada `.glb`): hay que reducir texturas
   (p. ej. import con compresión/tamaño máximo en los `.import`, o reexportar a 1024 px) y quitar del
   export lo que no se use (`demo/`, `scenes/` del pack).
2. Nombre del juego: ahora "Woodo Jam" (`application/config/name` en `project.godot`; sale en el
   letrero del menú). Preguntar.
3. Créditos con nombres reales (`data/creditos_es.txt`).
4. Sonidos y música: no hay ninguno (`assets/audio/...`; nombres en `autoload/sfx.gd`).
5. El diorama del menú y la arquitectura de la habitación son figuras simples: sustituir si llega arte.
6. **Mando sin probar** (no hay mando en la nube).
7. Más niveles (el plan habla de 3): cada nivel = escena con `core/diorama.gd` + `.glb` + línea en
   `data/levels.json`; el test ya prueba solo cada nivel de esa lista.

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

## 8. Herramientas de verificación

| Qué | Cómo |
|---|---|
| Todo el test | `bash tools/check.sh` → `CHECK OK (89 …)` |
| Ver los tests en rojo | `python3 -I tools/mutantes.py . build/mutantes "$GODOT"` → 21 × `ROJO BIEN` (~10 min) |
| Captura de cualquier pantalla | `tools/capture.sh` (opciones en `scenes/main.gd`: `--level=menu`, `--menu-page=`, `--solve=`, `--hold=X,Y`, `--zoom=K,X,Y`) |
| Medir si la luz quema | `python3 -I tools/medir_luz.py build/c.png` |
| Regenerar niveles | `"$GODOT" --headless --path . --script res://tools/build_room_level.gd` (y `build_title_level.gd`, `build_sample_level.gd`) |
