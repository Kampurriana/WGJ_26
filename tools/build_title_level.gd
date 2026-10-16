extends "res://tools/build_sample_level.gd"
## Genera levels/menu_titulo.tscn: el puzle que desbloquea el menú de inicio. Es un diorama de
## verdad (core/diorama.gd) pero sencillo: 4 piezas, sin orden, sin escondidos y sin rincones.
## Sirve de tutorial: arrastrar cada pieza a su silueta. El letrero lleva el nombre del juego
## (Label3D "Titulo"; main.gd le pone el nombre del proyecto al cargarlo). Ejecutar:
##   godot --headless --path . --script res://tools/build_title_level.gd
## Cuando las artistas lo hagan en Blender: assets/modelos/menu/menu.glb con los mismos P_.

const TITLE_OUT := "res://levels/menu_titulo.tscn"


func _initialize() -> void:
	_root = Node3D.new()
	_root.name = "MenuTitulo"
	_root.set_script(load("res://core/diorama.gd"))
	_root.set("level_title", "")
	_root.set("intro_key", "intro_menu")
	_root.set("outro_key", "fin_menu")
	_root.set("color_radius", 1.1)
	_root.set("camera_distance", 5.2)
	_root.set("camera_min_distance", 2.6)
	_root.set("camera_max_distance", 7.5)
	_root.set("camera_pitch_deg", 16.0)
	_root.set("camera_yaw_deg", 0.0)

	var wood := Color(0.62, 0.42, 0.26)
	var dark_wood := Color(0.45, 0.29, 0.18)
	_cyl(_root, "Base", Vector3(0, -0.13, 0), 1.45, 0.26, Color(0.55, 0.36, 0.22))
	_cyl(_root, "Hierba", Vector3(0, 0.02, 0), 1.36, 0.04, Color(0.56, 0.74, 0.42))
	# Postes del letrero (fijos: el letrero se cuelga de ellos).
	for x in [-0.82, 0.82]:
		_box(_root, "Poste%d" % (1 if x < 0 else 2), Vector3(x, 0.62, -0.25), Vector3(0.09, 1.24, 0.09), dark_wood)
	# Flores sueltas: se colorean con la onda al colocar las piezas.
	var flores := [[Vector3(-0.5, 0.08, 0.75), Color(0.95, 0.45, 0.5)], [Vector3(0.55, 0.08, 0.95), Color(0.98, 0.85, 0.35)],
		[Vector3(-1.05, 0.08, -0.35), Color(0.7, 0.55, 0.95)], [Vector3(1.1, 0.08, -0.5), Color(0.95, 0.6, 0.3)]]
	for i in flores.size():
		_sphere(_root, "Flor%d" % (i + 1), flores[i][0], 0.07, flores[i][1])

	# 1. El letrero con el título.
	var letrero := _node(_root, "P_letrero", Vector3(0, 1.0, -0.25))
	_box(letrero, "Tabla", Vector3.ZERO, Vector3(1.9, 0.62, 0.08), wood)
	_box(letrero, "Marco", Vector3(0, 0, -0.01), Vector3(2.0, 0.72, 0.06), dark_wood)
	var titulo := Label3D.new()
	titulo.name = "Titulo"
	titulo.text = "Diorama"
	titulo.position = Vector3(0, 0, 0.045)
	titulo.font_size = 72
	titulo.pixel_size = 0.004
	titulo.outline_size = 14
	titulo.modulate = Color(1.0, 0.95, 0.82)
	titulo.outline_modulate = Color(0.3, 0.19, 0.11)
	titulo.width = 440.0
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	letrero.add_child(titulo)

	# 2. Un farol (con su luz: se enciende al colocarlo).
	var farol := _node(_root, "P_farol", Vector3(-1.0, 0, 0.35))
	_cyl(farol, "Palo", Vector3(0, 0.45, 0), 0.03, 0.9, Color(0.22, 0.22, 0.25))
	_box(farol, "Caja", Vector3(0, 0.98, 0), Vector3(0.18, 0.22, 0.18), Color(1.0, 0.86, 0.45))
	_box(farol, "Tejadillo", Vector3(0, 1.12, 0), Vector3(0.24, 0.05, 0.24), Color(0.22, 0.22, 0.25))
	var luz := OmniLight3D.new()
	luz.name = "Luz"
	luz.position = Vector3(0, 0.98, 0)
	luz.light_color = Color(1.0, 0.82, 0.5)
	luz.light_energy = 0.8
	luz.omni_range = 1.4
	farol.add_child(luz)

	# 3. Un árbol pequeño.
	var arbol := _node(_root, "P_arbol", Vector3(1.0, 0, 0.3))
	_cyl(arbol, "Tronco", Vector3(0, 0.35, 0), 0.07, 0.7, wood)
	_sphere(arbol, "Copa", Vector3(0, 0.85, 0), 0.32, Color(0.37, 0.62, 0.3))

	# 4. Un banco delante del letrero.
	var banco := _node(_root, "P_banco", Vector3(0.05, 0, 0.55))
	_box(banco, "Asiento", Vector3(0, 0.3, 0), Vector3(0.8, 0.06, 0.26), wood)
	for x in [-0.32, 0.32]:
		_box(banco, "Pata%d" % (1 if x < 0 else 2), Vector3(x, 0.14, 0), Vector3(0.06, 0.28, 0.22), dark_wood)

	_own(_root)
	var packed := PackedScene.new()
	var err := packed.pack(_root)
	if err == OK:
		err = ResourceSaver.save(packed, TITLE_OUT)
	print("NIVEL TITULO %s err=%d" % [TITLE_OUT, err])
	_root.free()
	quit(0 if err == OK else 1)
