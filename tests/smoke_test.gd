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
const LAMP := &"lampara"                             ## la pieza del desván que lleva luz (la lámpara del escritorio)

var _fails := 0
var _completed := false
var _farol_energy := 0.0                             ## la luz de la lámpara del desván, tal como viene del modelo


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
	_test_narrator()
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
	var reach := GameState.camera.cam.global_position.distance_to(rig._center) + rig._radius * rig.margen_sombra if rig else -1.0
	var shadow_dist := (sun as DirectionalLight3D).directional_shadow_max_distance if sun is DirectionalLight3D else -1.0
	check(rig != null and absf(shadow_dist - clampf(reach, 4.0, 40.0)) < 0.3 and shadow_dist < 25.0,
		"las sombras cubren solo lo que se ve, para que no salgan pixeladas (%.1f m)" % shadow_dist)
	await _test_hint(d)
	var cam := GameState.camera.cam
	GameState.camera.snap()
	check(d.slots.size() >= 5, "hay huecos P_ (%d)" % d.slots.size())
	check(not d.inventory.is_empty(), "el inventario empieza con piezas (%d)" % d.inventory.size())
	check(not d.inventory.has(&"cuchara"), "lo escondido (H_) no empieza en el inventario")
	check(not d.inventory.has(&"cuadro"), "la recompensa de un Z_ no empieza en el inventario")
	check(d.slots[0].is_ghost(), "los huecos empiezan como silueta blanca")
	check(GameState.hud.cards(true).size() > 0, "el panel muestra piezas")

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
	var cam_before := cam.global_position
	check(mesa != null and d.try_place(&"mesa", cam.unproject_position(mesa.center()), cam), "la mesa encaja soltándola encima de su hueco")
	var painted_at_once := mesa != null and d.is_painted_at(mesa.center())
	await get_tree().process_frame
	var first_step := cam.global_position.distance_to(cam_before)
	check(mesa != null and mesa.filled and not mesa.is_ghost(), "la mesa colocada deja de ser silueta")
	check(mesa != null and not mesa.node.find_children("Superficie", "StaticBody3D", true, false).is_empty(),
		"la mesa colocada pasa a ser superficie (lo de encima se apoya en ella, no la atraviesa)")
	check(fx.bursts > bursts_before and fx.get_children().any(func(c: Node) -> bool: return c.name.begins_with("Serrin")),
		"al encajar una pieza salen serrín y chispas")
	if mesa != null:
		var far := mesa.center() + Vector3(d.color_radius * 1.6, 0.0, 0.0)
		check(not painted_at_once, "(control) justo al encajar la pintura aún no ha llegado: crece poco a poco")
		await get_tree().create_timer(Diorama.PAINT_TIME + 0.15).timeout
		check(d.is_painted_at(mesa.center()) and not d.is_painted_at(far) and d.has_unpainted_layer(),
			"al encajar, la pintura se extiende desde la pieza hasta su radio, y no más allá")
		var later := cam.global_position.distance_to(cam_before)
		check(first_step < 0.01 and later > 0.03,
			"al colocar, la cámara se acerca a la pieza suave: sin tirón al empezar (%.3f m) y se nota después (%.3f m)" % [first_step, later])

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
	check(fx.get_children().any(func(c: Node) -> bool: return c.name == "Luces") and not fx.get_children().any(func(c: Node) -> bool: return c.name == "Hojas"),
		"al completar suben luces cálidas (sin hojas)")
	await get_tree().create_timer(Diorama.FINAL_PAINT_TIME + 0.3).timeout
	check(not d.has_unpainted_layer(), "al completar no queda madera sin pintar (y la capa se quita)")
	check(sun != null and is_equal_approx(sun.light_energy, rig.energia_final) and sun.light_color.is_equal_approx(rig.color_final),
		"la luz despierta con el diorama: completo, la luz principal es la final (%.2f)" % (sun.light_energy if sun else -1.0))
	check(not GameState.hud._panel.visible, "al completar, la bandeja vacía se recoge")
	await _test_back_to_menu(main)
	await _test_story(main)
	await _test_complete_shortcut(main)
	await _test_real_levels(main)
	await _test_light_scale()
	_end()


## El narrador no pisa frases: una segunda frase espera a que acabe la primera.
func _test_narrator() -> void:
	Narrator.clear()
	var got: Array[String] = []
	var listen := func(text: String, _seconds: float) -> void: got.append(text)
	Narrator.subtitle.connect(listen)
	Narrator.say("pista")
	Narrator.say("orden")
	check(got.size() == 1 and got[0] == Narrator.text("pista") and Narrator.remaining() > 2.5,
		"el narrador no pisa frases: la segunda espera a que acabe la primera (%d de 2 dichas)" % got.size())
	Narrator.subtitle.disconnect(listen)
	Narrator.clear()


