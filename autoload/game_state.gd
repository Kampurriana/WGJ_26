extends Node
## Estado de la partida y accesos a los sistemas vivos (los rellena main.gd).

const LEVELS_PATH := "res://data/levels.json"

var diorama: Diorama
var camera: DioramaCamera
var hud: Hud
var drag: DragController

var is_dragging := false
var hovered_piece: StringName = &""
var level_index := 0
var levels: PackedStringArray = []


func _ready() -> void:
	var text := FileAccess.get_file_as_string(LEVELS_PATH)
	var data: Variant = JSON.parse_string(text)
	if data is Array:
		for p in data:
			levels.append(String(p))
	if levels.is_empty():
		push_error("GameState: %s no tiene niveles (o no es un array JSON)" % LEVELS_PATH)
