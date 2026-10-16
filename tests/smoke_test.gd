extends Node
## Test de humo: arranca el juego entero como un jugador: resuelve el puzle del título, usa el
## menú, juega el nivel 0 de principio a fin (con pausa) y vuelve al menú ya montado.
## Ejecutar (o mejor: tools/check.sh, que además lee el log):
##   godot --headless --path . res://tests/smoke_test.tscn
## Imprime "OK ..." / "FALLO ..." y termina con "SMOKE OK" o "SMOKE FALLO n".
## Un test que no imprime "SMOKE OK" NO ha pasado, diga lo que diga el código de salida.

const SAMPLE_LEVEL := "res://levels/level_00_muestra.tscn"
const TEST_SETTINGS := "user://test_ajustes.cfg"     ## nunca los ficheros de verdad del jugador
const TEST_PROGRESS := "user://test_progreso.cfg"

var _fails := 0
var _completed := false
var _farol_energy := 0.0                             ## la luz de un farol del título, tal como viene del modelo


func _ready() -> void:
	Events.level_completed.connect(func(_d: Node) -> void: _completed = true)
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		print("OK    ", what)
	else:
		_fails += 1
		print("FALLO ", what)


func _run() -> void:
	_test_name_rules()
	if GameState.RESET_ON_START:
		check(GameState.progress_path == "" and not GameState.menu_unlocked and not GameState.has_progress(),
			"modo prototipo: al darle a Play no se carga progreso (título y niveles desde cero)")
	for f in [TEST_SETTINGS, TEST_PROGRESS]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	_test_settings()
	Settings.load_from(TEST_SETTINGS)
	GameState.load_progress(TEST_PROGRESS)
	# Siempre el nivel de muestra, esté o no en data/levels.json: es el que usa toda la convención.
	GameState.levels = PackedStringArray([SAMPLE_LEVEL])
	GameState.level_index = 0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	for i in 3:
		await get_tree().process_frame
	if not await _test_title_menu(main):
		return _end()
	var d := GameState.diorama
	check(d != null and d.scene_file_path == SAMPLE_LEVEL, "Jugar carga el nivel 0 y registra su Diorama")
	if d == null:
		return _end()
	await get_tree().process_frame               # la luz anterior se libera al final del fotograma
	_check_lighting(main, main.DEFAULT_LIGHTING, "un nivel sin luz propia")
	var rig := main.get_node_or_null("Iluminacion") as RigLuz
	var sun := rig.get_node_or_null(rig.luz_principal) as Light3D if rig != null else null
	check(sun != null and is_equal_approx(sun.light_energy, rig.energia_inicio),
		"al empezar, la luz principal está en su energía de inicio (diorama sin montar)")
	var fx: Efectos = main.effects
	check(fx.dust != null and fx.dust.emitting and fx.dust.amount >= 30, "hay polvo flotando en la luz alrededor del diorama")
	await _test_pause(main, d)
	await _test_camera(d)
	for i in 2:
		await get_tree().process_frame
	var cam_yaw := GameState.camera.cam.global_rotation.y
	check(rig != null and absf(cam_yaw) > 0.1 and absf(wrapf(rig.rotation.y - cam_yaw * rig.seguir_camara, -PI, PI)) < 0.02,
		"la luz gira con la cámara (luz %.2f, cámara %.2f rad)" % [rig.rotation.y if rig else 0.0, cam_yaw])
	await _test_hint(d)
	var cam := GameState.camera.cam
	GameState.camera.snap()
	check(d.slots.size() >= 5, "hay huecos P_ (%d)" % d.slots.size())
	check(not d.inventory.is_empty(), "el inventario empieza con piezas (%d)" % d.inventory.size())
	check(not d.inventory.has(&"cuchara"), "lo escondido (H_) no empieza en el inventario")
	check(not d.inventory.has(&"cuadro"), "la recompensa de un Z_ no empieza en el inventario")
	check(d.slots[0].is_ghost(), "los huecos empiezan como silueta blanca")
	check(GameState.hud._list.get_child_count() > 0, "el panel muestra piezas")

	# Encaje por posición en pantalla: lejos falla, encima acierta.
	var id := d.inventory[0]
	check(not d.try_place(id, Vector2(-999, -999), cam), "soltar lejos NO encaja")

	# Orden: la taza no encaja sin la mesa.
	var taza := _slot(d, &"taza")
	if taza != null and d.inventory.has(&"taza"):
		var pos := cam.unproject_position(taza.center())
		check(not d.try_place(&"taza", pos, cam), "la taza NO encaja antes que la mesa (after-mesa)")

	var mesa := _slot(d, &"mesa")
	var bursts_before := fx.bursts
	check(mesa != null and d.try_place(&"mesa", cam.unproject_position(mesa.center()), cam), "la mesa encaja soltándola encima de su hueco")
	check(mesa != null and mesa.filled and not mesa.is_ghost(), "la mesa colocada deja de ser silueta")
	check(mesa != null and not mesa.node.find_children("Superficie", "StaticBody3D", true, false).is_empty(),
		"la mesa colocada pasa a ser superficie (lo de encima se apoya en ella, no la atraviesa)")
	check(fx.bursts > bursts_before and fx.get_children().any(func(c: Node) -> bool: return c.name.begins_with("Serrin")),
		"al encajar una pieza salen serrín y chispas")
	if mesa != null:
		var far := mesa.center() + Vector3(d.color_radius * 1.6, 0.0, 0.0)
		check(not d.is_painted_at(mesa.center()), "(control) justo al encajar la pintura aún no ha llegado: crece poco a poco")
		await get_tree().create_timer(Diorama.PAINT_TIME + 0.15).timeout
		check(d.is_painted_at(mesa.center()) and not d.is_painted_at(far) and d.has_unpainted_layer(),
			"al encajar, la pintura se extiende desde la pieza hasta su radio, y no más allá")

	# Arrastrar de verdad: pulsar en la ficha del panel, mover y soltar encima del hueco,
	# con eventos de ratón que recorren el mismo camino que los del jugador.
	var silla := _slot(d, &"silla")
	var item := GameState.hud.item_for(&"silla")
	check(item != null, "la silla tiene ficha en el panel")
	if silla != null and item != null:
		for i in 2:                                # el panel se maqueta un fotograma después
			await get_tree().process_frame
		item = GameState.hud.item_for(&"silla")
		var start := item.get_global_rect().get_center()
		var goal := cam.unproject_position(silla.center())
		_mouse_button(start, true)
		await get_tree().process_frame
		check(GameState.is_dragging and GameState.drag.piece_id == &"silla", "pulsar la ficha de la silla empieza a arrastrar la silla")
		_check_sweep("muestra")
		_mouse_move(goal)
		await get_tree().process_frame
		_mouse_button(goal, false)
		await get_tree().process_frame
		check(silla.filled, "soltar la silla sobre su hueco la coloca")
		check(not GameState.is_dragging, "al soltar se acaba el arrastre")

	# Cajón: se abre al pulsarlo y deja coger lo de dentro.
	var cajon := _interactable(d, NameRules.DRAWER)
	if cajon != null:
		var before := cajon.target.transform
		cajon.activate()
		await get_tree().create_timer(Interactable.OPEN_TIME + 0.2).timeout
		check(not cajon.target.transform.is_equal_approx(before), "el cajón se mueve al abrirlo")
		var cuchara := _interactable(d, NameRules.PICKUP)
		GameState.camera.snap()
		var hit := d.pick_interactable(cam.unproject_position(Visuals.global_aabb(cuchara.target).get_center()), cam)
		check(hit == cuchara, "con el cajón abierto, el clic sobre la cuchara la coge a ella (no al cajón)")

	# El resto, con el jugador automático.
	var steps := 0
	while not d.completed and steps < 200:
		d.debug_solve_step()
		steps += 1
		await get_tree().process_frame
	check(d.completed and _completed, "el nivel se completa (%d pasos) y emite level_completed" % steps)
	check(d.inventory.is_empty(), "inventario vacío al final")
	var all_filled := true
	for s in d.slots:
		all_filled = all_filled and s.filled
	check(all_filled, "todos los huecos llenos")
	check(GameState.camera.showcasing, "al completar, la cámara se mece enseñando el diorama")
	check(fx.get_children().any(func(c: Node) -> bool: return c.name == "Hojas"), "al completar caen hojas y chispas")
	await get_tree().create_timer(Diorama.FINAL_PAINT_TIME + 0.3).timeout
	check(not d.has_unpainted_layer(), "al completar no queda madera sin pintar (y la capa se quita)")
	check(sun != null and is_equal_approx(sun.light_energy, rig.energia_final) and sun.light_color.is_equal_approx(rig.color_final),
		"la luz despierta con el diorama: completo, la luz principal es la final (%.2f)" % (sun.light_energy if sun else -1.0))
	check(not GameState.hud._panel.visible, "al completar, la bandeja vacía se recoge")
	await _test_back_to_menu(main)
	await _test_real_levels(main)
	await _test_light_scale()
	_end()


