extends Node3D
## Escena principal: monta cámara, arrastre, interfaz, mando, luz por defecto y carga niveles.
##
## Argumentos para Claude (después de "--" en la línea de comandos):
##   --level=N            empieza en el nivel N (índice de data/levels.json)
##   --solve=K            coloca K piezas solo (jugador automático), una cada 0,3 s
##   --capture=ruta.png   guarda una captura (relativa al proyecto) y sale
##   --capture-after=S    segundos de espera antes de la captura (por defecto 3)

var _level: Node
var _capture_path := ""
var _capture_after := 3.0
var _solve_left := 0
var _solve_timer := 0.0
var _elapsed := 0.0


func _ready() -> void:
	_parse_args()
	_build_environment()
	var cam := DioramaCamera.new()
	cam.name = "Camera"
	add_child(cam)
	GameState.camera = cam
	var drag := DragController.new()
	drag.name = "Drag"
	add_child(drag)
	GameState.drag = drag
	var hud := Hud.new()
	hud.name = "Hud"
	add_child(hud)
	GameState.hud = hud
	add_child(GamepadCursor.new())
	hud.next_requested.connect(next_level)
	load_level(GameState.level_index)
	Sfx.music("musica")


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			GameState.level_index = a.get_slice("=", 1).to_int()
		elif a.begins_with("--solve="):
			_solve_left = a.get_slice("=", 1).to_int()
		elif a.begins_with("--capture="):
			_capture_path = a.get_slice("=", 1)
		elif a.begins_with("--capture-after="):
			_capture_after = a.get_slice("=", 1).to_float()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.96, 0.91, 0.84)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.96, 0.9)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)


func load_level(index: int) -> void:
	if GameState.levels.is_empty():
		return
	if _level != null:
		GameState.drag.cancel()
		remove_child(_level)
		_level.queue_free()
	GameState.level_index = clampi(index, 0, GameState.levels.size() - 1)
	var scene: PackedScene = load(GameState.levels[GameState.level_index])
	_level = scene.instantiate()
	add_child(_level)
	GameState.camera.configure(GameState.diorama)


func next_level() -> void:
	if GameState.level_index + 1 < GameState.levels.size():
		load_level(GameState.level_index + 1)
	else:
		Narrator.say_if_exists("fin_juego")


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
