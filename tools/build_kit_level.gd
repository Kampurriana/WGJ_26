extends "res://tools/build_attic_level.gd"
## EL DESVÁN QUE SE JUEGA (18-oct): la misma historia, secciones, piezas y reglas que el prototipo
## (tools/build_attic_level.gd, que se conserva en levels/prototipo/), pero montada sobre el ARTE
## OFICIAL: el diorama de las artistas (preview/diorama_kit.tscn, que sigue su blocking y se retoca a
## mano en el editor). Cada mueble del kit pasa a ser la pieza de la historia que le toca (instancias del
## tileset, sin escalar); lo que el kit aún no tiene (la cama, la nutria, la cámara, la guitarra...) son
## las figuras provisionales del prototipo, colocadas en su sitio de este desván.
##   S_1_desvan        12 tablones de tres largos (4 de cada), las tres paredes (con sus pilares y
##                     rodapiés), la ventana, la viga de arriba (cumbrera), 4 cabrios (vigas), el tejado
##                     (faldón, correas y postes) y la hucha (clave) sobre su caja, en el centro
##   S_2_infancia      izquierda: cómoda → caja de música → dibujo (pared) → nutria (clave, en la cama);
##                     la tele, la cama del gato, la caja de juguetes (tapa) con los cubos y la casa
##   S_3_adolescencia  centro, bajo la ventana: el escritorio del kit con sus cajones (la solicitud, en el
##                     de arriba), MP3 → solicitud → cámara (clave y flash, en la caja con tapa)
##   S_4_adultez       el caballete (donde lo dejaron las artistas, a la izquierda) y el entrante: llaves
##                     → caballete → espejo (clave, reflejo); el burro con el sombrero, la mesita
##   S_5_epilogo       la moneda (ofrecida) junto a la hucha
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

var _art: Node3D                             ## el diorama de las artistas, instanciado (de él salen los muebles)


func _initialize() -> void:
	_art = (load(KIT_DIORAMA) as PackedScene).instantiate() as Node3D
	root.add_child(_art)
	var model := Node3D.new()
	model.name = "DesvanOficial"
	_root = model
	root.add_child(model)
	await process_frame                          # (hasta el primer fotograma no están dentro del árbol)
	_base(model)
	_structure(_node(model, "S_1_desvan", Vector3.ZERO))
	_childhood(_node(model, "S_2_infancia", Vector3.ZERO))
	_teen(_node(model, "S_3_adolescencia", Vector3.ZERO))
	_adult(_node(model, "S_4_adultez", Vector3.ZERO))
	_epilogue(_node(model, "S_5_epilogo", Vector3.ZERO))
	_clothesline_kit(model.get_node("S_2_infancia"))   # aparece con la infancia, como en el prototipo
	_leftovers(model)
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
	level.set("iluminacion", "res://iluminacion/desvan.tscn")
	packed = PackedScene.new()
	err = packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, OFICIAL_LEVEL_OUT)
	print("NIVEL OFICIAL %s err=%d" % [OFICIAL_LEVEL_OUT, err])
	level.free()
	quit(0 if err == OK else 1)


## La peana (provisional: el kit no la tiene): el desván se monta encima, como en Woodo y en el
## prototipo; con la forma en L del suelo, por debajo de los tablones. Se ve desde el principio y en ella
## se apoya la pieza en mano antes de que haya suelo.
func _base(model: Node3D) -> void:
	var base := _node(model, "Peana", Vector3.ZERO)
	_box(base, "Centro", Vector3(0.0, -0.09, 0.5), Vector3(6.44, 0.18, 4.44), WOOD_DARK)
	_box(base, "Delante", Vector3(-2.1, -0.09, 3.2), Vector3(2.24, 0.18, 1.0), WOOD_DARK)
	_box(base, "Entrante", Vector3(2.0, -0.09, -2.7), Vector3(2.44, 0.18, 1.98), WOOD_DARK)


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
	# La hucha, en el centro sobre una caja del kit (el baúl viejo: lo que la sostiene en el final). El
	# cerdito del kit viene en 12 trozos: se montan en su rincón (Z_, primer plano), delante de la caja;
	# entero, va a la bandeja, y se pone el último encima de su caja.
	var trunk := _take("Muebles/SM_BoxB", _root, "BaulViejo")
	trunk.global_position = Vector3(0.45, FLOOR, 1.72)
	trunk.rotation_degrees.y = 8.0
	var top := Visuals.global_aabb(trunk).end.y
	var pig := _piece(sec, "P_hucha__clave", ["Muebles/SM_ComodaA/SM_Pig"], Vector3(0.45, top, 1.72))
	var kit_pig := pig.get_child(0) as Node3D
	kit_pig.global_position = Vector3(0.45, top, 1.72)
	kit_pig.global_rotation_degrees = Vector3(0, 200.0, 0)                       # de cara al jugador
	kit_pig.global_position.y += top - Visuals.global_aabb(kit_pig).position.y   # apoyada justo encima (el final busca lo que la sostiene)
	_pig_bench(sec, kit_pig, Vector3(0.45, FLOOR, 2.33))


