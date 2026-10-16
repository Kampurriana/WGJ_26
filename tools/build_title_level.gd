extends "res://tools/build_sample_level.gd"
## Genera el diorama del título, como en Woodo: un cofre de madera decorado. Se montan las LETRAS
## del nombre del juego (una pieza por letra; las letras repetidas valen en cualquiera de sus
## huecos) y, encima del cofre, un paisaje pequeño (casita, árboles, faroles que se encienden,
## banco). Al acabar sale el menú. Ejecutar:
##   godot --headless --path . --script res://tools/build_title_level.gd
##
## Escribe DOS ficheros:
##   levels/provisional/menu_provisional.glb  el modelo: UN asset con la convención de nombres P_
##                                            (lo mismo que exportarán las artistas desde Blender)
##   levels/menu_titulo.tscn                  el nivel: solo el Diorama con sus ajustes; carga el
##                                            modelo al empezar
## Cuando exista assets/modelos/menu/menu.glb (el de las artistas), el nivel usa ese sin tocar nada.
## Si cambia el nombre del juego (project.godot), volver a ejecutar esto para rehacer las letras.

const TITLE_OUT := "res://levels/menu_titulo.tscn"
const MODEL_OUT := "res://levels/provisional/menu_provisional.glb"
const ART_MODEL := "res://assets/modelos/menu/menu.glb"
const LETTER_HEIGHT := 0.34
const LETTER_DEPTH := 0.1
const LETTER_GAP := 0.05
const WORD_GAP := 0.2
const LETTER_ROW_Z := 0.86

var _mats: Dictionary = {}


func _initialize() -> void:
	var title := String(ProjectSettings.get_setting("application/config/name", "Diorama"))
	var model := Node3D.new()
	model.name = "Cofre"
	_root = model                                   # _own() de la muestra se adueña desde aquí
	_build_chest(model)
	_build_meadow(model)
	_build_letters(model, title)
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
	level.set("color_radius", 0.75)
	level.set("camera_distance", 5.6)
	level.set("camera_min_distance", 1.8)
	level.set("camera_max_distance", 7.5)
	level.set("camera_pitch_deg", 20.0)
	level.set("camera_yaw_deg", 0.0)
	level.set("camera_yaw_min_deg", -55.0)          ## las letras tienen que poder leerse
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


# --- El cofre (decorado: empieza en madera cruda y se pinta con la onda) ---------------------

func _build_chest(root: Node3D) -> void:
	var wood := Color(0.55, 0.33, 0.2)
	var dark := Color(0.32, 0.2, 0.13)
	var iron := Color(0.25, 0.24, 0.26)
	_cyl(root, "Peana", Vector3(0, -0.1, 0), 1.55, 0.2, Color(0.42, 0.27, 0.17))
	_cyl(root, "PeanaBorde", Vector3(0, 0.005, 0), 1.5, 0.01, Color(0.62, 0.45, 0.28))
	# Tarima de las letras, delante del cofre.
	_box(root, "Tarima", Vector3(0, 0.03, LETTER_ROW_Z), Vector3(2.7, 0.06, 0.34), Color(0.7, 0.5, 0.32))
	var chest := _node(root, "CuerpoCofre", Vector3(0, 0, -0.25))
	_box(chest, "Caja", Vector3(0, 0.42, 0), Vector3(2.0, 0.7, 1.05), wood)
	_box(chest, "Tapa", Vector3(0, 0.82, 0), Vector3(2.08, 0.1, 1.13), dark)
	for x in [-0.98, 0.98]:
		for z in [-0.48, 0.48]:
			_box(chest, "Pata%d%d" % [int(x > 0), int(z > 0)], Vector3(x, 0.035, z), Vector3(0.14, 0.07, 0.14), dark)
	for x in [-0.62, 0.62]:
		_box(chest, "Herraje%d" % int(x > 0), Vector3(x, 0.42, 0.53), Vector3(0.1, 0.72, 0.02), iron)
	_box(chest, "Cerradura", Vector3(0, 0.62, 0.535), Vector3(0.18, 0.2, 0.03), Color(0.78, 0.6, 0.25))
	_box(chest, "Tablon1", Vector3(0, 0.3, 0.527), Vector3(1.9, 0.015, 0.01), dark)
	_box(chest, "Tablon2", Vector3(0, 0.55, 0.527), Vector3(1.9, 0.015, 0.01), dark)


