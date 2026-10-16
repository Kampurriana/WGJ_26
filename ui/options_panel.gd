class_name OptionsPanel
extends VBoxContainer
## Las Opciones (en el menú de inicio y en la pausa). Cada control escribe en Settings al momento
## (se oye y se ve el cambio); Settings lo guarda en disco medio segundo después del último cambio.

const SLIDERS := [
	["volumen_general", "Volumen general", 0.0, 1.0],
	["volumen_musica", "Música", 0.0, 1.0],
	["volumen_efectos", "Efectos", 0.0, 1.0],
	["volumen_voz", "Voz del narrador", 0.0, 1.0],
	["sensibilidad_camara", "Giro de cámara", 0.3, 2.0],
]
const TOGGLES := [
	["subtitulos", "Subtítulos"],
	["pantalla_completa", "Pantalla completa"],
	["invertir_y", "Invertir eje vertical"],
	["ayuda_automatica", "Pista automática si te atascas"],
]
const RESET_CONFIRM_TIME := 3.0

var controls: Dictionary = {}               ## clave de Settings -> HSlider o CheckButton
var reset_button: Button
var _reset_armed := 0.0


## show_reset: el botón "Borrar progreso" solo tiene sentido en el menú de inicio.
func _init(show_reset := true) -> void:
	add_theme_constant_override("separation", 6)
	for s: Array in SLIDERS:
		_add_slider(s[0], s[1], s[2], s[3])
	for t: Array in TOGGLES:
		_add_toggle(t[0], t[1])
	if show_reset:
		reset_button = Button.new()
		reset_button.text = "Borrar progreso"
		reset_button.pressed.connect(_on_reset)
		add_child(reset_button)


## Vuelve a leer los valores (por si cambiaron desde la otra pantalla de opciones).
func refresh() -> void:
	for key: String in controls:
		var c: Control = controls[key]
		if c is Range:
			(c as Range).set_value_no_signal(Settings.get_value(key))
		else:
			(c as BaseButton).set_pressed_no_signal(Settings.get_value(key))
	if reset_button != null:
		_reset_armed = 0.0
		reset_button.text = "Borrar progreso"
		reset_button.disabled = not (GameState.has_progress() or GameState.menu_unlocked)


func _add_slider(key: String, label: String, lo: float, hi: float) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(190, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = Settings.get_value(key)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(150, 24)
	s.value_changed.connect(func(v: float) -> void: Settings.set_value(key, v))
	row.add_child(s)
	add_child(row)
	controls[key] = s


func _add_toggle(key: String, label: String) -> void:
	var c := CheckButton.new()
	c.text = label
	c.button_pressed = Settings.get_value(key)
	c.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	add_child(c)
	controls[key] = c


## Dos pulsaciones: la primera pregunta, la segunda borra. Sin ventanas emergentes.
func _on_reset() -> void:
	if _reset_armed > 0.0:
		_reset_armed = 0.0
		GameState.reset_progress()
		reset_button.text = "Progreso borrado"
		reset_button.disabled = true
	else:
		_reset_armed = RESET_CONFIRM_TIME
		reset_button.text = "¿Seguro? Pulsa otra vez"


func _process(delta: float) -> void:
	if _reset_armed > 0.0:
		_reset_armed -= delta
		if _reset_armed <= 0.0:
			reset_button.text = "Borrar progreso"