## El banco de la hucha (Z_ ... __reward-hucha__monta): sus 12 trozos, cada uno su pieza (las patas, las
## orejas y los ojos, iguales), montados donde van; primero el cuerpo.
func _pig_bench(sec: Node3D, pig: Node3D, at: Vector3) -> void:
	var bench := _node(sec, "Z_montaje_hucha__reward-hucha__monta", at)
	bench.rotation_degrees.y = 200.0
	var parts := {"SM_PigA": "pata_hucha", "SM_PigB": "pata_hucha", "SM_PigC": "pata_hucha", "SM_PigD": "pata_hucha",
		"SM_PigE": "cuerpo_hucha", "SM_PigF": "oreja_hucha", "SM_PigG": "oreja_hucha", "SM_PigH": "hocico_hucha",
		"SM_PigI": "ojo_hucha", "SM_PigJ": "ojo_hucha", "SM_PigK": "ranura_hucha", "SM_PigL": "cola_hucha"}
	var used := {}
	for m in Visuals.meshes_under(pig):
		var part: String = parts[String(m.name)]
		var n: int = used.get(part, 0)
		used[part] = n + 1
		var tokens := "" if part == "cuerpo_hucha" else "__after-cuerpo_hucha"
		var piece := _node(bench, "P_%s%s%s" % [part, tokens, "" if n == 0 else "_%03d" % n], Vector3.ZERO)
		var copy := m.duplicate() as MeshInstance3D
		copy.transform = _rel(m, pig)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MESHES_OUT))
		var path := MESHES_OUT + "hucha_%s.res" % String(m.name).trim_prefix("SM_Pig").to_lower()
		ResourceSaver.save(m.mesh.duplicate(), path)   # (su malla, en su fichero: la de la hucha es de su escena)
		copy.mesh = load(path)
		piece.add_child(copy)


# --- Sección 2: la infancia (izquierda) ----------------------------------------------------------