## escala_luces: las luces que trae un modelo (de Blender llegan con otras unidades) se ajustan
## para todo el nivel con un número, sin reexportar.
func _test_light_scale() -> void:
	var probe := (load(GameState.MENU_LEVEL) as PackedScene).instantiate() as Diorama
	probe.escala_luces = 2.0
	add_child(probe)
	var farol := _slot(probe, &"farol")
	var lights: Array = farol.lights() if farol != null else []
	var got := float(lights[0][1]) if not lights.is_empty() else -1.0
	check(_farol_energy > 0.0 and is_equal_approx(got, _farol_energy * 2.0),
		"escala_luces multiplica las luces del modelo (%.2f con escala 2, %.2f sin escala)" % [got, _farol_energy])
	probe.queue_free()
	await get_tree().process_frame


# --- Ajustes, menú de inicio y pausa ---------------------------------------------------------

func _test_settings() -> void:
	Settings.load_from(TEST_SETTINGS)
	check(AudioServer.get_bus_index(&"Musica") != -1 and AudioServer.get_bus_index(&"Voz") != -1, "existen los buses Musica, Efectos y Voz")
	check(is_equal_approx(Settings.get_value("volumen_musica"), Settings.DEFAULTS.volumen_musica), "sin fichero, los ajustes son los de por defecto")
	Settings.set_value("volumen_musica", 0.25)
	Settings.set_value("volumen_efectos", 0.0)
	Settings.set_value("subtitulos", false)
	var bus := AudioServer.get_bus_index(&"Musica")
	check(absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.25)) < 0.01, "el volumen de música llega al bus Musica")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Efectos")), "efectos a 0 = bus Efectos en silencio")
	check(Settings.save_now() == OK, "los ajustes se guardan en disco")
	Settings.load_from("")
	check(is_equal_approx(Settings.get_value("volumen_musica"), Settings.DEFAULTS.volumen_musica), "(control) sin fichero vuelven los de por defecto")
	Settings.load_from(TEST_SETTINGS)
	check(is_equal_approx(Settings.get_value("volumen_musica"), 0.25) and Settings.get_value("subtitulos") == false, "al volver a leer el fichero, los ajustes siguen ahí")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))


