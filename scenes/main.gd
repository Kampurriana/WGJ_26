extends Node3D
## Escena principal: monta cámara, arrastre, interfaz, menús, mando y la luz de cada nivel.
## Arranca en el menú de inicio: el diorama del título (levels/menu_titulo.tscn), cuyo puzle
## desbloquea el menú. Una vez resuelto, en las siguientes partidas sale ya montado.
## Los niveles jugables vienen de data/levels.json; el progreso se guarda en GameState.
##
## Argumentos para Claude (después de "--" en la línea de comandos):
##   --level=N            empieza directamente en el nivel N (índice de data/levels.json)
##   --level=menu         empieza en el menú de inicio (igual que sin --level)
##   --menu-page=P        al abrirse el menú, en la página P (elegir, opciones, creditos);
##                        "pausa" abre la pausa nada más cargar
##   --solve=K            coloca K piezas solo (jugador automático), una cada 0,3 s
##   --capture=ruta.png   guarda una captura (relativa al proyecto) y sale
##   --capture-after=S    segundos de espera antes de la captura (por defecto 3)
##   --hold=X,Y           (capturas) coge la pieza más grande del panel y la lleva a ese punto
##   --zoom=K,X,Y         (capturas) K pasos de zoom hacia ese punto de la pantalla
##   --solo-fondo         (capturas) sin diorama ni partículas: el fondo solo, para medir la luz

const MENU_DELAY := 1.6                      ## tras resolver el título, lo que dura la onda de color
const FADE_TIME := 0.7                       ## fundido desde negro al cargar un diorama
const DEFAULT_LIGHTING := "res://iluminacion/luz_por_defecto.tscn"

var start_in_menu := true                    ## los tests lo ponen a false para ir directos al nivel
var menu: MainMenu
var pause: PauseMenu
var effects: Efectos
var _level: Node
var _lighting: Node
var _fade: ColorRect
var _only_background := false
var _lighting_path := ""
var _menu_page := ""
var _hold := Vector2(-1, -1)
var _zoom_steps := 0
var _zoom_at := Vector2.ZERO
var _capture_path := ""
var _capture_after := 3.0
var _solve_left := 0
var _solve_timer := 0.0
var _elapsed := 0.0


func _ready() -> void:
	# main sigue viva en pausa (capturas, menús, mando); lo que es "juego" se pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	var cam := DioramaCamera.new()
	cam.name = "Camera"
	cam.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(cam)
	GameState.camera = cam
	var drag := DragController.new()
	drag.name = "Drag"
	drag.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(drag)
	GameState.drag = drag
	effects = Efectos.new()
	effects.name = "Efectos"
	effects.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(effects)
	var hud := Hud.new()
	hud.name = "Hud"
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hud)
	GameState.hud = hud
	add_child(GamepadCursor.new())
	menu = MainMenu.new()
	menu.name = "MainMenu"
	add_child(menu)
	pause = PauseMenu.new()
	pause.name = "PauseMenu"
	add_child(pause)
	_build_fade()
	hud.next_requested.connect(next_level)
	hud.pause_requested.connect(open_pause)
	menu.play_requested.connect(play_level)
	pause.main_menu_requested.connect(show_title)
	Events.level_completed.connect(_on_level_completed)
	if start_in_menu:
		show_title()
	else:
		load_level(GameState.level_index)
	if _menu_page == "pausa":
		open_pause()
	elif _menu_page != "":
		menu.pending_page = _menu_page
	Sfx.music("musica")


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			var v := a.get_slice("=", 1)
			start_in_menu = v == "menu"
			if not start_in_menu:
				GameState.level_index = v.to_int()
		elif a.begins_with("--menu-page="):
			_menu_page = a.get_slice("=", 1)
		elif a.begins_with("--hold="):
			var v := a.get_slice("=", 1).split_floats(",")
			_hold = Vector2(v[0], v[1])
		elif a.begins_with("--zoom="):
			var v := a.get_slice("=", 1).split_floats(",")
			_zoom_steps = int(v[0])
			_zoom_at = Vector2(v[1], v[2])
		elif a.begins_with("--solve="):
			_solve_left = a.get_slice("=", 1).to_int()
		elif a.begins_with("--capture="):
			_capture_path = a.get_slice("=", 1)
		elif a.begins_with("--capture-after="):
			_capture_after = a.get_slice("=", 1).to_float()
		elif a == "--solo-fondo":
			_only_background = true


## Cortina negra por encima de todo (menos de lo que no deja de verse): se abre al cargar.
func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func _fade_in() -> void:
	_fade.color.a = 1.0
	var tw := _fade.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_fade, "color:a", 0.0, FADE_TIME)


