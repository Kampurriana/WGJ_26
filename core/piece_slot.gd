class_name PieceSlot
extends RefCounted
## Un hueco del diorama: el nodo P_ del modelo, pintado como silueta blanca hasta que se coloca.

var id: StringName
var node: Node3D
var scope: Interactable          # el sub-diorama Z_ al que pertenece (null = el general)
var prereqs: Array[StringName] = []
var filled := false
var prototype: Node3D            # copia limpia: vista previa del inventario y pieza en mano

var _ghost: ShaderMaterial
var _meshes: Array[MeshInstance3D] = []
var _extras: Array[VisualInstance3D] = []   ## lo visible que no es malla (Label3D, Sprite3D...): oculto hasta colocar


func setup(p_id: StringName, p_node: Node3D, p_scope: Interactable) -> void:
	id = p_id
	node = p_node
	scope = p_scope
	prototype = Visuals.clean_copy(node)
	_meshes = Visuals.meshes_under(node)
	_ghost = Visuals.make_ghost_material()
	for m in _meshes:
		m.material_override = _ghost
	for v in node.find_children("*", "VisualInstance3D", true, false):
		if not (v is MeshInstance3D) and (v as VisualInstance3D).visible:
			_extras.append(v)
			(v as VisualInstance3D).hide()


func meshes() -> Array[MeshInstance3D]:
	return _meshes


func center() -> Vector3:
	return Visuals.global_aabb(node).get_center()


func set_pulse(on: bool) -> void:
	_ghost.set_shader_parameter("pulse", 1.0 if on else 0.0)


func is_ghost() -> bool:
	return not _meshes.is_empty() and _meshes[0].material_override == _ghost


func fill() -> void:
	filled = true
	for m in _meshes:
		m.material_override = null
	for v in _extras:
		v.show()