## Devuelve false si no se puede seguir (sin título o sin menú, el resto no tiene sentido).
func _test_title_menu(main: Node) -> bool:
	var t := GameState.diorama
	check(t != null and t.scene_file_path == GameState.MENU_LEVEL, "el juego arranca en el diorama del título")
	if t == null:
		return false
	check(GameState.mode == GameState.Mode.MENU and not main.menu.is_open(), "el menú empieza cerrado: hay que resolver el puzle")
	check(t.model_path.get_extension() == "glb" and t.get_node_or_null("Modelo") != null,
		"el diorama del título es un asset: se carga de un .glb (%s)" % t.model_path.get_file())
	check(t.slots.size() >= 10 and t.interactables.is_empty(), "el título son muchas piezas pequeñas, sin cajones ni escondidos (%d)" % t.slots.size())
	var letters := _title_letters(t)
	check(letters == GameState.game_title().to_upper().replace(" ", ""), "las letras del título forman el nombre del juego (%s)" % letters)
	check(t.count_of(&"letra_o") == 3 and _slots_with(t, &"letra_o") == 3, "las letras repetidas son la misma pieza: tres O que valen en cualquier hueco de O")
	var farol := _slot(t, &"farol")
	var lights: Array = farol.lights() if farol != null else []
	check(not lights.is_empty() and not (lights[0][0] as Light3D).visible, "la luz de un farol del título está apagada mientras es silueta")
	_farol_energy = float(lights[0][1]) if not lights.is_empty() else 0.0
	check(GameState.hud._panel.visible and GameState.hud._list.get_child_count() > 0, "durante el puzle del título se ve la bandeja de piezas")
	_check_lighting(main, "res://iluminacion/menu.tscn", "el título")
	var steps := 0
	while not t.completed and steps < 40:
		t.debug_solve_step()
		steps += 1
		await get_tree().process_frame
	check(t.completed, "el título se completa (%d pasos)" % steps)
	check(GameState.menu_unlocked and _saved(TEST_PROGRESS, "menu_desbloqueado") == true, "resolver el título desbloquea el menú y se guarda")
	await get_tree().create_timer(main.MENU_DELAY + 0.3).timeout
	if not lights.is_empty():
		var lamp: Light3D = lights[0][0]
		check(lamp.visible and is_equal_approx(lamp.light_energy, float(lights[0][1])),
			"al colocar el farol, su luz se enciende con un fundido (%.2f de %.2f)" % [lamp.light_energy, float(lights[0][1])])
	check(main.menu.is_open() and main.menu.page == "principal", "tras la onda de color se abre el menú")
	if not main.menu.is_open():
		return false
	check(not GameState.hud._panel.visible and not GameState.hud._done.visible, "con el menú abierto, el panel de piezas se esconde")
	check(main.menu.buttons.jugar.text == "Jugar", "sin progreso, el botón dice Jugar")
	for i in 20:
		await get_tree().process_frame
	check(GameState.camera.cam.h_offset < -0.3, "la cámara corre el diorama a la derecha del menú (h_offset %.2f)" % GameState.camera.cam.h_offset)
	main.menu.show_page("opciones")
	var slider := main.menu.options.controls["volumen_voz"] as HSlider
	slider.value = 0.35
	check(is_equal_approx(Settings.get_value("volumen_voz"), 0.35), "mover el deslizador de voz cambia el ajuste")
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	check(main.menu.page == "principal", "Esc en una página vuelve a la principal")
	main.menu.show_page("elegir")
	var level_button: Button = main.menu.buttons.get("nivel_0")
	check(level_button != null and level_button.text.contains("Muestra: la casita") and not level_button.disabled, "Elegir diorama lista el nivel 0 con su título")
	main.menu.show_page("creditos")
	check(main.menu.page == "creditos", "la página de créditos se abre")
	main.menu.show_page("principal")
	for i in 2:                                      # el menú se maqueta un fotograma después
		await get_tree().process_frame
	_click(main.menu.buttons.jugar.get_global_rect().get_center())
	await get_tree().process_frame
	check(not main.menu.is_open() and GameState.mode == GameState.Mode.PLAYING, "clic en Jugar cierra el menú y empieza la partida")
	check(GameState.hud._panel.visible and is_zero_approx(GameState.camera.cam.h_offset), "en partida vuelven el panel de piezas y la cámara centrada")
	return true