func _childhood(sec: Node3D) -> void:
	_zone_light(sec, Vector3(-1.6, 2.6, 1.6))
	# (lo que va encima o dentro de un mueble, antes de mover el mueble)
	_piece(sec, "P_caja_musica__after-comoda_infantil", ["Muebles/SM_ComodaA/SM_MusicBox"])
	_each(sec, "cajon_comoda__after-comoda_infantil", ["Muebles/SM_ComodaA/SM_ComodaB", "Muebles/SM_ComodaA/SM_ComodaC",
		"Muebles/SM_ComodaA/SM_ComodaD"])
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
	var rug := _node(sec, "P_alfombra_infancia", Vector3(-1.5, FLOOR + 0.012, 1.65))
	_cyl(rug, "Alfombra", Vector3.ZERO, 0.62, 0.015, PASTEL_PINK)
	_cyl(rug, "Circulo", Vector3(0, 0.002, 0), 0.4, 0.015, PASTEL_BLUE)
	_toy_chest(sec)                              # (antes que el de la cama: el orden de los dibujos es el del modelo)
	var bed_at := Vector3(-1.45, FLOOR, 2.7)
	var bed := _node(sec, "P_cama_infantil", bed_at)
	_box(bed, "Marco", Vector3(0, 0.12, 0), Vector3(0.6, 0.2, 1.0), Color(0.86, 0.8, 0.72))
	_box(bed, "Cabecero", Vector3(0, 0.28, -0.48), Vector3(0.6, 0.5, 0.04), Color(0.86, 0.8, 0.72))
	_box(bed, "Colchon", Vector3(0, 0.25, 0.02), Vector3(0.54, 0.08, 0.92), Color(0.96, 0.95, 0.92))
	_box(bed, "Almohada", Vector3(0, 0.31, -0.34), Vector3(0.36, 0.06, 0.18), Color(0.98, 0.98, 0.96))
	_box(bed, "Manta", Vector3(0, 0.3, 0.2), Vector3(0.56, 0.04, 0.58), PASTEL_YELLOW)
	# Debajo de la cama asoma el dibujo de Ana y Lurdes (desde que la cama está puesta).
	_kid_drawing(_lying(sec, "C_dibujo_amigas__after-cama_infantil", bed_at + Vector3(0.12, 0.013, 0.57), 160.0), "amigas")
	var ball := _node(sec, "P_pelota", Vector3(-2.2, FLOOR + 0.09, 1.45))
	_sphere(ball, "Pelota", Vector3.ZERO, 0.09, Color(0.9, 0.3, 0.3))
	_cyl(ball, "Franja", Vector3.ZERO, 0.092, 0.03, Color(0.98, 0.95, 0.9))
	var train := _node(sec, "P_tren", Vector3(-2.25, FLOOR + 0.03, 3.3))
	train.rotation_degrees.y = -15.0
	_box(train, "Locomotora", Vector3(0.14, 0.05, 0), Vector3(0.14, 0.08, 0.08), Color(0.3, 0.5, 0.8))
	_box(train, "Cabina", Vector3(0.1, 0.11, 0), Vector3(0.06, 0.06, 0.08), Color(0.3, 0.5, 0.8))
	_cyl(train, "Chimenea", Vector3(0.18, 0.11, 0), 0.015, 0.05, Color(0.2, 0.2, 0.22))
	_box(train, "Vagon1", Vector3(-0.02, 0.045, 0), Vector3(0.13, 0.07, 0.08), Color(0.95, 0.75, 0.3))
	_box(train, "Vagon2", Vector3(-0.17, 0.045, 0), Vector3(0.13, 0.07, 0.08), Color(0.6, 0.8, 0.45))
	_blocks(_node(sec, "P_cubos", Vector3(-1.25, FLOOR + 0.017, 1.4)))
	# La nutria del hermano (clave): sentada en la cama.
	var otter := _node(sec, "P_peluche__clave", bed_at + Vector3(0.0, 0.33, 0.28))
	otter.rotation_degrees.y = 20.0
	_otter(otter)


## La caja de juguetes: una caja del kit cuya tapa se levanta (OR_, bisagra atrás) y guarda los cubos y
## el dibujo de la casa (apoyado en el fondo: tumbado no se vería, trampa 34).
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
	var floor_y := body.position.y + 0.03
	var blocks := _node(chest, "H_cubos", Vector3(body.get_center().x, floor_y, body.get_center().z + 0.04))
	_blocks(blocks)
	var leaning := _node(chest, "C_dibujo_casa", Vector3(body.get_center().x, lid_box.position.y - 0.02, body.position.z + 0.05))
	leaning.rotation_degrees = Vector3(-20.0, 0.0, 0.0)
	_kid_drawing(leaning, "casa")


