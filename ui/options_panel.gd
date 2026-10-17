class_name OptionsPanel
extends VBoxContainer
## Las Opciones (en el menú de inicio y en la pausa). Cada control escribe en Settings al momento
## (se oye y se ve el cambio); Settings lo guarda en disco medio segundo después del último cambio.
## El fondo (quinta nota): una fila de muestras de color y otra de motivos (ui/fondos.gd); se ve el
## cambio detrás del menú en cuanto se toca.
## Por pestañas (pulido con la referencia de Ooblets, que agrupa sus ajustes): Fondo, Sonido y Juego.

const TABS := ["Fondo", "Sonido", "Juego"]
## [clave, texto, mínimo, máximo, pestaña]
const SLIDERS := [
	["volumen_general", "Volumen general", 0.0, 1.0, 1],
	["volumen_musica", "Música", 0.0, 1.0, 1],
	["volumen_efectos", "Efectos", 0.0, 1.0, 1],
	["volumen_voz", "Voz del narrador", 0.0, 1.0, 1],
	["sensibilidad_camara", "Giro de cámara", 0.3, 2.0, 2],
]
## [clave, texto, pestaña]
const TOGGLES := [
	["subtitulos", "Subtítulos", 1],
	["pantalla_completa", "Pantalla completa", 2],
	["invertir_y", "Invertir eje vertical", 2],
	["ayuda_automatica", "Pista automática si te atascas", 2],
]
const RESET_CONFIRM_TIME := 3.0

var controls: Dictionary = {}               ## clave de Settings -> HSlider o CheckButton
var swatches: Array[Button] = []            ## una muestra por color de fondo (Fondos.COLORES)
var motifs: Array[Button] = []              ## un botón por motivo (Fondos.MOTIVOS)
var reset_button: Button
var tabs: Array[Button] = []                 ## las pestañas (Fondo, Sonido, Juego)
var pages: Array[VBoxContainer] = []         ## lo de cada pestaña
var tab := 0
var _reset_armed := 0.0


## show_reset: el botón "Borrar progreso" solo tiene sentido en el menú de inicio.
func _init(show_reset := true) -> void:
	add_theme_constant_override("separation", 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	var group := ButtonGroup.new()
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(show_tab.bind(i))
		row.add_child(b)
		tabs.append(b)
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 6)
		page.custom_minimum_size = Vector2(0, 230)        # las tres del mismo alto: el panel no salta
		add_child(page)
		pages.append(page)
	_add_background(pages[0])                    # lo primero: es lo que más se nota al cambiarlo
	for s: Array in SLIDERS:
		_add_slider(pages[s[4]], s[0], s[1], s[2], s[3])
	for t: Array in TOGGLES:
		_add_toggle(pages[t[2]], t[0], t[1])
	if show_reset:
		reset_button = Button.new()
		reset_button.text = "Borrar progreso"
		reset_button.pressed.connect(_on_reset)
		pages[2].add_child(reset_button)
	show_tab(0)


## Enseña una pestaña (0 Fondo, 1 Sonido, 2 Juego).
func show_tab(i: int) -> void:
	tab = clampi(i, 0, pages.size() - 1)
	for k in pages.size():
		pages[k].visible = k == tab
		tabs[k].set_pressed_no_signal(k == tab)


## Vuelve a leer los valores (por si cambiaron desde la otra pantalla de opciones).
func refresh() -> void:
	for key: String in controls:
		var c: Control = controls[key]
		if c is Range:
			(c as Range).set_value_no_signal(Settings.get_value(key))
		else:
			(c as BaseButton).set_pressed_no_signal(Settings.get_value(key))
	for i in swatches.size():
		swatches[i].set_pressed_no_signal(i == int(Settings.get_value("fondo_color")))
	for i in motifs.size():
		motifs[i].set_pressed_no_signal(i == int(Settings.get_value("fondo_motivo")))
	if reset_button != null:
		_reset_armed = 0.0
		reset_button.text = "Borrar progreso"
		reset_button.disabled = not (GameState.has_progress() or GameState.menu_unlocked)


func _add_slider(parent: Control, key: String, label: String, lo: float, hi: float) -> void:
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
	parent.add_child(row)
	controls[key] = s


func _add_toggle(parent: Control, key: String, label: String) -> void:
	var c := CheckButton.new()
	c.text = label
	c.button_pressed = Settings.get_value(key)
	c.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	parent.add_child(c)
	controls[key] = c


## El fondo: muestras de color (redondas, la elegida con borde) y botones de motivo.
func _add_background(parent: Control) -> void:
	var title := Label.new()
	title.text = "Color"
	parent.add_child(title)
	var colors := HBoxContainer.new()
	colors.add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()
	for i in Fondos.COLORES.size():
		var c: Dictionary = Fondos.COLORES[i]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(38, 38)
		b.tooltip_text = c.nombre
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			b.add_theme_stylebox_override(state, _swatch(c.centro, state.contains("pressed"), state.begins_with("hover")))
		b.button_pressed = i == int(Settings.get_value("fondo_color"))
		b.pressed.connect(func() -> void: Settings.set_value("fondo_color", i))
		colors.add_child(b)
		swatches.append(b)
	parent.add_child(colors)
	var motif_title := Label.new()
	motif_title.text = "Motivo"
	parent.add_child(motif_title)
	var shapes := HBoxContainer.new()
	shapes.add_theme_constant_override("separation", 6)
	var shape_group := ButtonGroup.new()
	for i in Fondos.MOTIVOS.size():
		var b := Button.new()
		b.text = Fondos.MOTIVOS[i].nombre
		b.toggle_mode = true
		b.button_group = shape_group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 15)
		b.button_pressed = i == int(Settings.get_value("fondo_motivo"))
		b.pressed.connect(func() -> void: Settings.set_value("fondo_motivo", i))
		shapes.add_child(b)
		motifs.append(b)
	parent.add_child(shapes)


static func _swatch(color: Color, selected: bool, hover: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(19)
	sb.set_border_width_all(4 if selected else 2)
	sb.border_color = UiTheme.WOOD_DARK if selected else Color(UiTheme.INK, 0.45 if hover else 0.22)
	return sb


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