func _test_pause(main: Node, d: Diorama) -> void:
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	check(main.pause.is_open() and get_tree().paused, "Esc en partida abre la pausa y para el juego")
	check(main.pause.buttons.menu.visible, "en partida la pausa ofrece volver al menú principal")
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	check(not main.pause.is_open() and not get_tree().paused, "Esc otra vez reanuda")
	var zone: Interactable = null
	for it in d.interactables:
		if it.kind == NameRules.ZOOM:
			zone = it
	if zone != null:
		d.enter_focus(zone)
		_key(KEY_ESCAPE)
		await get_tree().process_frame
		check(d.focus == null and not main.pause.is_open(), "dentro de un rincón, Esc sale del rincón (no pausa)")


func _test_back_to_menu(main: Node) -> void:
	check(GameState.is_completed(0) and SAMPLE_LEVEL in _saved(TEST_PROGRESS, "completados", []), "completar el nivel queda guardado en el progreso")
	await get_tree().create_timer(1.9).timeout
	var done: Button = GameState.hud._done_button
	check(GameState.hud._done.visible and done.text == "Volver al menú", "tras el último nivel, el panel ofrece volver al menú")
	await get_tree().process_frame
	_click(done.get_global_rect().get_center())
	await get_tree().process_frame
	var t := GameState.diorama
	check(t != null and t.scene_file_path == GameState.MENU_LEVEL and t.completed, "al volver, el título sale ya montado")
	check(main.menu.is_open() and main.menu.page == "creditos", "al acabar el juego se ven los créditos")
	main.menu.show_page("principal")
	check(main.menu.buttons.jugar.text == "Continuar", "con progreso, el botón dice Continuar")
	main.menu.show_page("elegir")
	check(main.menu.buttons.nivel_0.text.contains("✓"), "Elegir diorama marca el nivel completado")
	main.menu.show_page("opciones")
	var reset: Button = main.menu.options.reset_button
	reset.pressed.emit()
	check(GameState.has_progress(), "la primera pulsación de Borrar progreso solo pregunta")
	reset.pressed.emit()
	check(not GameState.has_progress() and not GameState.menu_unlocked and _saved(TEST_PROGRESS, "menu_desbloqueado") == false, "la segunda pulsación borra el progreso (también en disco)")