func _otter(otter: Node3D) -> void:
	var fur := Color(0.55, 0.38, 0.25)
	var belly := Color(0.86, 0.74, 0.58)
	_cyl(otter, "Cuerpo", Vector3(0, 0.09, 0), 0.06, 0.12, fur)
	_sphere(otter, "Culete", Vector3(0, 0.03, 0), 0.065, fur)
	_sphere(otter, "Barriga", Vector3(0, 0.08, 0.035), 0.045, belly)
	_sphere(otter, "Cabeza", Vector3(0, 0.19, 0), 0.055, fur)
	_sphere(otter, "Hocico", Vector3(0, 0.175, 0.045), 0.025, belly)
	_sphere(otter, "Nariz", Vector3(0, 0.185, 0.068), 0.008, Color(0.15, 0.1, 0.08))
	for x in [-0.03, 0.03]:
		_sphere(otter, "Oreja%d" % int(x > 0), Vector3(x * 1.4, 0.235, -0.01), 0.013, fur.darkened(0.1))
		_sphere(otter, "Ojo%d" % int(x > 0), Vector3(x * 0.7, 0.2, 0.047), 0.007, Color(0.1, 0.08, 0.06))
		_sphere(otter, "Pata%d" % int(x > 0), Vector3(x * 1.3, 0.1, 0.05), 0.018, fur.darkened(0.05))
	var tail := _cyl(otter, "Cola", Vector3(0, 0.02, -0.09), 0.025, 0.12, fur.darkened(0.05))
	tail.rotation_degrees.x = 70.0
	(tail.mesh as CylinderMesh).top_radius = 0.01


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
	_piece(top_drawer, "P_cajon__after-escritorio", ["Muebles/SM_DeskA/SM_DeskC"])
	_piece(drawers, "P_cajon_pomo__after-escritorio", ["Muebles/SM_DeskA/SM_DeskD"])
	_piece(drawers, "P_cajon__after-escritorio_001", ["Muebles/SM_DeskA/SM_DeskC2"])
	_application(_node(top_drawer, "H_solicitud", Vector3(drawer_box.get_center().x, drawer_box.end.y - 0.05, drawer_box.get_center().z) - top_drawer.global_position), true)
	# Lo de encima del escritorio, cada cosa su pieza: el tapete, el bote y sus lápices (iguales).
	_each(sec, "lapiz__after-bote", ["Muebles/SM_Vase/SM_BrushA", "Muebles/SM_Vase/SM_BrushB", "Muebles/SM_Vase/SM_BrushC"])
	_piece(sec, "P_bote__after-escritorio", ["Muebles/SM_Vase"])
	_piece(sec, "P_tapete__after-escritorio", ["Muebles/SM_CoverDesk"])
	_piece(sec, "P_escritorio", ["Muebles/SM_DeskA"])
	var top := Visuals.global_aabb(desk).end.y
	# El MP3 viene en trozos: se monta en su banco (Z_, primer plano), en la alfombra, y entero se pone
	# en el escritorio.
	var mp3 := _piece(sec, "P_mp3__after-escritorio", ["Muebles/SM_MP3"])
	_mp3_bench(sec, mp3.get_child(0) as Node3D, Vector3(-0.42, FLOOR + 0.025, 0.55))
	_piece(sec, "P_fotos__after-mp3", ["Muebles/SM_Polaroid"])
	var lamp := _piece(sec, "P_lampara__after-escritorio", ["Adornos/SM_Lamp"])
	_lamp_light(lamp)
	(lamp.get_node("Luz") as SpotLight3D).spot_range = 1.9
	_prop(sec, "P_silla", "chair_01", Vector3(-0.61, FLOOR, -0.55), 180.0)
	_prop(sec, "P_altavoz__after-escritorio", "speaker_01", Vector3(0.08, top, -1.42))
	_prop(sec, "P_libro__after-escritorio", "book_01", Vector3(-0.55, top, -1.4), 10.0)
	_prop(sec, "P_libro__after-escritorio_001", "book_01", Vector3(-0.55, top + 0.035, -1.4), -6.0)
	var cam_at := Vector3(-0.28, top, -1.02)
	var cam_piece := _node(sec, "P_camara__clave__flash", cam_at)
	cam_piece.rotation_degrees.y = -20.0
	_retro_camera(cam_piece)
	for k in 3:                                   # las fotos, en abanico junto a la cámara
		var photo := _box(cam_piece, "Foto%d" % k, Vector3(-0.16 + k * 0.02, 0.003 + k * 0.002, 0.06), Vector3(0.07, 0.003, 0.085), Color(0.97, 0.97, 0.95))
		photo.rotation_degrees.y = -15.0 + k * 15.0
		_box(photo, "Imagen", Vector3(0, 0.002, -0.006), Vector3(0.058, 0.002, 0.058), [Color(0.5, 0.7, 0.85), Color(0.9, 0.7, 0.5), Color(0.6, 0.8, 0.55)][k])
	# Debajo de la cámara, entre las fotos: un dibujo suyo (se encuentra solo al ponerla).
	_kid_drawing(_lying(sec, "C_dibujo_monstruo__con-camara", cam_at + Vector3(-0.1, 0.008, -0.1), -10.0), "monstruo")
	# El corcho, a la derecha de la ventana; la solicitud va en él cuando se encuentra en el cajón.
	var cork_at := Vector3(0.72, 2.05, -1.565)
	var corkboard := _node(sec, "P_corcho", cork_at)
	_box(corkboard, "Corcho", Vector3.ZERO, Vector3(0.36, 0.26, 0.02), Color(0.78, 0.6, 0.4))
	_box(corkboard, "Marco", Vector3(0, 0, -0.004), Vector3(0.4, 0.3, 0.015), WOOD)
	for k in 3:
		_box(corkboard, "Nota%d" % k, Vector3(-0.12 + k * 0.08, 0.06 - (k % 2) * 0.05, 0.012), Vector3(0.06, 0.06, 0.003), [PASTEL_YELLOW, PASTEL_PINK, PASTEL_BLUE][k])
	_application(_node(sec, "P_solicitud__after-mp3", cork_at + Vector3(0.0, -0.02, 0.025)), false)
	# Pósteres en el faldón, entre los cabrios, sobre el escritorio.
	var poster_a := _node(sec, "P_poster_estrellas", _on_slope(-0.95, -0.6))
	poster_a.rotation_degrees.z = _slope_deg()
	_box(poster_a, "Poster", Vector3.ZERO, Vector3(0.48, 0.008, 0.36), Color(0.15, 0.18, 0.35))
	for k in 5:
		_box(poster_a, "Estrella%d" % k, Vector3(-0.15 + (k * 7 % 5) * 0.07, -0.006, -0.12 + k * 0.06), Vector3(0.025, 0.004, 0.025), Color(1.0, 0.92, 0.6))
	var poster_b := _node(sec, "P_poster_grupo", _on_slope(-0.95, 0.9))
	poster_b.rotation_degrees.z = _slope_deg()
	_box(poster_b, "Poster", Vector3.ZERO, Vector3(0.52, 0.008, 0.4), Color(0.85, 0.35, 0.4))
	_box(poster_b, "Banda", Vector3(0.08, -0.006, 0), Vector3(0.18, 0.004, 0.3), Color(0.2, 0.15, 0.2))
	var puf := _node(sec, "P_puf", Vector3(0.35, FLOOR, 0.85))
	var bean := _sphere(puf, "Puf", Vector3(0, 0.16, 0), 0.26, TEEN_TEAL.lightened(0.1))
	bean.scale = Vector3(1.0, 0.62, 1.0)
	var guitar := _node(sec, "P_guitarra", Vector3(0.22, FLOOR, 1.9))   # apoyada en el costado de la cómoda
	guitar.rotation_degrees = Vector3(-10, 90, 0)
	var g1 := _sphere(guitar, "Caja", Vector3(0, 0.18, 0), 0.14, Color(0.85, 0.35, 0.22))
	g1.scale = Vector3(1, 1, 0.35)
	var g2 := _sphere(guitar, "Caja2", Vector3(0, 0.36, 0), 0.1, Color(0.85, 0.35, 0.22))
	g2.scale = Vector3(1, 1, 0.35)
	var hole := _cyl(guitar, "Boca", Vector3(0, 0.3, 0.035), 0.035, 0.004, Color(0.15, 0.1, 0.08))
	hole.rotation_degrees.x = 90.0
	_box(guitar, "Mastil", Vector3(0, 0.62, 0), Vector3(0.05, 0.42, 0.025), WOOD_DARK)
	_box(guitar, "Pala", Vector3(0, 0.86, 0), Vector3(0.07, 0.1, 0.025), WOOD_DARK)
	# La cámara está guardada en una caja del kit con tapa (OR_, bisagra atrás), junto al escritorio; la
	# caja y la tapa, piezas (la tapa dentro del OR_: sin ella, la caja no se abre).
	var cam_box := _node(sec, "CajaCamara", Vector3.ZERO)
	var cover := _art.get_node("Adornos/SM_BoxB/SM_CoverBoxB") as Node3D
	var body := Visuals.global_aabb(_art.get_node("Adornos/SM_BoxB") as Node3D)
	var lid_box := Visuals.global_aabb(cover)
	var lid := _node(cam_box, "OR_tapa_caja__x", Vector3(body.get_center().x, lid_box.position.y, body.position.z))
	_piece(lid, "P_tapa_camara__after-caja_camara", ["Adornos/SM_BoxB/SM_CoverBoxB"])   # (otros nombres que las de la
	_piece(cam_box, "P_caja_camara", ["Adornos/SM_BoxB"])                               # infancia: after-x mira todo el desván)
	_retro_camera(_node(cam_box, "H_camara", Vector3(body.get_center().x, body.position.y + 0.03, body.get_center().z)))


