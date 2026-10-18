class_name Visuals
extends RefCounted
## Utilidades visuales sin estado: cajas, silueta blanca y capa de madera cruda (sin pintar).

## Las siluetas se pintan DESPUÉS de la arcilla. Las dos son transparentes y Godot las ordena por
## la distancia al centro de su caja: una pared grande tiene el centro más cerca que una estantería
## pegada a ella, se pintaba después y la borraba entera (visto en la habitación japonesa).
const GHOST_RENDER_PRIORITY := 10
## Capa física de las "superficies" (paredes, suelo, muebles ya puestos): la pieza que se arrastra
## choca con ellas y no las atraviesa. Los clics (cajones, rincones) van por la capa 1.
const SURFACE_LAYER := 2
const CLICK_LAYER := 1
const GHOST_SHADER := preload("res://shaders/ghost.gdshader")
const CLAY_SHADER := preload("res://shaders/madera_cruda.gdshader")
## Esferas de pintura que caben en el shader (MAX_PINTURA en madera_cruda.gdshader).
const MAX_PAINT := 128
## Las cosas de un capítulo, al abrirse, no salen de golpe (pedido del 18-oct): cada una crece desde el
## suelo con un rebote, y van saliendo de izquierda a derecha de la pantalla (grow_in, sweep_delay).
const GROW_FROM := 0.02                      ## tamaño con el que empieza (casi nada: con 0 no se podría invertir)
const GROW_TIME := 0.55                      ## lo que tarda cada una en crecer (s)
const GROW_SWEEP := 0.9                      ## de la que está más a la izquierda a la de más a la derecha (s)


static func meshes_under(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D and (root as MeshInstance3D).mesh != null:
		out.append(root)
	for c in root.get_children():
		out.append_array(meshes_under(c))
	return out


## Caja en coordenadas globales de todas las mallas bajo root.
static func global_aabb(root: Node3D) -> AABB:
	var box := AABB()
	var have := false
	for m in meshes_under(root):
		var b: AABB = m.global_transform * m.get_aabb()
		box = b if not have else box.merge(b)
		have = true
	if not have:
		box = AABB(root.global_position - Vector3.ONE * 0.1, Vector3.ONE * 0.2)
	return box


## Cuándo le toca aparecer a algo según dónde cae en la pantalla entre las cosas que aparecen con él
## (`along`: sus centros): 0 la que está más a la izquierda, GROW_SWEEP la de más a la derecha.
static func sweep_delay(node: Node3D, along: PackedVector3Array) -> float:
	var cam := node.get_viewport().get_camera_3d() if node.is_inside_tree() else null
	var at := global_aabb(node).get_center()
	if cam == null or cam.is_position_behind(at):
		return 0.0
	var left := INF
	var right := -INF
	for p in along:
		if not cam.is_position_behind(p):
			var px := cam.unproject_position(p).x
			left = minf(left, px)
			right = maxf(right, px)
	if right - left < 1.0:
		return 0.0
	return GROW_SWEEP * clampf((cam.unproject_position(at).x - left) / (right - left), 0.0, 1.0)


## La hace crecer desde el centro de abajo de su caja (desde el suelo) hasta su tamaño, con un pequeño
## rebote, pasados `delay` s. Al acabar, o si se corta con stop_growing, queda exactamente como estaba.
static func grow_in(node: Node3D, delay := 0.0) -> void:
	stop_growing(node)
	if not node.is_inside_tree():
		return
	var base := node.transform
	var box := global_aabb(node)
	var bottom := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var parent := node.get_parent_node_3d()
	var pivot := parent.global_transform.affine_inverse() * bottom if parent != null else bottom
	node.transform = _grown(base, pivot, GROW_FROM)
	var tw := node.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(func(s: float) -> void: node.transform = _grown(base, pivot, s), GROW_FROM, 1.0, GROW_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		node.remove_meta(&"crece")
		node.transform = base)
	node.set_meta(&"crece", [tw, base, delay])


## Si estaba creciendo, la deja ya a su tamaño (al colocar una pieza que aún crecía, al ocultarla...).
static func stop_growing(node: Node3D) -> void:
	if not node.has_meta(&"crece"):
		return
	var info: Array = node.get_meta(&"crece")
	node.remove_meta(&"crece")
	var tw := info[0] as Tween
	if tw != null and tw.is_valid():
		tw.kill()
	node.transform = info[1]


static func is_growing(node: Node3D) -> bool:
	return node.has_meta(&"crece")


## (Tests) Cuánto esperaba para crecer (-1 si no está creciendo).
static func grow_delay(node: Node3D) -> float:
	return float((node.get_meta(&"crece") as Array)[2]) if node.has_meta(&"crece") else -1.0


## `base` crecida a `s` (1 = su tamaño) desde `pivot`, en el espacio del padre.
static func _grown(base: Transform3D, pivot: Vector3, s: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3(s, s, s)) * base.basis, pivot + (base.origin - pivot) * s)


## Caja en el espacio local de root (para colisiones y para centrar copias).
## Usa transformaciones LOCALES encadenadas: funciona también con nodos fuera del árbol.
static func local_aabb(root: Node3D) -> AABB:
	var box := AABB()
	var have := false
	for m in meshes_under(root):
		var b: AABB = _relative_xform(root, m) * m.get_aabb()
		box = b if not have else box.merge(b)
		have = true
	if not have:
		box = AABB(-Vector3.ONE * 0.1, Vector3.ONE * 0.2)
	return box


static func _relative_xform(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## Copia limpia de una pieza (sin colisiones ni scripts) con la transformación a cero.
static func clean_copy(node: Node3D) -> Node3D:
	var copy := node.duplicate(0) as Node3D
	copy.transform = Transform3D.IDENTITY
	_strip_non_visual(copy)
	return copy


static func _strip_non_visual(n: Node) -> void:
	for c in n.get_children():
		if c is CollisionObject3D or c is CollisionShape3D or c is AnimationPlayer:
			n.remove_child(c)
			c.free()
		else:
			_strip_non_visual(c)


## Colisión con la forma exacta de la malla (triángulos), por las dos caras: una pieza que llega por
## detrás de una pared tampoco la cruza. Se cuelga de la malla, así un cajón la lleva consigo.
static func add_surface(m: MeshInstance3D) -> void:
	if m.mesh == null or m.has_node("Superficie"):
		return
	var shape := m.mesh.create_trimesh_shape()
	if shape == null:
		return
	shape.backface_collision = true
	var body := StaticBody3D.new()
	body.name = "Superficie"
	body.collision_layer = SURFACE_LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	m.add_child(body)


static func make_ghost_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GHOST_SHADER
	m.render_priority = GHOST_RENDER_PRIORITY
	return m


## Capa de madera cruda que tapa el color real hasta que llega la pintura. Un solo material para
## todo el diorama: las manchas de pintura van en sus parámetros (las pone el Diorama).
static func make_clay_overlay() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CLAY_SHADER
	return m