## Los niveles de verdad (data/levels.json): cargan, cada pieza tiene su modelo, y se completan.
func _test_real_levels(main: Node) -> void:
	var listed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GameState.LEVELS_PATH))
	check(listed is Array and not (listed as Array).is_empty(), "data/levels.json lista niveles")
	if not (listed is Array):
		return
	GameState.levels = PackedStringArray(listed)
	for i in GameState.levels.size():
		var path := GameState.levels[i]
		main.play_level(i)
		await get_tree().process_frame
		var d := GameState.diorama
		check(d != null and d.scene_file_path == path, "%s carga" % path.get_file())
		if d == null or d.scene_file_path != path:
			continue
		var empty: Array[String] = []
		for sl in d.slots:
			if sl.meshes().is_empty():
				empty.append(String(sl.id))
		check(d.slots.size() >= 5 and empty.is_empty(), "%s: %d huecos y todos con su modelo (sin modelo: %s)" % [path.get_file(), d.slots.size(), empty])
		check(d.slots[0].is_ghost() and (d.slots[0]._ghost as ShaderMaterial).render_priority > Visuals.make_clay_overlay().render_priority,
			"%s: las siluetas se pintan después de la arcilla (si no, una pared grande las borra)" % path.get_file())
		await get_tree().process_frame
		# La pieza más grande y la más pequeña del panel: las pequeñas son las que se colarían.
		var cards: Array = GameState.hud._list.get_children().filter(func(n: Node) -> bool: return n is InventoryItem)
		cards.sort_custom(func(a: InventoryItem, b: InventoryItem) -> bool:
			return Visuals.local_aabb(d.prototype_for(a.piece_id)).size.length() > Visuals.local_aabb(d.prototype_for(b.piece_id)).size.length())
		for card: InventoryItem in ([cards.front(), cards.back()] if not cards.is_empty() else []):
			GameState.drag.begin(card.piece_id, card)
			_check_sweep(path.get_file())
			GameState.drag.cancel()
		var steps := 0
		while not d.completed and steps < 400:
			d.debug_solve_step()
			steps += 1
			await get_tree().process_frame
		var all_filled := true
		for sl in d.slots:
			all_filled = all_filled and sl.filled
		check(d.completed and all_filled and d.inventory.is_empty(), "%s se completa entero (%d pasos)" % [path.get_file(), steps])
		await get_tree().process_frame
		check(GameState.hud._list.get_child_count() == 0 and not GameState.hud.says_nothing_left(),
			"%s completo: el panel no dice que busques más piezas" % path.get_file())


## La luz activa es la esperada, es la que usa el mundo, y no se ha quedado otra a la vez.
func _check_lighting(main: Node, expected: String, who: String) -> void:
	var light := main.get_node_or_null("Iluminacion")
	check(light != null and light.scene_file_path == expected, "%s usa la luz %s" % [who, expected.get_file()])
	var we: WorldEnvironment = null
	for c in (light.get_children() if light != null else []):
		if c is WorldEnvironment:
			we = c
	check(we != null and get_viewport().find_world_3d().environment == we.environment, "%s: el mundo usa el ambiente de esa escena" % who)
	var envs := _count_in_main_world("WorldEnvironment")
	var stray := 0
	for sun in _in_main_world("DirectionalLight3D"):
		stray += 0 if light != null and light.is_ancestor_of(sun) else 1
	check(envs == 1 and stray == 0, "%s: un solo ambiente y ningún sol de otra escena de luz (%d y %d)" % [who, envs, stray])