# --- Sección 4: la adultez (el caballete y el entrante) ------------------------------------------

func _adult(sec: Node3D) -> void:
	# La lámpara de pie del entrante es una pieza con su luz (se enciende al ponerla); la de la zona, aparte.
	var floor_lamp := _piece(sec, "P_lampara_pie", ["Muebles/SM_Lamp"])
	var head := Visuals.global_aabb(floor_lamp)
	_zone_light(sec, Vector3(head.get_center().x, head.end.y - 0.15, head.get_center().z))
	_lamp_light(floor_lamp)
	(floor_lamp.get_node("Luz") as SpotLight3D).spot_range = 1.9
	_piece(sec, "P_taburete", ["Muebles/SM_Stool"])
	_each(sec, "polaroid", ["A", "B", "C", "D"].map(func(k: String) -> String: return "Adornos/SM_Polaroid" + k))
	_piece(sec, "P_alfombra_adultez", ["Muebles/SM_Rug"])
	# Las llaves de la tienda, en la pared del entrante (de cara a la habitación).
	var keys := _node(sec, "P_llaves", Vector3(0.905, 1.05, -2.05))
	keys.rotation_degrees.y = 90.0
	_box(keys, "Tablilla", Vector3.ZERO, Vector3(0.24, 0.1, 0.02), WOOD)
	var hook := _cyl(keys, "Gancho", Vector3(0, -0.02, 0.02), 0.006, 0.03, Color(0.6, 0.6, 0.62))
	hook.rotation_degrees.x = 90.0
	var ring := _cyl(keys, "Llavero", Vector3(0, -0.05, 0.035), 0.022, 0.004, Color(0.75, 0.72, 0.6))
	ring.rotation_degrees.x = 90.0
	for k in 3:
		var key := _box(keys, "Llave%d" % k, Vector3(-0.02 + k * 0.02, -0.1, 0.035), Vector3(0.012, 0.07, 0.003), Color(0.82, 0.72, 0.4))
		key.rotation_degrees.z = -15.0 + k * 15.0
	var easel := _piece(sec, "P_caballete__after-llaves", ["Muebles/SM_Caballete"])
	var canvas_at := _easel_rest(easel)
	var canvas := _node(sec, "P_lienzo__after-caballete", canvas_at.origin)
	canvas.basis = canvas_at.basis
	_box(canvas, "Lienzo", Vector3(0, 0.36, 0), Vector3(0.58, 0.72, 0.03), Color(0.97, 0.96, 0.93))
	var brushes := _piece(sec, "P_pinceles__after-caballete", ["Adornos/SM_Vase"])
	(brushes.get_child(0) as Node3D).global_position = Vector3(-0.72, FLOOR, 1.0)
	_piece(sec, "P_espejo__clave__reflejo", ["Muebles/SM_Mirror"])
	_mirror_glass(sec.get_node("P_espejo__clave__reflejo") as Node3D)
	_piece(sec, "P_perchero", ["Muebles/SM_Burro"])
	_piece(sec, "P_sombrero__after-perchero", ["Muebles/SM_Hat"])
	# La mesita del entrante: en su cajón, los pinceles; encima, la taza y el reloj.
	var side := _node(sec, "Mesita", Vector3(2.62, FLOOR, -2.3))
	_box(side, "Tablero", Vector3(0, 0.5, 0), Vector3(0.42, 0.03, 0.36), WOOD)
	for x in [-0.18, 0.18]:
		for z in [-0.15, 0.15]:
			_box(side, "Pata%d%d" % [int(x > 0), int(z > 0)], Vector3(x, 0.25, z), Vector3(0.03, 0.5, 0.03), WOOD_DARK)
	var side_drawer := _node(side, "OD_cajon_mesita__nx", Vector3(0, 0.42, 0))
	_box(side_drawer, "Cajon", Vector3(0, 0, 0), Vector3(0.36, 0.1, 0.32), WOOD.lightened(0.1))
	_box(side_drawer, "Tirador", Vector3(-0.185, 0, 0), Vector3(0.012, 0.02, 0.08), Color(0.3, 0.3, 0.32))
	_brushes(_node(side_drawer, "H_pinceles", Vector3(0.02, 0.05, 0)), true)
	_prop(sec, "P_taza", "mug_01", Vector3(2.55, FLOOR + 0.515, -2.22))
	_prop(sec, "P_reloj", "clock_01", Vector3(2.69, FLOOR + 0.515, -2.38), -30.0)
	# Las cajas de la tienda, a la derecha; encima, el dibujo del gato.
	var boxes := _node(sec, "P_cajas_tienda", Vector3(2.55, FLOOR, 0.25))
	boxes.rotation_degrees.y = -20.0
	for k in 3:
		var bx := _box(boxes, "Caja%d" % k, Vector3(0.02 * (k % 2), 0.16 + k * 0.3, 0), Vector3(0.42 - k * 0.05, 0.3, 0.36 - k * 0.04), CARDBOARD.darkened(0.04 * k))
		bx.rotation_degrees.y = k * 5.0
	var label := MeshInstance3D.new()
	label.name = "Rotulo"
	var tm := TextMesh.new()
	tm.text = "TIENDA"
	tm.font_size = 40
	tm.pixel_size = 0.003
	tm.depth = 0.002
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color(0.25, 0.18, 0.12)
	tm.material = ink
	label.mesh = tm
	label.position = Vector3(0, 0.16, 0.185)
	boxes.add_child(label)
	_kid_drawing(_lying(sec, "C_dibujo_gato__after-cajas_tienda", Vector3(2.47, FLOOR + 0.913, 0.17), 0.0), "gato")
	var plant := _node(sec, "P_planta", Vector3(1.35, FLOOR, 0.55))
	_cyl(plant, "Maceta", Vector3(0, 0.12, 0), 0.12, 0.24, Color(0.75, 0.42, 0.3))
	for k in 5:
		var leaf := _sphere(plant, "Hoja%d" % k, Vector3(cos(k * 1.3) * 0.08, 0.32 + (k % 2) * 0.1, sin(k * 1.3) * 0.08), 0.1, Color(0.32, 0.55, 0.32))
		leaf.scale = Vector3(0.6, 1.1, 0.6)


