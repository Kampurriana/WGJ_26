extends Node
## Narrador: subtítulo + voz opcional. Las frases viven en data/narracion_<idioma>.json
## y la voz (si existe) en assets/audio/voz/<clave>.ogg. Sin audio, sale solo el subtítulo.
## Una clave puede ser una frase o una LISTA de frases (se dicen seguidas; "" = un silencio).
## Las frases van en COLA: una frase nueva espera a que acabe la anterior (nunca se pisan).

signal subtitle(text: String, seconds: float)
signal skipped                               ## el jugador ha pasado de frase (se quita el subtítulo)

const GAP := 0.4                             ## silencio entre frases (s)
const PAUSE := 1.6                           ## lo que dura un "" en una lista de frases

var language := "es"
var _lines: Dictionary = {}
var _names: Dictionary = {}                 ## id de pieza -> nombre (data/piezas_<idioma>.json)
var _player: AudioStreamPlayer
var _queue: Array[Dictionary] = []          ## {text, voice} pendientes
var _left := 0.0                             ## lo que le queda a la frase de ahora (con su silencio)


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Voz"
	add_child(_player)
	load_language(language)


func load_language(lang: String) -> void:
	language = lang
	var path := "res://data/narracion_%s.json" % lang
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_lines = data if data is Dictionary else {}
	if _lines.is_empty():
		push_error("Narrador: %s vacío o no es un objeto JSON" % path)
	var names: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/piezas_%s.json" % lang))
	_names = names if names is Dictionary else {}


## Nombre de una pieza para la interfaz ("la cómoda"). Si no está en piezas_<idioma>.json, el id
## sin guiones bajos. capital = con mayúscula ("La cómoda").
func piece_name(id: StringName, capital := false) -> String:
	var n := String(_names.get(String(id), String(id).replace("_", " ")))
	return n.left(1).to_upper() + n.substr(1) if capital else n


func has_line(key: String) -> bool:
	return _lines.has(key)


## Dice una frase. Si la clave no existe lo AVISA: un narrador mudo no se distingue de uno roto.
func say(key: String) -> void:
	if not _lines.has(key):
		push_warning("Narrador: falta la frase '%s' en narracion_%s.json" % [key, language])
		return
	_enqueue(key)


## Para frases opcionales (p. ej. una por pieza): si no existe, no dice nada y no avisa.
func say_if_exists(key: String) -> void:
	if _lines.has(key):
		_enqueue(key)


## El texto de una clave (para rótulos y consejos de la interfaz). "" si no existe.
func text(key: String) -> String:
	var v: Variant = _lines.get(key, "")
	return " ".join(PackedStringArray(v)) if v is Array else String(v)


## Segundos hasta que se calle (lo de ahora + lo que espera en la cola).
func remaining() -> float:
	var total := maxf(_left, 0.0)
	for e in _queue:
		total += PAUSE if String(e.text) == "" else _seconds_for(String(e.text)) + GAP
	return total


## Pasa a la siguiente frase de la cola (el jugador quiere seguir). false = no estaba hablando.
func skip() -> bool:
	if _left <= 0.0 and _queue.is_empty():
		return false
	_player.stop()
	_left = 0.0
	skipped.emit()                           # primero se quita el subtítulo de ahora...
	_next()                                  # ...y luego sale el siguiente, si lo hay
	return true


## Se calla y olvida la cola (al cambiar de diorama).
func clear() -> void:
	_queue.clear()
	_left = 0.0
	_player.stop()


func _enqueue(key: String) -> void:
	var v: Variant = _lines[key]
	var texts: Array = v if v is Array else [v]
	for i in texts.size():
		var suffix := "" if texts.size() == 1 else "_%d" % (i + 1)
		_queue.append({"text": String(texts[i]), "voice": "res://assets/audio/voz/%s%s.ogg" % [key, suffix]})
	if _left <= 0.0:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_left = 0.0
		return
	var e: Dictionary = _queue.pop_front()
	var line := String(e.text)
	if line == "":
		_left = PAUSE
		return
	var seconds := _seconds_for(line)
	if ResourceLoader.exists(e.voice):
		var stream: AudioStream = load(e.voice)
		_player.stream = stream
		_player.play()
		seconds = maxf(seconds, stream.get_length() + 0.5)
	subtitle.emit(line, seconds)
	_left = seconds + GAP


func _seconds_for(line: String) -> float:
	return clampf(line.length() * 0.06, 2.5, 8.0)


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			_next()
