extends SceneTree
## Genera levels/level_00_muestra.tscn con figuras simples que usan TODA la convención de nombres.
## Sirve para probar mecánicas antes de que llegue el arte. Ejecutar:
##   godot --headless --path . --script res://tools/build_sample_level.gd

const OUT := "res://levels/level_00_muestra.tscn"

var _root: Node3D


func _initialize() -> void:
	_root = Node3D.new()
	_root.name = "Nivel00Muestra"
	_root.set_script(load("res://core/diorama.gd"))
	_root.set("level_title", "Muestra: la casita")
	_root.set("intro_key", "intro_muestra")
	_root.set("outro_key", "fin_muestra")

	var wood := Color(0.62, 0.42, 0.26)
	_cyl(_root, "Base", Vector3(0, -0.15, 0), 2.1, 0.3, Color(0.55, 0.36, 0.22))
	_box(_root, "Suelo", Vector3(0, 0.01, 0), Vector3(3.0, 0.02, 2.6), Color(0.86, 0.74, 0.55))
	_box(_root, "Pared", Vector3(0, 1.0, -1.35), Vector3(3.0, 2.0, 0.12), Color(0.93, 0.83, 0.62))
	var arbol := _node(_root, "Arbol", Vector3(1.55, 0, 0.9))
	_cyl(arbol, "Tronco", Vector3(0, 0.4, 0), 0.08, 0.8, wood)
	_sphere(arbol, "Copa", Vector3(0, 0.95, 0), 0.32, Color(0.37, 0.62, 0.3))

	# Mesa (pieza) y lo que va encima: la taza solo encaja con la mesa puesta.
	var mesa := _node(_root, "P_mesa", Vector3(0.45, 0, 0.2))
	_box(mesa, "Tablero", Vector3(0, 0.74, 0), Vector3(1.1, 0.07, 0.65), wood)
	var leg := 0
	for x in [-0.48, 0.48]:
		for z in [-0.26, 0.26]:
			leg += 1
			_box(mesa, "Pata%d" % leg, Vector3(x, 0.36, z), Vector3(0.07, 0.72, 0.07), wood)
	_cyl(_node(_root, "P_taza__after-mesa", Vector3(0.25, 0.78, 0.25)), "Taza", Vector3(0, 0.06, 0), 0.07, 0.12, Color(0.85, 0.25, 0.22))
	_box(_node(_root, "P_cuchara__after-mesa", Vector3(0.7, 0.785, 0.15)), "Cuchara", Vector3.ZERO, Vector3(0.24, 0.02, 0.05), Color(0.75, 0.77, 0.8))

	# Dos sillas iguales: comparten id, cualquiera vale en cualquier hueco.
	for i in 2:
		var silla := _node(_root, "P_silla" + ("" if i == 0 else "_001"), Vector3(0.45, 0, 0.75 if i == 0 else -0.35))
		silla.rotation_degrees.y = 0 if i == 0 else 180
		_box(silla, "Asiento", Vector3(0, 0.42, 0), Vector3(0.42, 0.06, 0.42), Color(0.36, 0.6, 0.45))
		_box(silla, "Respaldo", Vector3(0, 0.72, 0.19), Vector3(0.42, 0.55, 0.05), Color(0.36, 0.6, 0.45))
		_box(silla, "Patas", Vector3(0, 0.2, 0), Vector3(0.36, 0.4, 0.36), wood)

	var lampara := _node(_root, "P_lampara", Vector3(-1.25, 0, -0.95))
	_cyl(lampara, "Pie", Vector3(0, 0.6, 0), 0.03, 1.2, Color(0.25, 0.25, 0.28))
	_cyl(lampara, "Pantalla", Vector3(0, 1.25, 0), 0.2, 0.25, Color(0.98, 0.82, 0.35))

	# Cómoda con un cajón (OD_) y una cuchara escondida dentro (H_).
	_box(_root, "Comoda", Vector3(-1.15, 0.35, 0.05), Vector3(0.8, 0.7, 0.45), Color(0.78, 0.6, 0.42))
	var cajon := _node(_root, "OD_cajon", Vector3(-1.15, 0.52, 0.06))
	_box(cajon, "Frente", Vector3.ZERO, Vector3(0.7, 0.18, 0.44), Color(0.7, 0.5, 0.33))
	_box(_node(cajon, "H_cuchara", Vector3(0, 0.1, 0.02)), "CucharaEscondida", Vector3.ZERO, Vector3(0.24, 0.02, 0.05), Color(0.75, 0.77, 0.8))

	# Puerta (OR_): el origen del nodo es la bisagra.
	var puerta := _node(_root, "OR_puerta", Vector3(-0.85, 0, -1.27))
	_box(puerta, "Hoja", Vector3(0.28, 0.6, 0), Vector3(0.56, 1.2, 0.05), Color(0.48, 0.32, 0.2))

	# Sub-diorama con zoom (Z_): la casita del ratón. Al completarla da el cuadro.
	var casita := _node(_root, "Z_ratonera__reward-cuadro", Vector3(1.25, 0, -0.85))
	_box(casita, "SueloRaton", Vector3(0, 0.03, 0), Vector3(0.6, 0.06, 0.5), Color(0.9, 0.8, 0.65))
	_box(casita, "ParedRaton", Vector3(0, 0.25, -0.23), Vector3(0.6, 0.4, 0.04), Color(0.95, 0.7, 0.6))
	_box(_node(casita, "P_cama", Vector3(-0.12, 0.06, 0)), "Cama", Vector3(0, 0.04, 0), Vector3(0.2, 0.08, 0.3), Color(0.4, 0.5, 0.85))
	_cyl(_node(casita, "P_mesita", Vector3(0.15, 0.06, 0.05)), "Mesita", Vector3(0, 0.05, 0), 0.06, 0.1, Color(0.8, 0.55, 0.3))

	_box(_node(_root, "P_cuadro__after-lampara", Vector3(0.2, 1.35, -1.27)), "Cuadro", Vector3.ZERO, Vector3(0.55, 0.4, 0.04), Color(0.3, 0.45, 0.75))

	_own(_root)
	var packed := PackedScene.new()
	var err := packed.pack(_root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("NIVEL MUESTRA %s err=%d" % [OUT, err])
	_root.free()
	quit(0 if err == OK else 1)


func _node(parent: Node, n: String, pos: Vector3) -> Node3D:
	var x := Node3D.new()
	x.name = n
	x.position = pos
	parent.add_child(x)
	return x


func _mesh(parent: Node, n: String, pos: Vector3, mesh: Mesh, color: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mesh.surface_set_material(0, mat)
	var m := MeshInstance3D.new()
	m.name = n
	m.mesh = mesh
	m.position = pos
	parent.add_child(m)
	return m


func _box(parent: Node, n: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(parent, n, pos, b, color)


func _cyl(parent: Node, n: String, pos: Vector3, r: float, h: float, color: Color) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	return _mesh(parent, n, pos, c, color)


func _sphere(parent: Node, n: String, pos: Vector3, r: float, color: Color) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return _mesh(parent, n, pos, s, color)


## Para que PackedScene guarde un nodo, su owner tiene que ser la raíz.
func _own(n: Node) -> void:
	for c in n.get_children():
		c.owner = _root
		_own(c)
