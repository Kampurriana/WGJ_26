extends "res://tools/build_sample_level.gd"
## Genera levels/level_01_habitacion.tscn: una habitación japonesa de estudio con los 16 modelos
## del pack Modern Japanese Home Props (MIT, assets/modelos/ModernJapaneseHomePropsLite).
## Los modelos van a su tamaño real (metros) y se instancian por referencia (no se copian).
## La arquitectura (peana, tatami, paredes, mesa baja, cajonera) son figuras simples: el pack no
## la trae. Ejecutar:
##   godot --headless --path . --script res://tools/build_room_level.gd
##
## Puzle:
##   muebles grandes: escritorio, silla, estantería
##   encima del escritorio (__after-escritorio): monitor, lámpara, taza, ratón, altavoz, cuaderno, boli
##   en la estantería (__after-estanteria): dos libros iguales, manga, reloj
##   escondido: el boli, dentro del cajón de la cajonera (OD_ + H_)
##   rincón con zoom (Z_): mesa baja con pila de mangas, mando y pañuelos; da el cuaderno

const ROOM_OUT := "res://levels/level_01_habitacion.tscn"
const PACK := "res://assets/modelos/ModernJapaneseHomePropsLite/addons/modern_japanese_home_props/models/"
const MODELS := {
	"book_01": "books/book_01.glb", "manga_01": "books/manga_01.glb", "manga_stack_01": "books/manga_stack_01.glb",
	"monitor_01": "computer/monitor_01.glb", "mouse_01": "computer/mouse_01.glb",
	"clock_01": "electronics/clock_01.glb", "remote_01": "electronics/remote_01.glb", "speaker_01": "electronics/speaker_01.glb",
	"bookshelf_01": "furniture/bookshelf_01.glb", "chair_01": "furniture/chair_01.glb", "desk_01": "furniture/desk_01.glb",
	"tissue_box_01": "household/tissue_box_01.glb", "lamp_01": "lighting/lamp_01.glb",
	"notebook_01": "stationery/notebook_01.glb", "pen_01": "stationery/pen_01.glb", "mug_01": "tableware/mug_01.glb",
}
const DESK_TOP := 0.74                       ## altura del tablero del escritorio (medida del modelo)
const SHELVES := [0.058, 0.385, 0.712, 1.07] ## baldas de la estantería (medidas en la demo del pack)


