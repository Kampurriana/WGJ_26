class_name Section
extends RefCounted
## Una sección del diorama (nodo S_<orden>_<nombre> del modelo): una zona que se monta entera antes
## de pasar a la siguiente (la infancia, la adolescencia...). Mientras está cerrada no se ve nada
## suyo: ni las siluetas de sus piezas, ni su decorado (muebles, bombillas), ni sus luces (el equipo
## no quería ver los actos que aún no tocan). La abre el Diorama cuando se completa la anterior: su
## decorado aparece, sus luces se encienden y sus siluetas se materializan.
## Las luces que cuelgan de la sección (y no de una pieza) son las de la zona.

var order := 0
var name := ""                   ## "infancia": la clave del rótulo es titulo_<name>, la de sus frases seccion_<name>
var node: Node3D
var slots: Array[PieceSlot] = []
var interactables: Array[Interactable] = []
var opening := false             ## abriéndose: luces, rótulo y frases en marcha; sus piezas aún no se ven
var opened := false
var completed := false

var decor: Array[Node3D] = []    ## lo que cuelga de la sección y no es pieza (muebles, bombillas, la cuerda...)
var _lights: Dictionary = {}     ## Light3D -> energía con la que vino del modelo
var _full_box := AABB()          ## su caja con todo a su tamaño (la de cuando se abrió, antes de que nada crezca)
var _sweep := PackedVector3Array()   ## por dónde pasa la ola de aparecer: el centro de cada cosa que aparece


func setup(p_node: Node3D, info: Dictionary, index: int) -> void:
	node = p_node
	order = NameRules.section_order(info.id)
	if order < 0:
		order = 1000 + index
	name = NameRules.section_name(info.id)


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
		# Un dibujo escondido (C_) no es decorado: se ve cuando toca encontrarlo (lo decide el Diorama).
		var collectible: bool = NameRules.parse(c.name).get("kind", "") == NameRules.COLLECTIBLE
		if not is_piece and not collectible and c is Node3D:
			decor.append(c)


## Decorado visible o no. animate = al abrirse durante la partida, cada mueble crece desde el suelo,
## de izquierda a derecha de la pantalla (Visuals.grow_in), como sus siluetas.
func set_decor(on: bool, animate := false) -> void:
	if on and animate and node.is_inside_tree():
		_full_box = Visuals.global_aabb(node)
		_sweep.clear()
		for d in decor:
			_sweep.append(Visuals.global_aabb(d).get_center())
		for s in slots:
			_sweep.append(Visuals.global_aabb(s.node).get_center())
	for d in decor:
		var was := d.visible
		d.visible = on
		# Lo que no se ve tampoco choca (la pieza en mano ni el zoom tropiezan con muebles ocultos).
		for body in d.find_children("Superficie", "StaticBody3D", true, false):
			(body as StaticBody3D).collision_layer = Visuals.SURFACE_LAYER if on else 0
		if on and animate and not was and d.is_inside_tree():
			Visuals.grow_in(d, Visuals.sweep_delay(d, _sweep))
		elif not on:
			Visuals.stop_growing(d)


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


## Su caja (para encuadrarla); mientras sus muebles crecen, la de todo a su tamaño.
func box() -> AABB:
	if decor.any(func(d: Node3D) -> bool: return Visuals.is_growing(d)):
		return _full_box
	return Visuals.global_aabb(node)


## Por dónde pasa la ola de aparecer (de izquierda a derecha): los centros de lo que aparece (medidos
## al abrirse, antes de que nada encoja).
func sweep() -> PackedVector3Array:
	return _sweep
