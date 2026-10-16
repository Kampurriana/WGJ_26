extends Node3D
## Escena principal: monta cámara, arrastre, interfaz, menús, mando y luz por defecto.
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

const MENU_DELAY := 1.6                      ## tras resolver el título, lo que dura la onda de color

var start_in_menu := true                    ## los tests lo ponen a false para ir directos al nivel
var menu: MainMenu
var pause: PauseMenu
var _level: Node
var _menu_page := ""
var _capture_path := ""
var _capture_after := 3.0
var _solve_left := 0
var _solve_timer := 0.0
var _elapsed := 0.0


func _ready() -> void:
	# main sigue viva en pausa (capturas, menús, mando); lo que es "juego" se pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	_build_environment()
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
		elif a.begins_with("--solve="):
			_solve_left = a.get_slice("=", 1).to_int()
		elif a.begins_with("--capture="):
			_capture_path = a.get_slice("=", 1)
		elif a.begins_with("--capture-after="):
			_capture_after = a.get_slice("=", 1).to_float()


## Luz por defecto, medida con capturas (ver "Trampas" en CLAUDE.md). Una cara de arriba recibe
## SUN_ENERGY * 0,77 + AMBIENT_ENERGY: por encima de ~0,8 los colores claros salen quemados.
const BACKGROUND_COLOR := Color(0.86, 0.80, 0.72)   ## más oscuro que la arcilla: el diorama se separa
const AMBIENT_COLOR := Color(1.0, 0.96, 0.9)
const AMBIENT_ENERGY := 0.35
const SUN_ENERGY := 0.55
const SUN_ROTATION := Vector3(-50, -35, 0)
const SHADOW_OPACITY := 0.8                          ## sombras marrones, no negras
const EXPOSURE := 1.0


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT_COLOR
	env.ambient_light_energy = AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = EXPOSURE
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = SUN_ROTATION
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = true
	sun.shadow_opacity = SHADOW_OPACITY
	add_child(sun)


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
	# El letrero del título lleva el nombre del proyecto. Antes de entrar en el árbol: el Diorama
	# copia sus piezas en _ready (la ficha del panel) y la copia tiene que salir ya con el nombre.
	var title_sign := _level.find_child("Titulo", true, false) as Label3D
	if path == GameState.MENU_LEVEL and title_sign != null:
		title_sign.text = GameState.game_title()
	add_child(_level)
	GameState.camera.configure(GameState.diorama)


func _process(delta: float) -> void:
	_elapsed += delta
	if _solve_left > 0:
		_solve_timer -= delta
		if _solve_timer <= 0.0:
			_solve_timer = 0.3
			_solve_left -= 1
			GameState.diorama.debug_solve_step()
	if _capture_path != "" and _elapsed >= _capture_after and _solve_left == 0:
		var img := get_viewport().get_texture().get_image()
		var out := ProjectSettings.globalize_path("res://" + _capture_path)
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var err := img.save_png(out)
		print("CAPTURA %s %dx%d err=%d" % [out, img.get_width(), img.get_height(), err])
		_capture_path = ""
		get_tree().quit()
