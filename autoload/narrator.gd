extends Node
## Narrador: subtítulo + voz. Las frases viven en data/narracion_<idioma>.json y la voz (si existe)
## en assets/audio/voz/<clave>.(ogg|wav|mp3) (tools/preparar_voces.sh las deja así). Sin audio, sale
## solo el subtítulo. Una clave puede ser:
##  - una frase;
##  - una LISTA (se dicen seguidas; "" = un silencio; "sfx:x" = suena el efecto x entera, p. ej. las
##    canciones que pasan entre los dos trozos del MP3). La voz de cada una: <clave>_1, <clave>_2...
##  - un TROZO GRABADO {"frases": [...], "marcas": [...], "voz": "..."}: un solo audio (por defecto el
##    de la clave) con su subtítulo partido en frases; "marcas" = el segundo del audio en que empieza
##    cada frase después de la primera (las pausas de la grabación). Sin marcas, a partes iguales
##    por letras. Si se pasa de frase, se salta el trozo entero (audio y subtítulos van juntos).
## Las frases van en COLA: una frase nueva espera a que acabe la anterior (nunca se pisan).
## Mientras suena una voz, la música baja (Sfx.duck; guion v2: "ducking").

signal subtitle(text: String, seconds: float)
signal skipped                               ## el jugador ha pasado de frase (se quita el subtítulo)

const GAP := 0.4                             ## silencio entre frases (s)
const PAUSE := 1.6                           ## lo que dura un "" en una lista de frases
const VOICE_TAIL := 0.5                      ## el subtítulo se queda esto tras acabar la voz (guion v2)
const VOICE_EXTENSIONS := ["ogg", "wav", "mp3"]
const SFX_PREFIX := "sfx:"

var language := "es"
var _lines: Dictionary = {}
var _names: Dictionary = {}                 ## id de pieza -> nombre (data/piezas_<idioma>.json)
var _player: AudioStreamPlayer
var _queue: Array[Dictionary] = []          ## {text, voice, seconds, group, last} o {sfx} pendientes
var _left := 0.0                             ## lo que le queda a la frase de ahora (con su silencio)
var _group := 0                              ## trozo grabado que suena ahora (0 = ninguno)
var _groups := 0
var _ducked := false


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
	var out := PackedStringArray()
	for seg: Variant in _segments(_lines.get(key, "")):
		if seg is Dictionary:
			out.append_array(PackedStringArray(_parts(seg as Dictionary)))
		elif not String(seg).begins_with(SFX_PREFIX):
			out.append(String(seg))
	return " ".join(out).strip_edges()


## Si suena una voz ahora mismo (la música está bajada).
func voice_playing() -> bool:
	return _player.playing


## Segundos hasta que se calle (lo de ahora + lo que espera en la cola).
func remaining() -> float:
	var total := maxf(_left, 0.0)
	for e in _queue:
		total += _duration(e)
	return total


## Pasa a la siguiente frase de la cola (el jugador quiere seguir). false = no estaba hablando.
func skip() -> bool:
	if _left <= 0.0 and _queue.is_empty():
		return false
	_player.stop()
	_left = 0.0
	while _group != 0 and not _queue.is_empty() and int(_queue[0].get("group", 0)) == _group:
		_queue.pop_front()                   # el resto del trozo grabado se va con su voz
	skipped.emit()                           # primero se quita el subtítulo de ahora...
	_next()                                  # ...y luego sale el siguiente, si lo hay
	return true


## Se calla y olvida la cola (al cambiar de diorama, al abrirse el menú). El subtítulo se quita.
func clear() -> void:
	var talking := _left > 0.0 or not _queue.is_empty()
	_queue.clear()
	_left = 0.0
	_player.stop()
	if talking:
		skipped.emit()


func _enqueue(key: String) -> void:
	var segments := _segments(_lines[key])
	for i in segments.size():
		var seg: Variant = segments[i]
		var voice := key + ("" if segments.size() == 1 else "_%d" % (i + 1))
		if seg is Dictionary:
			_enqueue_recorded(String((seg as Dictionary).get("voz", voice)), seg as Dictionary)
		elif String(seg).begins_with(SFX_PREFIX):
			_queue.append({"sfx": String(seg).trim_prefix(SFX_PREFIX)})
		else:
			var line := String(seg)
			var path := _voice(voice) if line != "" else ""
			var seconds := PAUSE if line == "" else _seconds_for(line)
			if path != "":
				seconds = maxf(seconds, (load(path) as AudioStream).get_length() + VOICE_TAIL)
			_queue.append({"text": line, "voice": path, "seconds": seconds, "last": line != ""})
	if _left <= 0.0:
		_next()


## Un trozo grabado: un audio, varias frases de subtítulo que cambian en sus marcas.
func _enqueue_recorded(voice: String, seg: Dictionary) -> void:
	var parts := _parts(seg)
	var path := _voice(voice)
	if path == "":                               # sin grabación: cada frase con su tiempo de lectura
		for line: String in parts:
			_queue.append({"text": line, "voice": "", "seconds": _seconds_for(line), "last": true})
		return
	var length := (load(path) as AudioStream).get_length()
	var starts: Array[float] = [0.0]
	var marks: Array = seg.get("marcas", [])
	if marks.size() == parts.size() - 1:
		for m: Variant in marks:
			starts.append(clampf(float(m), starts[-1], length))
	else:                                        # a partes iguales por letras
		var total := 0
		for line: String in parts:
			total += line.length()
		var acc := 0
		for i in parts.size() - 1:
			acc += parts[i].length()
			starts.append(length * acc / maxf(total, 1.0))
	_groups += 1
	for i in parts.size():
		var last := i == parts.size() - 1
		var end := length + VOICE_TAIL if last else starts[i + 1]
		_queue.append({"text": parts[i], "voice": path if i == 0 else "", "seconds": maxf(end - starts[i], 0.3),
			"group": _groups, "last": last})


func _next() -> void:
	_group = 0
	if _queue.is_empty():
		_left = 0.0
		return
	var e: Dictionary = _queue.pop_front()
	if e.has("sfx"):
		_left = _duration(e)
		Sfx.play(String(e.sfx), 0.0)
		return
	var line := String(e.text)
	_left = _duration(e)
	if line == "":
		return
	_group = int(e.get("group", 0))
	if String(e.voice) != "":
		_player.stream = load(String(e.voice))
		_player.play()
	subtitle.emit(line, float(e.seconds))


## Lo que ocupa una entrada de la cola (con su silencio detrás, salvo dentro de un trozo grabado).
func _duration(e: Dictionary) -> float:
	if e.has("sfx"):
		var l := Sfx.length(String(e.sfx))
		return l if l > 0.0 else PAUSE
	return float(e.seconds) + (GAP if bool(e.get("last", true)) else 0.0)


func _segments(v: Variant) -> Array:
	return v if v is Array else [v]


func _parts(seg: Dictionary) -> Array[String]:
	var f: Variant = seg.get("frases", "")
	var out: Array[String] = []
	for line: Variant in (f if f is Array else [f]):
		out.append(String(line))
	return out


func _voice(name: String) -> String:
	for ext: String in VOICE_EXTENSIONS:
		var path := "res://assets/audio/voz/%s.%s" % [name, ext]
		if ResourceLoader.exists(path):
			return path
	return ""


func _seconds_for(line: String) -> float:
	return clampf(line.length() * 0.06, 2.5, 8.0)


func _process(delta: float) -> void:
	if _player.playing != _ducked:                # la música baja mientras habla
		_ducked = _player.playing
		Sfx.duck(_ducked)
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			_next()