## Dónde apoya el lienzo en el caballete del kit: en su repisa (a un tercio de su alto), por delante
## del palo central y algo inclinado hacia atrás, como el caballete.
func _easel_rest(easel: Node3D) -> Transform3D:
	var box := Visuals.global_aabb(easel)
	var yaw := (easel.get_child(0) as Node3D).global_rotation.y
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(-8.0))
	var front := Basis(Vector3.UP, yaw) * Vector3.BACK
	var at := Vector3(box.get_center().x, box.position.y + box.size.y * 0.36, box.get_center().z) + front * 0.1
	return Transform3D(basis, at)


## La luna del espejo del kit: una malla "Luna" justo delante del cristal (Momentos la busca por el
## nombre para el reflejo y el primer plano de frente).
func _mirror_glass(piece: Node3D) -> void:
	var mirror := piece.get_child(0) as Node3D
	var local := Visuals.local_aabb(mirror)
	var quad := QuadMesh.new()
	quad.size = Vector2(local.size.x * 0.62, local.size.y * 0.66)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.86, 0.9)
	mat.metallic = 1.0
	mat.roughness = 0.05
	quad.material = mat
	var glass := MeshInstance3D.new()
	glass.name = "Luna"
	glass.mesh = quad
	glass.position = Vector3(local.get_center().x, local.position.y + local.size.y * 0.56, local.end.z + 0.004)
	mirror.add_child(glass)


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
		_box(pin, "Pinza", Vector3(0, 0.004, 0.006), Vector3(0.012, 0.04, 0.008), WOOD_LIGHT)


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