## Encima de la tapa: un prado con camino, estanque y flores (decorado) y sus huecos P_.
func _build_meadow(root: Node3D) -> void:
	var top := Vector3(0, 0.875, -0.25)                 # superficie de la tapa
	var meadow := _node(root, "Prado", top)
	_box(meadow, "Hierba", Vector3(0, 0.02, 0), Vector3(1.94, 0.04, 1.0), Color(0.5, 0.72, 0.36))
	_box(meadow, "Camino", Vector3(0.1, 0.042, 0.12), Vector3(0.22, 0.01, 0.76), Color(0.85, 0.72, 0.5))
	_cyl(meadow, "Estanque", Vector3(0.62, 0.043, 0.18), 0.17, 0.012, Color(0.35, 0.6, 0.85))
	var flowers := [[Vector3(-0.78, 0.07, 0.36), Color(0.95, 0.45, 0.5)], [Vector3(-0.55, 0.07, 0.42), Color(0.98, 0.85, 0.35)],
		[Vector3(0.38, 0.07, 0.4), Color(0.75, 0.55, 0.95)], [Vector3(0.85, 0.07, -0.3), Color(0.98, 0.6, 0.3)],
		[Vector3(-0.2, 0.07, 0.42), Color(0.98, 0.95, 0.9)]]
	for i in flowers.size():
		_sphere(meadow, "Flor%d" % (i + 1), flowers[i][0], 0.035, flowers[i][1])
	var y := top.y + 0.04
	_casita(_node(root, "P_casita", Vector3(0.12, y, -0.55)))
	_arbol(_node(root, "P_arbol", Vector3(-0.72, y, -0.5)))
	_arbol(_node(root, "P_arbol_001", Vector3(-0.42, y, -0.62)))
	_farol(_node(root, "P_farol", Vector3(-0.12, y, 0.08)))
	_farol(_node(root, "P_farol_001", Vector3(0.36, y, 0.08)))
	var banco := _node(root, "P_banco", Vector3(0.62, y, -0.38))
	banco.rotation_degrees.y = -20.0
	_banco(banco)


func _casita(n: Node3D) -> void:
	_box(n, "Paredes", Vector3(0, 0.15, 0), Vector3(0.4, 0.3, 0.3), Color(0.96, 0.9, 0.78))
	var roof := _cyl(n, "Tejado", Vector3(0, 0.38, 0), 0.25, 0.46, Color(0.82, 0.34, 0.24))
	(roof.mesh as CylinderMesh).radial_segments = 3
	roof.rotation_degrees = Vector3(0, 0, 90)
	roof.scale = Vector3(1.0, 1.0, 0.75)
	_box(n, "Puerta", Vector3(0, 0.08, 0.152), Vector3(0.09, 0.16, 0.01), Color(0.45, 0.28, 0.17))
	_box(n, "Ventana", Vector3(0.12, 0.18, 0.152), Vector3(0.07, 0.07, 0.01), Color(0.55, 0.78, 0.95))
	_box(n, "Chimenea", Vector3(-0.1, 0.48, -0.04), Vector3(0.06, 0.12, 0.06), Color(0.55, 0.35, 0.28))


func _arbol(n: Node3D) -> void:
	_cyl(n, "Tronco", Vector3(0, 0.1, 0), 0.03, 0.2, Color(0.45, 0.29, 0.18))
	for i in 3:
		var cone := _cyl(n, "Copa%d" % (i + 1), Vector3(0, 0.25 + i * 0.12, 0), 0.0, 0.22 - i * 0.03, Color(0.3, 0.55, 0.3))
		var cm := cone.mesh as CylinderMesh
		cm.bottom_radius = 0.17 - i * 0.04
		cm.top_radius = 0.0


