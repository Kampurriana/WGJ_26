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


# --- Sección 1: el desván (estructura) y la hucha ----------------------------------------------

func _structure(sec: Node3D) -> void:
	# Los tablones: tres largos (los del entrante, 6 m; los de la izquierda, 5 m; los del centro, 4 m).
	var kinds := {"FloorPlanks015": "largo", "FloorPlanks013": "medio", "FloorPlanks014": "corto"}
	for base: String in kinds:
		for k in 4:
			var kit_name := base if k == 0 else "%s_%d" % [base, k + 1]
			var piece := "P_tablon_%s%s" % [kinds[base], "" if k == 0 else "_%03d" % k]
			_piece(sec, piece, ["Arquitectura/" + kit_name])
	_piece(sec, "P_pared_fondo", ["Arquitectura/SM_WallA", "Arquitectura/SM_SkirtingBoardJ"])
	_piece(sec, "P_pared_lateral", ["Arquitectura/SM_WallB", "Arquitectura/SM_Pillar", "Arquitectura/SM_Pillar_2",
		"Arquitectura/SM_SkirtingBoardTopA", "Arquitectura/SM_SkirtingBoardTopA_2", "Adornos/CuerdaEntrante"])
	_piece(sec, "P_pared_rincon", ["Arquitectura/SM_WallC", "Arquitectura/SM_Pillar_3",
		"Arquitectura/SM_SkirtingBoardL", "Arquitectura/SM_SkirtingBoardTopA_3"])
	_piece(sec, "P_ventana__after-pared_fondo", ["Arquitectura/SM_Window"])
	_piece(sec, "P_cumbrera__after-pared_fondo__after-pared_lateral", ["Arquitectura/CeilingSupport020_2"])
	var rafters := ["A", "B", "C", "D"]
	for k in 4:
		_piece(sec, "P_viga__after-cumbrera" + ("" if k == 0 else "_%03d" % k),
			["Arquitectura/SM_CeilingSupportVertical" + rafters[k]])
	_piece(sec, "P_tejado__after-cumbrera", ["Arquitectura/SM_Ceiling", "Arquitectura/CeilingSupport018",
		"Arquitectura/CeilingSupport021", "Arquitectura/CeilingSupport020", "Arquitectura/CeilingSupport014",
		"Arquitectura/CeilingSupport015", "Arquitectura/CeilingSupport016", "Arquitectura/CeilingSupport017",
		"Arquitectura/SM_SkirtingBoardI", "Adornos/CuerdaFaldon"])        # (con la cuerda de bombillitas que cuelga de él)
	# La hucha, en el centro sobre una caja del kit (el baúl viejo: lo que la sostiene en el final).
	var trunk := _take("Muebles/SM_BoxB", _root, "BaulViejo")
	trunk.global_position = Vector3(0.45, FLOOR, 1.95)
	trunk.rotation_degrees.y = 8.0
	var top := Visuals.global_aabb(trunk).end.y
	var pig := _piece(sec, "P_hucha__clave", ["Muebles/SM_ComodaA/SM_Pig"], Vector3(0.45, top, 1.95))
	var kit_pig := pig.get_child(0) as Node3D
	kit_pig.global_position = Vector3(0.45, top, 1.95)
	kit_pig.global_rotation_degrees = Vector3(0, 20.0, 0)
	kit_pig.global_position.y += top - Visuals.global_aabb(kit_pig).position.y   # apoyada justo encima (el final busca lo que la sostiene)


# --- Sección 2: la infancia (izquierda) ----------------------------------------------------------

