class_name Inspeccion
extends CanvasLayer
## Sexta nota: al encontrar un dibujo escondido (C_), un primer plano para inspeccionarlo, con la
## disposición del aviso de "badge" de la referencia: arriba, un título grande ("¡UN DIBUJO!") y,
## debajo (sin solaparse), una cápsula con su nombre; en el centro, el dibujo en 3D, que se mece solo y se
## gira arrastrando; debajo, una barra con su texto y cuántos van (3 de 7, con puntos); y abajo, un
## botón grande para guardarlo. El juego queda detrás, apagado con un oscuro del tono del fondo, con
## un halo y rayos suaves detrás del dibujo (shaders/inspeccion.gdshader).
## Mientras se mira, el dibujo de la escena se queda donde estaba (Diorama.hold_collectible); al
## pulsar el botón (o Intro, Espacio, Esc) se cierra y vuela a su pinza (release_collectible). Si se
## encuentran dos seguidos, el segundo espera su turno.

const OPEN_TIME := 0.35
const CLOSE_TIME := 0.25
const BUTTON_DELAY := 0.7                    ## el botón llega el último: no se cierra sin querer
const VIEW_SIZE := Vector2(380, 270)         ## el visor del dibujo (px a 720)
const SWAY := Vector2(0.45, 0.12)            ## cuánto se mece solo (giro, inclinación; rad)
const DRAG_TURN := 0.012                     ## lo que gira al arrastrar (rad por px)
const RETURN := 1.6                          ## lo que tarda en volver a mecerse al soltarlo (muelle)
const TITLE := "¡UN DIBUJO!"
const TITLE_LAST := "¡EL ÚLTIMO!"
const BUTTON := "¡A LA CUERDA!"
const TITLE_COLOR := UiTheme.ORANGE
const TITLE_EDGE := UiTheme.CORAL
const PILL_INK := UiTheme.VIOLET
const BUTTON_COLOR := UiTheme.PURPLE

var item: Interactable                       ## el dibujo que se mira (null = cerrado)
var copy: Node3D                             ## su copia en el visor
var ready_to_close := false                  ## ya ha llegado el botón
var _queue: Array = []                       ## dibujos encontrados que esperan turno: [item, found, total]
var _root: Control
var _shade: ColorRect
var _shade_mat: ShaderMaterial
var _title: Label
var _pill_label: Label
var _view: SubViewportContainer
var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _bar_label: Label
var _count_label: Label
var _dots: HBoxContainer
var _button: Button
var _hint: Label
var _tween: Tween
var _yaw := 0.0
var _pitch := 0.0
var _dragging := false
var _t := 0.0


