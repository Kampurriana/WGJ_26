class_name UiTheme
extends RefCounted
## Aspecto de toda la interfaz (HUD y menús), construido en código: tablillas de madera sobre
## papel crema. Si existe res://ui/theme.tres (hecho por las artistas en el editor), manda ese.

const CREAM := Color(0.98, 0.94, 0.86)
const PAPER := Color(0.98, 0.94, 0.86, 0.94)
const INK := Color(0.29, 0.2, 0.13)
const WOOD := Color(0.56, 0.37, 0.22)
const WOOD_LIGHT := Color(0.66, 0.45, 0.27)
const WOOD_DARK := Color(0.42, 0.27, 0.16)
const CARD := Color(0.91, 0.85, 0.74)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	if ResourceLoader.exists("res://ui/theme.tres"):
		_theme = load("res://ui/theme.tres")
		return _theme
	var t := Theme.new()
	t.default_font_size = 20
	t.set_stylebox("normal", "Button", _box(WOOD, 12, WOOD_DARK, 4))
	t.set_stylebox("hover", "Button", _box(WOOD_LIGHT, 12, WOOD_DARK, 4))
	t.set_stylebox("pressed", "Button", _box(WOOD_DARK, 12, WOOD_DARK, 0))
	t.set_stylebox("disabled", "Button", _box(Color(WOOD, 0.45), 12, Color(WOOD_DARK, 0.45), 4))
	t.set_stylebox("focus", "Button", _outline(CREAM, 12))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "Button", CREAM)
	t.set_color("font_disabled_color", "Button", Color(CREAM, 0.6))
	t.set_stylebox("panel", "PanelContainer", _box(PAPER, 18, WOOD, 0, 3, 22, 22))
	t.set_color("font_color", "Label", INK)
	# Fichas del panel de piezas: un poco más oscuras que el papel para que se separen.
	t.set_type_variation("Ficha", "PanelContainer")
	t.set_stylebox("panel", "Ficha", _box(CARD, 12, WOOD, 0, 2, 4, 4))
	# Subtítulos: oscuros y translúcidos, para leerse sobre cualquier diorama.
	t.set_type_variation("Subtitulo", "PanelContainer")
	t.set_stylebox("panel", "Subtitulo", _box(Color(0.18, 0.12, 0.08, 0.78), 14, Color(0, 0, 0, 0), 0, 0, 18, 12))
	t.set_type_variation("SubtituloTexto", "Label")
	t.set_color("font_color", "SubtituloTexto", CREAM)
	# Interruptores: heredarían la tablilla de Button (texto oscuro sobre madera = ilegible).
	# Van sobre el papel, sin fondo; al pasar por encima, una franja suave.
	for type in ["CheckButton", "CheckBox"]:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(state, type, INK)
		for state in ["normal", "pressed", "disabled"]:
			t.set_stylebox(state, type, _box(Color(0, 0, 0, 0), 8, Color(0, 0, 0, 0), 0, 0, 8, 6))
		for state in ["hover", "hover_pressed"]:
			t.set_stylebox(state, type, _box(CARD, 8, Color(0, 0, 0, 0), 0, 0, 8, 6))
		t.set_stylebox("focus", type, _outline(WOOD, 8))
	t.set_stylebox("slider", "HSlider", _box(CARD, 4, WOOD, 0, 1, 0, 4))
	t.set_stylebox("grabber_area", "HSlider", _box(WOOD, 4, WOOD, 0, 0, 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(WOOD_LIGHT, 4, WOOD, 0, 0, 0, 4))
	t.set_stylebox("background", "ProgressBar", _box(Color(CARD, 0.9), 4, WOOD, 0, 1, 0, 0))
	t.set_stylebox("fill", "ProgressBar", _box(WOOD, 4, WOOD, 0, 0, 0, 0))
	_theme = t
	return t


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
