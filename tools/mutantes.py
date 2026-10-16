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
	("M2 luz de una pieza encendida siendo silueta", "core/piece_slot.gd",
		"\t\t\t(v as VisualInstance3D).hide()", "\t\t\tpass",
		"la luz de un farol del título está apagada mientras es silueta"),
	("M3 el menú no se abre tras el título", "scenes/main.gd",
		"\t\t\tif GameState.diorama == d and GameState.mode == GameState.Mode.MENU and not menu.is_open():\n\t\t\t\t_open_menu())",
		"\t\t\tpass)",
		"tras la onda de color se abre el menú"),
	("M5 el progreso no se escribe", "autoload/game_state.gd",
		"\tvar err := cfg.save(progress_path)", "\tvar err := OK",
		"resolver el título desbloquea el menú y se guarda"),
	("M6 el título no sale montado al volver", "core/diorama.gd",
		"\tfor s in slots:\n\t\tif not s.filled:\n\t\t\ts.fill(false)",
		"\treturn\n\tfor s in slots:\n\t\tif not s.filled:\n\t\t\ts.fill(false)",
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
	("M11 el modelo provisional no se carga si falta el de las artistas", "core/diorama.gd",
		"\tvar path := modelo if modelo != \"\" and ResourceLoader.exists(modelo) else modelo_provisional",
		"\tvar path := modelo",
		"el diorama del título es un asset"),
	("M12 la luz anterior no se quita", "scenes/main.gd",
		"\tif _lighting != null:\n\t\tremove_child(_lighting)\n\t\t_lighting.queue_free()\n",
		"",
		"un nivel sin luz propia: un solo ambiente"),
	("M13 se ignora la luz propia del nivel", "scenes/main.gd",
		"\t_apply_lighting(own if own != \"\" else DEFAULT_LIGHTING)",
		"\t_apply_lighting(DEFAULT_LIGHTING)",
		"el título usa la luz menu.tscn"),
	("M14 siluetas sin prioridad sobre la arcilla", "core/visuals.gd",
		"\tm.render_priority = GHOST_RENDER_PRIORITY\n", "",
		"level_01_desvan.tscn: las siluetas se pintan después de la arcilla"),
	("M15 ruta de un modelo rota (como pasó con el pack)", "levels/provisional/desvan_provisional.tscn",
		"furniture/desk_01.glb", "furniture/desk_XX.glb",
		"level_01_desvan.tscn: todos los huecos con su modelo"),
	("M16 el panel no se rehace al completar", "ui/hud.gd",
		"\t\trebuild_inventory()                  # el último encaje avisó antes de marcarse completado\n", "",
		"level_01_desvan.tscn completo: el panel no dice que busques más piezas"),
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
	("M23 la luz de la pieza no se enciende al colocarla", "core/piece_slot.gd",
		"\t\t\ttw.tween_property(light, \"light_energy\", float(_light_energy[light]), LIGHT_FADE)", "\t\t\tpass",
		"al colocar el farol, su luz se enciende"),
	("M24 la pintura no se extiende", "core/diorama.gd",
		"\t_add_paint(origin, color_radius, PAINT_TIME)", "\tpass",
		"al encajar, la pintura se extiende"),
	("M25 al completar queda madera sin pintar", "core/diorama.gd",
		"\tget_tree().create_timer(FINAL_PAINT_TIME + 0.1, false).timeout.connect(_finish_paint)\n", "",
		"al completar no queda madera sin pintar"),
	("M26 la luz no gira con la cámara", "iluminacion/rig_luz.gd",
		"\t\trotation.y = cam.global_rotation.y * seguir_camara", "\t\tpass",
		"la luz gira con la cámara"),
	("M27 la luz no despierta con el diorama", "iluminacion/rig_luz.gd",
		"\t\tgoal = d.progress()", "\t\tgoal = 0.0",
		"la luz despierta con el diorama"),
	("M28 sin partículas al encajar", "core/efectos.gd",
		"\tEvents.piece_placed.connect(func(_id: StringName, n: Node3D) -> void: placed_at(Visuals.global_aabb(n)))\n", "",
		"al encajar una pieza salen serrín y chispas"),
	("M29 sin polvo en el aire", "core/efectos.gd",
		"\tdust = _dust(box)", "\tdust = null",
		"hay polvo flotando en la luz"),
	("M30 la pista no acerca la cámara", "camera/diorama_camera.gd",
		"\tdistance = lerpf(float(_home.get(\"distance\", distance)), min_distance, HINT_ZOOM)", "\tpass",
		"la pista gira y acerca la cámara"),
	("M31 el giro sin inercia", "camera/diorama_camera.gd",
		"\t\t\t_spin = _spin.lerp(d / dt, 0.5)", "\t\t\tpass",
		"al soltar el giro en pleno movimiento"),
	("M32 la cámara no enseña el diorama completo", "camera/diorama_camera.gd",
		"\t\t\tshowcase())", "\t\t\tpass)",
		"al completar, la cámara se mece"),
	("M33 la bandeja no se recoge al completar", "ui/hud.gd",
		"\t\t_put_tray_away()\n", "",
		"al completar, la bandeja vacía se recoge"),
	("M34 escala_luces no se aplica", "core/diorama.gd",
		"\t\t(l as Light3D).light_energy *= escala_luces", "\t\tpass",
		"escala_luces multiplica las luces del modelo"),
	("M35 la cámara da un tirón al colocar", "camera/diorama_camera.gd",
		"\tvar rn := _spring3(_nudge, _v_nudge, _nudge_goal, NUDGE_SMOOTH, delta)",
		"\tvar rn: Array[Vector3] = [_nudge_goal, Vector3.ZERO]",
		"al colocar, la cámara se acerca a la pieza suave"),
	("M36 todas las secciones abiertas desde el principio", "core/diorama.gd",
		"\t\tsec.opened = i == 0", "\t\tsec.opened = true",
		"el desván empieza con su primera sección abierta"),
	("M37 la clave no espera a las demás", "core/diorama.gd",
		"\tif slot.is_key and slot.section != null:", "\tif false:",
		"al empezar, la bandeja solo trae paredes"),
	("M38 el decorado de una zona cerrada se ve", "core/diorama.gd",
		"\t\tsec.set_decor(sec.opened)", "\t\tsec.set_decor(true)",
		"las zonas cerradas no enseñan nada"),
	("M39 la luz de una zona cerrada encendida", "core/diorama.gd",
		"\t\tsec.set_lights(sec.opened)", "\t\tsec.set_lights(true)",
		"las zonas cerradas no enseñan nada"),
	("M40 el mueble no llama la atención", "core/diorama.gd",
		"\t\tc.set_attention(calling[c])", "\t\tpass",
		"el baúl que guarda lo que toca encontrar brilla"),
	("M41 lo de un armario o baúl no se enlaza con su puerta", "core/diorama.gd",
		"\t\t\tif n.name != \"Modelo\" and NameRules.parse(n.name).get(\"kind\", \"\") != NameRules.SECTION:",
		"\t\t\tif false:",
		"los cubos están guardados en el baúl"),
	("M42 la pista señala lo escondido y no su mueble", "core/diorama.gd",
		"\t\t\t\treturn {\"node\": it.container.target, \"container\": it.container, \"pickup\": it}",
		"\t\t\t\treturn {\"node\": it.target, \"pickup\": it}",
		"cuando solo falta buscar, la pista señala el mueble"),
	("M43 la cámara no hace flash", "core/diorama.gd",
		"\t\tEvents.flash_requested.emit()", "\t\tpass",
		"al colocar la cámara, destello blanco"),
	("M44 el final no funde a negro", "scenes/main.gd",
		"\t\tif ending != null and ending.fundido_final:", "\t\tif false:",
		"el final funde a negro"),
	("M45 el narrador pisa frases", "autoload/narrator.gd",
		"\tif _left <= 0.0:\n\t\t_next()", "\t_next()",
		"el narrador no pisa frases"),
	("M46 lo escondido se ve antes de tiempo", "core/diorama.gd",
		"\t\tit.set_available(wanted)", "\t\tit.set_available(true)",
		"al abrirse la adolescencia, ni la cámara ni la inscripción se ven todavía"),
	("M47 la sombra cubre 25 m fijos (pixelada)", "iluminacion/rig_luz.gd",
		"\t\t\t(_sol as DirectionalLight3D).directional_shadow_max_distance = clampf(reach, 4.0, 40.0)", "\t\t\tpass",
		"las sombras cubren solo lo que se ve"),
	("M48 los muebles ocultos siguen chocando", "core/section.gd",
		"\t\t\t(body as StaticBody3D).collision_layer = Visuals.SURFACE_LAYER if on else 0", "\t\t\tpass",
		"los muebles ocultos de una zona cerrada no chocan"),
	("M49 el mueble que llama no lleva contorno", "core/interactable.gd",
		"\t\t_glow.append(o)\n", "\t\to.queue_free()\n",
		"y lleva un contorno dorado"),
	("M50 la bandeja dice que no queda nada entre secciones", "ui/hud.gd",
		" and not d.is_opening()", "",
		"entre una sección y la siguiente, la bandeja espera"),
	("M51 F9 no completa nada", "ui/hud.gd",
		"\t\tGameState.diorama.debug_complete()\n", "\t\tpass\n",
		"F9 monta el desván entero de golpe"),
	("M52 tras F9 funde a negro", "core/diorama.gd",
		"\tfundido_final = false\n", "",
		"tras F9 el desván se queda a la vista"),
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