func _ready() -> void:
	layer = 4                                # encima de la interfaz (2), debajo del menú (5) y la pausa (8)
	_build()
	Events.collectible_found.connect(_on_found)
	Events.level_started.connect(func(_d: Node) -> void: reset())


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP     # mientras se mira, el juego no se toca
	_root.theme = UiTheme.get_theme()
	_root.hide()
	add_child(_root)
	_shade = ColorRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade_mat = ShaderMaterial.new()
	_shade_mat.shader = preload("res://shaders/inspeccion.gdshader")
	_shade_mat.set_shader_parameter("alpha", 0.0)
	_shade_mat.set_shader_parameter("color", Color(0.16, 0.2, 0.3))
	_shade_mat.set_shader_parameter("tam", Vector2(1280, 720))
	_shade_mat.set_shader_parameter("centro", Vector2(0.5, 0.48))
	_shade.material = _shade_mat
	_root.add_child(_shade)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(column)
	var heading := VBoxContainer.new()               # el título y, debajo, la cápsula
	heading.add_theme_constant_override("separation", 6)    # sin solaparse (feedback)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(heading)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", _bold(1.1))
	_title.add_theme_font_size_override("font_size", 72)
	_title.add_theme_color_override("font_color", TITLE_COLOR)
	_title.add_theme_color_override("font_outline_color", TITLE_EDGE)
	_title.add_theme_constant_override("outline_size", 18)
	_title.add_theme_color_override("font_shadow_color", Color(0.05, 0.05, 0.12, 0.45))
	_title.add_theme_constant_override("shadow_offset_y", 9)
	_title.add_theme_constant_override("shadow_offset_x", 0)
	heading.add_child(_title)
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", _round(Color(0.9, 0.95, 1.0, 0.96), 26, Color(1, 1, 1, 0.9), 3, 26, 4))
	heading.add_child(pill)
	_pill_label = Label.new()
	_pill_label.add_theme_font_override("font", _bold(0.7))
	_pill_label.add_theme_font_size_override("font_size", 30)
	_pill_label.add_theme_color_override("font_color", PILL_INK)
	pill.add_child(_pill_label)
	_view = SubViewportContainer.new()
	_view.stretch = true
	_view.custom_minimum_size = VIEW_SIZE
	_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_view.gui_input.connect(_on_view_input)
	column.add_child(_view)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.size = Vector2i(VIEW_SIZE)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view.add_child(_viewport)
	_build_stage()
	_hint = Label.new()
	_hint.text = "arrastra para girarlo"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(UiTheme.CREAM, 0.6))
	column.add_child(_hint)
	var bar := PanelContainer.new()
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(640, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", _round(Color(0.32, 0.4, 0.78, 0.55), 30, Color(0, 0, 0, 0), 0, 28, 10))
	column.add_child(bar)
	var bar_col := VBoxContainer.new()
	bar_col.add_theme_constant_override("separation", 6)
	bar.add_child(bar_col)
	_bar_label = Label.new()
	_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_label.add_theme_font_override("font", _bold(0.6))
	_bar_label.add_theme_font_size_override("font_size", 23)
	_bar_label.add_theme_color_override("font_color", UiTheme.CREAM)
	bar_col.add_child(_bar_label)
	var count_row := HBoxContainer.new()
	count_row.alignment = BoxContainer.ALIGNMENT_CENTER
	count_row.add_theme_constant_override("separation", 12)
	bar_col.add_child(count_row)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 6)
	count_row.add_child(_dots)
	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 16)
	_count_label.add_theme_color_override("font_color", Color(UiTheme.CREAM, 0.85))
	count_row.add_child(_count_label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	column.add_child(gap)
	_button = Button.new()
	_button.text = BUTTON
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.custom_minimum_size = Vector2(290, 76)
	_button.add_theme_font_override("font", _bold(0.9))
	_button.add_theme_font_size_override("font_size", 34)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_button.add_theme_color_override(state, Color(1, 1, 1))
	_button.add_theme_stylebox_override("normal", _round(BUTTON_COLOR, 36, Color(0.93, 0.95, 1.0), 5, 34, 8, BUTTON_COLOR.darkened(0.35)))
	_button.add_theme_stylebox_override("hover", _round(BUTTON_COLOR.lightened(0.12), 36, Color(1, 1, 1), 5, 34, 8, BUTTON_COLOR.darkened(0.35)))
	_button.add_theme_stylebox_override("pressed", _round(BUTTON_COLOR.darkened(0.15), 36, Color(0.93, 0.95, 1.0), 5, 34, 8))
	_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_button.pressed.connect(close)
	column.add_child(_button)


## El escenario del visor: su cámara, una luz cálida de lado y luz ambiente (es su propio mundo).
func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.97, 0.92)
	env.ambient_light_energy = 0.55
	var world := WorldEnvironment.new()
	world.environment = env
	_viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 0.8
	sun.rotation_degrees = Vector3(-30, -35, 0)
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_camera.position = Vector3(0, 0, 1)
	_viewport.add_child(_camera)
	_pivot = Node3D.new()
	_pivot.name = "Dibujo"
	_viewport.add_child(_pivot)