func _childhood(sec: Node3D) -> void:
	_zone_light(sec, Vector3(-1.6, 2.6, 1.6))
	_piece(sec, "P_caja_musica__after-comoda_infantil", ["Muebles/SM_ComodaA/SM_MusicBox"])   # (antes de mover la cómoda)
	var dresser := _piece(sec, "P_comoda_infantil", ["Muebles/SM_ComodaA"])
	assert(dresser.get_child(0).get_node_or_null("SM_ComodaB") != null, "la cómoda sin sus cajones")
	_piece(sec, "P_dibujo__after-caja_musica", ["Adornos/Dibujo_t_draw_03"])
	_piece(sec, "P_tele", ["Muebles/SM_TV"])
	_piece(sec, "P_cama_gato", ["Muebles/SM_CatBed"])
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
	var stacked := _take("Adornos/SM_BoxC/SM_BoxE", _root, "CajaApilada")   # la que llevaba encima, a la esquina
	stacked.global_position = Vector3(-2.72, FLOOR, 3.28)
	var chest := _node(sec, "BaulJuguetes", Vector3.ZERO)
	var box := _take("Adornos/SM_BoxC", chest)
	var cover := box.get_node("SM_CoverBoxC") as Node3D
	var body := Visuals.global_aabb(box)
	var lid_box := Visuals.global_aabb(cover)
	var lid := _node(chest, "OR_tapa_baul__x", Vector3(body.get_center().x, lid_box.position.y, body.position.z))
	cover.reparent(lid, true)
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
	# El escritorio del kit y sus cajones (decorado: se ven aunque el escritorio aún sea silueta). En el
	# de arriba, la inscripción a Bellas Artes.
	var desk := _art.get_node("Muebles/SM_DeskA") as Node3D
	var drawers := _node(sec, "Cajones", Vector3.ZERO)
	var top_drawer := _node(drawers, "OD_cajon_escritorio", (desk.get_node("SM_DeskC") as Node3D).global_position)
	_take("Muebles/SM_DeskA/SM_DeskC", top_drawer)
	_take("Muebles/SM_DeskA/SM_DeskD", drawers, "Cajon1")
	_take("Muebles/SM_DeskA/SM_DeskC2", drawers, "Cajon2")
	var drawer_box := Visuals.global_aabb(top_drawer)
	_application(_node(top_drawer, "H_solicitud", Vector3(drawer_box.get_center().x, drawer_box.end.y - 0.05, drawer_box.get_center().z) - top_drawer.global_position), true)
	_piece(sec, "P_escritorio", ["Muebles/SM_DeskA", "Muebles/SM_CoverDesk", "Muebles/SM_Vase"])
	var top := Visuals.global_aabb(desk).end.y
	_piece(sec, "P_mp3__after-escritorio", ["Muebles/SM_MP3"])
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
	# La cámara está guardada en una caja del kit con tapa (OR_, bisagra atrás), junto al escritorio.
	var cam_box := _node(sec, "CajaCamara", Vector3.ZERO)
	var box := _take("Adornos/SM_BoxB", cam_box)
	var cover := box.get_node("SM_CoverBoxB") as Node3D
	var body := Visuals.global_aabb(box)
	var lid_box := Visuals.global_aabb(cover)
	var lid := _node(cam_box, "OR_tapa_caja__x", Vector3(body.get_center().x, lid_box.position.y, body.position.z))
	cover.reparent(lid, true)
	_retro_camera(_node(cam_box, "H_camara", Vector3(body.get_center().x, body.position.y + 0.03, body.get_center().z)))


# --- Sección 4: la adultez (el caballete y el entrante) ------------------------------------------

func _adult(sec: Node3D) -> void:
	var floor_lamp := _take("Muebles/SM_Lamp", sec, "LamparaEntrante")      # decorado, con la luz de la zona
	var head := Visuals.global_aabb(floor_lamp)
	_zone_light(floor_lamp, Vector3(head.get_center().x, head.end.y - 0.15, head.get_center().z) - floor_lamp.global_position)
	_take("Muebles/SM_Stool", sec, "Taburete")
	for k in ["A", "B", "C", "D"]:
		_take("Adornos/SM_Polaroid" + k, sec)
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
			_take("%s/%s" % [group, c.name], trastos)


# --- Utilidades ------------------------------------------------------------------------------------

## Mueve un nodo del diorama de las artistas a `parent` (sin cambiar dónde está ni cómo gira).
func _take(path: String, parent: Node3D, new_name := "") -> Node3D:
	var n := _art.get_node(path) as Node3D
	assert(n != null, "falta %s en %s" % [path, KIT_DIORAMA])
	n.owner = null                               # (se lo vuelve a dar _own_all, ya en el modelo)
	n.reparent(parent, true)
	if new_name != "":
		n.name = new_name
	return n


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
