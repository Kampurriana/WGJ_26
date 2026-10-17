extends Node
## Estado de la partida, progreso guardado y accesos a los sistemas vivos (los rellena main.gd).
## Progreso en user://progreso.cfg: qué niveles están completados y si el puzle del título ya
## se resolvió (entonces el menú sale montado). Con --capture no lee ni escribe disco.

enum Mode { MENU, PLAYING }

const LEVELS_PATH := "res://data/levels.json"
const MENU_LEVEL := "res://levels/menu_titulo.tscn"
const SECTION := "progreso"
## MODO PROTOTIPO: cada vez que se le da a Play, el puzle del título y los niveles empiezan de cero
## (no se lee ni se guarda el progreso; las Opciones sí se guardan). Para la entrega: false.
const RESET_ON_START := true
## ATAJOS DE PRUEBA: F9 monta el diorama entero de golpe (para mirarlo o probar el final sin
## colocar pieza a pieza). Para la entrega: false.
const DEBUG_SHORTCUTS := true

var diorama: Diorama
var camera: DioramaCamera
var hud: Hud
var drag: DragController
var enfoque: Enfoque                         ## el postproceso de enfoque (core/enfoque.gd)

var mode := Mode.PLAYING
var is_dragging := false
var hovered_piece: StringName = &""
var level_index := 0
var levels: PackedStringArray = []

var progress_path := "user://progreso.cfg"   ## "" = solo en memoria
var menu_unlocked := false
var completed_levels: PackedStringArray = []


func _ready() -> void:
	var text := FileAccess.get_file_as_string(LEVELS_PATH)
	var data: Variant = JSON.parse_string(text)
	if data is Array:
		for p in data:
			levels.append(String(p))
	if levels.is_empty():
		push_error("GameState: %s no tiene niveles (o no es un array JSON)" % LEVELS_PATH)
	load_progress("" if _capturing() or RESET_ON_START else progress_path)


static func _capturing() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			return true
	return false


## Nombre del juego: el de Proyecto → Configuración → Nombre (project.godot).
func game_title() -> String:
	return String(ProjectSettings.get_setting("application/config/name", "Diorama"))


# --- Progreso ----------------------------------------------------------------------------

func load_progress(file: String) -> void:
	progress_path = file
	menu_unlocked = false
	completed_levels = PackedStringArray()
	if file == "" or not FileAccess.file_exists(file):
		return
	var cfg := ConfigFile.new()
	var err := cfg.load(file)
	if err != OK:
		push_warning("GameState: no puedo leer %s (err %d): empiezo de cero" % [file, err])
		return
	menu_unlocked = bool(cfg.get_value(SECTION, "menu_desbloqueado", false))
	for p: Variant in cfg.get_value(SECTION, "completados", []):
		completed_levels.append(String(p))


func save_progress() -> int:
	if progress_path == "":
		return OK
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "menu_desbloqueado", menu_unlocked)
	cfg.set_value(SECTION, "completados", Array(completed_levels))
	var err := cfg.save(progress_path)
	if err != OK:
		push_warning("GameState: no puedo guardar %s (err %d)" % [progress_path, err])
	return err


func unlock_menu() -> void:
	if not menu_unlocked:
		menu_unlocked = true
		save_progress()


func mark_completed(level_path: String) -> void:
	if not completed_levels.has(level_path):
		completed_levels.append(level_path)
		save_progress()


func reset_progress() -> void:
	menu_unlocked = false
	completed_levels = PackedStringArray()
	save_progress()


func is_completed(index: int) -> bool:
	return index >= 0 and index < levels.size() and completed_levels.has(levels[index])


## Se puede jugar el primero, uno ya completado, o el siguiente a uno completado.
func is_unlocked(index: int) -> bool:
	if index < 0 or index >= levels.size():
		return false
	return index == 0 or is_completed(index) or is_completed(index - 1)


func has_progress() -> bool:
	for p in levels:
		if completed_levels.has(p):
			return true
	return false


## Para "Continuar": el primer nivel sin completar (si están todos, el primero).
func next_level_to_play() -> int:
	for i in levels.size():
		if not is_completed(i):
			return i
	return 0
