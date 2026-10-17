extends "res://tools/build_sample_level.gd"
## Genera el diorama del título: la HUCHA DE CERDITO de la protagonista, sobre un cojín, hecha
## piezas. Se monta como todo el juego (bandeja de la derecha, siluetas): primero el cuerpo; luego
## patas, hocico, orejas, cola, ojos, ranura, coloretes y lazo; y sobre todo PEGATINAS (estrella,
## corazón, flor, luna, rayo, arcoíris y la del nombre del juego, en el cartel de delante). 21 piezas. Al acabar sale el menú. Ejecutar:
##   godot --headless --path . --script res://tools/build_title_level.gd
##
## Escribe DOS ficheros:
##   levels/provisional/menu_provisional.glb  el modelo: UN asset con la convención de nombres P_
##                                            (lo mismo que exportarán las artistas desde Blender)
##   levels/menu_titulo.tscn                  el nivel: solo el Diorama con sus ajustes; carga el
##                                            modelo al empezar
## Cuando exista assets/modelos/menu/menu.glb (el de las artistas), el nivel usa ese sin tocar nada.
## Si cambia el nombre del juego (project.godot), volver a ejecutar esto para rehacer la pegatina.

const TITLE_OUT := "res://levels/menu_titulo.tscn"
const MODEL_OUT := "res://levels/provisional/menu_provisional.glb"
const ART_MODEL := "res://assets/modelos/menu/menu.glb"
const PINK := Color(0.95, 0.62, 0.68)
const PINK_DARK := Color(0.84, 0.5, 0.57)
const BODY_C := Vector3(0, 0.62, 0)          ## centro del cuerpo (en el grupo de la hucha)
const BODY_R := Vector3(0.675, 0.5, 0.5)     ## semiejes del cuerpo (una esfera estirada)
const PIG_YAW := -35.0                       ## la hucha mira de tres cuartos: se le ve la cara

var _mats: Dictionary = {}


func _initialize() -> void:
	var title := String(ProjectSettings.get_setting("application/config/name", "Diorama"))
	var model := Node3D.new()
	model.name = "Cerdito"
	_root = model                                   # _own() de la muestra se adueña desde aquí
	_build_base(model)
	var pig := _node(model, "Hucha", Vector3(0, 0.2, -0.05))
	pig.rotation_degrees.y = PIG_YAW
	_build_pig(pig)
	_build_stickers(pig)
	_build_sign(model, title)
	_own(model)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MODEL_OUT.get_base_dir()))
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(model, state)
	if err == OK:
		err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(MODEL_OUT))
	print("MODELO TITULO %s err=%d" % [MODEL_OUT, err])
	model.free()
	if err != OK:
		quit(1)
		return

	var level := Node3D.new()
	level.name = "MenuTitulo"
	level.set_script(load("res://core/diorama.gd"))
	level.set("level_title", "")
	level.set("modelo", ART_MODEL)
	level.set("modelo_provisional", MODEL_OUT)
	level.set("intro_key", "intro_menu")
	level.set("outro_key", "fin_menu")
	level.set("color_radius", 0.55)
	level.set("camera_distance", 4.6)
	level.set("camera_min_distance", 1.4)
	level.set("camera_max_distance", 6.5)
	level.set("camera_pitch_deg", 18.0)
	level.set("camera_yaw_deg", 0.0)
	level.set("camera_yaw_min_deg", -55.0)          ## las pegatinas y el cartel tienen que verse
	level.set("camera_yaw_max_deg", 55.0)
	level.set("camera_pitch_min_deg", 6.0)
	level.set("camera_pitch_max_deg", 55.0)
	level.set("iluminacion", "res://iluminacion/menu.tscn")
	var packed := PackedScene.new()
	err = packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, TITLE_OUT)
	print("NIVEL TITULO %s err=%d" % [TITLE_OUT, err])
	level.free()
	quit(0 if err == OK else 1)


# --- Decorado: peana de madera y cojín (empiezan en madera cruda y se pintan) -----------------

