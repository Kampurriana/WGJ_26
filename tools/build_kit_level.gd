extends "res://tools/build_attic_level.gd"
## EL DESVÁN QUE SE JUEGA (18-oct): la misma historia, secciones, piezas y reglas que el prototipo
## (tools/build_attic_level.gd, que se conserva en levels/prototipo/), pero montada sobre el ARTE
## OFICIAL: el diorama de las artistas (preview/diorama_kit.tscn, que sigue su blocking y se retoca a
## mano en el editor). Cada mueble del kit pasa a ser la pieza de la historia que le toca (instancias del
## tileset, sin escalar). Solo arte de verdad (pedido del 18-oct): el kit de las artistas, el pack de props
## del principio (Modern Japanese Home Props Lite) y los planos de los dibujos (y del lienzo, la luna del
## espejo y la solicitud); nada de figuras hechas con cajas y esferas, salvo la moneda del final (el kit
## no la trae todavía).
##   S_1_desvan        12 tablones de tres largos (4 de cada), las tres paredes (con sus pilares y
##                     rodapiés), la ventana, la viga de arriba (cumbrera), 4 cabrios (vigas), el tejado
##                     (faldón, correas y postes) y la hucha (clave) sobre su caja, en el centro
##   S_2_infancia      izquierda: cómoda → caja de música → dibujo (pared) → nutria (clave, la del kit, en
##                     la cama del gato); la tele, la caja de juguetes (tapa) con el dibujo de la casa
##   S_3_adolescencia  centro, bajo la ventana: el escritorio del kit con sus cajones (la solicitud, en el
##                     de arriba), MP3 → solicitud → cámara (clave y flash: la polaroid del kit, en la caja
##                     con tapa, en la alfombra)
##   S_4_adultez       las llaves (el llavero del kit, en el pilar), el caballete (donde lo dejaron las
##                     artistas, a la izquierda) con su lienzo, y el entrante: llaves → caballete → espejo
##                     (clave, reflejo); el burro con el sombrero, el taburete, folios y papeles arrugados
##   S_5_epilogo       la moneda (ofrecida) junto a la hucha (provisional: la única figura hecha en código)
## Lo que no es de ninguna sección (el marco del suelo, las cajas del fondo, el arenero) se ve desde el
## principio; las cuerdas de bombillitas (apagadas) van con el tejado y la pared del entrante, y la del
## fondo del entrante es la de los dibujos (T_), que aparece con la infancia.
## Ejecutar (después de retocar preview/diorama_kit.tscn):
##   godot --headless --path . --script res://tools/build_kit_level.gd
## Escribe levels/desvan/desvan_oficial.tscn (el modelo) y levels/level_01_desvan.tscn (el nivel).

const KIT_DIORAMA := "res://preview/diorama_kit.tscn"
const MESHES_OUT := "res://levels/desvan/mallas/"        ## los trozos del MP3 y de la hucha (sus mallas)
const OFICIAL_MODEL_OUT := "res://levels/desvan/desvan_oficial.tscn"
const OFICIAL_LEVEL_OUT := "res://levels/level_01_desvan.tscn"
const FLOOR := 0.15                          ## el suelo de tablones del kit está a esta altura
const ROOF_A := Vector2(-3.2, 0.66)          ## el faldón (por debajo): de aquí (x, y)...
const ROOF_B := Vector2(-0.16, 5.05)         ## ...a aquí
const ZONE_LIGHT := 0.8                      ## las luces de zona (sin bombilla: las del kit van apagadas)
const ZONE_RANGE := 3.6
const TILESET := "res://assets/kit/piezas/"
const MIRROR_PAINTED := "res://assets/kit/materiales/M_Pack08.tres"   ## el espejo con ella en la luna (Pack08)
const RUG_TOP := 0.17                         ## la alfombra de la adolescencia (encima, lo que se tumba en ella)
const ADULT_RUG_TOP := 0.19                   ## la de la adultez
const PHOTO_LONG := 0.233                       ## lo largo de una polaroid del kit (tumbada, va de su pie hacia -Z)
const KEYS_AT := Vector3(0.94, 1.15, -1.347)  ## el llavero, en la cara de delante del pilar (la columna acaba en z -1,40)
const KIT_OTTER := "res://assets/kit/modelos/Otter/SM_otter.fbx"
const KIT_OTTER_MAT := "res://assets/kit/materiales/M_Otter.tres"
const OTTER_AT := Vector3(-1.45, FLOOR, 2.3)   ## la nutria, en el suelo del rincón de la infancia
const CAMERA_BOX_AT := Vector2(0.37, 0.72)   ## (x, z) del centro de la caja de la cámara: en la alfombra, lejos de la silla

var _art: Node3D                             ## el diorama de las artistas, instanciado (de él salen los muebles)
var _window_box := AABB()                    ## la ventana del kit (por ella entra la luz de la tarde)
const Estilo := preload("res://tools/estilo_kit.gd")


