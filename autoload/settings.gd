extends Node
## Ajustes del jugador (las Opciones del menú), guardados en user://ajustes.cfg.
## Los buses de audio Musica, Efectos y Voz (colgando de Master) están en default_bus_layout.tres: en la
## Web, el audio por muestras (el de Godot por defecto allí) solo conoce los buses del fichero; los creados
## en código al arrancar no sonaban (18-oct, medido en Chromium). Si faltara alguno, se crea aquí. Aplica
## cada ajuste en cuanto cambia. Con --capture en la línea de comandos no lee ni escribe disco:
## las capturas salen siempre con los valores por defecto.
## El idioma: el español es el original (los textos del código y la voz); el inglés va sin voz, con
## subtítulos (data/narracion_en.json) y la interfaz traducida desde data/ui_en.json.

signal changed(key: String)

const BUSES := ["Musica", "Efectos", "Voz"]
const SECTION := "ajustes"
const SAVE_DELAY := 0.5                  ## segundos sin cambios antes de escribir (un deslizador manda muchos)
const DEFAULTS := {
	"volumen_general": 0.8,
	"volumen_musica": 0.7,
	"volumen_efectos": 0.8,
	"volumen_voz": 0.9,
	"subtitulos": true,
	"pantalla_completa": false,
	"sensibilidad_camara": 1.0,
	"invertir_y": false,
	"ayuda_automatica": true,
	"fondo_color": 0,                    # ui/fondos.gd: qué color pastel tiene el fondo
	"fondo_motivo": 0,                   # y qué motivo se repite en él
	"idioma": "",                        # "es", "en" o "" = el del sistema
}
const LANGUAGES := ["es", "en"]
const UI_TEXTS := "res://data/ui_%s.json"   ## clave = el texto en español del código
const VOLUME_BUS := {
	"volumen_general": "Master",
	"volumen_musica": "Musica",
	"volumen_efectos": "Efectos",
	"volumen_voz": "Voz",
}

var path := "user://ajustes.cfg"         ## "" = solo en memoria
var _values: Dictionary = {}
var _save_in := -1.0
var _system_language := "es"
var music_duck_db := 0.0                     ## lo que baja la música mientras habla una voz (Sfx.duck)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, &"Master")
	_system_language = _detect_language()
	for lang: String in LANGUAGES:
		_load_translation(lang)
	load_from("" if _capturing() else path)


## El idioma en que sale todo: el elegido en Opciones o, si no, el del sistema.
func language() -> String:
	var chosen := String(_values.get("idioma", ""))
	return chosen if chosen != "" else _system_language


## Español si el sistema (o el navegador) está en español; si no, inglés. Las capturas, en español
## salvo que se pida otro con --idioma=en.
## (Tests) Fija el idioma "del sistema": la máquina de pruebas puede estar en inglés.
func set_system_language(lang: String) -> void:
	var before := language()
	_system_language = lang
	_apply("idioma")
	if language() != before:
		changed.emit("idioma")


## Un fichero en el idioma de ahora ("res://data/creditos_%s.txt"); si no existe, el español.
func localized(pattern: String) -> String:
	var file := pattern % language()
	return file if FileAccess.file_exists(file) else pattern % "es"


func _detect_language() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--idioma=") and LANGUAGES.has(a.trim_prefix("--idioma=")):
			return a.trim_prefix("--idioma=")
	if _capturing():
		return "es"
	return "es" if OS.get_locale_language() == "es" else "en"


func _load_translation(lang: String) -> void:
	var file := UI_TEXTS % lang
	if not FileAccess.file_exists(file):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not data is Dictionary:
		push_error("Settings: %s no es un objeto JSON" % file)
		return
	var t := Translation.new()
	t.locale = lang
	for key: String in data:
		if not key.begins_with("_"):
			t.add_message(key, String(data[key]))
	TranslationServer.add_translation(t)


static func _capturing() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			return true
	return false


## Cambia de fichero y lo lee (los tests usan uno suyo). Lo que falte o no cuadre, por defecto.
func load_from(file: String) -> void:
	var before := language() if not _values.is_empty() else ""
	path = file
	_save_in = -1.0
	_values = DEFAULTS.duplicate()
	if file != "" and FileAccess.file_exists(file):
		var cfg := ConfigFile.new()
		var err := cfg.load(file)
		if err != OK:
			push_warning("Settings: no puedo leer %s (err %d): uso los valores por defecto" % [file, err])
		else:
			for key: String in DEFAULTS:
				if cfg.has_section_key(SECTION, key):
					_values[key] = _coerce(key, cfg.get_value(SECTION, key))
	for key: String in _values:
		_apply(key)
	if before != "" and language() != before:   # el narrador y la interfaz cambian de idioma
		changed.emit("idioma")


func get_value(key: String) -> Variant:
	if not DEFAULTS.has(key):
		push_error("Settings: no existe el ajuste '%s'" % key)
		return null
	return _values[key]


func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		push_error("Settings: no existe el ajuste '%s'" % key)
		return
	_values[key] = _coerce(key, value)
	_apply(key)
	_save_in = SAVE_DELAY
	changed.emit(key)


## Escribe ya (al salir de Opciones, en tests). Devuelve el error de ConfigFile.save.
func save_now() -> int:
	_save_in = -1.0
	if path == "":
		return OK
	var cfg := ConfigFile.new()
	for key: String in _values:
		cfg.set_value(SECTION, key, _values[key])
	var err := cfg.save(path)
	if err != OK:
		push_warning("Settings: no puedo guardar %s (err %d)" % [path, err])
	return err


func _process(delta: float) -> void:
	if _save_in < 0.0:
		return
	_save_in -= delta
	if _save_in < 0.0:
		save_now()


func _coerce(key: String, value: Variant) -> Variant:
	if DEFAULTS[key] is String:
		return String(value) if LANGUAGES.has(String(value)) else ""
	if DEFAULTS[key] is bool:
		return bool(value)
	if DEFAULTS[key] is int:
		return clampi(int(value), 0, 15)
	return clampf(float(value), 0.0, 2.0)


## (Sfx.duck) La música, `db` por debajo de su volumen: va en el volumen del bus, no en un efecto (en la
## Web, el audio por muestras no aplica los efectos de los buses).
func set_music_duck(db: float) -> void:
	music_duck_db = db
	_apply("volumen_musica")


func _apply(key: String) -> void:
	var v: Variant = _values[key]
	if VOLUME_BUS.has(key):
		var i := AudioServer.get_bus_index(VOLUME_BUS[key])
		AudioServer.set_bus_mute(i, float(v) <= 0.001)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(float(v), 0.001)) + (music_duck_db if key == "volumen_musica" else 0.0))
	elif key == "idioma":
		TranslationServer.set_locale(language())
	elif key == "pantalla_completa" and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED)
