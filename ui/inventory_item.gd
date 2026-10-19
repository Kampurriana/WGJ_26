class_name InventoryItem
extends PanelContainer
## Una ficha de la bandeja de piezas: vista 3D de la pieza que GIRA CON LA CÁMARA, para que se vea
## en la misma orientación que tendrá en su hueco (así lo hace Woodo). Al pasar el ratón, la pieza
## crece un poco y la bandeja dice qué es. Pulsar = empezar a arrastrar.
## Bloqueada (set_locked): gris, con candado y quieta (su vista se dibuja una sola vez: así 50
## fichas no cuestan como 50); pulsarla no la coge: tiembla y la bandeja dice por qué.

signal hovered(item: InventoryItem, on: bool)
signal locked_pressed(item: InventoryItem)

const SIZE := Vector2(84, 84)
const HOVER_SCALE := 1.18
const LOCKED_TINT := Color(0.62, 0.6, 0.58, 0.75)
const REDRAW_DEG := 0.4                      ## una ficha disponible se redibuja si su pieza gira más que esto

var piece_id: StringName
var locked := false
var reason := ""                             ## por qué está bloqueada ("" = no lo está)
var _ref: Node3D                 ## nodo del hueco: su orientación es la que se copia
var _pivot: Node3D
var _viewport: SubViewport
var _view: TextureRect                       ## lo que se ve de _viewport
var _count: Label
var _lock: Control
var _hover := false
var _size := Vector3.ONE                     ## tamaño de la pieza (para saber si se ve de canto)


func setup(id: StringName, prototype: Node3D, ref: Node3D, count: int) -> void:
	piece_id = id
	_ref = ref
	custom_minimum_size = SIZE
	pivot_offset = SIZE * 0.5
	theme_type_variation = &"Ficha"
	mouse_filter = Control.MOUSE_FILTER_STOP
	# La vista 3D va en un SubViewport suelto y se enseña con un TextureRect: un SubViewportContainer
	# lo vuelve a poner a "dibujar siempre" cada vez que entra en el árbol o cambia de visibilidad, y
	# todas las fichas (también las bloqueadas, quietas) se dibujaban en cada fotograma (19-oct: la
	# build iba a tirones; en el título eran 17 escenas 3D por fotograma). Cuándo se dibuja: _process.
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(SIZE)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	_view = TextureRect.new()
	_view.texture = _viewport.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 0.97, 0.92)
	env.environment.ambient_light_energy = 0.7
	_viewport.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	_viewport.add_child(light)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	var copy := prototype.duplicate() as Node3D
	_pivot.add_child(copy)
	copy.position = -Visuals.local_aabb(copy).get_center()
	_size = Visuals.local_aabb(copy).size
	var radius := Visuals.local_aabb(copy).size.length() * 0.5 * maxf(ref.global_basis.get_scale().x, 0.001)
	var c := Camera3D.new()
	c.fov = 30.0
	c.position = Vector3(0, 0, maxf(radius, 0.05) / tan(deg_to_rad(15.0)) * 1.15)
	_viewport.add_child(c)
	_count = Label.new()
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.size_flags_horizontal = Control.SIZE_SHRINK_END
	_count.size_flags_vertical = Control.SIZE_SHRINK_END
	_count.add_theme_color_override("font_color", UiTheme.CREAM)
	_count.add_theme_color_override("font_outline_color", UiTheme.BLUE_DEEP)
	_count.add_theme_constant_override("outline_size", 6)
	_count.add_theme_font_size_override("font_size", 16)
	add_child(_count)
	_lock = LockBadge.new()
	_lock.size_flags_horizontal = Control.SIZE_SHRINK_END
	_lock.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_lock.hide()
	add_child(_lock)
	set_count(count)
	mouse_entered.connect(func() -> void:
		_hover = true
		if not locked:
			GameState.hovered_piece = piece_id
			_hover_scale(1.08)                   # la ficha se ofrece: crece un poco
			Sfx.play("pieza_preseleccion", 0.03)
		hovered.emit(self, true))
	mouse_exited.connect(func() -> void:
		_hover = false
		_hover_scale(1.0)
		if GameState.hovered_piece == piece_id:
			GameState.hovered_piece = &""
		hovered.emit(self, false))
	_orient()


func _hover_scale(s: float) -> void:
	pivot_offset = size * 0.5
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE * s, 0.2)