# --- Abrir y cerrar ------------------------------------------------------------------------

func _on_found(found_item: Node, found: int, total: int) -> void:
	var it := found_item as Interactable
	var d := GameState.diorama
	if it == null or d == null or GameState.mode != GameState.Mode.PLAYING:
		return
	d.hold_collectible(it)                   # que no vuele a la cuerda mientras se mira
	_queue.append([it, found, total])
	if item == null:
		_open_next()


func _open_next() -> void:
	while not _queue.is_empty():
		var next: Array = _queue.pop_front()
		if is_instance_valid(next[0]):
			open(next[0], next[1], next[2])
			return


func open(it: Interactable, found: int, total: int) -> void:
	item = it
	ready_to_close = false
	_dragging = false
	_yaw = -0.9                              # entra girando un poco
	_pitch = 0.0
	_t = 0.0
	var all := found >= total
	_title.text = TITLE_LAST if all else TITLE
	_pill_label.text = Narrator.piece_name(it.id).to_upper()
	_bar_label.text = Narrator.text("logro_dibujos_todos" if all else "logro_dibujo")
	_count_label.text = "%d DE %d" % [found, total]
	_fill_dots(found, total, Hud.drawing_color(it.target))
	Narrator.say_if_exists("dibujo_encontrado_%d" % found)    # su voz: una por dibujo, en el orden en que salen
	_show_copy(it.target)
	_shade_mat.set_shader_parameter("color", Fondos.dark(Settings.get_value("fondo_color")).lightened(0.12))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_root.modulate.a = 1.0
	_root.show()
	_button.disabled = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_method(_set_alpha, 0.0, 1.0, OPEN_TIME)
	_pop_in(_title, 0.05, 0.5)
	_pop_in(_pill_label.get_parent() as Control, 0.2, 0.4)
	_pop_in(_view, 0.25, 0.5)
	_pop_in(_bar_label.get_parent().get_parent() as Control, 0.4, 0.4)
	_pop_in(_hint, 0.5, 0.3)
	_pop_in(_button, BUTTON_DELAY - 0.2, 0.4)
	_tween.tween_callback(func() -> void:
		ready_to_close = true
		_button.disabled = false
		_button.grab_focus()).set_delay(BUTTON_DELAY)


## Se cierra: el visor se apaga y el dibujo de la escena vuela por fin a su pinza.
func close() -> void:
	if item == null or not ready_to_close:
		return
	ready_to_close = false
	_button.disabled = true
	var leaving := item
	item = null
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 0.0, CLOSE_TIME)
	_tween.tween_callback(func() -> void:
		_root.hide()
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_free_copy()
		_open_next())
	var d := GameState.diorama
	if d != null and is_instance_valid(leaving):
		d.release_collectible(leaving)
	Sfx.play("pickup")


## Sin mirar nada (al cambiar de nivel): lo que esperaba se descarta.
func reset() -> void:
	_queue.clear()
	item = null
	ready_to_close = false
	if _tween != null:
		_tween.kill()
	_root.hide()
	_set_alpha(0.0)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_free_copy()


func is_open() -> bool:
	return item != null


## (Capturas y pasos automáticos) Cerrar sin esperar al botón.
func close_now() -> void:
	ready_to_close = true
	close()


func _set_alpha(a: float) -> void:
	_shade_mat.set_shader_parameter("alpha", a)


## Aparece con un saltito (crece desde pequeño, pasándose un poco), con un retraso.
func _pop_in(c: Control, delay: float, seconds: float) -> void:
	c.modulate.a = 0.0
	c.scale = Vector2.ONE * 0.6
	_tween.tween_property(c, "modulate:a", 1.0, seconds * 0.6).set_delay(delay)
	_tween.tween_property(c, "scale", Vector2.ONE, seconds).set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fill_dots(found: int, total: int, color: Color) -> void:
	for c in _dots.get_children():
		_dots.remove_child(c)
		c.queue_free()
	for k in total:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(6)
		sb.bg_color = (color if k == found - 1 else UiTheme.CREAM) if k < found else Color(1, 1, 1, 0.0)
		sb.border_color = Color(UiTheme.CREAM, 0.85)
		sb.set_border_width_all(2)
		dot.add_theme_stylebox_override("panel", sb)
		_dots.add_child(dot)