func _initialize() -> void:
	_art = (load(KIT_DIORAMA) as PackedScene).instantiate() as Node3D
	root.add_child(_art)
	var model := Node3D.new()
	model.name = "DesvanOficial"
	_root = model
	root.add_child(model)
	await process_frame                          # (hasta el primer fotograma no están dentro del árbol)
	_window_box = Visuals.global_aabb(_art.get_node("Arquitectura/SM_Window") as Node3D)
	_ground(model)
	_structure(_node(model, "S_1_desvan", Vector3.ZERO))
	_childhood(_node(model, "S_2_infancia", Vector3.ZERO))
	_teen(_node(model, "S_3_adolescencia", Vector3.ZERO))
	_adult(_node(model, "S_4_adultez", Vector3.ZERO))
	_epilogue(_node(model, "S_5_epilogo", Vector3.ZERO))
	_clothesline_kit(model.get_node("S_2_infancia"))   # aparece con la infancia, como en el prototipo
	_leftovers(model)
	_unify_colors(model)
	_own_all(model)
	root.remove_child(model)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OFICIAL_MODEL_OUT.get_base_dir()))
	var packed := PackedScene.new()
	var err := packed.pack(model)
	if err == OK:
		err = ResourceSaver.save(packed, OFICIAL_MODEL_OUT)
	print("MODELO OFICIAL %s err=%d" % [OFICIAL_MODEL_OUT, err])
	model.free()
	_art.free()
	if err != OK:
		quit(1)
		return
	var level := Node3D.new()
	level.name = "Nivel01Desvan"
	level.set_script(load("res://core/diorama.gd"))
	level.set("level_title", "El desván")
	level.set("modelo", "")
	level.set("modelo_provisional", OFICIAL_MODEL_OUT)
	level.set("intro_key", "intro_desvan")
	level.set("outro_key", "")
	level.set("fundido_final", true)
	level.set("momentos", true)
	level.set("color_radius", 0.9)
	level.set("camera_distance", 11.5)
	level.set("camera_min_distance", 2.6)
	level.set("camera_max_distance", 14.0)
	level.set("camera_pitch_deg", 24.0)
	level.set("camera_yaw_deg", 18.0)
	level.set("camera_yaw_min_deg", -20.0)       ## abierto por delante y por la derecha
	level.set("camera_yaw_max_deg", 60.0)
	level.set("camera_pitch_min_deg", 10.0)
	level.set("camera_pitch_max_deg", 55.0)
	level.set("iluminacion", "res://iluminacion/desvan_tarde.tscn")
	# La luz de la tarde que entra por la ventana (se enciende al poner la ventana).
	var sun := Node3D.new()
	sun.name = "LuzVentana"
	sun.set_script(load("res://core/luz_ventana.gd"))
	sun.set("ventana", Vector3(_window_box.get_center().x, _window_box.get_center().y, _window_box.position.z))
	sun.set("tam_ventana", Vector2(_window_box.size.x, _window_box.size.y) * 0.86)
	level.add_child(sun)
	sun.owner = level
	packed = PackedScene.new()
	err = packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, OFICIAL_LEVEL_OUT)
	print("NIVEL OFICIAL %s err=%d" % [OFICIAL_LEVEL_OUT, err])
	level.free()
	quit(0 if err == OK else 1)


