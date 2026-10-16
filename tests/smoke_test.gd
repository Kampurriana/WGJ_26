extends Node
## Test de humo: arranca el juego entero y juega el nivel 0 de principio a fin.
## Ejecutar (o mejor: tools/check.sh, que además lee el log):
##   godot --headless --path . res://tests/smoke_test.tscn
## Imprime "OK ..." / "FALLO ..." y termina con "SMOKE OK" o "SMOKE FALLO n".
## Un test que no imprime "SMOKE OK" NO ha pasado, diga lo que diga el código de salida.

const SAMPLE_LEVEL := "res://levels/level_00_muestra.tscn"

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
	# Siempre el nivel de muestra, esté o no en data/levels.json: es el que usa toda la convención.
	GameState.levels = PackedStringArray([SAMPLE_LEVEL])
	GameState.level_index = 0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	for i in 3:
		await get_tree().process_frame
	var d := GameState.diorama
	check(d != null, "el nivel 0 carga y registra su Diorama")
	if d == null:
		return _end()
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
	_end()


func _test_name_rules() -> void:
	var a := NameRules.parse("P_silla__after-mesa_001")
	check(a.get("kind") == NameRules.PIECE and a.get("id") == &"silla", "NameRules: P_silla__after-mesa_001 -> pieza 'silla'")
	check(NameRules.values(a.get("tokens", PackedStringArray()), "after") == [&"mesa"], "NameRules: token after-mesa")
	check(NameRules.parse("Cube").is_empty(), "NameRules: un nombre sin prefijo se ignora")
	check(NameRules.strip_copy_suffix("P_taza.003") == "P_taza", "NameRules: quita el .003 de Blender")


## Los eventos se entregan en coordenadas LOCALES del viewport: sin ventana (--headless) el
## tamaño de ventana es 0x0 y Godot escalaría las posiciones x0,05.
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
