extends Node
## Narrador: subtítulo + voz. Las frases viven en data/narracion_<idioma>.json y la voz (si existe)
## en assets/audio/voz/<clave>.(ogg|wav|mp3) (tools/preparar_voces.sh las deja así). Sin audio, sale
## solo el subtítulo. Una clave puede ser:
##  - una frase;
##  - una LISTA (se dicen seguidas; "" = un silencio; "sfx:x" = suena el efecto x entera, p. ej. las
##    canciones que pasan entre los dos trozos del MP3). La voz de cada una: <clave>_1, <clave>_2...
##  - un TROZO GRABADO {"frases": [...], "marcas": [...], "voz": "..."}: un solo audio (por defecto el
##    de la clave) con su subtítulo partido en frases; "marcas" = el segundo del audio en que empieza
##    cada frase después de la primera (las pausas de la grabación). Sin marcas, en las pausas que
##    mejor reparten el texto (data/voces_tiempos.json). Una frase "" = sin subtítulo en ese trozo; una
##    "sfx:x", lo mismo, y sin grabación (en inglés) suena el efecto x: las canciones del MP3. Si se pasa
##    de frase, se salta el trozo entero (audio y subtítulos van juntos).
##    Con "frases": [] suena solo la voz, sin subtítulo (una grabación de la que aún no hay texto).
## AL RITMO DE LA VOZ (20-oct, "que los textos se adapten a la velocidad del sonido"): el reloj de las
## frases grabadas es la posición del audio (si el audio empieza tarde o el juego va a tirones, no se
## adelantan), y el subtítulo se escribe mientras habla y se para en las pausas: typed_ratio(), con los
## tramos en que habla cada grabación (tools/tiempos_voces.py → data/voces_tiempos.json).
## Las frases van en COLA: una frase nueva espera a que acabe la anterior (nunca se pisan).
## Mientras suena una voz, la música baja (Sfx.duck; guion v2: "ducking").
## El idioma es el de Settings.language(). Solo hay voces en español (VOICE_LANGUAGE): en otro idioma
## no suena ninguna y cada frase dura su tiempo de lectura (los subtítulos salen siempre).

signal subtitle(text: String, seconds: float)
signal skipped                               ## el jugador ha pasado de frase (se quita el subtítulo)

const GAP := 0.4                             ## silencio entre frases (s)
const PAUSE := 1.6                           ## lo que dura un "" en una lista de frases
const VOICE_TAIL := 0.5                      ## el subtítulo se queda esto tras acabar la voz (guion v2)
const VOICE_PAD := 0.4                       ## la cola de silencio de cada grabación (tools/preparar_voces.sh)
const TYPE_AHEAD := 0.15                     ## con voz, el texto va esto por delante de lo que dice (s)
const MARK_LEAD := 0.1                       ## (marcas automáticas) la frase siguiente sale esto antes de que vuelva a hablar
const TIMINGS := "res://data/voces_tiempos.json"
const PUNCTUATION := ",;:.…!?"               ## donde acaba un trozo del texto (se suele parar a respirar)
const VOICE_EXTENSIONS := ["ogg", "wav", "mp3"]
const SFX_PREFIX := "sfx:"
const VOICE_LANGUAGE := "es"                 ## el idioma en que están grabadas las voces
const NOT_LOGGED := ["pista", "orden", "sub_completo"]   ## avisos de juego, no historia: fuera del historial

var language := "es"
var _lines: Dictionary = {}
var _names: Dictionary = {}                 ## id de pieza -> nombre (data/piezas_<idioma>.json)
var _player: AudioStreamPlayer
var _queue: Array[Dictionary] = []          ## {text, voice, seconds, group, last} o {sfx} pendientes
var _left := 0.0                             ## lo que le queda a la frase de ahora (con su silencio)
var _group := 0                              ## trozo grabado que suena ahora (0 = ninguno)
var _groups := 0
var _ducked := false
var _timings: Dictionary = {}                ## voz -> tramos en que habla [[ini, fin], ...] (data/voces_tiempos.json)
var _current: Dictionary = {}                ## la entrada de la cola que suena ahora
var _voice_t := 0.0                          ## segundos desde que empezó la grabación de ahora (si el audio no dice su posición)


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Voz"
	add_child(_player)
	var timings: Variant = JSON.parse_string(FileAccess.get_file_as_string(TIMINGS))
	_timings = timings if timings is Dictionary else {}
	load_language(Settings.language())
	Settings.changed.connect(func(key: String) -> void:
		if key == "idioma" and Settings.language() != language:
			clear()
			load_language(Settings.language()))


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