## Donde se apoya la pieza en mano antes de que haya suelo: solo choque (capa de superficies), sin nada
## que se vea (la peana provisional se quitó el 18-oct: en el desván oficial, solo arte de verdad). Con la
## forma en L del suelo, por debajo de los tablones.
func _ground(model: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "ApoyoSuelo"
	body.collision_layer = Visuals.SURFACE_LAYER
	body.collision_mask = 0
	model.add_child(body)
	for part: Array in [[Vector3(0.0, -0.09, 0.5), Vector3(6.44, 0.18, 4.44)], [Vector3(-2.1, -0.09, 3.2), Vector3(2.24, 0.18, 1.0)],
			[Vector3(2.0, -0.09, -2.7), Vector3(2.44, 0.18, 1.98)]]:
		var shape := BoxShape3D.new()
		shape.size = part[1]
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = part[0]
		body.add_child(cs)


# --- Sección 1: el desván (estructura) y la hucha ----------------------------------------------

## Cada pieza del kit, la suya (pedido del 18-oct: "que todo sea un puzle"); las que son iguales o del
## mismo tipo comparten nombre, y al poner una se ponen todas (Diorama.place, twins_of).
func _structure(sec: Node3D) -> void:
	# Los tablones: tres largos (los del entrante, 6 m; los de la izquierda, 5 m; los del centro, 4 m).
	var kinds := {"FloorPlanks015": "largo", "FloorPlanks013": "medio", "FloorPlanks014": "corto"}
	for base: String in kinds:
		var planks: Array = []
		for k in 4:
			planks.append("Arquitectura/" + (base if k == 0 else "%s_%d" % [base, k + 1]))
		_each(sec, "tablon_" + kinds[base], planks)
	_each(sec, "borde_suelo", ["SB020", "SB021", "SB022", "SB023", "SB024", "SB025", "SB026", "SB029", "SB029_2",
		"SB030", "SB033", "SB034"].map(func(n: String) -> String: return "Arquitectura/" + n))
	_piece(sec, "P_pared_fondo", ["Arquitectura/SM_WallA"])
	_piece(sec, "P_pared_lateral", ["Arquitectura/SM_WallB"])
	_piece(sec, "P_pared_rincon", ["Arquitectura/SM_WallC"])
	_each(sec, "pilar__after-pared_fondo", ["Arquitectura/SM_Pillar", "Arquitectura/SM_Pillar_2", "Arquitectura/SM_Pillar_3"])
	_each(sec, "rodapie__after-pared_fondo", ["Arquitectura/SM_SkirtingBoardI", "Arquitectura/SM_SkirtingBoardJ",
		"Arquitectura/SM_SkirtingBoardL", "Arquitectura/SM_SkirtingBoardTopA"])
	_each(sec, "moldura__after-pared_lateral", ["Arquitectura/SM_SkirtingBoardTopA_2", "Arquitectura/SM_SkirtingBoardTopA_3"])
	_piece(sec, "P_ventana__after-pared_fondo", ["Arquitectura/SM_Window"])
	_each(sec, "cumbrera__after-pared_fondo__after-pared_lateral", ["Arquitectura/CeilingSupport020_2", "Arquitectura/CeilingSupport020"])
	_each(sec, "viga__after-cumbrera", ["A", "B", "C", "D"].map(func(k: String) -> String: return "Arquitectura/SM_CeilingSupportVertical" + k))
	_each(sec, "poste__after-cumbrera", ["014", "015", "016", "017"].map(func(k: String) -> String: return "Arquitectura/CeilingSupport" + k))
	_each(sec, "correa__after-viga", ["Arquitectura/CeilingSupport018", "Arquitectura/CeilingSupport021"])
	_piece(sec, "P_tejado__after-cumbrera", ["Arquitectura/SM_Ceiling"])
	# Las cuerdas de bombillitas (apagadas): cada tramo y cada bombilla, su pieza.
	var ropes: Array = []
	var bulbs: Array = []
	for rope in ["Adornos/CuerdaFaldon/SM_Cuerda", "Adornos/CuerdaFaldon/SM_Cuerda2", "Adornos/CuerdaFaldon/SM_Cuerda3",
			"Adornos/CuerdaEntrante/SM_Cuerda"]:
		ropes.append(rope)
		for c in _added(rope):
			bulbs.append("%s/%s" % [rope, c.name])
	_each(sec, "bombilla__after-guirnalda", bulbs)
	_each(sec, "guirnalda__after-tejado", ropes)
	# La hucha, en el centro sobre una caja del kit (el baúl viejo: lo que la sostiene en el final). Viene
	# ya montada (18-oct: sin rincón de montaje): sale de la bandeja y se pone la última encima de su caja.
	var trunk := _take("Muebles/SM_BoxB", _root, "BaulViejo")
	trunk.global_position = Vector3(0.45, FLOOR, 1.72)
	trunk.rotation_degrees.y = 8.0
	var top := Visuals.global_aabb(trunk).end.y
	var pig := _piece(sec, "P_hucha__clave", ["Muebles/SM_ComodaA/SM_Pig"], Vector3(0.45, top, 1.72))
	var kit_pig := pig.get_child(0) as Node3D
	kit_pig.global_position = Vector3(0.45, top, 1.72)
	kit_pig.global_rotation_degrees = Vector3(0, 200.0, 0)                       # de cara al jugador
	kit_pig.global_position.y += top - Visuals.global_aabb(kit_pig).position.y   # apoyada justo encima (el final busca lo que la sostiene)


# --- Sección 2: la infancia (izquierda) ----------------------------------------------------------

func _childhood(sec: Node3D) -> void:
	_zone_light(sec, Vector3(-1.6, 2.6, 1.6))
	# (lo que va encima o dentro de un mueble, antes de mover el mueble)
	_piece(sec, "P_caja_musica__after-comoda_infantil", ["Muebles/SM_ComodaA/SM_MusicBox"])
	# Los cajones de la cómoda: piezas (iguales: al poner uno se ponen los tres) y, puestos, se abren (OD_;
	# vacíos, pero suenan y se mueven: 18-oct, «que los cajones de los muebles se puedan hacer»). El OD_
	# gira como la cómoda y el cajón sale por su -Z (la cara de los muebles del kit).
	var dresser_yaw := (_art.get_node("Muebles/SM_ComodaA") as Node3D).global_rotation.y
	for k in 3:
		var path: String = "Muebles/SM_ComodaA/SM_Comoda" + ["B", "C", "D"][k]
		var holder := _node(sec, "OD_cajon_comoda_%d__nz" % (k + 1), Visuals.global_aabb(_art.get_node(path) as Node3D).get_center())
		holder.rotation.y = dresser_yaw
		_piece(holder, "P_cajon_comoda__after-comoda_infantil%s" % ("" if k == 0 else "_%03d" % k), [path], Vector3.ZERO)
	_piece(sec, "P_comoda_infantil", ["Muebles/SM_ComodaA"])
	_piece(sec, "P_dibujo__after-caja_musica", ["Adornos/Dibujo_t_draw_03"])
	_piece(sec, "P_tele", ["Muebles/SM_TV"])
	_piece(sec, "P_cama_gato", ["Muebles/SM_CatBed"])
	_piece(sec, "P_arenero", ["Muebles/SM_LitterBox"])
	# Las cajas del fondo: cada caja y cada tapa, su pieza (la de encima, después de las tapas).
	var covers: Array = []
	for box in ["Muebles/SM_BoxA", "Muebles/SM_BoxE", "Muebles/SM_BoxD_2"]:
		for c in _added(box):
			covers.append("%s/%s" % [box, c.name])
	_each(sec, "tapa_caja__after-caja", covers)
	_piece(sec, "P_caja_encima__after-tapa_caja", ["Muebles/SM_BoxD_2"])
	_each(sec, "caja", ["Muebles/SM_BoxA", "Muebles/SM_BoxE", "Muebles/SM_BoxD", "Muebles/SM_BoxD_3"])
	_toy_chest(sec)                              # (antes que el de la cómoda: el orden de los dibujos es el del modelo)
	# Asomando por delante de la cómoda, el dibujo de Ana y Lurdes (desde que la cómoda está puesta).
	var dresser := Visuals.global_aabb(sec.get_node("P_comoda_infantil") as Node3D)
	_kid_drawing(_lying(sec, "C_dibujo_amigas__after-comoda_infantil",
		Vector3(dresser.get_center().x + 0.12, FLOOR + 0.013, dresser.end.z - 0.12), 160.0), "amigas")
	# La nutria del hermano (clave): la del kit, sentada en el suelo del rincón (entre la caja de juguetes y
	# la cómoda, donde estaba la cama del prototipo).
	var otter := _node(sec, "P_peluche__clave", OTTER_AT)
	otter.rotation_degrees.y = 25.0              # de cara al jugador
	_kit_otter(otter)
	# El tebeo (del pack) se guarda en la caja de juguetes (H_) y va en el suelo, junto a la nutria: lo que
	# guarda el mueble que brilla de la infancia (el tutorial de buscar).
	_prop(sec, "P_tebeo", "manga_01", OTTER_AT + Vector3(0.26, 0.0, -0.18), 75.0)


## La caja de juguetes: una caja del kit cuya tapa se levanta (OR_, bisagra atrás) y guarda el tebeo (H_,
## del pack) y el dibujo de la casa (apoyado en el fondo: tumbado no se vería, trampa 34).
func _toy_chest(sec: Node3D) -> void:
	# La que llevaba encima, a la esquina (su caja y su tapa, piezas como las otras).
	var stacked := _art.get_node("Adornos/SM_BoxC/SM_BoxE") as Node3D
	stacked.global_position = Vector3(-2.72, FLOOR, 3.28)
	_each(sec, "tapa_caja__after-caja", ["Adornos/SM_BoxC/SM_BoxE/SM_CoverBoxE"], 3)
	_each(sec, "caja", ["Adornos/SM_BoxC/SM_BoxE"], 4)
	# La caja y la tapa son piezas; la tapa va dentro del OR_: la caja no se abre sin ella.
	var chest := _node(sec, "BaulJuguetes", Vector3.ZERO)
	var cover := _art.get_node("Adornos/SM_BoxC/SM_CoverBoxC") as Node3D
	var body := Visuals.global_aabb(_art.get_node("Adornos/SM_BoxC") as Node3D)
	var lid_box := Visuals.global_aabb(cover)
	var lid := _node(chest, "OR_tapa_baul__x", Vector3(body.get_center().x, lid_box.position.y, body.position.z))
	_each(lid, "tapa_caja__after-caja", ["Adornos/SM_BoxC/SM_CoverBoxC"], 4)
	_each(chest, "caja", ["Adornos/SM_BoxC"], 5)
	_prop(chest, "H_tebeo", "manga_01", Vector3(body.get_center().x, body.position.y + 0.04, body.get_center().z + 0.06), 20.0)
	var leaning := _node(chest, "C_dibujo_casa", Vector3(body.get_center().x, lid_box.position.y - 0.02, body.position.z + 0.05))
	leaning.rotation_degrees = Vector3(-20.0, 0.0, 0.0)
	_kid_drawing(leaning, "casa")


## La nutria del kit (Otter/SM_otter.fbx): el fichero trae la nutria montada (Box080) y, al lado, sus
## trozos sueltos para texturizar; solo vale la montada, con su material (M_Otter, estilo cozy).
func _kit_otter(otter: Node3D) -> void:
	var src := (load(KIT_OTTER) as PackedScene).instantiate() as Node3D
	var whole := src.find_child("Box080", true, false) as MeshInstance3D
	assert(whole != null, "falta la nutria montada (Box080) en " + KIT_OTTER)
	var m := MeshInstance3D.new()
	m.name = "Nutria"
	m.mesh = whole.mesh
	m.set_surface_override_material(0, load(KIT_OTTER_MAT))
	var box := whole.transform * whole.get_aabb()
	m.transform = Transform3D(whole.transform.basis, whole.transform.origin - Vector3(box.get_center().x, box.position.y, box.get_center().z))
	otter.add_child(m)                           # (los pies en el origen de la pieza)
	src.free()


## Un dibujo de cuando era pequeña: solo su plano (el folio con la imagen), sin el trozo de celo del
## prototipo (18-oct: en el desván oficial, nada hecho con cajas).
func _kid_drawing(n: Node3D, cual: String) -> void:
	var path: String = DIBUJOS[cual]
	_sheet(n, path, DRAWING_LONG, true)
	n.set_meta("color", _dominant_color(Image.load_from_file(ProjectSettings.globalize_path(path))))


## La altura de lo de arriba de un mueble en esa vertical (el primer triángulo que toca un rayo desde
## arriba): dónde se apoya lo que se le pone encima (la nutria, en el hueco de la cama del gato).
func _top_at(furniture: Node3D, at: Vector3) -> float:
	var best := -INF
	var from := Vector3(at.x, 10.0, at.z)
	for m in Visuals.meshes_under(furniture):
		var faces := m.mesh.get_faces()
		var xf := m.global_transform
		for i in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(from, Vector3.DOWN, xf * faces[i], xf * faces[i + 1], xf * faces[i + 2])
			if hit != null and (hit as Vector3).y > best:
				best = (hit as Vector3).y
	return best if best > -INF else Visuals.global_aabb(furniture).end.y


# --- Sección 3: la adolescencia (centro, bajo la ventana) -----------------------------------------

func _teen(sec: Node3D) -> void:
	_zone_light(sec, Vector3(-0.3, 2.8, -0.2))
	_piece(sec, "P_alfombra_adolescencia", ["Adornos/SM_Rug"])
	# El escritorio del kit y sus cajones, que también hay que poner (después del escritorio: los dos de
	# estrella son iguales, el del pomo va aparte). El de arriba se abre (OD_) y guarda la inscripción a
	# Bellas Artes: su cajón-pieza va dentro del OD_, que no se abre hasta que está puesto.
	var desk := _art.get_node("Muebles/SM_DeskA") as Node3D
	var drawers := _node(sec, "Cajones", Vector3.ZERO)
	var top_drawer := _node(drawers, "OD_cajon_escritorio", (desk.get_node("SM_DeskC") as Node3D).global_position)
	var drawer_box := Visuals.global_aabb(desk.get_node("SM_DeskC") as Node3D)
	_piece(top_drawer, "P_cajon__after-escritorio", ["Muebles/SM_DeskA/SM_DeskC"], Vector3.ZERO)
	# Los otros dos también se abren (vacíos), como el de arriba: hacia delante del escritorio.
	var knob := _node(drawers, "OD_cajon_escritorio_pomo", (desk.get_node("SM_DeskD") as Node3D).global_position)
	_piece(knob, "P_cajon_pomo__after-escritorio", ["Muebles/SM_DeskA/SM_DeskD"], Vector3.ZERO)
	var low := _node(drawers, "OD_cajon_escritorio_bajo", (desk.get_node("SM_DeskC2") as Node3D).global_position)
	_piece(low, "P_cajon__after-escritorio_001", ["Muebles/SM_DeskA/SM_DeskC2"], Vector3.ZERO)
	_application(_node(top_drawer, "H_solicitud", Vector3(drawer_box.get_center().x, drawer_box.end.y - 0.05, drawer_box.get_center().z) - top_drawer.global_position), true)
	# Lo de encima del escritorio, cada cosa su pieza: el tapete, el bote y sus lápices (iguales).
	_each(sec, "lapiz__after-bote", ["Muebles/SM_Vase/SM_BrushA", "Muebles/SM_Vase/SM_BrushB", "Muebles/SM_Vase/SM_BrushC"])
	_piece(sec, "P_bote__after-escritorio", ["Muebles/SM_Vase"])
	_piece(sec, "P_tapete__after-escritorio", ["Muebles/SM_CoverDesk"])
	_piece(sec, "P_escritorio", ["Muebles/SM_DeskA"])
	var top := Visuals.global_aabb(desk).end.y
	# El MP3 viene en trozos y se monta en su sitio, encima del escritorio (18-oct: sin rincón aparte):
	# con el último trozo, su primer plano y su frase (token de-mp3).
	_mp3_parts(sec, "Muebles/SM_MP3")
	# La cámara (clave, flash): la polaroid del kit, en el escritorio (donde la dejaron las artistas).
	_piece(sec, "P_camara__clave__flash", ["Muebles/SM_Polaroid"])
	# Y junto a ella, unas fotos suyas sueltas (18-oct): una medio debajo de la cámara y otra en el tapete.
	var desk_photos := [["SM_PolaroidD", Vector3(0.05, top + 0.006, -1.02), -8.0], ["SM_PolaroidA", Vector3(-0.17, top + 0.016, -1.08), 12.0]]
	for k in desk_photos.size():
		var yaw: float = desk_photos[k][2]
		var foot: Vector3 = desk_photos[k][1] + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, PHOTO_LONG * 0.5)
		_kit_piece(sec, "P_foto_camara__after-escritorio" + ("" if k == 0 else "_%03d" % k), desk_photos[k][0], foot, yaw, -90.0)
	var lamp := _piece(sec, "P_lampara__after-escritorio", ["Adornos/SM_Lamp"])
	_lamp_light(lamp)
	(lamp.get_node("Luz") as SpotLight3D).spot_range = 1.9
	_prop(sec, "P_silla", "chair_01", Vector3(-0.61, FLOOR, -0.55), 180.0)
	_prop(sec, "P_altavoz__after-escritorio", "speaker_01", Vector3(0.08, top, -1.42))
	_prop(sec, "P_libro__after-escritorio", "book_01", Vector3(-0.55, top, -1.4), 10.0)
	_prop(sec, "P_libro__after-escritorio_001", "book_01", Vector3(-0.55, top + 0.035, -1.4), -6.0)
	# La solicitud, en la pared a la derecha de la ventana, cuando se encuentra en el cajón.
	_application(_node(sec, "P_solicitud__after-mp3", Vector3(0.72, 2.03, -1.54)), false)
	# Debajo de la silla asoma un dibujo suyo, el monstruo (sobre la alfombra; desde que la silla está puesta).
	var chair := Visuals.global_aabb(sec.get_node("P_silla") as Node3D)
	_kid_drawing(_lying(sec, "C_dibujo_monstruo__after-silla",
		Vector3(chair.get_center().x + 0.02, FLOOR + 0.03, chair.get_center().z), 15.0), "monstruo")
	# La cámara está guardada en una caja del kit con tapa (OR_, bisagra atrás), en la alfombra (donde la
	# dejaron las artistas se metía en la silla); la caja y la tapa, piezas (la tapa dentro del OR_: sin
	# ella, la caja no se abre).
	var art_box := _art.get_node("Adornos/SM_BoxB") as Node3D
	var was := Visuals.global_aabb(art_box).get_center()
	art_box.global_position += Vector3(CAMERA_BOX_AT.x - was.x, 0.0, CAMERA_BOX_AT.y - was.z)
	var cam_box := _node(sec, "CajaCamara", Vector3.ZERO)
	var cover := _art.get_node("Adornos/SM_BoxB/SM_CoverBoxB") as Node3D
	var body := Visuals.global_aabb(_art.get_node("Adornos/SM_BoxB") as Node3D)
	var lid_box := Visuals.global_aabb(cover)
	var lid := _node(cam_box, "OR_tapa_caja__x", Vector3(body.get_center().x, lid_box.position.y, body.position.z))
	_piece(lid, "P_tapa_camara__after-caja_camara", ["Adornos/SM_BoxB/SM_CoverBoxB"])   # (otros nombres que las de la
	_piece(cam_box, "P_caja_camara", ["Adornos/SM_BoxB"])                               # infancia: after-x mira todo el desván)
	var stored := _node(cam_box, "H_camara", Vector3(body.get_center().x, body.position.y + 0.03, body.get_center().z))
	stored.add_child((load(TILESET + "SM_Polaroid.scn") as PackedScene).instantiate())   # la misma polaroid
	# Más cosas del kit (18-oct, «más assets de los que tenemos modelados, como fotos, folios»): fotos sueltas
	# por la alfombra, junto a la caja de la cámara, y un montón de apuntes en el suelo, junto a la silla.
	var photos := [["SM_PolaroidA", Vector3(0.25, 0.0, 1.18), 12.0], ["SM_PolaroidB", Vector3(0.6, 0.0, 1.22), -18.0],
		["SM_PolaroidC", Vector3(-0.02, 0.0, 0.25), 25.0]]
	for k in photos.size():
		var at: Vector3 = photos[k][1] + Vector3(0, RUG_TOP + 0.011, 0.115)   # (tumbada, la foto queda delante de su pie)
		_kit_piece(sec, "P_foto_suelta__after-caja_camara" + ("" if k == 0 else "_%03d" % k), photos[k][0], at, photos[k][2], -90.0)
	_kit_piece(sec, "P_papeles__after-escritorio", "SM_PaperStack", Vector3(-1.02, FLOOR, -0.6), 20.0)


