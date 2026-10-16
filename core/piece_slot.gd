class_name PieceSlot
extends RefCounted
## Un hueco del diorama: el nodo P_ del modelo, pintado como silueta blanca hasta que se coloca.
## Lo que cuelga de la pieza y no es malla (luces, textos) está apagado hasta colocarla; las luces
## se encienden entonces con un fundido ("colocar enciende las luces", como en Woodo).

const LIGHT_FADE := 0.8

var id: StringName
var node: Node3D
var scope: Interactable          # el sub-diorama Z_ al que pertenece (null = el general)
var prereqs: Array[StringName] = []
var filled := false
var prototype: Node3D            # copia limpia: vista previa del inventario y pieza en mano

var _ghost: ShaderMaterial
var _meshes: Array[MeshInstance3D] = []
var _extras: Array[VisualInstance3D] = []   ## lo visible que no es malla (luces, Label3D...): oculto hasta colocar
var _light_energy: Dictionary = {}          ## Light3D -> energía con la que vino del modelo


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
			if v is Light3D:
				_light_energy[v] = (v as Light3D).light_energy
			(v as VisualInstance3D).hide()


func meshes() -> Array[MeshInstance3D]:
	return _meshes


func center() -> Vector3:
	return Visuals.global_aabb(node).get_center()


func set_pulse(on: bool) -> void:
	_ghost.set_shader_parameter("pulse", 1.0 if on else 0.0)


func is_ghost() -> bool:
	return not _meshes.is_empty() and _meshes[0].material_override == _ghost


## fade = las luces se encienden poco a poco (false: de golpe, para el título ya montado).
func fill(fade := true) -> void:
	filled = true
	for m in _meshes:
		m.material_override = null
	for v in _extras:
		v.show()
		if v is Light3D and fade and node.is_inside_tree():
			var light := v as Light3D
			light.light_energy = 0.0
			var tw := node.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(light, "light_energy", float(_light_energy[light]), LIGHT_FADE)


## (Tests) Las luces de la pieza: [luz, energía de origen].
func lights() -> Array:
	var out := []
	for l: Light3D in _light_energy:
		out.append([l, _light_energy[l]])
	return out
