"""Ver en ROJO los tests: cada mutante mete UN defecto en una COPIA del proyecto y exige que
tools/check.sh falle justo en la comprobación que lo vigila (y no en otra cosa).
Si un mutante sale "VERDE: EL TEST NO LO VIGILA", ese test no sirve: arreglar el test (o el mutante).
Si sale "NO APLICADO", el código cambió: actualizar el texto del mutante.

Uso (desde la raíz del proyecto; tarda ~25 s por mutante):
    python3 -I tools/mutantes.py . build/mutantes "$GODOT"
    SOLO=M17 python3 -I tools/mutantes.py . build/mutantes "$GODOT"     # solo uno
Al añadir una mecánica con su test, añadir aquí su mutante y verlo en ROJO BIEN.
"""
import os
import shutil
import subprocess
import sys

proyecto, trabajo, godot = sys.argv[1:4]

MUTANTES = [
	("M1 volumen no llega al bus", "autoload/settings.gd",
		"\t\tAudioServer.set_bus_volume_db(i, linear_to_db(maxf(float(v), 0.001)))", "\t\tpass",
		"el volumen de música llega al bus Musica"),
	("M2 letrero visible siendo silueta", "core/piece_slot.gd",
		"\t\t\t(v as VisualInstance3D).hide()", "\t\t\tpass",
		"el texto del letrero no se ve mientras su pieza es silueta"),
	("M3 el menú no se abre tras el título", "scenes/main.gd",
		"\t\t\tif GameState.diorama == d and GameState.mode == GameState.Mode.MENU and not menu.is_open():\n\t\t\t\t_open_menu())",
		"\t\t\tpass)",
		"tras la onda de color se abre el menú"),
	("M5 el progreso no se escribe", "autoload/game_state.gd",
		"\tvar err := cfg.save(progress_path)", "\tvar err := OK",
		"resolver el título desbloquea el menú y se guarda"),
	("M6 el título no sale montado al volver", "core/diorama.gd",
		"\tfor s in slots:\n\t\tif not s.filled:\n\t\t\ts.fill()\n\t\t\tfor m in s.meshes():\n\t\t\t\tVisuals.add_surface(m)\n\tinventory.clear()",
		"\treturn\n\tinventory.clear()",
		"al volver, el título sale ya montado"),
	("M7 el último nivel dice Siguiente", "ui/hud.gd",
		'\t_done_button.text = "Volver al menú" if last else "Siguiente"', '\t_done_button.text = "Siguiente"',
		"tras el último nivel, el panel ofrece volver al menú"),
	("M8 la cámara no se corre en el menú", "camera/diorama_camera.gd",
		"\treturn -MENU_SHIFT * _cur_distance if _menu_view else 0.0", "\treturn 0.0",
		"la cámara corre el diorama a la derecha del menú"),
	("M9 Esc en un rincón abre la pausa", "ui/hud.gd",
		"\t\tif GameState.diorama != null and GameState.diorama.focus != null:\n\t\t\t_on_back()",
		"\t\tif false:\n\t\t\t_on_back()",
		"dentro de un rincón, Esc sale del rincón (no pausa)"),
	("M10 borrar progreso a la primera", "ui/options_panel.gd",
		"\tif _reset_armed > 0.0:\n\t\t_reset_armed = 0.0\n\t\tGameState.reset_progress()",
		"\tif true:\n\t\t_reset_armed = 0.0\n\t\tGameState.reset_progress()",
		"la primera pulsación de Borrar progreso solo pregunta"),
	("M11 nombre del letrero puesto después de _ready (el fallo visto en la captura)", "scenes/main.gd",
		"\tif path == GameState.MENU_LEVEL and title_sign != null:\n\t\ttitle_sign.text = GameState.game_title()\n\tadd_child(_level)",
		"\tadd_child(_level)\n\tif path == GameState.MENU_LEVEL and title_sign != null:\n\t\ttitle_sign.text = GameState.game_title()",
		"la ficha del letrero en el panel también lleva el nombre del juego"),
	("M12 la luz anterior no se quita", "scenes/main.gd",
		"\tif _lighting != null:\n\t\tremove_child(_lighting)\n\t\t_lighting.queue_free()\n",
		"",
		"un nivel sin luz propia: un solo ambiente y un solo sol"),
	("M13 se ignora la luz propia del nivel", "scenes/main.gd",
		"\t_apply_lighting(own if own != \"\" else DEFAULT_LIGHTING)",
		"\t_apply_lighting(DEFAULT_LIGHTING)",
		"el título usa la luz menu.tscn"),
	("M14 siluetas sin prioridad sobre la arcilla", "core/visuals.gd",
		"\tm.render_priority = GHOST_RENDER_PRIORITY\n", "",
		"level_01_habitacion.tscn: las siluetas se pintan después de la arcilla"),
	("M15 ruta de un modelo rota (como pasó con el pack)", "levels/level_01_habitacion.tscn",
		"furniture/desk_01.glb", "furniture/desk_XX.glb",
		"level_01_habitacion.tscn: 17 huecos y todos con su modelo"),
	("M16 el panel no se rehace al completar", "ui/hud.gd",
		"\t\trebuild_inventory()                  # el último encaje avisó antes de marcarse completado\n", "",
		"level_01_habitacion.tscn completo: el panel no dice que busques más piezas"),
	("M17 el giro sin límites", "camera/diorama_camera.gd",
		"\tyaw = clampf(yaw + d_yaw * s, yaw_min, yaw_max)", "\tyaw = yaw + d_yaw * s",
		"el giro se para en su límite"),
	("M18 el zoom no devuelve la cámara a su sitio", "camera/diorama_camera.gd",
		"\tcenter = c + (center - c).limit_length(float(_home.get(\"radius\", 1.0)) * (1.0 - t))", "\tpass",
		"al alejar el zoom, la cámara vuelve a su sitio"),
	("M19 la pieza en mano no choca con nada", "ui/drag_controller.gd",
		"\tq.collision_mask = Visuals.SURFACE_LAYER\n\tq.transform = Transform3D(xf.basis", "\tq.collision_mask = 0\n\tq.transform = Transform3D(xf.basis",
		"muestra: la pieza en mano se apoya en las superficies"),
	("M20 el camino del imán no choca", "ui/drag_controller.gd",
		"\t_held.global_transform = loose.translated(toward * r[0])", "\t_held.global_transform = loose.translated(toward)",
		"muestra: la pieza en mano (silla) no atraviesa nada"),
	("M21 lo colocado no pasa a ser superficie", "core/diorama.gd",
		"\tslot.fill()\n\tfor m in slot.meshes():\n\t\tVisuals.add_surface(m)\n", "\tslot.fill()\n",
		"la mesa colocada pasa a ser superficie"),
	("M22 modo prototipo encendido pero se carga el progreso", "autoload/game_state.gd",
		"\tload_progress(\"\" if _capturing() or RESET_ON_START else progress_path)", "\tload_progress(\"\" if _capturing() else progress_path)",
		"modo prototipo"),
]