func _initialize() -> void:
	_root = Node3D.new()
	_root.name = "Nivel01Habitacion"
	_root.set_script(load("res://core/diorama.gd"))
	_root.set("level_title", "La habitación de estudio")
	_root.set("intro_key", "intro_habitacion")
	_root.set("outro_key", "fin_habitacion")
	_root.set("color_radius", 0.9)
	_root.set("camera_distance", 5.0)
	_root.set("camera_min_distance", 1.5)          ## zoom máximo: para colocar ratón, boli, mando
	_root.set("camera_max_distance", 6.0)
	_root.set("camera_yaw_min_deg", -12.0)         ## más a la izquierda, la pared izquierda tapa la habitación
	_root.set("camera_yaw_max_deg", 70.0)          ## más a la derecha, se ve el canto de la pared del fondo
	_root.set("camera_pitch_min_deg", 15.0)
	_root.set("camera_pitch_max_deg", 60.0)
	_root.set("camera_pitch_deg", 30.0)
	_root.set("camera_yaw_deg", 25.0)

	# --- Arquitectura (figuras simples) ---
	var wood := Color(0.55, 0.36, 0.22)
	var light_wood := Color(0.78, 0.62, 0.42)
	var wall := Color(0.84, 0.79, 0.7)        ## más claro quema con el sol de frente (medido)
	_cyl(_root, "Peana", Vector3(0, -0.16, 0), 1.75, 0.26, wood)
	_box(_root, "Tatami", Vector3(0, -0.015, 0), Vector3(2.6, 0.03, 2.3), Color(0.8, 0.76, 0.52))
	for i in 3:                               # bordes oscuros de los tatamis
		_box(_root, "BordeTatami%d" % (i + 1), Vector3(-0.43 + i * 0.87, 0.001, 0.05), Vector3(0.03, 0.004, 2.2), Color(0.28, 0.33, 0.22))
	_box(_root, "ParedFondo", Vector3(0, 0.8, -1.12), Vector3(2.6, 1.6, 0.06), wall)
	_box(_root, "ParedIzquierda", Vector3(-1.27, 0.8, 0), Vector3(0.06, 1.6, 2.3), wall)
	_box(_root, "Zocalo", Vector3(0, 0.04, -1.08), Vector3(2.6, 0.08, 0.02), light_wood)
	# Ventana tipo shoji en la pared del fondo.
	_box(_root, "Shoji", Vector3(0.7, 1.05, -1.085), Vector3(0.8, 0.6, 0.01), Color(0.88, 0.85, 0.77))
	for x in [-0.4, 0.0, 0.4]:
		_box(_root, "ShojiV%d" % int(x * 10 + 5), Vector3(0.7 + x, 1.05, -1.078), Vector3(0.025, 0.62, 0.015), light_wood)
	for y in [-0.3, -0.1, 0.1, 0.3]:
		_box(_root, "ShojiH%d" % int(y * 10 + 5), Vector3(0.7, 1.05 + y, -1.078), Vector3(0.82, 0.025, 0.015), light_wood)

	# --- Muebles grandes ---
	var desk := Vector3(0.15, 0, -0.78)
	_prop(_root, "P_escritorio", "desk_01", desk)
	_prop(_root, "P_silla", "chair_01", Vector3(0.12, 0, -0.18), 180.0)
	var shelf := Vector3(-0.92, 0, -0.95)
	_prop(_root, "P_estanteria", "bookshelf_01", shelf)

	# --- Encima del escritorio ---
	_prop(_root, "P_monitor__after-escritorio", "monitor_01", desk + Vector3(-0.02, DESK_TOP, -0.12))
	var lampara := _prop(_root, "P_lampara__after-escritorio", "lamp_01", desk + Vector3(-0.42, DESK_TOP, -0.12))
	_lamp_light(lampara)
	_prop(_root, "P_altavoz__after-escritorio", "speaker_01", desk + Vector3(0.40, DESK_TOP, -0.13))
	_prop(_root, "P_taza__after-escritorio", "mug_01", desk + Vector3(-0.38, DESK_TOP, 0.13))
	_prop(_root, "P_raton__after-escritorio", "mouse_01", desk + Vector3(0.33, DESK_TOP, 0.14))
	_prop(_root, "P_cuaderno__after-escritorio", "notebook_01", desk + Vector3(-0.06, DESK_TOP, 0.14), -8.0)
	_prop(_root, "P_boli__after-escritorio", "pen_01", desk + Vector3(0.10, DESK_TOP, 0.14), 6.0)

	# --- En la estantería ---
	_prop(_root, "P_libro__after-estanteria", "book_01", shelf + Vector3(-0.15, SHELVES[2], 0.0))
	_prop(_root, "P_libro__after-estanteria_001", "book_01", shelf + Vector3(0.12, SHELVES[2], 0.0), 4.0)
	_prop(_root, "P_manga__after-estanteria", "manga_01", shelf + Vector3(0.0, SHELVES[1], 0.0))
	_prop(_root, "P_reloj__after-estanteria", "clock_01", shelf + Vector3(0.12, SHELVES[3], 0.02))

	# --- Cajonera con un cajón (OD_) y el boli escondido dentro (H_) ---
	var drawers := Vector3(0.98, 0, -0.85)
	_box(_root, "Cajonera", drawers + Vector3(0, 0.27, 0), Vector3(0.42, 0.54, 0.42), light_wood)
	var cajon := _node(_root, "OD_cajon", drawers + Vector3(0, 0.44, 0.02))
	_box(cajon, "FrenteCajon", Vector3.ZERO, Vector3(0.38, 0.15, 0.4), Color(0.7, 0.53, 0.34))
	_box(cajon, "Tirador", Vector3(0, 0.0, 0.205), Vector3(0.12, 0.02, 0.015), Color(0.25, 0.22, 0.2))
	var boli := _node(cajon, "H_boli", Vector3(0, 0.08, 0.0))
	_instance(boli, "pen_01")

	# --- Rincón de la mesa baja (Z_): al completarlo da el cuaderno ---
	var rincon := _node(_root, "Z_rincon__reward-cuaderno", Vector3(-0.62, 0, 0.55))
	_box(rincon, "Zabuton", Vector3(0.0, 0.03, 0.42), Vector3(0.42, 0.06, 0.42), Color(0.62, 0.3, 0.3))
	_box(rincon, "TableroMesaBaja", Vector3(0, 0.3, 0), Vector3(0.7, 0.04, 0.5), light_wood)
	for x in [-0.31, 0.31]:
		for z in [-0.21, 0.21]:
			_box(rincon, "PataMesa%d%d" % [int(x > 0), int(z > 0)], Vector3(x, 0.14, z), Vector3(0.05, 0.28, 0.05), wood)
	_prop(rincon, "P_mangas", "manga_stack_01", Vector3(-0.2, 0.32, -0.05), 12.0)
	_prop(rincon, "P_mando", "remote_01", Vector3(0.06, 0.32, 0.08), -20.0)
	_prop(rincon, "P_panuelos", "tissue_box_01", Vector3(0.2, 0.32, -0.1), 8.0)

	_own(_root)
	var packed := PackedScene.new()
	var err := packed.pack(_root)
	if err == OK:
		err = ResourceSaver.save(packed, ROOM_OUT)
	print("NIVEL HABITACION %s err=%d" % [ROOM_OUT, err])
	_root.free()
	quit(0 if err == OK else 1)