## Si en este idioma hay voz (si no, solo subtítulos).
func voiced() -> bool:
	return language == VOICE_LANGUAGE


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
			out.append_array(PackedStringArray(_parts(seg as Dictionary).filter(func(l: String) -> bool:
				return l != "" and not l.begins_with(SFX_PREFIX))))
		elif not String(seg).begins_with(SFX_PREFIX):
			out.append(String(seg))
	return " ".join(out).strip_edges()


## Si suena una voz ahora mismo (la música está bajada).
func voice_playing() -> bool:
	return _player.playing


## Lo que lleva dicho la voz de la frase de ahora (0..1): el subtítulo se escribe a su ritmo (en las pausas
## espera). -1 si la frase de ahora no va con voz (se escribe al suyo).
func typed_ratio() -> float:
	if _left <= 0.0 or not _current.has("t1") or String(_current.get("text", "")) == "":
		return -1.0
	return reveal(String(_current.text), _current.runs, float(_current.t0), float(_current.t1), clock() + TYPE_AHEAD)


## El reloj de la grabación que suena: su posición (con lo que lleva desde la última mezcla); si el audio
## no la da (en la Web, por muestras), lo que lleva sonando por los fotogramas.
func clock() -> float:
	var p := _player.get_playback_position() if _player.playing else 0.0
	return p + AudioServer.get_time_since_last_mix() if p > 0.0 else _voice_t


## Cuánto del texto (0..1) se ha dicho en el segundo t de la grabación, si la frase va de t0 a t1 y la voz
## habla en `runs`. Si el texto tiene un trozo (hasta su coma o su punto) por cada tramo de voz y se parecen
## en lo que ocupan (un tramo cortísimo es una respiración, no un trozo), cada trozo se escribe con el suyo;
## si no, al ritmo de lo que lleva hablado. En las pausas, el texto espera.
static func reveal(line: String, runs: Array, t0: float, t1: float, t: float) -> float:
	var inside: Array[Vector2] = []
	for r: Variant in runs:
		var a := maxf(float(r[0]), t0)
		var b := minf(float(r[1]), t1)
		if b - a > 0.05:
			inside.append(Vector2(a, b))
	if inside.is_empty():                        # sin tramos medidos: a ritmo constante
		return clampf((t - t0) / maxf(t1 - t0, 0.01), 0.0, 1.0)
	var ends := chunk_ends(line)
	var total := 0.0
	for r in inside:
		total += r.y - r.x
	var paired := ends.size() == inside.size()
	for k in (inside.size() if paired else 0):
		var share := float(ends[k] - (ends[k - 1] if k > 0 else 0)) / maxf(line.length(), 1.0)
		var said_share := (inside[k].y - inside[k].x) / total
		paired = paired and said_share > share * 0.4 and said_share < share * 2.5
	if paired:
		var done := 0.0
		for k in inside.size():
			if t < inside[k].x:
				break
			var from := float(ends[k - 1]) if k > 0 else 0.0
			done = from + (ends[k] - from) * clampf((t - inside[k].x) / (inside[k].y - inside[k].x), 0.0, 1.0)
		return done / maxf(line.length(), 1.0)
	var said := 0.0
	for r in inside:
		said += clampf(t - r.x, 0.0, r.y - r.x)
	return said / total


## Dónde acaba cada trozo del texto (el carácter tras su coma, punto, puntos suspensivos...). El último, al final.
static func chunk_ends(line: String) -> Array[int]:
	var ends: Array[int] = []
	for i in line.length():
		if i + 1 < line.length() and PUNCTUATION.contains(line[i]) and line[i + 1] == " ":
			ends.append(i + 1)
	ends.append(line.length())
	return ends


## (Sin marcas) Dónde empieza cada frase después de la primera: en la pausa de la grabación más cerca de
## donde tocaría por letras (contando solo el tiempo que habla; las pausas largas, mejor). [] si no hay
## pausas bastantes.
static func auto_starts(parts: Array[String], runs: Array) -> Array[float]:
	var pauses: Array[Vector3] = []              # (lo hablado antes, cuándo vuelve a hablar, lo que dura)
	var said := 0.0
	for k in runs.size():
		said += float(runs[k][1]) - float(runs[k][0])
		if k + 1 < runs.size():
			pauses.append(Vector3(said, float(runs[k + 1][0]), float(runs[k + 1][0]) - float(runs[k][1])))
	var n := parts.size() - 1
	var out: Array[float] = []
	if pauses.size() < n or said <= 0.0:
		return out
	var letters := 0
	for line in parts:
		letters += line.length()
	var acc := 0
	var j := 0
	for i in n:
		acc += parts[i].length()
		var goal := said * acc / maxf(letters, 1.0)
		var best := j
		var best_cost := INF
		for q in range(j, pauses.size() - (n - 1 - i)):
			var cost := absf(pauses[q].x - goal) / said - 0.08 * minf(pauses[q].z, 1.5)
			if cost < best_cost:
				best_cost = cost
				best = q
		out.append(pauses[best].y - MARK_LEAD)
		j = best + 1
	return out


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
	_player.stream = null
	if talking:
		skipped.emit()