## La historia del desván (docs/GUION.md): se monta por secciones en orden; en cada una los objetos
## de la historia aparecen de uno en uno y la clave al final; lo que está guardado en un mueble se
## descubre porque el mueble brilla, y en la adolescencia primero la cámara y luego la inscripción.
func _test_story(main: Node) -> void:
	var attic := "res://levels/level_01_desvan.tscn"
	GameState.levels = PackedStringArray([attic])
	main.play_level(0)
	await get_tree().process_frame
	GameState.camera.snap()
	var d := GameState.diorama
	check(d != null and d.scene_file_path == attic and d.sections.size() == 5 and d.sections[0].opened and not d.sections[1].opened,
		"el desván empieza con su primera sección abierta y las otras cuatro cerradas")
	if d == null or d.sections.size() != 5:
		return
	var s1 := d.sections[0]
	var s2 := d.sections[1]
	var s3 := d.sections[2]
	var s4 := d.sections[3]
	var s5 := d.sections[4]
	var shown := d.visible_inventory()
	check(not shown.is_empty() and shown.all(func(id: StringName) -> bool: return _slot(d, id).section == s1)
		and not shown.has(&"tejado") and not shown.has(&"hucha"),
		"al empezar, la bandeja trae el suelo y las paredes: ni el tejado (va después) ni la hucha (la clave) ni nada de otra zona")
	var otter_slot := _slot(d, &"peluche")
	check(not otter_slot.shown and not otter_slot.ghost_visible() and not s2.decor[0].visible and not (s2.lights()[0] as Light3D).visible
		and d.find_children("*", "Label3D", true, false).is_empty(),
		"los actos cerrados no se ven: ni sus siluetas, ni sus muebles, ni su luz, ni su nombre en la escena")
	var wall := _slot(d, &"pared_fondo")
	var roof := _slot(d, &"tejado")
	check(wall.ghost_visible() and not wall.looks_locked() and roof.ghost_visible() and roof.looks_locked()
		and not wall._ghost.shader.code.contains("ALPHA"),
		"en el acto abierto se ven todas sus siluetas (opacas, como en Woodo): blancas las que ya van, grises las que esperan")
	var fx_focus: Dictionary = GameState.enfoque.state()
	check(GameState.enfoque._rect.visible and absf(float(fx_focus.fuera) - Enfoque.PLAY_BLUR) < 0.3,
		"todo se ve un poco desdibujado, más lejos del foco (enfoque de cine: %.1f px)" % float(fx_focus.fuera))
	await _test_tray(d, shown)
	# El suelo, a tablones de tres largos parecidos: cada uno vale en varios huecos, pero no en todos.
	var planks := {}
	for sl in s1.slots:
		if String(sl.id).begins_with("tablon_"):
			planks[sl.id] = planks.get(sl.id, 0) + 1
	check(planks.size() == 3 and planks.values().all(func(n: int) -> bool: return n == 6),
		"el suelo son 18 tablones de tres largos (%s)" % planks)
	var cam3 := GameState.camera.cam
	var mid_plank: PieceSlot = s1.slots.filter(func(sl: PieceSlot) -> bool: return sl.id == &"tablon_medio")[0]
	var long_plank: PieceSlot = s1.slots.filter(func(sl: PieceSlot) -> bool: return sl.id == &"tablon_largo")[0]
	d.try_place(&"tablon_largo", cam3.unproject_position(mid_plank.center()), cam3)
	check(not mid_plank.filled, "un tablón largo no entra en el hueco de uno mediano")
	check(d.try_place(&"tablon_largo", cam3.unproject_position(long_plank.center()), cam3) and long_plank.filled,
		"y en el de uno largo, sí (cualquiera de los largos)")
	GameState.drag.begin(&"tablon_corto", GameState.hud.item_for(&"tablon_corto"))
	check(GameState.is_dragging and not d.slots.any(func(sl: PieceSlot) -> bool:
		return float(sl._ghost.get_shader_parameter("pulse")) > 0.0 if sl._ghost != null else false),
		"al coger un tablón no late ninguna silueta: encontrar dónde va es el reto")
	GameState.drag.cancel()
	var solid := 0
	for dec in s2.decor:
		for body in dec.find_children("Superficie", "StaticBody3D", true, false):
			solid += 1 if (body as StaticBody3D).collision_layer != 0 else 0
	check(solid == 0, "los muebles ocultos de una zona cerrada no chocan con la pieza en mano (%d chocan)" % solid)
	var placed: Array[StringName] = []
	var record := func(id: StringName, _n: Node3D) -> void: placed.append(id)
	Events.piece_placed.connect(record)
	var flashes := [0]
	var count_flash := func() -> void: flashes[0] += 1
	Events.flash_requested.connect(count_flash)
	var found_events: Array = []
	var record_found := func(item: Node, n: int, total: int) -> void: found_events.append([item, n, total])
	Events.collectible_found.connect(record_found)
	var hung := [0]
	var count_hung := func(_item: Node) -> void: hung[0] += 1
	Events.collectible_hung.connect(count_hung)
	Narrator.clear()
	var steps := 0
	while not s1.completed and steps < 80:
		d.debug_solve_step()
		steps += 1
	check(s1.completed and not placed.is_empty() and placed.back() == &"hucha",
		"la estructura se monta entera y la hucha (clave) va la última (%s)" % [placed.back() if not placed.is_empty() else &""])
	var cam_ctl := GameState.camera
	var m: Momentos = main.momentos
	check(m.active and m.target == _slot(d, &"hucha").node and cam_ctl.in_moment and GameState.hud.in_moment()
		and cam_ctl.distance < d.camera_distance * 0.6 + 0.01,
		"al poner la hucha (tiene frase), momento: la cámara se le acerca, la pantalla se enmarca y la bandeja se aparta")
	# Algo que se cruce entre la cámara y la hucha se esconde mientras dura el plano.
	var pig_node := _slot(d, &"hucha").node
	var blocker := MeshInstance3D.new()
	var blocker_mesh := BoxMesh.new()
	blocker_mesh.size = Vector3(0.25, 0.25, 0.25)
	blocker.mesh = blocker_mesh
	d.add_child(blocker)
	blocker.global_position = cam_ctl.goal_position().lerp(Visuals.global_aabb(pig_node).get_center(), 0.5)
	Visuals.add_surface(blocker)
	await get_tree().physics_frame               # que la física ya lo tenga en cuenta
	m.start(pig_node, "normal", "hucha")
	check(m.hidden_for_shot.has(blocker) and not m.hidden_for_shot.any(func(g: Node) -> bool: return pig_node.is_ancestor_of(g)),
		"lo que se cruza delante del objeto del primer plano se esconde (y el objeto no)")
	await get_tree().create_timer(0.8).timeout
	var pig_px := GameState.camera.cam.unproject_position(Visuals.global_aabb(pig_node).get_center())
	fx_focus = GameState.enfoque.state()
	check(float(fx_focus.fuera) > Enfoque.PLAY_BLUR + 0.5 and (fx_focus.centro as Vector2).distance_to(pig_px) < 120.0,
		"en un momento, el enfoque se va al objeto y lo demás se desenfoca más")
	var still := pig_node.global_transform
	await get_tree().create_timer(0.5).timeout
	check(pig_node.global_transform.is_equal_approx(still) and cam_ctl.breath_amount() < 0.01,
		"en el primer plano el objeto se queda quieto (sin gesto) y la cámara deja de respirar")
	GameState.hud.show_tip("(prueba)")
	check(GameState.hud.tip_text() == "", "un consejo no sale encima de un primer plano: espera a que acabe")
	GameState.hud._tip_waiting = []
	await get_tree().process_frame
	check(d.is_opening() and not GameState.hud.says_nothing_left(),
		"entre una sección y la siguiente, la bandeja espera: no dice que aquí no queda nada")
	var waited := 0.0
	while not s2.opened and waited < 10.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	check(s2.opened and waited >= Diorama.SECTION_PAUSE - 0.3, "al completarla, la infancia se abre sola tras una pausa (%.1f s)" % waited)
	check(not m.active and not cam_ctl.in_moment and not GameState.hud.in_moment(),
		"al callarse, el momento acaba: la cámara vuelve al jugador y la bandeja vuelve")
	await get_tree().create_timer(Momentos.HIDE_TIME + 0.1).timeout
	check(blocker.visible and is_zero_approx(blocker.transparency), "y lo que se había escondido vuelve")
	blocker.queue_free()
	await get_tree().create_timer(0.3).timeout
	check(GameState.hud.chapter_text() == Narrator.text("titulo_infancia") and s2.decor[0].visible and (s2.lights()[0] as Light3D).visible,
		"al abrirse la infancia: su rótulo, sus muebles y su luz")
	check(GameState.hud._chapter_kicker.text == "CAPÍTULO I" and GameState.hud._chapter_title.text == "Infancia"
		and otter_slot.shown and otter_slot.ghost_visible(),
		"el rótulo es de nuevo capítulo (CAPÍTULO I / Infancia) y las siluetas del acto aparecen")
	shown = d.visible_inventory()
	check(shown.has(&"comoda_infantil") and not shown.has(&"caja_musica") and not shown.has(&"dibujo") and not shown.has(&"peluche"),
		"infancia: la caja de música espera a su cómoda, el dibujo a la caja y la nutria (clave) a todo lo demás")
	var orange := _collectible(d, &"dibujo_naranja")
	check(orange != null and not orange.available and not orange.target.visible and d.clothesline != null and d.clothesline.is_visible_in_tree(),
		"al abrirse la infancia aparece la cuerda de los dibujos; el de debajo de la cama aún no está (after-cama_infantil)")
	var blocks := _pickup(d, &"cubos")
	var chest: Interactable = blocks.container if blocks != null else null
	check(chest != null and chest.kind == NameRules.DOOR and not chest.target.is_ancestor_of(blocks.target),
		"los cubos están guardados en el baúl, sin ser hijos de la tapa (si no, girarían con ella)")
	check(chest != null and chest.attention and chest.glow_count() > 0 and main.effects.is_calling(chest),
		"el baúl que guarda lo que toca encontrar brilla, se mueve y echa motas")
	check(chest != null and chest.outline_count() > 0, "y lleva un contorno dorado (lo que se ve de lejos)")
	var tip_wait := 0.0
	while GameState.hud.tip_text() == "" and tip_wait < 6.0:      # sale cuando se va el rótulo de capítulo
		await get_tree().create_timer(0.25).timeout
		tip_wait += 0.25
	check(GameState.hud.tip_text() == Narrator.text("consejo_muebles") and tip_wait > 1.0,
		"la primera vez sale el consejo de tocar el mueble que brilla (cuando se va el rótulo de capítulo: %.1f s)" % tip_wait)
	steps = 0
	while steps < 30:                              # todo lo que se pueda colocar sin buscar
		var h := d.hint_target()
		if not h.has("slot"):
			break
		d.place(h.slot)
		steps += 1
	check(d.hint_target().get("container") == chest, "cuando solo falta buscar, la pista señala el mueble (no lo escondido)")
	check(not _slot(d, &"peluche").available, "(control) la nutria no aparece mientras falten los cubos")
	var green := _collectible(d, &"dibujo_verde")
	check(d.collectible_total() == 7 and green != null and green.available and green.container == chest and not green.is_clickable(),
		"hay 7 dibujos escondidos; uno está en el baúl y, con el baúl cerrado, no se puede coger")
	check(orange.available and orange.target.visible and orange.is_clickable(), "con la cama puesta, asoma el dibujo de debajo y se puede coger")
	Narrator.clear()                           # sin primer plano encima: consejos y avisos esperan a que acabe
	m.finish()
	if chest != null:
		chest.set_open(true)
		await get_tree().process_frame
		check(not chest.attention and blocks.attention and GameState.hud.tip_text() == Narrator.text("consejo_dentro"),
			"al abrir el baúl, lo que brilla es lo de dentro (y sale el consejo de cogerlo)")
		d.collect(blocks)
		check(d.visible_inventory().has(&"cubos"), "los cubos encontrados pasan a la bandeja")
		await get_tree().process_frame
		await get_tree().process_frame
		var flying := GameState.hud.flights()
		var cubes_card := GameState.hud.item_for(&"cubos")
		var fly_from: Vector2 = flying[0].get_global_rect().get_center() if not flying.is_empty() else Vector2.ZERO
		check(flying.size() == 1 and cubes_card != null and fly_from.distance_to(cubes_card.get_global_rect().get_center()) > 150.0,
			"al coger lo guardado, su ficha sale de donde estaba y vuela por la pantalla (no aparece de golpe en la bandeja)")
		await get_tree().create_timer(Hud.FLY_TIME + 0.15).timeout
		check(GameState.hud.flights().is_empty(), "y llega a su sitio en la bandeja")
		check(green.is_clickable(), "con el baúl abierto, el dibujo de dentro se puede coger")
		green.activate()
		await get_tree().process_frame
		await get_tree().process_frame
		check(green.collected and found_events.size() == 1 and found_events[0][1] == 1 and found_events[0][2] == 7
			and green.target.get_parent() == d.clothesline,
			"tocar el dibujo lo encuentra (1 de 7) y se va hacia la cuerda")
		check(GameState.hud.award_text().contains("1 DE 7") and GameState.hud.award_text().contains(Narrator.piece_name(&"dibujo_verde", true))
			and GameState.hud.drawings_text() == "1 / 7",
			"sale el aviso de logro (%s) y el contador de dibujos" % GameState.hud.award_text())
		await get_tree().create_timer(Diorama.LIFT_TIME + 0.15 + Diorama.HANG_TIME + 0.25).timeout
		check(green.target.global_position.distance_to(d.spot(0).global_position) < 0.02 and hung[0] == 1,
			"el dibujo vuela hasta la primera pinza de la cuerda y se cuelga")
		check(not GameState.hud.tip_text().contains("dibujo") and not Narrator.has_line("consejo_dibujos"),
			"no hay frases ni consejos sobre los dibujos escondidos: los encuentra el jugador")
		await get_tree().create_timer(Efectos.GLINT_EVERY + 0.3).timeout
		check(main.effects.glints > 0, "los dibujos que esperan echan un destello de vez en cuando (%d)" % main.effects.glints)
		d.place(_slot(d, &"cubos"))
	check(_slot(d, &"peluche").available and d.visible_inventory().has(&"peluche"), "con todo lo demás puesto aparece la nutria (clave)")
	d.place(_slot(d, &"peluche"))
	check(s2.completed and placed.find(&"caja_musica") < placed.find(&"dibujo") and placed.find(&"dibujo") < placed.find(&"peluche"),
		"infancia completa en el orden del guion: caja de música, dibujo, nutria")
	# El dibujo es plano y está en la pared: su primer plano es de frente.
	var drawing := _slot(d, &"dibujo").node
	var face := drawing.global_basis.z
	m.start(drawing, "normal", "dibujo")
	check(absf(wrapf(cam_ctl.yaw - rad_to_deg(atan2(face.x, face.z)), -180.0, 180.0)) < 1.0 and absf(cam_ctl.pitch - 8.0) < 0.5
		and m._flat_front(_slot(d, &"hucha").node) == Vector3.ZERO,
		"los objetos planos de pared (el dibujo) se ven de frente en su primer plano")
	m.finish()
	d.debug_solve_step()                           # abre la adolescencia sin esperar (la espera ya se probó)
	var camera_pick := _pickup(d, &"camara")
	var application := _pickup(d, &"solicitud")
	check(s3.opened and camera_pick != null and application != null and not camera_pick.available and not application.available,
		"al abrirse la adolescencia, ni la cámara ni la inscripción se ven todavía")
	var lamp := _slot(d, LAMP)
	var lamp_lights: Array = lamp.lights() if lamp != null else []
	check(not lamp_lights.is_empty() and not lamp.filled and not (lamp_lights[0][0] as Light3D).visible,
		"la luz de una pieza (la lámpara del escritorio) está apagada mientras es silueta")
	_farol_energy = float(lamp_lights[0][1]) if not lamp_lights.is_empty() else 0.0
	steps = 0
	while not _slot(d, &"mp3").filled and steps < 40:
		d.debug_solve_step()
		steps += 1
	check(camera_pick.available and not application.available and camera_pick.container != null and camera_pick.container.attention,
		"con el MP3 puesto toca encontrar la cámara: el armario brilla (la inscripción aún no aparece)")
	var flashes_before: int = flashes[0]
	steps = 0
	while not _slot(d, &"camara").filled and steps < 40:
		d.debug_solve_step()
		steps += 1
	check(flashes[0] > flashes_before, "al colocar la cámara, destello blanco (el flash)")
	var pink := _collectible(d, &"dibujo_rosa")
	if not lamp.filled:
		d.place(lamp)
	await get_tree().create_timer(maxf(Diorama.GIVEN_DELAY + 0.3, PieceSlot.LIGHT_FADE + 0.1)).timeout
	if not lamp_lights.is_empty():
		var bulb: Light3D = lamp_lights[0][0]
		check(bulb.visible and is_equal_approx(bulb.light_energy, float(lamp_lights[0][1])),
			"al colocar la lámpara, su luz se enciende con un fundido (%.2f de %.2f)" % [bulb.light_energy, float(lamp_lights[0][1])])
	check(pink != null and pink.comes_with == &"camara" and pink.available and pink.target.visible and not pink.collected and m.active,
		"al poner la cámara aparece su dibujo, y espera quieto mientras dura su momento")
	Narrator.clear()
	m.finish()
	await get_tree().create_timer(Diorama.GIVEN_DELAY + 0.3).timeout
	check(pink.collected and found_events.size() == 2 and found_events[1][1] == 2 and pink.target.get_parent() == d.clothesline,
		"al acabar el momento de la cámara, su dibujo se encuentra solo: logro (2 de 7) y a la cuerda")
	steps = 0
	while not application.available and steps < 60:
		d.debug_solve_step()
		steps += 1
	var rest := s3.slots.filter(func(sl: PieceSlot) -> bool: return not sl.filled and sl.id != &"solicitud")
	check(application.available and rest.is_empty() and application.container != null
		and application.container.kind == NameRules.DRAWER and application.container.attention,
		"después de la cámara y de todo lo demás, toca encontrar la inscripción a Bellas Artes: el cajón brilla")
	steps = 0
	while not _slot(d, &"lienzo").filled and steps < 120:
		d.debug_solve_step()
		steps += 1
	var easel := _slot(d, &"caballete").node
	var canvas := _slot(d, &"lienzo").node
	m.start(easel, "normal", "caballete")
	check(_slot(d, &"lienzo").filled and not m.hidden_for_shot.any(func(g: Node) -> bool: return canvas.is_ancestor_of(g)),
		"en el primer plano del caballete no se quita el cuadro que lleva encima")
	Narrator.clear()
	m.finish()
	while not s4.completed and steps < 120:
		d.debug_solve_step()
		steps += 1
	check(s4.completed and placed.find(&"llaves") < placed.find(&"caballete") and placed.find(&"caballete") < placed.find(&"espejo"),
		"adultez en el orden del guion: llaves, caballete y el espejo (clave) el último")
	var mirror := _slot(d, &"espejo")
	var front := mirror.node.global_basis.z
	var want_yaw := rad_to_deg(atan2(front.x, front.z))
	await get_tree().create_timer(1.6).timeout
	check(m.kind == "reflejo" and absf(cam_ctl.yaw - want_yaw) < 1.0 and cam_ctl.pitch < 8.0,
		"al poner el espejo, la cámara se pone delante de él (giro %.0f, quiere %.0f)" % [cam_ctl.yaw, want_yaw])
	check(m.is_isolated() and cam_ctl.cam.cull_mask != 0xFFFFF and m.iris_strength() > 0.95 and is_instance_valid(m.reflection),
		"espejo: todo lo demás a negro y en la luna aparece su reflejo")
	d._open_when_free(s5)                        # lo que hace la pausa entre secciones al acabar
	check(d.hold_sections and d.opening_section() == s5 and not s5.opening,
		"mientras dura el espejo, el final espera: no se abre encima")
	Narrator.clear()
	await get_tree().create_timer(Momentos.MIN_TIME * 0.5).timeout     # un momento dura al menos MIN_TIME
	check(m.active and m.kind == "transicion" and m.is_isolated() and cam_ctl.in_moment and not s5.opening,
		"al callarse el espejo no se vuelve al desván: transición (el espejo vacío, en silencio)")
	var cut_wait := 0.0
	while m.kind == "transicion" and cut_wait < 6.0:
		await get_tree().process_frame
		cut_wait += get_process_delta_time()
	check(cut_wait > Momentos.TRANSITION_HOLD and s5.opening and m.kind == "ofrecida" and m._curtain.color.a > 0.95 and not is_instance_valid(m.reflection)
		and GameState.hud.chapter_text() == "",
		"después, fundido lento a negro y, ya a oscuras, empieza el final (sin rótulo de capítulo)")
	check(not s5.opened and Narrator.remaining() > 3.0 and not _slot(d, &"moneda").available,
		"el final habla antes de enseñar la moneda")
	await get_tree().create_timer(0.3).timeout
	var pig := _slot(d, &"hucha").node
	check(m.kind == "ofrecida" and cam_ctl.in_moment and cam_ctl.center.distance_to(_slot(d, &"hucha").center()) < 0.2
		and not d.tray_entries().any(func(e: Dictionary) -> bool: return e.id == &"moneda"),
		"el final es un primer plano de la hucha mientras habla, y la moneda no va a la bandeja")
	var trunk := d.find_child("BaulViejo", true, false)
	check(m.is_isolated() and m.is_in_isolation(Visuals.meshes_under(pig)[0]) and m.is_in_isolation(trunk)
		and not m.is_in_isolation(Visuals.meshes_under(_slot(d, &"escritorio").node)[0])
		and absf(cam_ctl.pitch - Momentos.ZENITH) < 0.5 and absf(cam_ctl._cur_pitch - cam_ctl.pitch) < 0.5,
		"corte a la hucha sola (sobre su baúl), vista un poco desde arriba, quieta y sin vueltas")
	check(m.cozy_shown() and is_instance_valid(m._rim) and is_instance_valid(m._motes) and m.is_in_isolation(m._motes),
		"la escena del final es acogedora: fondo cálido con luces desenfocadas, contraluz y motas en la luz")
	await get_tree().create_timer(Momentos.COIN_DELAY + 0.9).timeout
	check(is_instance_valid(m.coin), "mientras habla, la moneda aparece junto a la hucha")
	var coin_xf: Transform3D = m.coin.global_transform if is_instance_valid(m.coin) else Transform3D()
	var pig_xf := pig.global_transform
	await get_tree().create_timer(0.5).timeout
	check(is_instance_valid(m.coin) and m.coin.global_transform.is_equal_approx(coin_xf) and pig.global_transform.is_equal_approx(pig_xf),
		"la moneda y la hucha se quedan quietas (lo que se mueve es la luz)")
	d.debug_solve_step()
	check(s5.opened and _slot(d, &"moneda").available, "después aparece la moneda, sobre la hucha")
	Narrator.clear()
	await get_tree().process_frame
	_click(m.coin_screen_position())               # un clic sin arrastrar no la mete: vuelve a su sitio
	await get_tree().create_timer(0.6).timeout
	check(not _slot(d, &"moneda").filled and is_instance_valid(m.coin) and m._coin_state == "",
		"soltar la moneda lejos de la ranura no la mete: vuelve a su sitio")
	_mouse_button(m.coin_screen_position(), true)
	await get_tree().process_frame
	_mouse_move(m.slot_screen_position())
	await get_tree().process_frame
	_mouse_button(m.slot_screen_position(), false)
	await get_tree().create_timer(0.8).timeout
	check(d.completed and _slot(d, &"moneda").filled, "arrastrar la moneda hasta la ranura la mete en la hucha y completa el desván")
	check(d.find_child("ChispasMoneda", false, false) != null and float(m._cozy_mat.get_shader_parameter("brillo")) > 1.2,
		"al entrar la moneda: golpe de luz, chispas doradas y el fondo se aviva")
	Events.piece_placed.disconnect(record)
	Events.flash_requested.disconnect(count_flash)
	Events.collectible_found.disconnect(record_found)
	Events.collectible_hung.disconnect(count_hung)
	await get_tree().create_timer(2.0).timeout
	check(not GameState.hud._done.visible, "el final de la historia no enseña el aviso de «completado»")
	await get_tree().create_timer(3.0).timeout
	check(main._fade.color.a > 0.05, "el final funde a negro (hacia los créditos) (%.2f)" % main._fade.color.a)
	var credits: Creditos = main.credits
	var wait_credits := 0.0
	while not credits.rolling and wait_credits < 8.0:
		await get_tree().create_timer(0.25).timeout
		wait_credits += 0.25
	check(credits.rolling and credits.lines().has("DIBUJOS ENCONTRADOS") and credits.lines().has("2 de 7"),
		"tras el fundido pasan los créditos, con los dibujos encontrados (2 de 7)")
	await get_tree().create_timer(1.2).timeout
	_click(Vector2(640, 360))
	await get_tree().create_timer(Creditos.FADE + 0.4).timeout
	check(not credits.visible and GameState.diorama.scene_file_path == GameState.MENU_LEVEL
		and main.menu.is_open() == GameState.menu_unlocked,
		"y después de los créditos, el menú (con el cerdito)")