func _build_base(root: Node3D) -> void:
	_cyl(root, "Peana", Vector3(0, -0.1, 0), 1.35, 0.2, Color(0.42, 0.27, 0.17))
	_cyl(root, "PeanaBorde", Vector3(0, 0.005, 0), 1.3, 0.01, Color(0.62, 0.45, 0.28))
	var cushion := _cyl(root, "Cojin", Vector3(0, 0.1, -0.05), 1.0, 0.18, Color(0.55, 0.36, 0.55))
	(cushion.mesh as CylinderMesh).rings = 2
	_cyl(root, "CojinRibete", Vector3(0, 0.19, -0.05), 1.01, 0.025, Color(0.95, 0.8, 0.45))
	# Unas monedas sueltas sobre el cojín (los ahorros).
	var coins := [Vector3(-0.62, 0.198, 0.42), Vector3(-0.5, 0.198, 0.55), Vector3(0.7, 0.198, 0.3), Vector3(0.58, 0.212, 0.38)]
	for i in coins.size():
		var c := _cyl(root, "Moneda%d" % (i + 1), coins[i], 0.06, 0.016, Color(0.95, 0.76, 0.3))
		c.rotation_degrees.z = 4.0 * (i % 2)


# --- La hucha: cuerpo, patas, cara ------------------------------------------------------------

func _build_pig(pig: Node3D) -> void:
	var body := _node(pig, "P_cuerpo", BODY_C)
	var shell := _sphere(body, "Cuerpo", Vector3.ZERO, 0.5, PINK)
	shell.scale = Vector3(BODY_R.x / 0.5, 1.0, 1.0)
	var k := 0
	for x in [-0.36, 0.36]:
		for z in [-0.22, 0.22]:
			var leg := _node(pig, "P_pata__after-cuerpo" + ("" if k == 0 else "_%03d" % k), Vector3(x, 0.17, z))
			_cyl(leg, "Pata", Vector3.ZERO, 0.1, 0.34, PINK_DARK)
			_cyl(leg, "Pezuna", Vector3(0, -0.16, 0), 0.105, 0.03, Color(0.55, 0.3, 0.32))
			k += 1
	var snout := _node(pig, "P_hocico__after-cuerpo", Vector3(0.7, 0.6, 0))
	var nose := _cyl(snout, "Hocico", Vector3.ZERO, 0.17, 0.14, PINK_DARK)
	nose.rotation_degrees.z = 90.0
	for z in [-0.06, 0.06]:
		var hole := _sphere(snout, "Agujero%d" % int(z > 0), Vector3(0.068, 0, z), 0.032, Color(0.45, 0.22, 0.26))
		hole.scale = Vector3(0.4, 1.2, 1.0)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var ear := _node(pig, "P_oreja__after-cuerpo" + ("" if i == 0 else "_001"), Vector3(0.32, 1.06, 0.2 * side))
		var cone := _cyl(ear, "Oreja", Vector3.ZERO, 0.0, 0.22, PINK_DARK)
		(cone.mesh as CylinderMesh).bottom_radius = 0.13
		cone.rotation_degrees = Vector3(18.0 * side, 0, -14.0)
		cone.scale = Vector3(1.0, 1.0, 0.55)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var eye := _node(pig, "P_ojo__after-hocico" + ("" if i == 0 else "_001"), Vector3(0.55, 0.78, 0.24 * side))
		_sphere(eye, "Ojo", Vector3.ZERO, 0.05, Color(0.1, 0.07, 0.08))
		_sphere(eye, "Brillo", Vector3(0.025, 0.02, 0.025 * side), 0.016, Color(1, 1, 1))
	var tail := _node(pig, "P_cola__after-cuerpo", Vector3(-0.7, 0.74, 0))
	var curl := TorusMesh.new()
	curl.inner_radius = 0.035
	curl.outer_radius = 0.085
	var ring := _mesh(tail, "Cola", Vector3.ZERO, curl, PINK_DARK)
	ring.rotation_degrees = Vector3(0, 0, 70)
	_sphere(tail, "Punta", Vector3(-0.03, 0.08, 0.05), 0.03, PINK_DARK)
	var slot := _node(pig, "P_ranura__after-cuerpo", Vector3(0.04, 1.118, 0))
	_box(slot, "Marco", Vector3.ZERO, Vector3(0.09, 0.025, 0.28), Color(0.85, 0.72, 0.4))
	_box(slot, "Ranura", Vector3(0, 0.006, 0), Vector3(0.04, 0.02, 0.22), Color(0.12, 0.08, 0.08))
	var cheeks := _node(pig, "P_mejillas__after-ojo", Vector3.ZERO)
	for side in [-1.0, 1.0]:
		var at: Array = _on_body(0.58, 0.58, side)
		var blush := _cyl(cheeks, "Colorete%d" % int(side > 0), at[0], 0.065, 0.008, Color(0.96, 0.42, 0.5))
		blush.basis = Basis.looking_at(at[1], Vector3.UP, true) * Basis(Vector3.RIGHT, PI * 0.5)
	var bow := _node(pig, "P_lazo__after-oreja", Vector3(0.18, 1.12, -0.16))
	bow.rotation_degrees = Vector3(0, 30, 12)
	var blue := Color(0.35, 0.55, 0.92)
	for side in [-1.0, 1.0]:
		var wing := _cyl(bow, "Ala%d" % int(side > 0), Vector3(0, 0, 0.07 * side), 0.0, 0.14, blue)
		(wing.mesh as CylinderMesh).bottom_radius = 0.06
		wing.rotation_degrees.x = -90.0 * side
		wing.scale = Vector3(1.0, 1.0, 0.5)
	_sphere(bow, "Nudo", Vector3.ZERO, 0.04, blue.darkened(0.15))


