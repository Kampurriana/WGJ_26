class_name UiTheme
extends RefCounted
## Aspecto de toda la interfaz (HUD y menús), construido en código. Desde el pulido con la
## referencia (Ooblets, la imagen del aviso de "badge"): letra redonda y gruesa (Fredoka, OFL, en
## ui/fuentes/), paneles azules translúcidos con borde claro y sombra, botones morados en forma de
## píldora con borde blanco y un canto oscuro debajo, cápsulas claras con texto violeta y títulos
## naranjas con contorno rosa y sombra. Si existe res://ui/theme.tres (hecho por las artistas en el
## editor), manda ese.

const FONT := preload("res://ui/fuentes/Fredoka-SemiBold.woff2")
const FONT_BOLD := preload("res://ui/fuentes/Fredoka-Bold.woff2")

# La paleta de la referencia.
const BLUE := Color(0.22, 0.36, 0.78)          ## paneles
const BLUE_DEEP := Color(0.1, 0.16, 0.42)      ## sombras y contornos oscuros
const PALE := Color(0.9, 0.95, 1.0)            ## cápsulas y bordes claros
const VIOLET := Color(0.33, 0.35, 0.85)        ## texto sobre las cápsulas
const PURPLE := Color(0.56, 0.38, 0.88)        ## botones
const ORANGE := Color(1.0, 0.74, 0.3)          ## títulos y lo que se destaca
const CORAL := Color(0.94, 0.42, 0.48)         ## contorno de los títulos
# Los nombres de antes (madera y papel), ya con los colores nuevos: así todo lo que los usa cambia.
const CREAM := Color(0.99, 0.98, 1.0)          ## texto claro
const PAPER := Color(0.22, 0.36, 0.78, 0.94)   ## fondo de los paneles
const INK := Color(0.99, 0.98, 1.0)            ## texto sobre los paneles (que ahora son azules)
const WOOD := Color(0.56, 0.38, 0.88)          ## botón
const WOOD_LIGHT := Color(0.64, 0.48, 0.94)    ## botón con el ratón encima
const WOOD_DARK := Color(0.36, 0.22, 0.66)     ## botón pulsado, canto de debajo
const CARD := Color(0.3, 0.46, 0.88)           ## paneles de dentro (páginas del álbum, franjas)