## La solicitud a Bellas Artes: el papel de las artistas (SM_PaperUniversidad, Pack09 del 18-oct; en el
## tileset viene tumbado, cara arriba y con el encabezado hacia -Z). En el cajón, tumbada; en la pared, de
## pie mirando a la habitación (el encabezado arriba).
func _application(n: Node3D, on_floor: bool) -> void:
	var paper := (load(TILESET + "SM_PaperUniversidad.scn") as PackedScene).instantiate() as Node3D
	paper.name = "Folio"
	if on_floor:
		paper.rotation_degrees.y = 4.0
	else:
		paper.rotation_degrees.x = 90.0
	n.add_child(paper)


# --- Sección 4: la adultez (el caballete y el entrante) ------------------------------------------

func _adult(sec: Node3D) -> void:
	# La lámpara de pie del entrante es una pieza con su luz (se enciende al ponerla); la de la zona, aparte.
	var floor_lamp := _piece(sec, "P_lampara_pie", ["Muebles/SM_Lamp"])
	var head := Visuals.global_aabb(floor_lamp)
	_zone_light(sec, Vector3(head.get_center().x, head.end.y - 0.15, head.get_center().z))
	_lamp_light(floor_lamp)
	(floor_lamp.get_node("Luz") as SpotLight3D).spot_range = 1.9
	_piece(sec, "P_taburete", ["Muebles/SM_Stool"])
	# Las llaves de la tienda (el llavero del kit, Pack09): colgadas en la cara de delante del pilar entre la
	# ventana y el entrante; son lo primero de la adultez, como en el guion (llaves, caballete, espejo).
	_kit_piece(sec, "P_llaves", "SM_Keyholder", KEYS_AT)
	_each(sec, "polaroid", ["A", "B", "C", "D"].map(func(k: String) -> String: return "Adornos/SM_Polaroid" + k))
	_piece(sec, "P_alfombra_adultez", ["Muebles/SM_Rug"])
	var easel := _piece(sec, "P_caballete__after-llaves", ["Muebles/SM_Caballete"])
	var canvas_at := _easel_rest(easel)
	var canvas := _node(sec, "P_lienzo__after-caballete", canvas_at.origin)
	canvas.basis = canvas_at.basis
	_box(canvas, "Lienzo", Vector3(0, 0.36, 0), Vector3(0.58, 0.72, 0.03), Color(0.97, 0.96, 0.93))
	var picture := Node3D.new()                  # (lo que pinta: el cuadro de las artistas, en la cara de delante)
	picture.name = "Cara"
	picture.position = Vector3(0, 0.36, 0)
	canvas.add_child(picture)
	_painting(picture, CUADRO_LIENZO, Vector2(0.55, 0.69), 0.0155)
	var brushes := _piece(sec, "P_pinceles__after-caballete", ["Adornos/SM_Vase"])
	(brushes.get_child(0) as Node3D).global_position = Vector3(-0.72, FLOOR, 1.0)
	_piece(sec, "P_espejo__clave__reflejo", ["Muebles/SM_Mirror"])
	_mirror_glass(sec.get_node("P_espejo__clave__reflejo") as Node3D)
	_piece(sec, "P_perchero", ["Muebles/SM_Burro"])
	# Folios y papeles arrugados en su alfombra (los bocetos que no salieron).
	var papers := [["folio", "SM_Paper01", Vector3(1.55, 0, -1.3), 20.0], ["folio", "SM_Paper01", Vector3(2.25, 0, -0.85), -40.0],
		["papel_arrugado", "SM_PaperBroken", Vector3(1.95, 0, -1.55), 70.0], ["papel_arrugado", "SM_PaperBroken", Vector3(2.4, 0, -1.3), 10.0]]
	var seen := {}
	for paper: Array in papers:
		var n: int = seen.get(paper[0], 0)
		seen[paper[0]] = n + 1
		_kit_piece(sec, "P_%s__after-caballete%s" % [paper[0], "" if n == 0 else "_%03d" % n], paper[1],
			(paper[2] as Vector3) + Vector3(0, ADULT_RUG_TOP, 0), paper[3])
	_piece(sec, "P_sombrero__after-perchero", ["Muebles/SM_Hat"])
	# En el taburete del entrante, la taza y el reloj (del pack).
	var stool := Visuals.global_aabb(sec.get_node("P_taburete") as Node3D)
	_prop(sec, "P_taza", "mug_01", Vector3(stool.get_center().x - 0.07, stool.end.y, stool.get_center().z + 0.05))
	_prop(sec, "P_reloj", "clock_01", Vector3(stool.get_center().x + 0.07, stool.end.y, stool.get_center().z - 0.04), -30.0)
	# Debajo del burro, en el suelo, el dibujo del gato (desde que el burro está puesto).
	var rack := Visuals.global_aabb(sec.get_node("P_perchero") as Node3D)
	_kid_drawing(_lying(sec, "C_dibujo_gato__after-perchero", Vector3(rack.get_center().x, FLOOR + 0.013, rack.get_center().z - 0.1), 10.0), "gato")


