class_name DragController
extends Node
## Arrastrar una pieza del panel al diorama. Sobre el panel se ve su icono; sobre el 3D se ve
## la pieza real, ya orientada como su hueco, que se "imanta" al acercarse. Soltar cerca = encaja.
## La pieza en mano NUNCA atraviesa paredes, suelo ni muebles puestos: su caja se lanza desde la
## cámara por el rayo del cursor y se para en el primer contacto (capa Visuals.SURFACE_LAYER).

const MAGNET := 1.6              ## el imán empieza a 1,6 veces la distancia de encaje
const START_AHEAD := 0.15        ## la caja sale un poco por delante de la cámara

var piece_id: StringName = &""
var _source: InventoryItem
var _icon: TextureRect
var _held: Node3D
var _held_box := AABB()          ## caja de la pieza en su espacio local
var _reach := 10.0               ## hasta dónde puede ir por el rayo (más allá del diorama, nada)
var _shape := BoxShape3D.new()
var last_rested := false         ## (tests) la última posición se paró en una superficie


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.size = InventoryItem.SIZE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.hide()
	layer.add_child(_icon)


func begin(id: StringName, source: InventoryItem) -> void:
	var d := GameState.diorama
	if d == null or piece_id != &"" or d.lock_reason(id) != "":
		return                                   # una pieza con candado no se coge (la ficha dice por qué)
	piece_id = id
	_source = source
	GameState.is_dragging = true
	_icon.texture = source.texture()
	_held = d.prototype_for(id).duplicate() as Node3D
	_held.hide()
	d.add_child(_held)
	_held_box = Visuals.local_aabb(_held)
	var cam := get_viewport().get_camera_3d()
	var box := Visuals.global_aabb(d)
	_reach = cam.global_position.distance_to(box.get_center()) + box.size.length() * 0.5
	Events.piece_drag_started.emit(id)
	_update(get_viewport().get_mouse_position())


func _input(e: InputEvent) -> void:
	if piece_id == &"":
		return
	if e is InputEventMouseMotion:
		_update((e as InputEventMouseMotion).position)
	elif e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_finish(mb.position)
			get_viewport().set_input_as_handled()


func _update(pos: Vector2) -> void:
	var over_panel := GameState.hud != null and GameState.hud.is_over_panel(pos)
	_icon.visible = over_panel
	_icon.position = pos - _icon.size * 0.5
	_held.visible = not over_panel
	if over_panel:
		return
	var cam := get_viewport().get_camera_3d()
	var d := GameState.diorama
	var c := d.candidate_for(piece_id, pos, cam)
	# Orientación: la de su hueco (así se ve igual que en el panel y que como quedará).
	var ref := (c.slot as PieceSlot).node if not c.is_empty() else d.reference_node_for(piece_id)
	var loose := _free_transform(pos, ref.global_basis if ref != null else Basis(), cam)
	if c.is_empty():
		_held.global_transform = loose
		return
	var goal := (c.slot as PieceSlot).node.global_transform
	var t := clampf(1.0 - float(c.dist) / (d.snap_distance_px() * MAGNET), 0.0, 1.0)
	if t * t > 0.999:
		_held.global_transform = goal            # imantada del todo: en su hueco
		return
	# El camino hacia el hueco también choca: si algo se cruza, la pieza se para ahí.
	var toward := loose.interpolate_with(goal, t * t).origin - loose.origin
	var q := _box_query(loose)
	q.motion = toward
	var r := cam.get_world_3d().direct_space_state.cast_motion(q)
	_held.global_transform = loose.translated(toward * r[0])


## Dónde puede estar la pieza bajo el cursor sin meterse en nada: su caja viaja desde la cámara
## por el rayo del cursor y se para justo antes del primer contacto.
func _free_transform(pos: Vector2, basis: Basis, cam: Camera3D) -> Transform3D:
	var dir := cam.project_ray_normal(pos)
	var start := cam.project_ray_origin(pos) + dir * START_AHEAD
	var at_start := Transform3D(basis, start - basis * _held_box.get_center())
	var q := _box_query(at_start)
	q.motion = dir * _reach
	var r := cam.get_world_3d().direct_space_state.cast_motion(q)
	last_rested = r[0] < 1.0
	return at_start.translated(q.motion * r[0])


## Consulta física con la caja de la pieza colocada como `xf` (sin escala: la escala va al tamaño).
func _box_query(xf: Transform3D) -> PhysicsShapeQueryParameters3D:
	_shape.size = (_held_box.size * xf.basis.get_scale()).max(Vector3.ONE * 0.01)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _shape
	q.collision_mask = Visuals.SURFACE_LAYER
	q.transform = Transform3D(xf.basis.orthonormalized(), xf * _held_box.get_center())
	return q


## Para capturas: deja la pieza en mano como si el cursor estuviera en `pos`.
func hold_at(pos: Vector2) -> void:
	if piece_id != &"":
		_update(pos)


## (Tests) Cuántas superficies atraviesa ahora la pieza en mano, con su caja encogida `margin`
## (tocar no cuenta). 0 = ninguna. -1 = no hay pieza en mano.
func held_overlaps(margin := 0.01) -> int:
	if not is_instance_valid(_held) or not _held.visible:
		return -1
	var t := _held.global_transform
	var shape := BoxShape3D.new()
	shape.size = (_held_box.size * t.basis.get_scale() - Vector3.ONE * margin * 2.0).max(Vector3.ONE * 0.002)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = Visuals.SURFACE_LAYER
	q.transform = Transform3D(t.basis.orthonormalized(), t * _held_box.get_center())
	return get_viewport().get_camera_3d().get_world_3d().direct_space_state.intersect_shape(q, 8).size()


func _finish(pos: Vector2) -> void:
	var id := piece_id
	var d := GameState.diorama
	var placed := false
	var over_panel := GameState.hud != null and GameState.hud.is_over_panel(pos)
	if not over_panel and d != null:
		placed = d.try_place(id, pos, get_viewport().get_camera_3d())
		if not placed:
			Sfx.play("reject")
			if is_instance_valid(_source):
				_source.shake()
	cancel()
	Events.piece_drag_ended.emit(id, placed)


func cancel() -> void:
	if is_instance_valid(_held):
		_held.queue_free()
	_held = null
	_icon.hide()
	piece_id = &""
	GameState.is_dragging = false
