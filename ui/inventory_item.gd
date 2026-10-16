class_name InventoryItem
extends PanelContainer
## Una ficha del panel de piezas: vista 3D de la pieza que GIRA CON LA CÁMARA, para que se vea
## en la misma orientación que tendrá en su hueco (así lo hace Woodo). Pulsar = empezar a arrastrar.

const SIZE := Vector2(190, 140)

var piece_id: StringName
var _ref: Node3D                 ## nodo del hueco: su orientación es la que se copia
var _pivot: Node3D
var _viewport: SubViewport
var _count: Label


func setup(id: StringName, prototype: Node3D, ref: Node3D, count: int) -> void:
	piece_id = id
	_ref = ref
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	holder.add_child(_viewport)
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
	var radius := Visuals.local_aabb(copy).size.length() * 0.5 * maxf(ref.global_basis.get_scale().x, 0.001)
	var c := Camera3D.new()
	c.fov = 30.0
	c.position = Vector3(0, 0, maxf(radius, 0.05) / tan(deg_to_rad(15.0)) * 1.15)
	_viewport.add_child(c)
	_count = Label.new()
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.size_flags_horizontal = Control.SIZE_SHRINK_END
	_count.size_flags_vertical = Control.SIZE_SHRINK_END
	add_child(_count)
	set_count(count)
	mouse_entered.connect(func() -> void: GameState.hovered_piece = piece_id)
	mouse_exited.connect(func() -> void:
		if GameState.hovered_piece == piece_id:
			GameState.hovered_piece = &"")


func set_count(n: int) -> void:
	_count.text = "x%d" % n if n > 1 else ""


func texture() -> Texture2D:
	return _viewport.get_texture()


func _process(_delta: float) -> void:
	var main_cam := get_viewport().get_camera_3d()
	if main_cam == null or not is_instance_valid(_ref):
		return
	# Orientación de la pieza vista desde la cámara principal = la que verá en su hueco.
	_pivot.basis = main_cam.global_basis.orthonormalized().inverse() * _ref.global_basis


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			GameState.drag.begin(piece_id, self)
			accept_event()


func shake() -> void:
	var tw := create_tween()
	for x in [8.0, -8.0, 5.0, -5.0, 0.0]:
		tw.tween_property(self, "position:x", position.x + x, 0.04)


func highlight(on: bool) -> void:
	modulate = Color(1.15, 1.1, 0.8) if on else Color.WHITE
