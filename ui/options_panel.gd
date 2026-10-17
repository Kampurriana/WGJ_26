class_name OptionsPanel
extends VBoxContainer
## Las Opciones (en el menú de inicio y en la pausa). Cada control escribe en Settings al momento
## (se oye y se ve el cambio); Settings lo guarda en disco medio segundo después del último cambio.
## El fondo (quinta nota): una fila de muestras de color y otra de motivos (ui/fondos.gd); se ve el
## cambio detrás del menú en cuanto se toca.
## Por pestañas (pulido con la referencia de Ooblets, que agrupa sus ajustes): Fondo, Sonido y Juego,
## en una barra en forma de cápsula. Dentro, cada grupo de ajustes va en su TARJETA con su título
## (feedback: "resáltalas por secciones para que quede más unificado y no parezca información
## flotando"): Color y Motivo; Volumen y Texto; Cámara, Pantalla y ayuda, Progreso.

const TABS := ["Fondo", "Sonido", "Juego"]
## [clave, texto, mínimo, máximo, pestaña, sección]
const SLIDERS := [
	["volumen_general", "General", 0.0, 1.0, 1, "Volumen"],
	["volumen_musica", "Música", 0.0, 1.0, 1, "Volumen"],
	["volumen_efectos", "Efectos", 0.0, 1.0, 1, "Volumen"],
	["volumen_voz", "Voz del narrador", 0.0, 1.0, 1, "Volumen"],
	["sensibilidad_camara", "Giro de cámara", 0.3, 2.0, 2, "Cámara"],
]
## [clave, texto, pestaña, sección]
const TOGGLES := [
	["subtitulos", "Subtítulos", 1, "Texto"],
	["invertir_y", "Invertir eje vertical", 2, "Cámara"],
	["pantalla_completa", "Pantalla completa", 2, "Pantalla y ayuda"],
	["ayuda_automatica", "Pista automática si te atascas", 2, "Pantalla y ayuda"],
]
const LABEL_WIDTH := 150.0                   ## los textos de las filas, todos del mismo ancho (alineados)
const RESET_CONFIRM_TIME := 3.0

var controls: Dictionary = {}               ## clave de Settings -> HSlider o CheckButton
var swatches: Array[Button] = []            ## una muestra por color de fondo (Fondos.COLORES)
var motifs: Array[Button] = []              ## un botón por motivo (Fondos.MOTIVOS)
var reset_button: Button
var tabs: Array[Button] = []                 ## las pestañas (Fondo, Sonido, Juego)
var pages: Array[VBoxContainer] = []         ## lo de cada pestaña
var tab := 0
var _reset_armed := 0.0
var _sections: Dictionary = {}               ## "pestaña/título" -> lo de dentro de su tarjeta


## show_reset: el botón "Borrar progreso" solo tiene sentido en el menú de inicio.
func _init(show_reset := true) -> void:
	add_theme_constant_override("separation", 12)
	var bar := PanelContainer.new()              # las pestañas, juntas en una cápsula
	bar.add_theme_stylebox_override("panel", UiTheme._box(Color(UiTheme.BLUE_DEEP, 0.45), 24, Color(UiTheme.PALE, 0.5), 0, 2, 6, 5))
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	bar.add_child(row)
	var group := ButtonGroup.new()
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pill_style(b, 18)
		b.pressed.connect(show_tab.bind(i))
		row.add_child(b)
		tabs.append(b)
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 10)
		add_child(page)
		pages.append(page)
	_add_background()                            # lo primero: es lo que más se nota al cambiarlo
	for s: Array in SLIDERS:
		_add_slider(_section(s[4], s[5]), s[0], s[1], s[2], s[3])
	for t: Array in TOGGLES:
		_add_toggle(_section(t[2], t[3]), t[0], t[1])
	if show_reset:
		reset_button = Button.new()
		reset_button.text = "Borrar progreso"
		reset_button.add_theme_font_size_override("font_size", 17)
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			reset_button.add_theme_stylebox_override(state, UiTheme._box(Color(UiTheme.CORAL, 0.9 if state != "hover" else 1.0), 18, Color.WHITE, 0, 2, 16, 6))
		reset_button.add_theme_stylebox_override("disabled", UiTheme._box(Color(UiTheme.CORAL, 0.35), 18, Color(1, 1, 1, 0.4), 0, 2, 16, 6))
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			reset_button.add_theme_color_override(state, Color.WHITE)
		reset_button.add_theme_constant_override("outline_size", 0)
		reset_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		reset_button.pressed.connect(_on_reset)
		_section(2, "Progreso").add_child(reset_button)
	show_tab(0)