## Dónde apoya el lienzo en el caballete del kit: en su repisa (a un tercio de su alto), por DELANTE de
## las patas (la cara del caballete es su -Z: el lienzo quedaba detrás, 18-oct) y echado hacia atrás
## como el caballete; la cara pintada (+Z del lienzo) mira hacia delante.
func _easel_rest(easel: Node3D) -> Transform3D:
	var box := Visuals.global_aabb(easel)
	var yaw := (easel.get_child(0) as Node3D).global_rotation.y
	var front := -(Basis(Vector3.UP, yaw) * Vector3.BACK)
	var ledge := box.position.y + box.size.y * 0.36
	var center := Vector3(box.get_center().x, ledge, box.get_center().z)
	var reach := 0.0                             # lo más adelantado de las patas, a la altura del lienzo
	for m in Visuals.meshes_under(easel):
		var xf := m.global_transform
		for v in m.mesh.get_faces():
			var w := xf * v
			if w.y > ledge and w.y < ledge + 0.7:
				reach = maxf(reach, (w - center).dot(front))
	var basis := Basis(Vector3.UP, yaw + PI) * Basis(Vector3.RIGHT, deg_to_rad(-8.0))
	return Transform3D(basis, center + front * (reach + 0.03))


## El espejo del kit (Pack08, 18-oct) trae el reflejo pintado en la luna (ella de mayor): no lleva luna
## aparte. Solo una marca sin malla, "ReflejoPintado", en el centro de la luna y con su +Z hacia donde
## mira (la -Z del kit, como el caballete): Momentos la usa para ponerse de frente y no pinta encima.
## Durante la partida la luna está vacía (el tileset le pone M_Pack08_02, T_Pack08_BC_02); la marca
## lleva el material con ella pintada (M_Pack08), al que pasa en el primer plano.
func _mirror_glass(piece: Node3D) -> void:
	var mirror := piece.get_child(0) as Node3D
	var local := Visuals.local_aabb(mirror)
	var mark := Node3D.new()
	mark.name = "ReflejoPintado"
	mark.position = Vector3(local.get_center().x, local.position.y + local.size.y * 0.56, local.position.z)
	mark.rotation_degrees.y = 180.0
	mark.set_meta("material_pintado", load(MIRROR_PAINTED))
	mirror.add_child(mark)


