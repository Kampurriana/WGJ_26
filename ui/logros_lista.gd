class_name LogrosLista
extends VBoxContainer
## Los logros (en la pausa y en el menú de inicio), más visual (feedback): arriba cuántos llevas,
## con su barra; debajo, una tarjeta por logro en dos columnas, con su medalla grande (naranja con
## estrella si está conseguido, con su cinta; gris con "?" si no), su nombre y qué hay que hacer.
## Los secretos (Logros.is_secret) no dicen qué hay que hacer hasta conseguirlos.

const GOLD := Color(1.0, 0.8, 0.22)

var rows: Array[Control] = []                ## (tests) una tarjeta por logro, en orden de Logros.LISTA
var _count: Label
var _bar: ProgressBar
var _grid: GridContainer


func _init() -> void:
	add_theme_constant_override("separation", 10)
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", UiTheme._box(Color(UiTheme.BLUE_DEEP, 0.45), 18, Color(UiTheme.PALE, 0.5), 0, 2, 16, 8))
	add_child(head)
	var head_col := VBoxContainer.new()
	head_col.add_theme_constant_override("separation", 6)
	head.add_child(head_col)
	_count = Label.new()
	_count.add_theme_font_override("font", UiTheme.FONT_BOLD)
	_count.add_theme_font_size_override("font_size", 17)
	_count.add_theme_color_override("font_color", Color.WHITE)
	_count.add_theme_constant_override("outline_size", 0)
	head_col.add_child(_count)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 10)
	_bar.max_value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.25)
	bg.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(5)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fill)
	head_col.add_child(_bar)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	add_child(_grid)


func refresh() -> void:
	for r in rows:
		r.queue_free()
	rows.clear()
	var got_count := 0
	for l: Dictionary in Logros.LISTA:
		var got := Logros.is_unlocked(l.id)
		got_count += 1 if got else 0
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", UiTheme._box(Color(1.0, 0.97, 0.88, 0.97), 18, GOLD, 0, 3, 10, 10) if got
			else UiTheme._box(Color(1, 1, 1, 0.5), 18, Color(1, 1, 1, 0.75), 0, 2, 10, 10))
		card.set_meta(&"conseguido", got)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		card.add_child(col)
		var medal := Medalla.new(27.0)
		medal.got = got
		medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(medal)
		var title := Label.new()
		title.text = l.nombre
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_override("font", UiTheme.FONT_BOLD)
		title.add_theme_font_size_override("font_size", 16)
		title.add_theme_color_override("font_color", UiTheme.BLUE_DEEP if got else Color(UiTheme.BLUE_DEEP, 0.75))
		title.add_theme_constant_override("outline_size", 0)
		col.add_child(title)
		var text := Label.new()
		var hidden := Logros.is_secret(l.id) and not got
		text.text = "Logro secreto: descúbrelo jugando." if hidden else l.texto
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(150, 0)
		text.add_theme_font_size_override("font_size", 13)
		text.add_theme_color_override("font_color", Color(UiTheme.BLUE_DEEP, 0.55 if hidden else 0.8))
		text.add_theme_constant_override("outline_size", 0)
		col.add_child(text)
		card.set_meta(&"texto", text.text)
		_grid.add_child(card)
		rows.append(card)
	_count.text = tr("Conseguidos: %d de %d") % [got_count, Logros.LISTA.size()]
	_bar.value = float(got_count) / maxf(1.0, Logros.LISTA.size())


## La medalla de un logro, dibujada: círculo naranja con una estrella y su cinta, o gris con "?".
class Medalla extends Control:
	var got := false
	var radius := 18.0

	func _init(r := 18.0) -> void:
		radius = r
		custom_minimum_size = Vector2(r * 2.0 + 6.0, r * 2.0 + (14.0 if r > 20.0 else 4.0))
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, radius + 2.0)
		if got and radius > 20.0:                    # la cinta, por detrás
			for side: float in [-1.0, 1.0]:
				var x := c.x + side * radius * 0.35
				draw_colored_polygon(PackedVector2Array([Vector2(x - 6, c.y), Vector2(x + 6, c.y),
					Vector2(x + 6 + side * 3.0, size.y), Vector2(x + side * 3.0, size.y - 5), Vector2(x - 6 + side * 3.0, size.y)]),
					UiTheme.CORAL)
		draw_circle(c + Vector2(0, 2), radius, Color(UiTheme.BLUE_DEEP, 0.35))
		draw_circle(c, radius, UiTheme.ORANGE if got else Color(0.62, 0.65, 0.75))
		draw_arc(c, radius, 0.0, TAU, 40, Color.WHITE, 2.5 if radius < 20.0 else 3.5, true)
		if got:
			var pts := PackedVector2Array()
			for k in 10:
				var r := radius * (0.56 if k % 2 == 0 else 0.23)
				var a := -PI * 0.5 + k * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, Color.WHITE)
		else:
			var fs := int(radius * 1.1)
			draw_string(UiTheme.FONT_BOLD, c + Vector2(-fs * 0.27, fs * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
