class_name DragController
extends Node
## Arrastrar una pieza del panel al diorama. Sobre el panel se ve su icono; sobre el 3D se ve
## la pieza real, ya orientada como su hueco, que se "imanta" al acercarse. Soltar cerca = encaja.

const MAGNET := 1.6              ## el imán empieza a 1,6 veces la distancia de encaje

var piece_id: StringName = &""
var _source: InventoryItem
var _icon: TextureRect
var _held: Node3D


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
	if d == null or piece_id != &"":
		return
	piece_id = id
	_source = source
	GameState.is_dragging = true
	_icon.texture = source.texture()
	_held = d.prototype_for(id).duplicate() as Node3D
	_held.hide()
	d.add_child(_held)
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
	if c.is_empty():
		_held.global_transform = Transform3D(Basis(), cam.project_position(pos, GameState.camera.distance * 0.8))
		return
	var slot: PieceSlot = c.slot
	var goal := slot.node.global_transform
	var depth := cam.global_position.distance_to(slot.center())
	var offset := slot.center() - goal.origin            # para que el cursor agarre la pieza por el centro
	var loose := Transform3D(goal.basis, cam.project_position(pos, depth) - offset)
	var t := clampf(1.0 - float(c.dist) / (d.snap_distance_px() * MAGNET), 0.0, 1.0)
	_held.global_transform = loose.interpolate_with(goal, t * t)


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