## Un punto del cuerpo (en el lado +Z o -Z del grupo, según side) y su normal: ahí se pegan las cosas.
func _on_body(x: float, y: float, side := 1.0) -> Array:
	var dx := x / BODY_R.x
	var dy := (y - BODY_C.y) / BODY_R.y
	var z := BODY_R.z * sqrt(maxf(0.0, 1.0 - dx * dx - dy * dy)) * side
	var nrm := Vector3(x / (BODY_R.x * BODY_R.x), (y - BODY_C.y) / (BODY_R.y * BODY_R.y), z / (BODY_R.z * BODY_R.z)).normalized()
	return [Vector3(x, y, z) + nrm * 0.006, nrm]


# --- Pegatinas ---------------------------------------------------------------------------------

func _build_stickers(pig: Node3D) -> void:
	var star := _sticker(pig, "P_pegatina_estrella__after-cuerpo", -0.38, 0.86, 12.0)
	_flat(star, "Estrella", _star(0.1, 0.045), Color(1.0, 0.84, 0.25))   # solo una pegatina: no brilla (quinta nota)
	_flat(_sticker(pig, "P_pegatina_corazon__after-cuerpo", 0.18, 0.9, -10.0), "Corazon", _heart(0.085), Color(0.95, 0.3, 0.42))
	var flower := _sticker(pig, "P_pegatina_flor__after-cuerpo", -0.5, 0.48, 6.0)
	for i in 5:
		var a := TAU * i / 5.0
		_flat(flower, "Petalo%d" % i, _circle(0.035, Vector2(cos(a), sin(a)) * 0.042), Color(0.98, 0.96, 0.98))
	_flat(flower, "Centro", _circle(0.03, Vector2.ZERO), Color(1.0, 0.78, 0.25), false, 0.016)
	_flat(_sticker(pig, "P_pegatina_luna__after-cuerpo", 0.32, 0.4, 20.0), "Luna", _moon(0.075), Color(0.62, 0.76, 1.0))
	_flat(_sticker(pig, "P_pegatina_rayo__after-cuerpo", -0.25, 0.27, -8.0), "Rayo", _bolt(0.08), Color(1.0, 0.6, 0.15))
	var rainbow := _sticker(pig, "P_pegatina_arcoiris__after-cuerpo", 0.06, 1.0, -4.0)
	var bands := [Color(0.92, 0.3, 0.3), Color(1.0, 0.62, 0.2), Color(1.0, 0.88, 0.3), Color(0.4, 0.75, 0.4), Color(0.38, 0.58, 0.95)]
	for i in bands.size():
		var r := 0.11 - i * 0.017
		_flat(rainbow, "Banda%d" % i, _arc(r, r - 0.017), bands[i], false, 0.012 + i * 0.001)


## El cartel de delante, con la pegatina del nombre del juego.
func _build_sign(root: Node3D, title: String) -> void:
	var sign := _node(root, "Cartel", Vector3(0.05, 0.19, 0.88))
	sign.rotation_degrees.x = -14.0
	_box(sign, "Tabla", Vector3(0, 0.15, 0), Vector3(1.0, 0.3, 0.05), Color(0.66, 0.46, 0.28))
	for x in [-0.42, 0.42]:
		_box(sign, "Clavo%d" % int(x > 0), Vector3(x, 0.15, 0.027), Vector3(0.02, 0.02, 0.01), Color(0.3, 0.3, 0.32))
	var piece := _node(sign, "P_pegatina_nombre__after-cuerpo", Vector3(0, 0.15, 0.03))
	piece.rotation_degrees.z = -3.0
	_flat(piece, "Fondo", _rounded_rect(Vector2(0.78, 0.2), 0.05), Color(0.98, 0.94, 0.84))
	var tm := TextMesh.new()
	tm.text = title.to_upper()
	tm.font_size = 64
	tm.depth = 0.008
	tm.pixel_size = 0.0021
	tm.material = _material(Color(0.42, 0.24, 0.18))
	var text := MeshInstance3D.new()
	text.name = "Nombre-" + title.to_upper().replace(" ", "_")   # el test lee el nombre de aquí
	text.mesh = tm
	text.position = Vector3(0, -0.005, 0.009)
	piece.add_child(text)


