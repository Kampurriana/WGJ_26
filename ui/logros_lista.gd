class_name LogrosLista
extends VBoxContainer
## La lista de logros (en la pausa y en el menú de inicio): una fila por logro, con su medalla
## (naranja con estrella si está conseguido; gris con "?" si no), su nombre y qué hay que hacer.

var rows: Array[Control] = []                ## (tests) una por logro, en orden de Logros.LISTA


func _init() -> void:
	add_theme_constant_override("separation", 8)


func refresh() -> void:
	for r in rows:
		r.queue_free()
	rows.clear()
	for l: Dictionary in Logros.LISTA:
		var got := Logros.is_unlocked(l.id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.modulate.a = 1.0 if got else 0.6
		row.set_meta(&"conseguido", got)
		var medal := Medalla.new()
		medal.got = got
		row.add_child(medal)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var title := Label.new()
		title.text = l.nombre
		title.add_theme_font_override("font", UiTheme.FONT_BOLD)
		title.add_theme_font_size_override("font_size", 19)
		col.add_child(title)
		var text := Label.new()
		text.text = l.texto
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(260, 0)
		text.add_theme_font_size_override("font_size", 15)
		col.add_child(text)
		add_child(row)
		rows.append(row)


## La medalla de un logro, dibujada: círculo naranja con una estrella, o gris con "?".
class Medalla extends Control:
	var got := false

	func _init() -> void:
		custom_minimum_size = Vector2(40, 40)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c + Vector2(0, 2), 18.0, Color(UiTheme.BLUE_DEEP, 0.35))
		draw_circle(c, 18.0, UiTheme.ORANGE if got else Color(0.62, 0.65, 0.75))
		draw_arc(c, 18.0, 0.0, TAU, 32, Color.WHITE, 2.5, true)
		if got:
			var pts := PackedVector2Array()
			for k in 10:
				var r := 10.0 if k % 2 == 0 else 4.2
				var a := -PI * 0.5 + k * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, Color.WHITE)
		else:
			draw_string(UiTheme.FONT_BOLD, c + Vector2(-5, 7), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