solo = os.environ.get("SOLO")
os.makedirs(trabajo, exist_ok=True)
for nombre, fichero, viejo, nuevo, esperado in MUTANTES:
	if solo and not nombre.startswith(solo + " "):
		continue
	copia = os.path.join(trabajo, "proj")
	shutil.rmtree(copia, ignore_errors=True)
	shutil.copytree(proyecto, copia, ignore=shutil.ignore_patterns("build", ".git", ".claude"))
	ruta = os.path.join(copia, fichero)
	src = open(ruta, encoding="utf-8").read()
	n = src.count(viejo)
	if n != 1:
		print(f"{nombre}: NO APLICADO (el texto aparece {n} veces)")
		continue
	open(ruta, "w", encoding="utf-8").write(src.replace(viejo, nuevo))
	r = subprocess.run(["bash", "tools/check.sh"], cwd=copia, env=dict(os.environ, GODOT=godot),
		capture_output=True, text=True, timeout=600)
	log = open(os.path.join(copia, "build", "check.log"), encoding="utf-8", errors="replace").read()
	fallos = [l[6:].strip() for l in log.splitlines() if l.startswith("FALLO ")]
	errores = [l for l in log.splitlines() if "SCRIPT ERROR" in l or "Parse Error" in l]
	acierta = any(f.startswith(esperado) for f in fallos)
	veredicto = "ROJO BIEN" if acierta else ("VERDE: EL TEST NO LO VIGILA" if not fallos and r.returncode == 0 else "ROJO POR OTRO MOTIVO")
	print(f"{nombre}: {veredicto}  | fallos={fallos[:3]} errores_script={len(errores)}")
shutil.rmtree(os.path.join(trabajo, "proj"), ignore_errors=True)