# --- Sección 5: el final ---------------------------------------------------------------------------

func _epilogue(sec: Node3D) -> void:
	var pig := _root.get_node("S_1_desvan/P_hucha__clave") as Node3D
	var box := Visuals.global_aabb(pig)
	var coin := _node(sec, "P_moneda__ofrecida", Vector3(box.get_center().x, box.end.y - 0.02, box.get_center().z))
	var c := _cyl(coin, "Moneda", Vector3.ZERO, 0.045, 0.012, Color(0.95, 0.76, 0.3))
	c.rotation_degrees = Vector3(0, 20.0, 90)          # de canto, a lo largo del lomo
	_shiny(c, 0.85, 0.3)


# --- La cuerda de los dibujos y lo que no es de ninguna sección -----------------------------------

## La cuerda de bombillitas del fondo del entrante es la de los dibujos (T_): una pinza por dibujo,
## entre bombilla y bombilla, donde la cuerda pasa (corte exacto de su malla).
func _clothesline_kit(sec: Node3D) -> void:
	var line := _take("Adornos/CuerdaDibujos", sec, "T_dibujos")
	var rope := line.get_node("SM_Cuerda") as Node3D
	var tilts := [-4.0, 3.0, -2.0, 5.0]
	var xs := [-0.6, -0.2, 0.2, 0.6]
	for k in DIBUJOS.size():
		var at := _rope_bottom(rope, xs[k])
		var pin := _node(line, "Pinza%d" % (k + 1), line.global_transform.affine_inverse() * (at + Vector3(0, -0.006, 0.01)))
		pin.rotation_degrees.z = tilts[k]


