class_name Creditos
extends CanvasLayer
## Los créditos del final (cuarta nota: la hucha → transición → créditos). Sobre el fondo pastel del
## juego (con sus estrellas) sube despacio el texto de data/creditos_es.txt, con el nombre del juego arriba y los
## dibujos que se encontraron (los que faltan, en hueco). El último renglón ("¡Gracias por jugar!")
## se queda en el centro y todo se funde a negro. Un clic o Esc lo acaban antes. Al acabar avisa
## (finished): main vuelve al menú, con el cerdito y sin frases.
## En el texto: renglón vacío = espacio; renglón en MAYÚSCULAS = encabezado; el resto, nombres.

signal finished

const CREDITS_PATH := "res://data/creditos_es.txt"
const SPEED := 46.0                          ## lo que sube, en px por segundo (a 720 de alto)
const HOLD := 3.0                            ## lo que se queda el último renglón en el centro (s)
const FADE := 1.2                            ## fundido a negro de salida (s)
const INK := Color(0.29, 0.2, 0.13)          ## texto (sobre el pastel)
const HEADING := Color(0.45, 0.33, 0.62)     ## encabezados
## El fondo pastel del juego, con sus colores tal como se ven (todos los parámetros: trampa 32).
const BACKGROUND := {
	"color_centro": Color8(214, 230, 248), "color_borde": Color8(182, 205, 236), "centro": Vector2(0.5, 0.5),
	"radio": 0.9, "color_forma": Color(0.9, 0.94, 0.99, 0.35), "forma": 0, "tam_forma": 190.0, "tam_figura": 0.2, "angulo_patron": 0.785,
	"velocidad": 18.0, "giro": 0.25, "exposicion": 1.0, "saturacion": 1.0,
}

var rolling := false
var _root: Control
var _roll: VBoxContainer
var _out: ColorRect
var _skip: Label
var _y := 0.0
var _end_y := 0.0
var _hold_left := 0.0
var _ending := false
var _bg_mat: ShaderMaterial
var _age := 0.0                              ## lo que lleva pasando (un clic recién empezados no los salta)


func _ready() -> void:
	layer = 45                               # encima de todo menos del fundido de main (50)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	# El mismo fondo que el juego (quinta nota: pastel con estrellas que se desplazan). Aquí no pasa
	# por el tonemap del 3D: los colores son los que se ven.
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://iluminacion/fondo.gdshader")
	for k: String in BACKGROUND:
		mat.set_shader_parameter(k, BACKGROUND[k])
	bg.material = mat
	_bg_mat = mat
	_root.add_child(bg)
	_roll = VBoxContainer.new()
	_roll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roll.alignment = BoxContainer.ALIGNMENT_CENTER
	_roll.add_theme_constant_override("separation", 6)
	_root.add_child(_roll)
	_skip = Label.new()
	_skip.text = "clic para saltar  ›"
	_skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skip.offset_right = -24
	_skip.offset_bottom = -14
	_skip.add_theme_font_size_override("font_size", 15)
	_skip.add_theme_color_override("font_color", Color(INK, 0.5))
	_root.add_child(_skip)
	_out = ColorRect.new()
	_out.set_anchors_preset(Control.PRESET_FULL_RECT)
	_out.color = Color(0, 0, 0, 0)
	_out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_out)
	hide()


## Empieza a pasar. drawings = colores de los dibujos encontrados; total = los que había (0 = no hay).
func play(drawings: Array, total: int) -> void:
	for c in _roll.get_children():
		_roll.remove_child(c)
		c.queue_free()
	Fondos.apply(_bg_mat, false, Settings.get_value("fondo_color"), Settings.get_value("fondo_motivo"))   # los que eligió el jugador
	_roll.add_child(_line(GameState.game_title(), 54, INK))
	_roll.add_child(_space(30))
	if total > 0:
		_roll.add_child(_line("DIBUJOS ENCONTRADOS", 15, HEADING, 4))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		for k in total:
			var icon := DibujoIcono.new(Vector2(34, 43))
			if k < drawings.size():
				icon.color = drawings[k]
			else:
				icon.faded = true
			row.add_child(icon)
		_roll.add_child(row)
		_roll.add_child(_line("%d de %d" % [drawings.size(), total], 20, Color(INK, 0.8)))
		_roll.add_child(_space(40))
	var text := FileAccess.get_file_as_string(CREDITS_PATH).strip_edges()
	if text == "":
		push_warning("Creditos: %s vacío o no existe" % CREDITS_PATH)
	for raw in text.split("\n"):
		var l := raw.strip_edges()
		if l == "":
			_roll.add_child(_space(26))
		elif l == l.to_upper() and l.to_lower() != l:
			_roll.add_child(_line(l, 15, HEADING, 4))
		else:
			_roll.add_child(_line(l, 24, INK))
	_ending = false
	_age = 0.0
	_hold_left = HOLD
	_out.color.a = 0.0
	_skip.modulate.a = 0.0
	_skip.create_tween().tween_property(_skip, "modulate:a", 1.0, 1.0).set_delay(2.0)
	show()
	rolling = true
	_roll.position = Vector2(0, 100000)          # fuera de la vista hasta que se maquete (trampa 3)
	await get_tree().process_frame
	await get_tree().process_frame
	var screen := _root.size
	_roll.size = Vector2(screen.x, 0)
	_roll.reset_size()
	_roll.size.x = screen.x
	_y = screen.y + 20.0
	var last := _roll.get_child(_roll.get_child_count() - 1) as Control
	_end_y = screen.y * 0.5 - (last.position.y + last.size.y * 0.5)
	_roll.position = Vector2(0, _y)


func _process(delta: float) -> void:
	_age += delta
	if not rolling or _ending or _roll.position.y > 99999.0:
		return
	var speed := SPEED * _root.size.y / 720.0
	if _y > _end_y:
		_y = maxf(_y - speed * delta, _end_y)
		_roll.position.y = _y
		return
	_hold_left -= delta
	if _hold_left <= 0.0:
		end()


## Se acaba: fundido a negro y aviso.
func end() -> void:
	if not rolling or _ending:
		return
	_ending = true
	var tw := create_tween()
	tw.tween_property(_out, "color:a", 1.0, FADE).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		rolling = false
		hide()
		finished.emit())


## Los quita sin avisar (se carga otro diorama por otro camino).
func cancel() -> void:
	rolling = false
	_ending = false
	hide()


func _input(e: InputEvent) -> void:
	if not rolling:
		return
	var press := (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) \
		or e.is_action_pressed("back") or e.is_action_pressed("ui_accept")
	if press or e is InputEventMouseButton:
		get_viewport().set_input_as_handled()    # nada de lo de debajo recibe clics mientras pasan
	if press and _age > 1.0:
		end()


## (Tests) Lo que dicen los créditos, renglón a renglón.
func lines() -> PackedStringArray:
	var out: PackedStringArray = []
	for c in _roll.get_children():
		if c is Label:
			out.append((c as Label).text)
	return out


func _line(text: String, size: int, color: Color, spacing := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if spacing > 0:
		var f := FontVariation.new()
		f.base_font = UiTheme.FONT_BOLD
		f.spacing_glyph = spacing
		l.add_theme_font_override("font", f)
	return l


func _space(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