## Una pieza P_ (o cualquier nodo) con el modelo dentro: el nodo lleva posición y giro; el modelo,
## su origen en la base (así lo exporta el pack) a 0,0,0.
func _prop(parent: Node, n: String, model: String, pos: Vector3, rot_y := 0.0) -> Node3D:
	var holder := _node(parent, n, pos)
	holder.rotation_degrees.y = rot_y
	_instance(holder, model)
	return holder


## La lámpara del escritorio alumbra de verdad: un foco cálido desde la pantalla hacia la mesa.
## Cuelga de la pieza, así está apagado hasta colocarla y entonces se enciende (PieceSlot.fill).
func _lamp_light(lamp: Node3D) -> void:
	var box := Visuals.local_aabb(lamp)
	var luz := SpotLight3D.new()
	luz.name = "Luz"
	luz.position = Vector3(box.get_center().x, box.end.y - 0.04, box.get_center().z)
	luz.rotation_degrees = Vector3(-90, 0, 0)
	luz.light_color = Color(1.0, 0.8, 0.55)
	luz.light_energy = 1.1                         # quinta nota: quemaba la mesa (medido)
	luz.spot_range = 1.2
	luz.spot_angle = 55.0
	luz.spot_attenuation = 1.2
	lamp.add_child(luz)


func _instance(parent: Node, model: String) -> Node3D:
	var scene := load(PACK + MODELS[model]) as PackedScene
	var inst := scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	inst.name = "Modelo"
	parent.add_child(inst)
	return inst


## Como el de la muestra, pero sin entrar en los modelos instanciados: se guardan como referencia
## al .glb (si se adueñara de sus hijos, se copiarían enteros dentro del .tscn).
func _own(n: Node) -> void:
	for c in n.get_children():
		c.owner = _root
		if c.scene_file_path == "":
			_own(c)