## El punto más bajo de la cuerda (su malla, en global) en la vertical de x (local de la cuerda).
func _rope_bottom(rope: Node3D, x: float) -> Vector3:
	var best := Vector3(0, INF, 0)
	var found := false
	for m in Visuals.meshes_under(rope):
		var bulb := false                         # (las bombillas cuelgan de la cuerda: no cuentan)
		var p := m.get_parent()
		while p != null and p != rope:
			bulb = bulb or String(p.name).begins_with("SM_Bombilla")
			p = p.get_parent()
		if bulb:
			continue
		var to_rope := rope.global_transform.affine_inverse() * m.global_transform
		for s in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
			for t in range(0, idx.size(), 3):
				for k in 3:
					var a := to_rope * v[idx[t + k]]
					var b := to_rope * v[idx[t + (k + 1) % 3]]
					if (a.x - x) * (b.x - x) > 0.0 or is_equal_approx(a.x, b.x):
						continue
					var cut := a.lerp(b, (x - a.x) / (b.x - a.x))
					if cut.y < best.y:
						best = cut
						found = true
	assert(found, "la cuerda no pasa por x = %.2f" % x)
	return rope.global_transform * best


## Lo que queda del diorama de las artistas (el marco del suelo, las cajas del fondo, el arenero, las
## cuerdas de bombillitas): a la vista desde el principio, sin ser de ninguna sección.
func _leftovers(model: Node3D) -> void:
	var trastos := _node(model, "Trastos", Vector3.ZERO)
	for group in ["Arquitectura", "Muebles", "Adornos"]:
		for c in _art.get_node(group).get_children():
			if not Visuals.meshes_under(c).is_empty():  # (los grupos que se quedaron vacíos, no)
				_take("%s/%s" % [group, c.name], trastos)


# --- Utilidades ------------------------------------------------------------------------------------

## Lo que las artistas pusieron colgando de esa pieza (la tapa de una caja, las bombillas de una cuerda):
## sus hijos del diorama, no los de dentro de su escena del tileset (su malla).
func _added(path: String) -> Array:
	return _art.get_node(path).get_children().filter(func(c: Node) -> bool: return c.owner == _art)


## Mueve un nodo del diorama de las artistas a `parent` (sin cambiar dónde está ni cómo gira).
func _take(path: String, parent: Node3D, new_name := "") -> Node3D:
	var n := _art.get_node(path) as Node3D
	assert(n != null, "falta %s en %s" % [path, KIT_DIORAMA])
	n.owner = null                               # (se lo vuelve a dar _own_all, ya en el modelo)
	n.reparent(parent, true)
	if new_name != "":
		n.name = new_name
	return n


## Una pieza por cosa del kit, todas con el mismo nombre (iguales o del mismo tipo: al poner una se ponen
## todas): P_<id_y_tokens>, P_<id_y_tokens>_001... `first` = el primer número (si ya hay otras con ese nombre).
func _each(parent: Node3D, id_and_tokens: String, paths: Array, first := 0) -> void:
	for k in paths.size():
		var n := first + k
		_piece(parent, "P_%s%s" % [id_and_tokens, "" if n == 0 else "_%03d" % n], [paths[k]])