## Se calla con un fundido corto de la voz (el jugador pasa al acto siguiente mientras hablaba): el
## subtítulo se quita ya, la cola se olvida y la voz baja hasta apagarse en `seconds`.
func fade_out(seconds: float) -> void:
	var talking := _left > 0.0 or not _queue.is_empty()
	_queue.clear()
	_left = 0.0
	_group = 0
	if talking:
		skipped.emit()
	if not _player.playing:
		return
	var tw := create_tween()
	tw.tween_property(_player, "volume_db", -40.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_player.stop()
		_player.stream = null
		_player.volume_db = 0.0)


func _enqueue(key: String) -> void:
	if not NOT_LOGGED.has(key) and not key.begins_with("_"):
		GameState.log_dialogue(key)              # para releerlo en la pausa (Diálogos)
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
			var e := {"text": line, "voice": path, "seconds": seconds, "last": line != ""}
			if path != "":
				var length := (load(path) as AudioStream).get_length()
				e["seconds"] = maxf(seconds, length + VOICE_TAIL)
				e.merge({"t0": 0.0, "t1": length - VOICE_PAD, "until": e["seconds"], "runs": _timings.get(voice, [])})
			_queue.append(e)
	if _left <= 0.0:
		_next()


## Un trozo grabado: un audio, varias frases de subtítulo que cambian en sus marcas.
func _enqueue_recorded(voice: String, seg: Dictionary) -> void:
	var parts := _parts(seg)
	var path := _voice(voice)
	if parts.is_empty():                         # solo voz: suena sin subtítulo
		if path != "":
			var seconds := (load(path) as AudioStream).get_length() + VOICE_TAIL
			_queue.append({"text": "", "voice": path, "seconds": seconds, "last": true})
		return
	if path == "":                               # sin grabación: cada frase con su tiempo de lectura
		for line: String in parts:
			if line.begins_with(SFX_PREFIX):
				_queue.append({"sfx": line.trim_prefix(SFX_PREFIX)})
			else:
				_queue.append({"text": line, "voice": "", "seconds": _seconds_for(line), "last": true})
		return
	var length := (load(path) as AudioStream).get_length()
	var runs: Array = _timings.get(voice, [])
	var starts: Array[float] = [0.0]
	var marks: Array = seg.get("marcas", [])
	if marks.size() != parts.size() - 1:         # sin marcas: en las pausas de la grabación...
		marks = auto_starts(parts, runs)
	if marks.size() == parts.size() - 1:
		for m: Variant in marks:
			starts.append(clampf(float(m), starts[-1], length))
	else:                                        # ...y si no se midió, a partes iguales por letras
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
		var line := "" if parts[i].begins_with(SFX_PREFIX) else parts[i]   # (lo que suena ya está en la grabación)
		_queue.append({"text": line, "voice": path if i == 0 else "", "seconds": maxf(end - starts[i], 0.3),
			"group": _groups, "last": last, "t0": starts[i], "t1": length - VOICE_PAD if last else starts[i + 1],
			"until": end, "runs": runs})


func _next() -> void:
	_group = 0
	if _queue.is_empty():
		_left = 0.0
		return
	var e: Dictionary = _queue.pop_front()
	_current = e
	if e.has("sfx"):
		_left = _duration(e)
		Sfx.play(String(e.sfx), 0.0)
		return
	var line := String(e.text)
	_left = _duration(e)
	_group = int(e.get("group", 0))
	if String(e.get("voice", "")) != "":
		_player.stream = load(String(e.voice))
		_player.play()
		_voice_t = 0.0
	if line == "":                               # un silencio, o una voz sin subtítulo
		return
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
	if not voiced():
		return ""
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
	_voice_t += delta
	if _left > 0.0:
		if _current.has("until") and _player.playing:   # con su grabación sonando, manda el reloj del audio
			_left = float(_current.until) - clock() + (GAP if bool(_current.get("last", true)) else 0.0)
		else:
			_left -= delta
		if _left <= 0.0:
			_next()