## La luz vive en escenas de iluminacion/ que se ajustan en el editor (docs/ILUMINACION.md), no aquí.
## Cada nivel usa la suya si la indica (Diorama.iluminacion) y si no, la de por defecto. Solo hay
## una a la vez: dos WorldEnvironment no se suman (manda uno) y dos soles sí (doble de luz).
func _apply_lighting(path: String) -> void:
	if path == _lighting_path:
		return
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Main: no puedo cargar la iluminación '%s'; uso la de por defecto" % path)
		if path == DEFAULT_LIGHTING:
			return
		return _apply_lighting(DEFAULT_LIGHTING)
	if _lighting != null:
		remove_child(_lighting)
		_lighting.queue_free()
	_lighting = scene.instantiate()
	_lighting.name = "Iluminacion"
	add_child(_lighting)
	_lighting_path = path


func load_level(index: int) -> void:
	if GameState.levels.is_empty():
		return
	GameState.level_index = clampi(index, 0, GameState.levels.size() - 1)
	GameState.mode = GameState.Mode.PLAYING
	_load(GameState.levels[GameState.level_index])


## El diorama del título. Si ya se resolvió alguna vez, sale montado y con el menú abierto.
func show_title() -> void:
	get_tree().paused = false
	GameState.mode = GameState.Mode.MENU
	var unlocked := GameState.menu_unlocked
	_load(GameState.MENU_LEVEL, unlocked)
	if unlocked:
		GameState.diorama.complete_silently()
		_open_menu()
	else:
		GameState.camera.set_menu_view(false)
		GameState.hud.set_game_ui_visible(true)


func play_level(index: int) -> void:
	menu.close()
	GameState.camera.set_menu_view(false)
	GameState.hud.set_game_ui_visible(true)
	load_level(index)


func next_level() -> void:
	if GameState.level_index + 1 < GameState.levels.size():
		load_level(GameState.level_index + 1)
	else:
		show_title()
		menu.show_page("creditos")
		Narrator.say_if_exists("fin_juego")


func open_pause() -> void:
	if menu.is_open():
		return
	pause.open(GameState.mode == GameState.Mode.PLAYING)


func _open_menu() -> void:
	GameState.hud.set_game_ui_visible(false)
	GameState.camera.set_menu_view(true)
	menu.open()


func _on_level_completed(d: Node) -> void:
	if GameState.mode == GameState.Mode.MENU:
		GameState.unlock_menu()
		get_tree().create_timer(MENU_DELAY).timeout.connect(func() -> void:
			if GameState.diorama == d and GameState.mode == GameState.Mode.MENU and not menu.is_open():
				_open_menu())
	else:
		GameState.mark_completed(GameState.levels[GameState.level_index])


## silent = sin la frase de entrada (el título ya montado no tiene que explicar nada).
func _load(path: String, silent := false) -> void:
	if _level != null:
		GameState.drag.cancel()
		remove_child(_level)
		_level.queue_free()
	var scene: PackedScene = load(path)
	_level = scene.instantiate()
	_level.process_mode = Node.PROCESS_MODE_PAUSABLE
	if silent:
		_level.set("intro_key", "")
	add_child(_level)
	var own := String(_level.get("iluminacion")) if "iluminacion" in _level else ""
	_apply_lighting(own if own != "" else DEFAULT_LIGHTING)
	GameState.camera.configure(GameState.diorama)
	GameState.camera.intro()
	_fade_in()
	if _only_background:
		_level.hide()
		effects.hide()


func _process(delta: float) -> void:
	_elapsed += delta
	if _solve_left > 0:
		_solve_timer -= delta
		if _solve_timer <= 0.0:
			_solve_timer = 0.3
			_solve_left -= 1
			GameState.diorama.debug_solve_step()
	if _zoom_steps > 0 and _elapsed > 0.5:
		_zoom_steps -= 1
		GameState.camera.zoom_at(1.0 - GameState.camera.zoom_step, _zoom_at)
	if _hold.x >= 0.0 and _elapsed > 1.0 and _solve_left == 0 and not GameState.is_dragging:
		var cards := GameState.hud._list.get_children().filter(func(n: Node) -> bool: return n is InventoryItem)
		if not cards.is_empty():
			var card: InventoryItem = cards[0]
			GameState.drag.begin(card.piece_id, card)
			GameState.drag.hold_at(_hold)
		_hold = Vector2(-1, -1)
	if _capture_path != "" and _elapsed >= _capture_after and _solve_left == 0:
		var img := get_viewport().get_texture().get_image()
		var out := ProjectSettings.globalize_path("res://" + _capture_path)
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var err := img.save_png(out)
		print("CAPTURA %s %dx%d err=%d" % [out, img.get_width(), img.get_height(), err])
		_capture_path = ""
		get_tree().quit()