## La bandeja enseña todas las piezas (las que aún no van, con candado y el porqué), se aparta al
## coger una pieza para poder soltar detrás de ella, y vuelve al soltar.
func _test_tray(d: Diorama, shown: Array[StringName]) -> void:
	for i in 2:                                    # el panel se maqueta un fotograma después
		await get_tree().process_frame
	var hud: Hud = GameState.hud
	var all_ids: Dictionary = {}
	for sl in d.slots:
		if not sl.offered:
			all_ids[sl.id] = true
	check(hud.cards().size() == all_ids.size() and hud.cards(true).size() == shown.size(),
		"la bandeja enseña todas las piezas del juego (%d), las que aún no van con candado (%d se pueden poner)" % [hud.cards().size(), hud.cards(true).size()])
	var otter := hud.item_for(&"peluche")
	check(otter != null and otter.locked and otter.reason.contains(Narrator.text("titulo_infancia")),
		"la nutria va con candado y dice de qué acto es (%s)" % (otter.reason if otter != null else ""))
	check(d.lock_reason(&"tejado").contains(Narrator.piece_name(&"cumbrera")) and d.lock_reason(&"hucha").contains("última"),
		"cada candado dice qué va antes: tejado (%s), hucha (%s)" % [d.lock_reason(&"tejado"), d.lock_reason(&"hucha")])
	if otter != null:
		_click(otter.get_global_rect().get_center())
		await get_tree().process_frame
		check(not GameState.is_dragging and hud.info_text().begins_with("Todavía no se puede poner") and hud.info_text().contains(otter.reason),
			"tocar una ficha con candado no la coge: tiembla y dice por qué (%s)" % hud.info_text().replace("\n", " / "))
		GameState.drag.begin(&"peluche", otter)
		check(not GameState.is_dragging, "ni a la fuerza: una pieza bloqueada no se puede arrastrar")
	var wall := hud.item_for(&"pared_fondo")
	var tray_spot := hud._panel.get_global_rect().get_center()
	GameState.drag.begin(&"pared_fondo", wall)
	await get_tree().create_timer(Hud.SLIDE_TIME + 0.15).timeout
	check(GameState.is_dragging and hud.tray_is_away() and not hud.is_over_panel(tray_spot)
		and float(_slot(d, &"pared_fondo")._ghost.get_shader_parameter("pulse")) == 1.0,
		"al coger una pieza la bandeja se aparta (se puede soltar donde estaba) y late su silueta")
	_mouse_button(hud._panel.get_global_rect().get_center(), false)     # soltar en el borde que asoma = nada
	await get_tree().create_timer(Hud.SLIDE_TIME + 0.15).timeout
	check(not GameState.is_dragging and not hud.tray_is_away() and not _slot(d, &"pared_fondo").filled,
		"al soltar en el borde de la bandeja no se pone nada, y la bandeja vuelve")