## Solo los del mundo principal: las fichas del panel tienen su propio mundo con su propia luz.
func _count_in_main_world(type: String) -> int:
	return _in_main_world(type).size()


func _in_main_world(type: String) -> Array[Node]:
	var out: Array[Node] = []
	for x in get_tree().root.find_children("*", type, true, false):
		if x.is_inside_tree() and not x.is_queued_for_deletion() and x.get_viewport() == get_tree().root:
			out.append(x)
	return out


## Con una pieza en mano, recorre el diorama en rejilla: en ningún punto puede atravesar paredes,
## suelo ni muebles, y en buena parte tiene que quedar apoyada en algo (si no, el control no mide).
func _check_sweep(who: String) -> void:
	var checked := 0
	var inside := 0
	var rested := 0
	var piece := String(GameState.drag.piece_id)
	for x in range(140, 1000, 110):
		for y in range(110, 650, 90):
			_mouse_move(Vector2(x, y))
			var n := GameState.drag.held_overlaps()
			if n < 0:
				continue
			checked += 1
			inside += 1 if n > 0 else 0
			rested += 1 if GameState.drag.last_rested else 0
	check(checked >= 20 and inside == 0, "%s: la pieza en mano (%s) no atraviesa nada en %d puntos (dentro: %d)" % [who, piece, checked, inside])
	check(rested * 2 >= checked, "%s: la pieza en mano se apoya en las superficies (%d de %d puntos)" % [who, rested, checked])


func _test_camera(d: Diorama) -> void:
	var c := GameState.camera
	c.configure(d)
	var home := c.home_center()
	_drag_mouse(MOUSE_BUTTON_MIDDLE, Vector2(500, 350), Vector2(800, 500))
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(500, 350), Vector2(800, 500), true)
	check(c.center.is_equal_approx(home), "la cámara no se desplaza (ni botón central ni Mayús+arrastrar)")
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(300, 350), Vector2(950, 350))
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(300, 350), Vector2(950, 350))
	check(is_equal_approx(c.yaw, c.yaw_min), "el giro se para en su límite (%.0f, mínimo %.0f)" % [c.yaw, c.yaw_min])
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(950, 350), Vector2(300, 350))
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(950, 350), Vector2(300, 350))
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(950, 350), Vector2(300, 350))
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(950, 350), Vector2(300, 350))
	check(is_equal_approx(c.yaw, c.yaw_max), "y por el otro lado también (%.0f, máximo %.0f)" % [c.yaw, c.yaw_max])
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(500, 100), Vector2(500, 650))
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(500, 100), Vector2(500, 650))
	check(c.pitch >= c.pitch_min and c.pitch <= c.pitch_max, "la inclinación se queda en sus límites (%.0f)" % c.pitch)
	c.configure(d)
	for i in 30:
		_wheel(MOUSE_BUTTON_WHEEL_UP, Vector2(420, 300))
	check(is_equal_approx(c.distance, c.min_distance), "el zoom tiene tope (%.2f)" % c.distance)
	check(not c.center.is_equal_approx(home), "el zoom se acerca hacia lo que señala el cursor")
	for i in 30:
		_wheel(MOUSE_BUTTON_WHEEL_DOWN, Vector2(420, 300))
	check(is_equal_approx(c.distance, c.max_distance) and c.center.is_equal_approx(home), "al alejar el zoom, la cámara vuelve a su sitio")
	c.configure(d)
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(600, 350), Vector2(660, 350))
	var released := c.yaw
	check(c.is_spinning(), "al soltar el giro en pleno movimiento, la cámara sigue girando (inercia)")
	for i in 10:
		await get_tree().process_frame
	check(c.yaw < released and c.yaw >= c.yaw_min, "la inercia sigue en el mismo sentido y respeta los límites (%.1f -> %.1f)" % [released, c.yaw])
	c.configure(d)
	check(not c.is_spinning(), "(control) al recolocar la cámara se acaba la inercia")