## El MP3 del kit es una malla con sus trozos juntos (en el paquete, Pack05, vienen sueltos pero puestos
## para texturizar, no montados). Se parte en sus trozos sueltos (triángulos unidos), cada uno en su sitio
## del montado, y se agrupan en tres piezas: la carcasa (con la pantalla y los botones, que no se podrían
## coger de tan pequeños), la rueda y los auriculares (lo que queda fuera de la carcasa).
func _mp3_bench(sec: Node3D, mp3: Node3D, at: Vector3) -> void:
	var bench := _node(sec, "Z_montaje_mp3__reward-mp3__monta", at)
	bench.global_basis = mp3.global_basis
	var joined := Visuals.meshes_under(mp3)[0]
	var mat := joined.get_active_material(0)
	var in_piece := _rel(joined, mp3)              # (el montado va girado y escalado dentro de su pieza)
	var arrays := joined.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
	var faces := PackedVector3Array()
	for i in idx:
		faces.append(verts[i])
	var comps := _components(faces)
	comps.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.n > y.n)
	# La carcasa: la parte de 5 × 8 cm (como un iPod); la rueda: la redonda de ~3 cm que va encima.
	var body: Dictionary = {}
	var wheel: Dictionary = {}
	for c in comps:
		var sz := (c.box as AABB).size
		var dims := [sz.x, sz.y, sz.z]
		dims.sort()
		if body.is_empty() and dims[2] > 0.07 and dims[2] < 0.1 and dims[1] > 0.04:
			body = c
		elif wheel.is_empty() and absf(dims[2] - dims[1]) < 0.003 and dims[2] > 0.025 and dims[2] < 0.04:
			wheel = c
	assert(not body.is_empty() and not wheel.is_empty(), "no encuentro la carcasa o la rueda del MP3")
	var shell := (body.box as AABB).grow(0.003)
	var groups := {"carcasa_mp3": [], "rueda_mp3": [], "auriculares_mp3": []}
	for c in comps:
		var key := "rueda_mp3" if c == wheel else ("carcasa_mp3" if shell.has_point((c.box as AABB).get_center()) else "auriculares_mp3")
		groups[key].append_array(c.tris)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MESHES_OUT))
	for key: String in groups:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for t: int in groups[key]:
			for k in 3:
				var i := idx[t * 3 + k]
				if arrays[Mesh.ARRAY_NORMAL] != null:
					st.set_normal(arrays[Mesh.ARRAY_NORMAL][i])
				if arrays[Mesh.ARRAY_TEX_UV] != null:
					st.set_uv(arrays[Mesh.ARRAY_TEX_UV][i])
				st.add_vertex(verts[i])
		var part_mesh := st.commit()
		var path := MESHES_OUT + key + ".res"
		ResourceSaver.save(part_mesh, path)
		var tokens := "" if key == "carcasa_mp3" else "__after-carcasa_mp3"
		var piece := _node(bench, "P_%s%s" % [key, tokens], Vector3.ZERO)
		var m := MeshInstance3D.new()
		m.name = "Malla"
		m.mesh = load(path)
		m.transform = in_piece
		m.set_surface_override_material(0, mat)
		piece.add_child(m)
		print("MP3 %s: %d triángulos" % [key, (groups[key] as Array).size()])


