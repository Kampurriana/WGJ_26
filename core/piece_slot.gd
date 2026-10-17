class_name PieceSlot
extends RefCounted
## Un hueco del diorama: el nodo P_ del modelo, que se ve como una VERSIÓN BLANCA de la pieza hasta
## que se coloca (como en Woodo: blanca y opaca, iluminada; se lee aunque varias se solapen).
## Lo que cuelga de la pieza y no es malla (luces, textos) está apagado hasta colocarla; las luces
## se encienden entonces con un fundido ("colocar enciende las luces", como en Woodo).
## shown: la silueta se ve (su sección está abierta); al abrirse se materializa (set_shown).
## available: ya se puede poner (blanca); si no (le falta una anterior), gris (set_available).

const LIGHT_FADE := 0.8
const UNLOCK_TIME := 0.7
const APPEAR_TIME := 0.9

var id: StringName
var node: Node3D
var scope: Interactable          # el sub-diorama Z_ al que pertenece (null = el general)
var prereqs: Array[StringName] = []
var section: Section             # la sección S_ que la contiene (null = ninguna: siempre abierta)
var is_key := false              # token clave: va la última de su sección
var flash := false               # token flash: destello blanco al colocarla
var reflejo := false             # token reflejo: su momento es de frente, todo a negro, con un reflejo (el espejo)
var offered := false             # token ofrecida: no va a la bandeja; aparece flotando junto a su hueco (la moneda)
var available := true            # ya toca: silueta blanca y se puede poner (si no, gris y bloqueada)
var shown := true                # se ve la silueta (su sección está abierta)
var filled := false
var prototype: Node3D            # copia limpia: vista previa del inventario y pieza en mano

var _ghost: ShaderMaterial
var _meshes: Array[MeshInstance3D] = []
var _extras: Array[VisualInstance3D] = []   ## lo visible que no es malla (luces, Label3D...): oculto hasta colocar
var _light_energy: Dictionary = {}          ## Light3D -> energía con la que vino del modelo
var _tween: Tween
var _appear: Tween


func setup(p_id: StringName, p_node: Node3D, p_scope: Interactable) -> void:
	id = p_id
	node = p_node
	scope = p_scope
	prototype = Visuals.clean_copy(node)
	_meshes = Visuals.meshes_under(node)
	_ghost = Visuals.make_ghost_material()
	_ghost.set_shader_parameter("bloqueada", 0.0)
	_ghost.set_shader_parameter("aparicion", 1.0)
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


## Silueta a la vista o no. animate = se materializa (disolución con trama) al abrirse su sección.
func set_shown(on: bool, animate := false) -> void:
	if filled or on == shown:
		return
	shown = on
	for m in _meshes:
		m.visible = on
	if _appear != null:
		_appear.kill()
	if on and animate and node.is_inside_tree():
		_appear = node.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_appear.tween_method(func(a: float) -> void: _ghost.set_shader_parameter("aparicion", a), 0.0, 1.0, APPEAR_TIME)
	else:
		_ghost.set_shader_parameter("aparicion", 1.0)


## Disponible o no: blanca si ya se puede poner, gris si le falta una anterior.
## animate = al desbloquearse durante la partida, se aclara poco a poco.
func set_available(on: bool, animate := false) -> void:
	if filled or on == available:
		return
	available = on
	if _tween != null:
		_tween.kill()
	if on and animate and node.is_inside_tree():
		_tween = node.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_method(func(a: float) -> void: _ghost.set_shader_parameter("bloqueada", a), 1.0, 0.0, UNLOCK_TIME)
	else:
		_ghost.set_shader_parameter("bloqueada", 0.0 if on else 1.0)


## (Tests) ¿Se ve la silueta, y con aspecto de bloqueada?
func ghost_visible() -> bool:
	return is_ghost() and _meshes.all(func(m: MeshInstance3D) -> bool: return m.is_visible_in_tree())


func looks_locked() -> bool:
	var v: Variant = _ghost.get_shader_parameter("bloqueada")
	return v != null and float(v) > 0.5


func set_pulse(on: bool) -> void:
	_ghost.set_shader_parameter("pulse", 1.0 if on else 0.0)


func is_ghost() -> bool:
	return not _meshes.is_empty() and _meshes[0].material_override == _ghost


## fade = las luces se encienden poco a poco (false: de golpe, para el título ya montado).
func fill(fade := true) -> void:
	filled = true
	available = true
	shown = true
	if _tween != null:
		_tween.kill()
	if _appear != null:
		_appear.kill()
	for m in _meshes:
		m.material_override = null
		m.visible = true
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