## La tarjeta de una sección (en su pestaña), con su título; la crea la primera vez. Devuelve dónde
## van sus filas.
func _section(i: int, title: String) -> VBoxContainer:
	var key := "%d/%s" % [i, title]
	if _sections.has(key):
		return _sections[key]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme._box(Color(0.16, 0.27, 0.62, 0.5), 18, Color(UiTheme.PALE, 0.7), 0, 2, 16, 10))
	var calm := Theme.new()                      # dentro de la tarjeta el fondo ya da contraste: sin contorno
	calm.set_constant("outline_size", "Label", 0)
	calm.set_constant("outline_size", "CheckButton", 0)
	for state in ["normal", "pressed", "disabled", "focus"]:   # interruptores alineados con los textos
		calm.set_stylebox(state, "CheckButton", UiTheme._box(Color(0, 0, 0, 0), 10, Color(0, 0, 0, 0), 0, 0, 0, 4))
	for state in ["hover", "hover_pressed"]:
		calm.set_stylebox(state, "CheckButton", UiTheme._box(Color(1, 1, 1, 0.1), 10, Color(0, 0, 0, 0), 0, 0, 0, 4))
	card.theme = calm
	pages[i].add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	var head := Label.new()
	head.text = title.to_upper()
	head.add_theme_font_override("font", UiTheme.FONT_BOLD)
	head.add_theme_font_size_override("font_size", 13)
	head.add_theme_color_override("font_color", UiTheme.ORANGE)
	col.add_child(head)
	_sections[key] = col
	return col


## Botón en cápsula pequeña: transparente; elegido, morado con borde blanco (pestañas y motivos).
static func _pill_style(b: Button, font_size: int) -> void:
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_constant_override("outline_size", 0)
	b.add_theme_stylebox_override("normal", UiTheme._box(Color(1, 1, 1, 0.08), 18, Color(1, 1, 1, 0.0), 0, 0, 12, 5))
	b.add_theme_stylebox_override("hover", UiTheme._box(Color(1, 1, 1, 0.2), 18, Color(1, 1, 1, 0.0), 0, 0, 12, 5))
	for state: String in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, UiTheme._box(UiTheme.PURPLE, 18, Color.WHITE, 0, 2, 12, 5))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, Color.WHITE)


## Enseña una pestaña (0 Fondo, 1 Sonido, 2 Juego).
## Las pestañas no se mueven; las tarjetas de la elegida se despliegan hacia abajo, una tras otra.
func show_tab(i: int) -> void:
	var changed := clampi(i, 0, pages.size() - 1) != tab
	tab = clampi(i, 0, pages.size() - 1)
	for k in pages.size():
		pages[k].visible = k == tab
		tabs[k].set_pressed_no_signal(k == tab)
	if changed and is_inside_tree():
		var n := 0
		for card in pages[tab].get_children():
			Juice.unfold(card as Control, n * 0.06)
			n += 1


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
	l.add_theme_font_size_override("font_size", 17)
	l.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
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
	c.add_theme_font_size_override("font_size", 17)
	c.button_pressed = Settings.get_value(key)
	c.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	parent.add_child(c)
	controls[key] = c


## El fondo: muestras de color (redondas, la elegida con borde) y botones de motivo.
func _add_background() -> void:
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
	_section(0, "Color").add_child(colors)
	var shapes := HBoxContainer.new()
	shapes.add_theme_constant_override("separation", 6)
	var shape_group := ButtonGroup.new()
	for i in Fondos.MOTIVOS.size():
		var b := Button.new()
		b.text = Fondos.MOTIVOS[i].nombre
		b.toggle_mode = true
		b.button_group = shape_group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pill_style(b, 15)
		b.button_pressed = i == int(Settings.get_value("fondo_motivo"))
		b.pressed.connect(func() -> void: Settings.set_value("fondo_motivo", i))
		shapes.add_child(b)
		motifs.append(b)
	_section(0, "Motivo").add_child(shapes)


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