static var _theme: Theme
static var _floating: Theme


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	if ResourceLoader.exists("res://ui/theme.tres"):
		_theme = load("res://ui/theme.tres")
		return _theme
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = 20
	t.set_font("font", "Button", FONT_BOLD)
	t.set_stylebox("normal", "Button", _pill(WOOD, PALE, WOOD_DARK))
	t.set_stylebox("hover", "Button", _pill(WOOD_LIGHT, Color.WHITE, WOOD_DARK))
	t.set_stylebox("pressed", "Button", _pill(WOOD_DARK, PALE, Color(0, 0, 0, 0)))
	t.set_stylebox("hover_pressed", "Button", _pill(WOOD_DARK, Color.WHITE, Color(0, 0, 0, 0)))
	t.set_stylebox("disabled", "Button", _pill(Color(WOOD, 0.45), Color(PALE, 0.45), Color(0, 0, 0, 0)))
	t.set_stylebox("focus", "Button", _outline(ORANGE, 30))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "Button", CREAM)
	t.set_color("font_disabled_color", "Button", Color(CREAM, 0.6))
	var panel := _box(PAPER, 28, Color(PALE, 0.9), 0, 4, 26, 22)
	panel.shadow_color = Color(BLUE_DEEP, 0.35)
	panel.shadow_size = 14
	panel.shadow_offset = Vector2(0, 6)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_color("font_color", "Label", INK)
	# Bandeja de piezas: azul translúcido con borde claro; fichas apenas marcadas (lo que se ve es
	# la pieza, no la ficha). Flota a la derecha y se aparta al coger una pieza.
	t.set_type_variation("Bandeja", "PanelContainer")
	# Feedback: "recuadro semi-transparente" y "recuadros semi-transparentes con un borde blanco que
	# resalta el objeto".
	t.set_stylebox("panel", "Bandeja", _box(Color(0.16, 0.27, 0.62, 0.36), 24, Color(PALE, 0.6), 0, 2, 10, 12))
	t.set_type_variation("Ficha", "PanelContainer")
	t.set_stylebox("panel", "Ficha", _box(Color(1, 1, 1, 0.16), 16, Color(1, 1, 1, 0.92), 0, 3, 2, 2))
	# Subtítulos, consejos y tarjetas: azul oscuro translúcido, muy redondeado (las barras de la
	# referencia), para leerse sobre cualquier diorama.
	t.set_type_variation("Subtitulo", "PanelContainer")
	t.set_stylebox("panel", "Subtitulo", _box(Color(0.14, 0.21, 0.52, 0.84), 22, Color(PALE, 0.25), 0, 2, 20, 12))
	t.set_type_variation("SubtituloTexto", "Label")
	t.set_color("font_color", "SubtituloTexto", CREAM)
	# Interruptores: van sobre el panel, sin fondo; al pasar por encima, una franja suave.
	for type in ["CheckButton", "CheckBox"]:
		t.set_font("font", type, FONT)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(state, type, INK)
		for state in ["normal", "pressed", "disabled"]:
			t.set_stylebox(state, type, _box(Color(0, 0, 0, 0), 12, Color(0, 0, 0, 0), 0, 0, 8, 6))
		for state in ["hover", "hover_pressed"]:
			t.set_stylebox(state, type, _box(CARD, 12, Color(0, 0, 0, 0), 0, 0, 8, 6))
		t.set_stylebox("focus", type, _outline(ORANGE, 12))
	t.set_stylebox("slider", "HSlider", _box(Color(PALE, 0.35), 6, Color(0, 0, 0, 0), 0, 0, 0, 4))
	t.set_stylebox("grabber_area", "HSlider", _box(ORANGE, 6, ORANGE, 0, 0, 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(Color(1.0, 0.82, 0.45), 6, ORANGE, 0, 0, 0, 4))
	t.set_stylebox("background", "ProgressBar", _box(Color(1, 1, 1, 0.16), 6, Color(0, 0, 0, 0), 0, 0, 0, 0))
	t.set_stylebox("fill", "ProgressBar", _box(ORANGE, 6, ORANGE, 0, 0, 0, 0))
	_theme = t
	return t


## El tema de los menús que flotan sobre el diorama (el de inicio y sus opciones; feedback: "quitar
## este recuadro feo", "logo flotante, opciones flotantes en texto", como la referencia de Absolum):
## sin panel, y los botones son solo texto blanco con contorno azul que se pone naranja al pasar.
## La pausa conserva su recuadro (usa get_theme).
static func get_floating_theme() -> Theme:
	if _floating != null:
		return _floating
	var t := Theme.new()
	t.merge_with(get_theme())
	t.set_stylebox("panel", "PanelContainer", StyleBoxEmpty.new())
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(state, "Button", StyleBoxEmpty.new())
	t.set_font_size("font_size", "Button", 30)
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_focus_color", "Button", ORANGE)
	t.set_color("font_hover_color", "Button", ORANGE)
	t.set_color("font_pressed_color", "Button", ORANGE)
	t.set_color("font_hover_pressed_color", "Button", ORANGE)
	t.set_color("font_disabled_color", "Button", Color(CREAM, 0.45))
	t.set_color("font_outline_color", "Button", BLUE_DEEP)
	t.set_constant("outline_size", "Button", 9)
	for type in ["Label", "CheckButton"]:           # texto blanco sobre el pastel: con contorno se lee
		t.set_color("font_outline_color", type, BLUE_DEEP)
		t.set_constant("outline_size", type, 7)
	_floating = t
	return t


## Un título como los de la referencia: letra gruesa naranja, contorno rosa y sombra azul debajo.
static func style_title(l: Label, font_size: int) -> void:
	l.add_theme_font_override("font", FONT_BOLD)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", ORANGE)
	l.add_theme_color_override("font_outline_color", CORAL)
	l.add_theme_constant_override("outline_size", maxi(6, font_size / 5))
	l.add_theme_color_override("font_shadow_color", Color(BLUE_DEEP, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(3, font_size / 10))


## Una cápsula clara con texto violeta (el nombre de algo, como "COLLECTING I" en la referencia).
static func pill_box() -> StyleBoxFlat:
	return _box(Color(PALE, 0.96), 26, Color.WHITE, 0, 3, 24, 4)


## Botón en píldora: relleno, borde claro y, debajo, un canto más oscuro (se lee como algo que se pulsa).
static func _pill(bg: Color, border: Color, under: Color) -> StyleBoxFlat:
	var s := _box(bg, 40, border, 0, 4, 24, 10)
	if under.a > 0.0:
		s.shadow_color = under
		s.shadow_size = 1
		s.shadow_offset = Vector2(0, 5)
	s.anti_aliasing = true
	return s


## Caja redondeada. bottom = borde inferior más grueso (relieve de tablilla); width = borde general;
## margin_h / margin_v = relleno interior (en un HSlider, margin_v da el grosor de la barra).
static func _box(bg: Color, radius: int, border: Color, bottom := 0, width := 0, margin_h := 18.0, margin_v := 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(width)
	if bottom > 0:
		s.border_width_bottom = bottom
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	return s


static func _outline(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.set_corner_radius_all(radius)
	s.border_color = color
	s.set_border_width_all(3)
	s.expand_margin_left = 3
	s.expand_margin_right = 3
	s.expand_margin_top = 3
	s.expand_margin_bottom = 3
	return s