## Los triángulos de una malla (en el espacio de `root`).
func _faces(m: MeshInstance3D, root: Node) -> PackedVector3Array:
	var xf := _rel(m, root)
	var faces := m.mesh.get_faces()
	for i in faces.size():
		faces[i] = xf * faces[i]
	return faces


## Las partes sueltas de una malla (triángulos unidos por sus vértices): [{n, box: AABB, tris: [índices]}].
func _components(faces: PackedVector3Array) -> Array:
	var tris := faces.size() / 3
	var up: Array[int] = []
	up.resize(tris)
	for t in tris:
		up[t] = t
	var find := func(x: int) -> int:
		while up[x] != x:
			up[x] = up[up[x]]
			x = up[x]
		return x
	var seen := {}
	for t in tris:
		for k in 3:
			var v := faces[t * 3 + k]
			var key := Vector3i(roundi(v.x * 20000.0), roundi(v.y * 20000.0), roundi(v.z * 20000.0))
			if seen.has(key):
				var a: int = find.call(t)
				var b: int = find.call(seen[key])
				if a != b:
					up[a] = b
			else:
				seen[key] = t
	var groups := {}
	for t in tris:
		var r: int = find.call(t)
		var tri_box := AABB(faces[t * 3], Vector3.ZERO).expand(faces[t * 3 + 1]).expand(faces[t * 3 + 2])
		if groups.has(r):
			groups[r].n += 1
			groups[r].box = (groups[r].box as AABB).merge(tri_box)
			groups[r].tris.append(t)
		else:
			groups[r] = {"n": 1, "box": tri_box, "tris": [t]}
	return groups.values()


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


## Dueño de todo lo nuevo y de lo traído del kit (lo de dentro de cada instancia sigue siendo suyo:
## se guarda como referencia a su escena del tileset, no copiado).
func _own_all(n: Node) -> void:
	for c in n.get_children():
		if c.owner == null or c.owner == _art:
			c.owner = _root
		_own_all(c)
