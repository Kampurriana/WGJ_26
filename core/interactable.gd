class_name Interactable
extends StaticBody3D
## Todo lo que se pulsa en el diorama: cajones (OD_), puertas (OR_), piezas escondidas (H_)
## y sub-dioramas con zoom (Z_). Se cuelga como hijo del nodo del modelo, con una caja de
## colisión calculada de sus mallas, para que el rayo del clic lo encuentre.

const OPEN_TIME := 0.45

var kind: String
var id: StringName
var target: Node3D
var scope: Interactable          # sub-diorama que lo contiene (null = el general)
var diorama: Diorama
var is_open := false
var collected := false
var completed := false
var reward: StringName = &""

var _closed: Transform3D
var _open: Transform3D
var _shape: CollisionShape3D


func setup(p_diorama: Diorama, p_target: Node3D, info: Dictionary, p_scope: Interactable) -> void:
	diorama = p_diorama
	target = p_target
	kind = info.kind
	id = info.id
	scope = p_scope
	name = "Interactable"
	var tokens: PackedStringArray = info.tokens
	var box := Visuals.local_aabb(target)
	target.add_child(self)
	_shape = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size.max(Vector3.ONE * 0.05)
	_shape.shape = shape
	_shape.position = box.get_center()
	add_child(_shape)
	_closed = target.transform
	match kind:
		NameRules.DRAWER:
			var axis := _axis_from_tokens(tokens, Vector3.BACK)
			var depth := absf(box.size.dot(axis.abs()))
			_open = _closed.translated_local(axis * depth * 0.75)
		NameRules.DOOR:
			var side := -1.0 if NameRules.has_token(tokens, "n") else 1.0
			_open = _closed * Transform3D(Basis(Vector3.UP, deg_to_rad(90.0 * side)), Vector3.ZERO)
		NameRules.ZOOM:
			var r := NameRules.values(tokens, "reward")
			reward = r[0] if not r.is_empty() else &""


static func _axis_from_tokens(tokens: PackedStringArray, fallback: Vector3) -> Vector3:
	var table := {"x": Vector3.RIGHT, "nx": Vector3.LEFT, "y": Vector3.UP, "ny": Vector3.DOWN,
		"z": Vector3.BACK, "nz": Vector3.FORWARD}
	for t in tokens:
		if table.has(t):
			return table[t]
	return fallback


func is_openable() -> bool:
	return kind == NameRules.DRAWER or kind == NameRules.DOOR


func activate() -> void:
	match kind:
		NameRules.DRAWER, NameRules.DOOR:
			set_open(not is_open)
		NameRules.PICKUP:
			diorama.collect(self)
		NameRules.ZOOM:
			diorama.enter_focus(self)


func set_open(value: bool, animate := true) -> void:
	is_open = value
	Sfx.play("open" if is_open else "close")
	var goal := _open if is_open else _closed
	if not animate:
		target.transform = goal
		return
	var tw := target.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(target, "transform", goal, OPEN_TIME)


## Encender o apagar el clic (un Z_ se apaga mientras estás dentro para poder tocar lo de dentro).
func set_clickable(value: bool) -> void:
	_shape.disabled = not value