func set_count(n: int) -> void:
	_count.text = "x%d" % n if n > 1 else ""


## Bloqueada (gris, candado, quieta) o disponible. Al pasar de bloqueada a disponible, da un saltito
## y brilla un momento: "esta ya se puede poner".
func set_locked(on: bool, why := "") -> void:
	reason = why
	if on == locked and _lock.visible == on:
		return
	var was_locked := locked
	locked = on
	_lock.visible = on
	self_modulate = LOCKED_TINT if on else Color.WHITE
	_view.modulate = LOCKED_TINT if on else Color.WHITE
	_orient()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE   # (disponible: se redibuja cuando gira, _process)
	if was_locked and not on and is_inside_tree():
		celebrate_unlock()


func celebrate_unlock() -> void:
	scale = Vector2.ONE * 0.8
	modulate = Color(1.35, 1.25, 0.85)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate", Color.WHITE, 1.2).set_delay(0.2)


func texture() -> Texture2D:
	return _viewport.get_texture()


func _process(delta: float) -> void:
	if locked:
		return                                   # quieta: su vista se dibujó una vez
	var grow := lerpf(_pivot.basis.get_scale().x, HOVER_SCALE if _hover else 1.0, 1.0 - exp(-12.0 * delta))
	var before := _pivot.basis
	_orient(grow)
	# Solo se vuelve a dibujar si se nota (19-oct: cada ficha es una escena 3D aparte, y dibujarlas todas en
	# cada fotograma, con la cámara siempre respirando, costaba en la Web).
	var turned := rad_to_deg(before.orthonormalized().get_rotation_quaternion().angle_to(
		_pivot.basis.orthonormalized().get_rotation_quaternion()))
	if turned > REDRAW_DEG or absf(before.get_scale().x - _pivot.basis.get_scale().x) > 0.002:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	else:
		_pivot.basis = before                    # (lo que se ve sigue siendo lo último dibujado)


## Orientación de la pieza vista desde la cámara principal = la que verá en su hueco.
func _orient(grow := 1.0) -> void:
	var main_cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if main_cam == null or not is_instance_valid(_ref) or not _ref.is_inside_tree():
		return
	var rot := (main_cam.global_basis.orthonormalized().inverse() * _ref.global_basis).orthonormalized()
	# Una pieza plana vista de canto (una pared, un póster, una alfombra) sería una raya: se gira un
	# poco para que se reconozca (de pie: hacia un lado; tumbada: se inclina hacia quien mira). Sigue
	# indicando hacia dónde mira; solo deja de ser ilegible.
	var e := (rot * Vector3(_size.x, 0, 0)).abs() + (rot * Vector3(0, _size.y, 0)).abs() + (rot * Vector3(0, 0, _size.z)).abs()
	if e.y < e.x * 0.25:
		rot = Basis(Vector3.RIGHT, deg_to_rad(40.0)) * rot
	elif e.x < e.y * 0.18:
		rot = Basis(Vector3.UP, deg_to_rad(40.0)) * rot
	_pivot.basis = rot.scaled(Vector3.ONE * grow)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if locked:
				shake()
				locked_pressed.emit(self)
			else:
				Sfx.play("pieza_seleccion", 0.03)
				GameState.drag.begin(piece_id, self)
			accept_event()


func shake() -> void:
	var tw := create_tween()
	for x in [8.0, -8.0, 5.0, -5.0, 0.0]:
		tw.tween_property(self, "position:x", position.x + x, 0.04)


func highlight(on: bool) -> void:
	modulate = Color(1.15, 1.1, 0.8) if on else Color.WHITE


## El candado de una ficha bloqueada (dibujado, sin imagen).
class LockBadge extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(22, 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var ink := Color(0.16, 0.11, 0.07, 0.9)
		var metal := Color(0.98, 0.9, 0.7)
		draw_circle(Vector2(11, 14), 11.0, ink)
		draw_arc(Vector2(11, 11), 4.5, PI, TAU, 12, metal, 2.2, true)
		draw_line(Vector2(6.5, 11), Vector2(6.5, 13), metal, 2.2, true)
		draw_line(Vector2(15.5, 11), Vector2(15.5, 13), metal, 2.2, true)
		draw_rect(Rect2(5, 13, 12, 8), metal)
		draw_rect(Rect2(10, 15.5, 2, 3), ink)
