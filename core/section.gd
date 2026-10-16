class_name Section
extends RefCounted
## Una sección del diorama (nodo S_<orden>_<nombre> del modelo): una zona que se monta entera antes
## de pasar a la siguiente (la infancia, la adolescencia...). Mientras está cerrada se ve entera en
## modo fantasma, del color de su acto (tint): las siluetas de sus piezas y también su decorado
## (muebles, bombillas), que ni choca ni se puede tocar; sus luces, apagadas. La abre el Diorama
## cuando se completa la anterior: su decorado se vuelve de verdad y sus luces se encienden.
## Las luces que cuelgan de la sección (y no de una pieza) son las de la zona.

## Color de cada acto, por orden de sección (la primera, la estructura, neutra).
const TINTS: Array[Color] = [Color(1.0, 0.97, 0.92), Color(1.0, 0.68, 0.78), Color(0.62, 0.76, 1.0),
	Color(0.66, 0.94, 0.7), Color(1.0, 0.85, 0.48)]

var order := 0
var name := ""                   ## "infancia": la clave del rótulo es titulo_<name>, la de sus frases seccion_<name>
var node: Node3D
var slots: Array[PieceSlot] = []
var interactables: Array[Interactable] = []
var opening := false             ## abriéndose: luces, rótulo y frases en marcha; sus piezas aún no se ven
var opened := false
var completed := false

var decor: Array[Node3D] = []    ## lo que cuelga de la sección y no es pieza (muebles, bombillas...)
var tint := Color.WHITE          ## color de su acto (siluetas, decorado fantasma, letrero)
var label: Label3D               ## letrero flotante con el nombre del acto mientras está cerrada
var _lights: Dictionary = {}     ## Light3D -> energía con la que vino del modelo
var _ghost_mat: ShaderMaterial   ## decorado en modo fantasma
var _saved: Dictionary = {}      ## MeshInstance3D del decorado -> [material_override, material_overlay]
var _decor_on := true


func setup(p_node: Node3D, info: Dictionary, index: int) -> void:
	node = p_node
	order = NameRules.section_order(info.id)
	if order < 0:
		order = 1000 + index
	name = NameRules.section_name(info.id)


## Color del acto según su puesto (0 = la primera sección).
static func tint_for(index: int) -> Color:
	return TINTS[index] if index < TINTS.size() else TINTS[1 + (index - 1) % (TINTS.size() - 1)]


## Las luces de la zona: las de la sección que no son de ninguna pieza (esas se encienden al colocarla).
func collect_lights() -> void:
	for l in node.find_children("*", "Light3D", true, false):
		var inside_piece := false
		for s in slots:
			if s.node.is_ancestor_of(l):
				inside_piece = true
				break
		if not inside_piece:
			_lights[l] = (l as Light3D).light_energy
	for c in node.get_children():
		var is_piece := false
		for s in slots:
			if s.node == c:
				is_piece = true
				break
		if not is_piece and c is Node3D:
			decor.append(c)


## Decorado de verdad (on) o en modo fantasma (off: del color del acto, sin chocar). animate = al
## abrirse durante la partida, se vuelve de verdad con un pequeño rebote.
## skip = mallas que no son del decorado aunque cuelguen de él (lo escondido en un mueble).
func set_decor(on: bool, animate := false, skip: Dictionary = {}) -> void:
	if _ghost_mat == null:
		_ghost_mat = Visuals.make_ghost_material()
		_ghost_mat.set_shader_parameter("tint", tint)
		_ghost_mat.set_shader_parameter("bloqueada", 1.0)
		for d in decor:
			for m in Visuals.meshes_under(d):
				if not skip.has(m):
					_saved[m] = [m.material_override, m.material_overlay]
	for d in decor:
		d.visible = true
		# El fantasma no choca: la pieza en mano ni el zoom tropiezan con muebles que aún no están.
		for body in d.find_children("Superficie", "StaticBody3D", true, false):
			(body as StaticBody3D).collision_layer = Visuals.SURFACE_LAYER if on else 0
		if on and animate and not _decor_on and d.is_inside_tree():
			var base := d.scale
			d.scale = base * 0.85
			var tw := d.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(d, "scale", base, 0.6)
	for m: MeshInstance3D in _saved:
		if not is_instance_valid(m):
			continue
		var was: Array = _saved[m]
		m.material_override = was[0] if on else _ghost_mat
		m.material_overlay = was[1] if on else null
	_decor_on = on
	if label != null:
		if on and animate and label.is_inside_tree():
			var tw := label.create_tween()
			tw.tween_property(label, "modulate:a", 0.0, 0.8)
			tw.tween_callback(label.hide)
		else:
			label.visible = not on


## (Tests) ¿El decorado está en modo fantasma?
func decor_is_ghost() -> bool:
	return not _decor_on and not _saved.is_empty()


func set_lights(on: bool, fade_seconds := 0.0) -> void:
	for l: Light3D in _lights:
		if not on:
			l.hide()
			continue
		l.show()
		if fade_seconds <= 0.0 or not l.is_inside_tree():
			l.light_energy = float(_lights[l])
			continue
		l.light_energy = 0.0
		var tw := l.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(l, "light_energy", float(_lights[l]), fade_seconds)


func lights() -> Array:
	return _lights.keys()


func is_full() -> bool:
	for s in slots:
		if not s.filled:
			return false
	return true


func box() -> AABB:
	return Visuals.global_aabb(node)