## El MP3 del kit (el de Pack05, montado en el tileset: MP3_JUNTAR de tools/piezas_kit.gd) en tres piezas,
## cada una con sus mallas: la carcasa (con sus botones de los lados), la rueda (con sus letras) y los
## auriculares. Van juntas en "MP3", donde estaba el del kit (encima del escritorio), cada una __de-mp3:
## puestas las tres, el MP3.
const MP3_PARTES := {"MP301": "carcasa_mp3", "MP302": "carcasa_mp3", "MP304": "carcasa_mp3", "MP305": "carcasa_mp3",
	"MP309": "rueda_mp3", "MP3011": "rueda_mp3", "MP3012": "rueda_mp3", "MP3013": "rueda_mp3", "MP3014": "rueda_mp3",
	"MP307": "auriculares_mp3"}

func _mp3_parts(sec: Node3D, kit_path: String) -> void:
	var mp3 := _take(kit_path, sec)              # (el del kit se reparte en sus piezas y sobra: se libera al acabar)
	var bench := _node(sec, "MP3", Vector3.ZERO)
	bench.global_transform = mp3.global_transform
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MESHES_OUT))
	var pieces := {}
	for m in Visuals.meshes_under(mp3):
		var key: String = MP3_PARTES[String(m.name)]
		if not pieces.has(key):
			var tokens := ("__after-escritorio" if key == "carcasa_mp3" else "__after-carcasa_mp3") + "__de-mp3"
			pieces[key] = _node(bench, "P_%s%s" % [key, tokens], Vector3.ZERO)
		var copy := MeshInstance3D.new()
		copy.name = m.name
		var path := MESHES_OUT + "mp3_%s.res" % String(m.name).to_lower()
		ResourceSaver.save(m.mesh.duplicate(), path)   # (su malla, en su fichero: la del kit es de su .fbx)
		copy.mesh = load(path)
		copy.transform = _rel(m, mp3)
		for k in m.mesh.get_surface_count():
			copy.set_surface_override_material(k, m.get_active_material(k))
		(pieces[key] as Node3D).add_child(copy)
	print("MP3 en %d piezas: %s" % [pieces.size(), pieces.keys()])
	mp3.free()


## La transformación de `n` respecto a `root` (encadenando las locales: vale fuera del árbol).
func _rel(n: Node, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var p := n
	while p != root and p != null:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Una pieza (P_...) hecha con esas cosas del kit; su origen, el de la primera (o `at`).
func _piece(sec: Node3D, piece_name: String, paths: Array, at := Vector3.INF) -> Node3D:
	var first := _art.get_node(paths[0]) as Node3D
	var p := _node(sec, piece_name, first.global_position if at == Vector3.INF else at)
	for path: String in paths:
		_take(path, p)
	return p


## Una pieza del tileset que no está en el diorama de las artistas (las que se añadieron después): P_ en
## `at`, girada `yaw` grados y, con `tilt` = -90, tumbada boca arriba (las fotos, que son de pie).
func _kit_piece(sec: Node3D, piece_name: String, kit: String, at: Vector3, yaw := 0.0, tilt := 0.0) -> Node3D:
	var p := _node(sec, piece_name, at)
	var inst := (load(TILESET + kit + ".scn") as PackedScene).instantiate() as Node3D
	inst.rotation_degrees = Vector3(tilt, yaw, 0.0)
	p.add_child(inst)
	return p


## Una luz de zona: se enciende al abrirse su sección (Section.collect_lights).
func _zone_light(parent: Node3D, pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = "LuzZona"
	light.position = pos
	light.light_color = WARM_BULB
	light.light_energy = ZONE_LIGHT
	light.omni_range = ZONE_RANGE
	light.omni_attenuation = 1.2
	parent.add_child(light)


## Un punto del faldón (por debajo, un poco hacia dentro) a esa x y esa z.
func _on_slope(x: float, z: float) -> Vector3:
	var t := (x - ROOF_A.x) / (ROOF_B.x - ROOF_A.x)
	var y := lerpf(ROOF_A.y, ROOF_B.y, t)
	var along := (ROOF_B - ROOF_A).normalized()
	var inward := Vector2(along.y, -along.x)       # perpendicular, hacia la habitación
	return Vector3(x, y, z) + Vector3(inward.x, inward.y, 0) * 0.06


## Lo que gira algo plano (su cara por -Y) para quedar pegado al faldón mirando a la habitación.
func _slope_deg() -> float:
	return rad_to_deg(atan2(ROOF_B.y - ROOF_A.y, ROOF_B.x - ROOF_A.x))


## Las figuras provisionales (lo que el kit aún no tiene) con el mismo estilo que el kit (estilo_kit.gd):
## su color mezclado con el tono cálido en la misma proporción y los mismos reflejos suaves, para que el
## diorama se lea de una pieza (pedido del 18-oct: "que cromáticamente esté unificado").
func _unify_colors(model: Node3D) -> void:
	var done := {}
	for m in Visuals.meshes_under(model):
		var mat := (m.mesh.surface_get_material(0) if m.mesh is PrimitiveMesh or m.mesh is TextMesh else null) as StandardMaterial3D
		if mat == null or done.has(mat) or mat.albedo_texture != null or mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or mat.metallic > 0.5:
			continue
		done[mat] = true
		var c := mat.albedo_color
		mat.albedo_color = Color(c.lerp(Estilo.TONO, Estilo.MEZCLA), c.a)
		mat.metallic_specular = Estilo.ESPECULAR
		mat.roughness = maxf(mat.roughness, 0.75)


## Dueño de todo lo nuevo y de lo traído del kit (lo de dentro de cada instancia sigue siendo suyo:
## se guarda como referencia a su escena del tileset, no copiado).
func _own_all(n: Node) -> void:
	for c in n.get_children():
		if c.owner == null or c.owner == _art:
			c.owner = _root
		_own_all(c)
