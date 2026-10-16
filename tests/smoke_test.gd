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
	await _test_pause(main, d)
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
	check(mesa != null and d.try_place(&"mesa", cam.unproject_position(mesa.center()), cam), "la mesa encaja soltándola encima de su hueco")
	check(mesa != null and mesa.filled and not mesa.is_ghost(), "la mesa colocada deja de ser silueta")

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
	await _test_back_to_menu(main)
	await _test_real_levels(main)
	_end()


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
	check(t.slots.size() == 4 and t.interactables.is_empty(), "el puzle del título es sencillo: 4 piezas, sin cajones ni escondidos (%d)" % t.slots.size())
	var title_sign := t.find_child("Titulo", true, false) as Label3D
	check(title_sign != null and title_sign.text == GameState.game_title(), "el letrero lleva el nombre del juego")
	check(title_sign != null and not title_sign.visible, "el texto del letrero no se ve mientras su pieza es silueta")
	var proto := t.prototype_for(&"letrero")
	var card_sign := proto.find_child("Titulo", true, false) as Label3D if proto != null else null
	check(card_sign != null and card_sign.text == GameState.game_title(), "la ficha del letrero en el panel también lleva el nombre del juego")
	check(GameState.hud._panel.visible, "durante el puzle del título se ve el panel de piezas")
	_check_lighting(main, "res://iluminacion/menu.tscn", "el título")
	var steps := 0
	while not t.completed and steps < 20:
		t.debug_solve_step()
		steps += 1
		await get_tree().process_frame
	check(t.completed and title_sign != null and title_sign.visible, "al colocar el letrero se ve el título")
	check(GameState.menu_unlocked and _saved(TEST_PROGRESS, "menu_desbloqueado") == true, "resolver el título desbloquea el menú y se guarda")
	await get_tree().create_timer(main.MENU_DELAY + 0.3).timeout
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
		check(GameState.hud._list.get_child_count() == 0, "%s completo: el panel no dice que busques más piezas" % path.get_file())


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
	var suns := _count_in_main_world("DirectionalLight3D")
	check(envs == 1 and suns == 1, "%s: un solo ambiente y un solo sol (%d y %d)" % [who, envs, suns])


## Solo los del mundo principal: las fichas del panel tienen su propio mundo con su propia luz.
func _count_in_main_world(type: String) -> int:
	var n := 0
	for x in get_tree().root.find_children("*", type, true, false):
		if x.is_inside_tree() and not x.is_queued_for_deletion() and x.get_viewport() == get_tree().root:
			n += 1
	return n


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