func _collectible(d: Diorama, id: StringName) -> Interactable:
	for it in d.interactables:
		if it.kind == NameRules.COLLECTIBLE and it.id == id:
			return it
	return null


func _pickup(d: Diorama, id: StringName) -> Interactable:
	for it in d.interactables:
		if it.kind == NameRules.PICKUP and it.id == id:
			return it
	return null


## escala_luces: las luces que trae un modelo (de Blender llegan con otras unidades) se ajustan
## para todo el nivel con un número, sin reexportar.
func _test_light_scale() -> void:
	var probe := (load("res://levels/level_01_desvan.tscn") as PackedScene).instantiate() as Diorama
	probe.escala_luces = 2.0
	add_child(probe)
	var farol := _slot(probe, LAMP)
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
	check(t.slots.size() >= 18 and t.interactables.is_empty(), "el título son muchas piezas pequeñas, sin cajones ni escondidos (%d)" % t.slots.size())
	var stickers := t.slots.filter(func(sl: PieceSlot) -> bool: return String(sl.id).begins_with("pegatina_")).size()
	check(_slot(t, &"cuerpo") != null and _slot(t, &"hocico") != null and stickers >= 6,
		"el título es la hucha de cerdito, con pegatinas para decorarla (%d pegatinas)" % stickers)
	check(_title_name(t) == GameState.game_title().to_upper().replace(" ", "_"), "la pegatina del cartel lleva el nombre del juego (%s)" % _title_name(t))
	check(t.count_of(&"pata") == 4 and _slots_with(t, &"pata") == 4, "las patas repetidas son la misma pieza: cuatro que valen en cualquier hueco de pata")
	var star := _slot(t, &"pegatina_estrella")
	var star_glows := star == null or not star.lights().is_empty()
	for m in (Visuals.meshes_under(star.prototype) if star != null else []):
		var mat := m.get_active_material(0) as StandardMaterial3D
		star_glows = star_glows or (mat != null and mat.emission_enabled)
	check(not star_glows, "la estrella del cerdito es solo una pegatina: ni luz ni brillo propio")
	check(main.get_viewport().use_hdr_2d, "el fondo se pinta con HDR 2D (sin él, el pastel se queda en un gris apagado)")
	check(GameState.hud._panel.visible and GameState.hud.cards(true).size() > 0, "durante el puzle del título se ve la bandeja de piezas")
	_check_lighting(main, "res://iluminacion/menu.tscn", "el título")
	var steps := 0
	while not t.completed and steps < 40:
		t.debug_solve_step()
		steps += 1
		await get_tree().process_frame
	check(t.completed, "el título se completa (%d pasos)" % steps)
	await get_tree().process_frame
	check(not (main.effects as Efectos).get_children().any(func(c: Node) -> bool: return c.name == "Luces" or c.name == "Destellos"),
		"al completar el cerdito y pasar al menú, no salen partículas por delante")
	check(GameState.menu_unlocked and _saved(TEST_PROGRESS, "menu_desbloqueado") == true, "resolver el título desbloquea el menú y se guarda")
	var talk := Narrator.remaining()
	await get_tree().create_timer(main.MENU_DELAY + 0.3).timeout
	check(talk > main.MENU_DELAY + 0.6 and not main.menu.is_open(),
		"el menú no sale mientras el cerdito habla (le quedaban %.1f s de frases)" % talk)
	var menu_wait := 0.0
	while not main.menu.is_open() and menu_wait < 12.0:
		await get_tree().create_timer(0.25).timeout
		menu_wait += 0.25
	check(main.menu.is_open() and Narrator.remaining() <= 0.0 and not GameState.hud._subtitle_box.visible,
		"el menú sale cuando el cerdito ha acabado de hablar, y sin frases encima")
	check(main.menu.is_open() and main.menu.page == "principal", "tras la onda de color se abre el menú")
	if not main.menu.is_open():
		return false
	check(not GameState.hud._panel.visible and not GameState.hud._done.visible, "con el menú abierto, el panel de piezas se esconde")
	check(main.menu.buttons.jugar.text == "Jugar", "sin progreso, el botón dice Jugar")
	var waited := 0.0
	while GameState.camera.cam.h_offset > -0.3 and waited < 1.5:
		waited += get_process_delta_time()
		await get_tree().process_frame
	check(GameState.camera.cam.h_offset < -0.3, "la cámara corre el diorama a la derecha del menú (h_offset %.2f)" % GameState.camera.cam.h_offset)
	main.menu.show_page("opciones")
	var slider := main.menu.options.controls["volumen_voz"] as HSlider
	slider.value = 0.35
	check(is_equal_approx(Settings.get_value("volumen_voz"), 0.35), "mover el deslizador de voz cambia el ajuste")
	for i in 2:                                      # la página se maqueta un fotograma después
		await get_tree().process_frame
	var swatch: Button = main.menu.options.swatches[3]
	_click(swatch.get_global_rect().get_center())
	await get_tree().process_frame
	var bg := (main.get_node("Iluminacion/Fondo/Degradado") as CanvasItem).material as ShaderMaterial
	check(int(Settings.get_value("fondo_color")) == 3 and bg.get_shader_parameter("color_centro") == Fondos.COLORES[3].centro_3d,
		"en Opciones, tocar un color cambia el fondo al momento (%s)" % Fondos.COLORES[3].nombre)
	main.menu.options.motifs[3].pressed.emit()
	check((bg.get_shader_parameter("color_forma") as Color).a == 0.0, "y el motivo «Liso» quita las figuras del fondo")
	main.menu.options.motifs[1].pressed.emit()
	check((bg.get_shader_parameter("color_forma") as Color).a > 0.0 and int(bg.get_shader_parameter("forma")) == 2,
		"y «Corazones» pone corazones")
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
	var credits: Creditos = main.credits
	check(credits._bg_mat.get_shader_parameter("color_centro") == Fondos.color(Settings.get_value("fondo_color")).centro,
		"los créditos llevan el mismo fondo que eligió el jugador")
	Settings.set_value("fondo_color", 0)
	Settings.set_value("fondo_motivo", 0)
	check(credits.rolling and credits.visible and credits.lines().has(GameState.game_title())
		and credits.lines()[credits.lines().size() - 1] == "¡Gracias por jugar!" and not main.menu.is_open(),
		"al acabar el juego pasan los créditos (del nombre del juego a «¡Gracias por jugar!»)")
	await get_tree().create_timer(1.2).timeout
	var y0 := credits._roll.position.y
	await get_tree().create_timer(0.5).timeout
	check(credits._roll.position.y < y0 - 5.0, "los créditos suben despacio (%.0f px en medio segundo)" % (y0 - credits._roll.position.y))
	_click(Vector2(640, 360))                      # un clic los acaba
	await get_tree().create_timer(Creditos.FADE + 0.4).timeout
	var t := GameState.diorama
	check(not credits.visible and t != null and t.scene_file_path == GameState.MENU_LEVEL and t.completed,
		"después de los créditos, el menú: el título sale ya montado")
	check(main.menu.is_open() and main.menu.page == "principal" and Narrator.remaining() <= 0.0,
		"y el menú se abre en su página principal, sin frases")
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
## F9 (atajo de prueba) monta el desván entero de golpe y se queda a la vista, sin fundido.
func _test_complete_shortcut(main: Node) -> void:
	GameState.levels = PackedStringArray(["res://levels/level_01_desvan.tscn"])
	main.play_level(0)
	await get_tree().process_frame
	var d := GameState.diorama
	var ended := [false]
	var on_end := func(_d: Node) -> void: ended[0] = true
	Events.level_completed.connect(on_end)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F9
	key.pressed = true
	get_viewport().push_input(key, true)
	await get_tree().process_frame
	var all_open := d.sections.all(func(s: Section) -> bool: return s.opened)
	var all_placed := d.slots.all(func(s: PieceSlot) -> bool: return s.filled)
	check(d.completed and ended[0] and all_open and all_placed and d.visible_inventory().is_empty(),
		"F9 monta el desván entero de golpe: todas las zonas abiertas y cada pieza en su sitio")
	var on_line := 0
	for k in d.collectible_total():
		for it in d.interactables:
			if it.kind == NameRules.COLLECTIBLE and it.target.visible and it.target.global_position.distance_to(d.spot(k).global_position) < 0.01:
				on_line += 1
	check(d.collectibles_found() == 7 and on_line == 7, "y con F9 los 7 dibujos están colgados en la cuerda (%d)" % on_line)
	await get_tree().create_timer(4.0).timeout
	check(GameState.diorama == d and GameState.hud._done.visible and main._fade.color.a < 0.1,
		"tras F9 el desván se queda a la vista (panel de fin, sin fundido a negro)")
	Events.level_completed.disconnect(on_end)


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
		GameState.camera.snap()                  # sin la entrada de cine: las medidas, con el encuadre del nivel
		var d := GameState.diorama
		check(d != null and d.scene_file_path == path, "%s carga" % path.get_file())
		if d == null or d.scene_file_path != path:
			continue
		var empty: Array[String] = []
		for sl in d.slots:
			if sl.meshes().is_empty():
				empty.append(String(sl.id))
		check(d.slots.size() >= 5 and empty.is_empty(), "%s: todos los huecos con su modelo (%d huecos; sin modelo: %s)" % [path.get_file(), d.slots.size(), empty])
		check(d.slots[0].is_ghost() and (d.slots[0]._ghost as ShaderMaterial).render_priority > Visuals.make_clay_overlay().render_priority,
			"%s: las siluetas se pintan después de la arcilla (si no, una pared grande las borra)" % path.get_file())
		await get_tree().process_frame
		# La pieza más grande y la más pequeña del panel: las pequeñas son las que se colarían.
		var cards: Array = GameState.hud.cards(true)
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
		check(GameState.hud.cards().is_empty() and not GameState.hud.says_nothing_left(),
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
	var view := get_viewport().get_visible_rect().size     # sin pantalla mide 1280x1280: la rejilla, a su medida
	for i in 8:
		for j in 6:
			_mouse_move(Vector2(view.x * (0.11 + i * 0.086), view.y * (0.15 + j * 0.14)))
			var n := GameState.drag.held_overlaps()
			if n < 0:
				continue
			checked += 1
			inside += 1 if n > 0 else 0
			rested += 1 if GameState.drag.last_rested else 0
	check(checked >= 20 and inside == 0, "%s: la pieza en mano (%s) no atraviesa nada en %d puntos (dentro: %d)" % [who, piece, checked, inside])
	# Control (que el instrumento mida algo): al menos 1 de cada 8 puntos tiene que apoyarse. No más:
	# un diorama que empieza casi vacío (el desván: solo suelo) tiene media pantalla de aire.
	check(rested * 8 >= checked, "%s: la pieza en mano se apoya en las superficies (%d de %d puntos)" % [who, rested, checked])


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
	c.snap()
	var aim := Vector2(420, 300)
	var mid := get_viewport().get_visible_rect().size * 0.5
	var aimed := c._point_under(aim)
	for i in 6:
		_wheel(MOUSE_BUTTON_WHEEL_UP, aim)
	c.snap()
	await get_tree().process_frame
	var aimed_px := c.cam.unproject_position(aimed)
	check(aimed_px.distance_to(mid) < aim.distance_to(mid) * 0.75,
		"al hacer zoom, la zona señalada se va hacia el centro de la pantalla (%.0f px del centro, antes %.0f)" % [aimed_px.distance_to(mid), aim.distance_to(mid)])
	await get_tree().create_timer(0.6).timeout
	check((GameState.enfoque.state().centro as Vector2).distance_to(mid) < 20.0,
		"y el enfoque está en el centro de la pantalla: lo acercado, nítido; los bordes, desenfocados")
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


## El nombre que lleva la pegatina del cartel del título (su malla se llama "Nombre-WOODO_JAM").
func _title_name(d: Diorama) -> String:
	var sticker := _slot(d, &"pegatina_nombre")
	if sticker == null:
		return ""
	for n in sticker.node.find_children("Nombre-*", "", true, false):
		return String(n.name).trim_prefix("Nombre-")
	return ""


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
