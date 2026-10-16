extends Node
## Ajustes del jugador (las Opciones del menú), guardados en user://ajustes.cfg.
## Crea en código los buses de audio Musica, Efectos y Voz (colgando de Master) y aplica cada
## ajuste en cuanto cambia. Con --capture en la línea de comandos no lee ni escribe disco:
## las capturas salen siempre con los valores por defecto.

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
}
const VOLUME_BUS := {
	"volumen_general": "Master",
	"volumen_musica": "Musica",
	"volumen_efectos": "Efectos",
	"volumen_voz": "Voz",
}

var path := "user://ajustes.cfg"         ## "" = solo en memoria
var _values: Dictionary = {}
var _save_in := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, &"Master")
	load_from("" if _capturing() else path)


static func _capturing() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			return true
	return false


## Cambia de fichero y lo lee (los tests usan uno suyo). Lo que falte o no cuadre, por defecto.
func load_from(file: String) -> void:
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
	if DEFAULTS[key] is bool:
		return bool(value)
	return clampf(float(value), 0.0, 2.0)


func _apply(key: String) -> void:
	var v: Variant = _values[key]
	if VOLUME_BUS.has(key):
		var i := AudioServer.get_bus_index(VOLUME_BUS[key])
		AudioServer.set_bus_mute(i, float(v) <= 0.001)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(float(v), 0.001)))
	elif key == "pantalla_completa" and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED)