## Pista: la cámara gira hacia el hueco y se ACERCA (como en Woodo), y salen chispas allí.
func _test_hint(d: Diorama) -> void:
	var c := GameState.camera
	c.configure(d)
	var home := c.home_center()
	var home_distance := c.distance
	var h := d.hint_target(GameState.hovered_piece)
	var before: int = (get_tree().root.find_child("Efectos", true, false) as Efectos).bursts
	GameState.hud.request_hint()
	var target := Visuals.global_aabb(h.node).get_center() if not h.is_empty() else home
	check(not h.is_empty() and c.distance < home_distance - 0.1 and c.center.distance_to(target) < home.distance_to(target) - 0.05,
		"la pista gira y acerca la cámara hacia el hueco (distancia %.2f -> %.2f)" % [home_distance, c.distance])
	check((get_tree().root.find_child("Efectos", true, false) as Efectos).bursts > before, "la pista enseña chispas en el sitio")
	await get_tree().process_frame
	GameState.hud._clear_hint()
	c.configure(d)


## Pulsar, arrastrar en 10 pasos (con su desplazamiento relativo) y soltar.
func _drag_mouse(button: MouseButton, from: Vector2, to: Vector2, shift := false) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = button
	press.pressed = true
	press.shift_pressed = shift
	press.position = from
	press.global_position = from
	get_viewport().push_input(press, true)
	var last := from
	for i in range(1, 11):
		var p := from.lerp(to, i / 10.0)
		var m := InputEventMouseMotion.new()
		m.position = p
		m.global_position = p
		m.relative = p - last
		m.shift_pressed = shift
		get_viewport().push_input(m, true)
		last = p
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.position = to
	release.global_position = to
	get_viewport().push_input(release, true)


func _wheel(button: MouseButton, pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		get_viewport().push_input(e, true)


## Lee una clave del progreso guardado en disco (lo que vería la próxima partida).
func _saved(path: String, key: String, default: Variant = null) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return default
	return cfg.get_value(GameState.SECTION, key, default)


func _test_name_rules() -> void:
	var a := NameRules.parse("P_silla__after-mesa_001")
	check(a.get("kind") == NameRules.PIECE and a.get("id") == &"silla", "NameRules: P_silla__after-mesa_001 -> pieza 'silla'")
	check(NameRules.values(a.get("tokens", PackedStringArray()), "after") == [&"mesa"], "NameRules: token after-mesa")
	check(NameRules.parse("Cube").is_empty(), "NameRules: un nombre sin prefijo se ignora")
	check(NameRules.strip_copy_suffix("P_taza.003") == "P_taza", "NameRules: quita el .003 de Blender")


## Los eventos se entregan en coordenadas LOCALES del viewport: sin ventana (--headless) el
## tamaño de ventana es 0x0 y Godot escalaría las posiciones x0,05.
func _click(pos: Vector2) -> void:
	_mouse_button(pos, true)
	_mouse_button(pos, false)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = pressed
		get_viewport().push_input(e, true)


func _mouse_button(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	get_viewport().push_input(e, true)


func _mouse_move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(e, true)


## Las letras del título, de izquierda a derecha (vistas de frente): "WOODOJAM".
func _title_letters(d: Diorama) -> String:
	var letters := d.slots.filter(func(sl: PieceSlot) -> bool: return String(sl.id).begins_with("letra_"))
	letters.sort_custom(func(a: PieceSlot, b: PieceSlot) -> bool: return a.center().x < b.center().x)
	var out := ""
	for sl: PieceSlot in letters:
		out += String(sl.id).trim_prefix("letra_").to_upper()
	return out


func _slots_with(d: Diorama, id: StringName) -> int:
	return d.slots.filter(func(sl: PieceSlot) -> bool: return sl.id == id).size()


func _slot(d: Diorama, id: StringName) -> PieceSlot:
	for s in d.slots:
		if s.id == id:
			return s
	return null


func _interactable(d: Diorama, kind: String) -> Interactable:
	for it in d.interactables:
		if it.kind == kind:
			return it
	return null


func _end() -> void:
	if _fails == 0:
		print("SMOKE OK")
	else:
		print("SMOKE FALLO %d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