## Una pieza-pegatina pegada al cuerpo en (x, y) del lado que se ve, girada `roll` grados.
func _sticker(pig: Node3D, n: String, x: float, y: float, roll: float) -> Node3D:
	var at: Array = _on_body(x, y)
	var s := _node(pig, n, at[0])
	s.basis = Basis.looking_at(at[1], Vector3.UP, true) * Basis(Vector3.FORWARD, deg_to_rad(roll))
	return s


## Una forma plana (polígono en XY) con un poco de grosor: lo que es una pegatina.
func _flat(parent: Node3D, n: String, points: PackedVector2Array, color: Color, glow := false, z := 0.0) -> MeshInstance3D:
	var mesh := _extrude(points, 0.008)
	var m := _mesh(parent, n, Vector3(0, 0, z), mesh, color)
	if glow:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.35
		mesh.surface_set_material(0, mat)
	return m


## Extruye un polígono en Z (tapas delante y detrás, y los lados). Caras de delante en sentido
## horario, que es lo que Godot pinta (medido: build/pruebas/probe_winding.gd).
func _extrude(points: PackedVector2Array, depth: float) -> ArrayMesh:
	var pts := points.duplicate()
	if Geometry2D.is_polygon_clockwise(pts):
		pts.reverse()
	var idx := Geometry2D.triangulate_polygon(pts)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := depth * 0.5
	for i in range(0, idx.size(), 3):
		for cap in [1.0, -1.0]:
			var tri := [pts[idx[i]], pts[idx[i + 1]], pts[idx[i + 2]]]
			_tri(st, Vector3(tri[0].x, tri[0].y, h * cap), Vector3(tri[1].x, tri[1].y, h * cap),
				Vector3(tri[2].x, tri[2].y, h * cap), Vector3(0, 0, cap))
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var out := Vector3(b.y - a.y, a.x - b.x, 0).normalized()      # a la derecha del borde: fuera
		_tri(st, Vector3(a.x, a.y, h), Vector3(b.x, b.y, h), Vector3(b.x, b.y, -h), out)
		_tri(st, Vector3(a.x, a.y, h), Vector3(b.x, b.y, -h), Vector3(a.x, a.y, -h), out)
	return st.commit()


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:             # Godot: cara de delante = sentido horario
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)


func _star(outer: float, inner: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 10:
		var a := PI * 0.5 + TAU * i / 10.0
		var r := outer if i % 2 == 0 else inner
		p.append(Vector2(cos(a), sin(a)) * r)
	return p


func _heart(s: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40.0
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
		p.append(Vector2(x, y) * s / 16.0)
	return p


func _circle(r: float, c: Vector2) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		p.append(c + Vector2(cos(a), sin(a)) * r)
	return p


func _moon(r: float) -> PackedVector2Array:
	var cut := Geometry2D.clip_polygons(_circle(r, Vector2.ZERO), _circle(r * 0.82, Vector2(r * 0.42, r * 0.12)))
	return cut[0] if not cut.is_empty() else _circle(r, Vector2.ZERO)


func _bolt(s: float) -> PackedVector2Array:
	var pts := [Vector2(0.15, 1.0), Vector2(-0.45, 0.0), Vector2(-0.05, 0.05), Vector2(-0.25, -1.0),
		Vector2(0.45, 0.15), Vector2(0.05, 0.1), Vector2(0.35, 1.0)]
	var p := PackedVector2Array()
	for v: Vector2 in pts:
		p.append(v * s)
	return p


func _arc(r_out: float, r_in: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 17:
		var a := PI * i / 16.0
		p.append(Vector2(cos(a), sin(a)) * r_out)
	for i in range(16, -1, -1):
		var a := PI * i / 16.0
		p.append(Vector2(cos(a), sin(a)) * r_in)
	return p


func _rounded_rect(size: Vector2, r: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	var h := size * 0.5 - Vector2(r, r)
	var corners := [Vector2(h.x, h.y), Vector2(-h.x, h.y), Vector2(-h.x, -h.y), Vector2(h.x, -h.y)]
	for k in 4:
		for i in 6:
			var a := PI * 0.5 * k + PI * 0.5 * i / 5.0
			p.append(corners[k] + Vector2(cos(a), sin(a)) * r)
	return p


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.75
		_mats[key] = m
	return _mats[key]