func _farol(n: Node3D) -> void:
	var iron := Color(0.2, 0.19, 0.21)
	_cyl(n, "Poste", Vector3(0, 0.18, 0), 0.012, 0.36, iron)
	_box(n, "Base", Vector3(0, 0.015, 0), Vector3(0.07, 0.03, 0.07), iron)
	var glass := _box(n, "Cristal", Vector3(0, 0.4, 0), Vector3(0.07, 0.09, 0.07), Color(1.0, 0.85, 0.5))
	(glass.mesh as BoxMesh).material = _glow_material()
	_box(n, "Tejadillo", Vector3(0, 0.46, 0), Vector3(0.1, 0.025, 0.1), iron)
	var luz := OmniLight3D.new()
	luz.name = "Luz"
	luz.position = Vector3(0, 0.4, 0)
	luz.light_color = Color(1.0, 0.75, 0.45)
	luz.light_energy = 0.7
	luz.omni_range = 0.8
	luz.omni_attenuation = 1.4
	n.add_child(luz)


func _banco(n: Node3D) -> void:
	var wood := Color(0.62, 0.4, 0.24)
	_box(n, "Asiento", Vector3(0, 0.1, 0), Vector3(0.3, 0.025, 0.1), wood)
	_box(n, "Respaldo", Vector3(0, 0.17, -0.045), Vector3(0.3, 0.08, 0.02), wood)
	for x in [-0.12, 0.12]:
		_box(n, "Pata%d" % int(x > 0), Vector3(x, 0.045, 0), Vector3(0.025, 0.09, 0.08), Color(0.35, 0.22, 0.14))


# --- Las letras del nombre del juego ---------------------------------------------------------

func _build_letters(root: Node3D, title: String) -> void:
	var chars := title.to_upper()
	var palette := [Color(0.9, 0.36, 0.26), Color(0.98, 0.76, 0.3), Color(0.42, 0.68, 0.38),
		Color(0.32, 0.55, 0.85), Color(0.86, 0.45, 0.62), Color(0.95, 0.58, 0.25)]
	# Primero se miden todas para centrar la fila.
	var items: Array = []
	var width := 0.0
	var color_of: Dictionary = {}                      # letras iguales, mismo color (son la misma pieza)
	for i in chars.length():
		var ch := chars[i]
		if ch == " ":
			items.append(null)
			width += WORD_GAP
			continue
		var id := _letter_id(ch)
		if id == "":
			continue
		if not color_of.has(id):
			color_of[id] = palette[color_of.size() % palette.size()]
		var mesh := _letter_mesh(ch, color_of[id])
		items.append([id, mesh])
		width += mesh.get_aabb().size.x + LETTER_GAP
	var x := -width * 0.5
	var seen: Dictionary = {}
	for it: Variant in items:
		if it == null:
			x += WORD_GAP
			continue
		var id: String = it[0]
		var mesh: TextMesh = it[1]
		var box := mesh.get_aabb()
		var copy := seen.get(id, 0) as int
		seen[id] = copy + 1
		var holder := _node(root, "P_" + id + ("" if copy == 0 else "_%03d" % copy),
			Vector3(x + box.size.x * 0.5, 0.06, LETTER_ROW_Z))
		var m := MeshInstance3D.new()
		m.name = "Letra"
		m.mesh = mesh
		m.position = -box.get_center() + Vector3(0, box.size.y * 0.5, 0)   # base de la letra en el suelo
		holder.add_child(m)
		x += box.size.x + LETTER_GAP


## Id de la pieza de una letra: letra_a, letra_n (Ñ), letra_7... "" si no es letra ni número.
func _letter_id(ch: String) -> String:
	const PLAIN := {"Á": "A", "É": "E", "Í": "I", "Ó": "O", "Ú": "U", "Ü": "U", "Ñ": "N", "Ç": "C"}
	var c := String(PLAIN.get(ch, ch)).to_lower()
	if c.length() != 1 or not (c >= "a" and c <= "z" or c >= "0" and c <= "9"):
		return ""
	return "letra_" + c


func _letter_mesh(ch: String, color: Color) -> TextMesh:
	var tm := TextMesh.new()
	tm.text = ch
	tm.font_size = 64
	tm.depth = LETTER_DEPTH
	tm.curve_step = 2.0
	tm.pixel_size = 0.01
	var h := tm.get_aabb().size.y                     # se escala para que mida LETTER_HEIGHT
	tm.pixel_size = 0.01 * LETTER_HEIGHT / maxf(h, 0.001)
	tm.material = _material(color)
	return tm


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.75
		_mats[key] = m
	return _mats[key]


func _glow_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.55)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.72, 0.4)
	m.emission_energy_multiplier = 2.5
	return m