# --- El dibujo en el visor -----------------------------------------------------------------

func _show_copy(target: Node3D) -> void:
	_free_copy()
	copy = Visuals.clean_copy(target)
	copy.show()                              # el de la escena puede estar oculto (aún no se veía)
	for m in Visuals.meshes_under(copy):
		m.show()
		m.material_overlay = null             # sin el brillo de "aquí hay algo" que llevaba en la escena
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(copy)
	var box := Visuals.local_aabb(copy)
	copy.position = -box.get_center()
	var aspect := VIEW_SIZE.x / VIEW_SIZE.y
	var fit := maxf(box.size.y, box.size.x / aspect) * 1.3
	_camera.position = Vector3(0, 0, fit / (2.0 * tan(deg_to_rad(_camera.fov * 0.5))))
	_pivot.rotation = Vector3(_pitch, _yaw, 0)


func _free_copy() -> void:
	if is_instance_valid(copy):
		copy.queue_free()
	copy = null


func _on_view_input(e: InputEvent) -> void:
	if item == null:
		return
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (e as InputEventMouseButton).pressed
	elif e is InputEventMouseMotion and _dragging:
		var rel := (e as InputEventMouseMotion).relative
		_yaw += rel.x * DRAG_TURN
		_pitch = clampf(_pitch + rel.y * DRAG_TURN, -1.0, 1.0)


func _process(delta: float) -> void:
	if item == null:
		return
	_t += delta
	if not _dragging:                        # se mece solo; si lo has girado, vuelve poco a poco
		var k := 1.0 - exp(-delta * 3.0 / RETURN)
		_yaw = lerpf(_yaw, sin(_t * 0.9) * SWAY.x, k)
		_pitch = lerpf(_pitch, sin(_t * 0.7 + 1.0) * SWAY.y, k)
	_pivot.rotation = Vector3(_pitch, _yaw, 0)
	_pivot.position.y = sin(_t * 1.6) * 0.004
	_shade_mat.set_shader_parameter("tam", _shade.size)
	for c in [_title, _pill_label.get_parent(), _view, _bar_label.get_parent().get_parent(), _button, _hint]:
		(c as Control).pivot_offset = (c as Control).size * 0.5


func _input(e: InputEvent) -> void:
	if item == null:
		return
	if e.is_action_pressed("back") or e.is_action_pressed("ui_accept"):
		close()
		get_viewport().set_input_as_handled()   # Esc no abre la pausa: cierra esto


# --- Estilos ---------------------------------------------------------------------------------

static func _bold(amount: float) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = UiTheme.FONT_BOLD if amount >= 0.6 else UiTheme.FONT
	return f


static func _round(bg: Color, radius: int, border: Color, width: int, margin_h: float, margin_v: float,
		under := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(width)
	if under.a > 0.0:                        # un canto oscuro debajo: se lee como un botón que se pulsa
		sb.shadow_color = under
		sb.shadow_size = 1
		sb.shadow_offset = Vector2(0, 7)
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	sb.anti_aliasing = true
	return sb


# --- Para los tests ----------------------------------------------------------------------------

func title_text() -> String:
	return _title.text if is_open() else ""


func name_text() -> String:
	return _pill_label.text if is_open() else ""


func count_text() -> String:
	return _count_label.text if is_open() else ""


func view_rotation() -> Vector3:
	return _pivot.rotation


func button_center() -> Vector2:
	return _button.get_global_rect().get_center()


func view_center() -> Vector2:
	return _view.get_global_rect().get_center()
