extends Node
## Narrador: subtítulo + voz opcional. Las frases viven en data/narracion_<idioma>.json
## y la voz (si existe) en assets/audio/voz/<clave>.ogg. Sin audio, sale solo el subtítulo.

signal subtitle(text: String, seconds: float)

var language := "es"
var _lines: Dictionary = {}
var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	load_language(language)


func load_language(lang: String) -> void:
	language = lang
	var path := "res://data/narracion_%s.json" % lang
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_lines = data if data is Dictionary else {}
	if _lines.is_empty():
		push_error("Narrador: %s vacío o no es un objeto JSON" % path)


func has_line(key: String) -> bool:
	return _lines.has(key)


## Dice una frase. Si la clave no existe lo AVISA: un narrador mudo no se distingue de uno roto.
func say(key: String) -> void:
	if not _lines.has(key):
		push_warning("Narrador: falta la frase '%s' en narracion_%s.json" % [key, language])
		return
	_speak(key)


## Para frases opcionales (p. ej. una por pieza): si no existe, no dice nada y no avisa.
func say_if_exists(key: String) -> void:
	if _lines.has(key):
		_speak(key)


func _speak(key: String) -> void:
	var text := String(_lines[key])
	var seconds := clampf(text.length() * 0.06, 2.5, 8.0)
	var voice := "res://assets/audio/voz/%s.ogg" % key
	if ResourceLoader.exists(voice):
		var stream: AudioStream = load(voice)
		_player.stream = stream
		_player.play()
		seconds = maxf(seconds, stream.get_length() + 0.5)
	subtitle.emit(text, seconds)
