extends "res://tools/pack_props.gd"
## EL PROTOTIPO (16-18 oct): el desván de la historia con figuras provisionales, con el que se iteró
## la jugabilidad. Se conserva aparte (levels/prototipo/; se juega con levels/prototipo/jugar_prototipo.tscn
## o `--prototipo`). El desván que se juega es el del arte oficial: tools/build_kit_level.gd, con las
## mismas secciones, piezas y reglas. Secciones que se montan por orden (S_):
##   S_1_desvan        el suelo (18 tablones de tres largos parecidos: cada uno vale en varios huecos,
##                     no en todos), paredes y tejado; al final, la hucha (prólogo, __clave)
##   S_2_infancia      zona izquierda: caja de música -> dibujo -> nutria (clave) + su dressing
##   S_3_adolescencia  zona central (guion v2): MP3 -> solicitud de Bellas Artes (escondida en el
##                     cajón de arriba del escritorio) -> cámara (escondida en el armario, clave y
##                     flash) + su dressing. El escritorio y sus cajones son los de las artistas (kit)
##   S_4_adultez       zona derecha, la profesión: llaves -> caballete -> espejo (clave, __reflejo: su momento
##                     es de frente y con todo a negro) + su dressing
##   S_5_epilogo       la moneda (__ofrecida: aparece junto a la hucha y se arrastra a la ranura)
## Las tres zonas comparten suelo y tejado (integradas); cada una tiene su alfombra, su bombilla
## (se enciende al abrirse) y muebles que se abren con algo dentro (baúl, armario, cajones).
## Dibujos escondidos (C_, cuarta nota): los dibujos de cuando era pequeña, los de las artistas
## (assets/kit/dibujos/, DIBUJOS); cada uno que se encuentra se cuelga en la cuerda de la infancia
## (T_): la casa en el baúl de juguetes · Ana y Lurdes debajo de la cama (after-cama_infantil) · el
## monstruo debajo del puf (after-puf) · el gato encima de las cajas de la tienda. El de la niña y la abuela bailarina no es coleccionable:
## es el dibujo de pared de la infancia (P_dibujo, "las niñas no pintan monstruos"), DIBUJO_PARED.
## Ejecutar:
##   godot --headless --path . --script res://tools/build_attic_level.gd
## Escribe:
##   levels/provisional/desvan_provisional.tscn  el modelo provisional (figuras + props del pack MIT)
##   levels/prototipo/desvan_prototipo.tscn      el nivel: solo el Diorama con sus ajustes

const ATTIC_MODEL_OUT := "res://levels/provisional/desvan_provisional.tscn"
const ATTIC_LEVEL_OUT := "res://levels/prototipo/desvan_prototipo.tscn"
const HALF_W := 2.7                          ## el desván va de x=-2.7 a 2.7
const HALF_D := 1.65                         ## y de z=-1.65 (fondo) a 1.65 (delante, abierto)
const KNEE := 1.0                            ## altura de la pared del fondo
const RIDGE := 2.4                           ## altura de la cumbrera (z = 0)
const WALL_IN := -1.55                       ## cara interior de la pared del fondo

var _slope := atan2(RIDGE - KNEE, HALF_D)    ## inclinación del tejado (rad)

## Paleta: madera del desván, pasteles de la infancia, morados de la adolescencia, grises de la adultez.
const WOOD := Color(0.55, 0.37, 0.24)
const WOOD_DARK := Color(0.36, 0.24, 0.16)
const WOOD_LIGHT := Color(0.76, 0.6, 0.42)
const PLASTER := Color(0.84, 0.78, 0.68)
const CARDBOARD := Color(0.7, 0.55, 0.38)
const PASTEL_PINK := Color(0.93, 0.68, 0.72)
const PASTEL_BLUE := Color(0.62, 0.76, 0.9)
const PASTEL_MINT := Color(0.66, 0.85, 0.74)
const PASTEL_YELLOW := Color(0.98, 0.88, 0.58)
const TEEN_PURPLE := Color(0.46, 0.36, 0.62)
const TEEN_TEAL := Color(0.25, 0.58, 0.6)
const ADULT_GREY := Color(0.48, 0.52, 0.58)
const ADULT_OLIVE := Color(0.5, 0.52, 0.36)
const WARM_BULB := Color(1.0, 0.76, 0.48)
const DRAWING_LONG := 0.23                   ## el lado largo de un dibujo (m): el otro, según la imagen
## Los dibujos coleccionables (C_dibujo_<clave>): la imagen de cada uno.
const DIBUJOS := {
	"casa": "res://assets/kit/dibujos/t_draw_00.jpg",
	"monstruo": "res://assets/kit/dibujos/t_draw_01.jpg",
	"gato": "res://assets/kit/dibujos/t_draw_02.jpg",
	"amigas": "res://assets/kit/dibujos/t_draw_04.jpg",
}
## El dibujo de la pared de la infancia (la pieza P_dibujo): la niña bailarina y su abuela.
const DIBUJO_PARED := "res://assets/kit/dibujos/t_draw_03.png"
const CUADRO_LIENZO := "res://assets/kit/dibujos/t_draw_05.jpg"   ## lo que pinta en el lienzo del caballete (la adultez)
## El escritorio de las artistas (assets/kit/): SM_DeskA con el frente a -Z (aquí se gira 180° para que
## mire al jugador). A un lado, una columna de 0,27 m sin baldas, bajo el tablero, para tres cajones
## (SM_DeskC con estrella; SM_DeskD, con pomo redondo, solo viene en el paquete; SM_DeskB aún no está).
const KIT_DESK := "res://assets/kit/modelos/Desk/SM_DeskA.fbx"
const KIT_DRAWER := "res://assets/kit/modelos/Desk/SM_DeskC.fbx"
const KIT_DRAWER_PACK := "res://assets/kit/paquetes/FloorCeilingPlanksCajonesqueFaltan.fbx"
const KIT_DESK_MAT := "res://assets/kit/materiales/M_Desk.tres"
const KIT_DESK_TOP := 0.745                  ## altura del tablero (medida del modelo)
const KIT_DESK_COLUMN := Vector2(0.385, 0.66) ## la columna de cajones (girado): x del centro y techo
const KIT_DRAWER_H := 0.2084                 ## alto de un cajón
const KIT_DRAWER_Z := 0.064                  ## centro de un cajón: su frente, a ras del escritorio
const LINE_Z := -1.15                        ## la cuerda de los dibujos: delante del faldón, encima de la cama
const LINE_X := Vector2(-2.6, -0.98)         ## de la pared izquierda hasta casi el escritorio
const LINE_Y := 1.42                         ## altura de sus extremos
const LINE_SAG := 0.09                       ## lo que cuelga en el centro


func _initialize() -> void:
	var model := Node3D.new()
	model.name = "Desvan"
	_root = model
	_build_base(model)
	_build_structure(_node(model, "S_1_desvan", Vector3.ZERO))
	_build_childhood(_node(model, "S_2_infancia", Vector3.ZERO))
	_build_teen(_node(model, "S_3_adolescencia", Vector3.ZERO))
	_build_adult(_node(model, "S_4_adultez", Vector3.ZERO))
	var epilogue := _node(model, "S_5_epilogo", Vector3.ZERO)
	var coin := _node(epilogue, "P_moneda__ofrecida", Vector3(0.0, 0.62, 1.12))
	var c := _cyl(coin, "Moneda", Vector3.ZERO, 0.045, 0.012, Color(0.95, 0.76, 0.3))
	c.rotation_degrees = Vector3(0, 0, 90)          # de canto, a lo largo de la ranura
	_shiny(c, 0.85, 0.3)
	_own(model)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ATTIC_MODEL_OUT.get_base_dir()))
	var packed := PackedScene.new()
	var err := packed.pack(model)
	if err == OK:
		err = ResourceSaver.save(packed, ATTIC_MODEL_OUT)
	print("MODELO DESVAN %s err=%d" % [ATTIC_MODEL_OUT, err])
	model.free()
	if err != OK:
		quit(1)
		return

	var level := Node3D.new()
	level.name = "DesvanPrototipo"
	level.set_script(load("res://core/diorama.gd"))
	level.set("level_title", "El desván (prototipo)")
	level.set("modelo", "")
	level.set("modelo_provisional", ATTIC_MODEL_OUT)
	level.set("intro_key", "intro_desvan")
	level.set("outro_key", "")
	level.set("fundido_final", true)
	level.set("momentos", true)
	level.set("color_radius", 0.7)
	level.set("camera_distance", 8.2)
	level.set("camera_min_distance", 2.0)
	level.set("camera_max_distance", 10.0)
	level.set("camera_pitch_deg", 24.0)
	level.set("camera_yaw_deg", 6.0)
	level.set("camera_yaw_min_deg", -32.0)        ## el desván está abierto por delante: más allá se ven las paredes por fuera
	level.set("camera_yaw_max_deg", 32.0)
	level.set("camera_pitch_min_deg", 10.0)
	level.set("camera_pitch_max_deg", 55.0)
	level.set("iluminacion", "res://iluminacion/desvan.tscn")
	packed = PackedScene.new()
	err = packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, ATTIC_LEVEL_OUT)
	print("NIVEL DESVAN %s err=%d" % [ATTIC_LEVEL_OUT, err])
	level.free()
	quit(0 if err == OK else 1)


# --- Base y trastos del desván (decorado: siempre ahí, empieza sin pintar) --------------------

func _build_base(root: Node3D) -> void:
	_box(root, "Peana", Vector3(0, -0.16, 0), Vector3(HALF_W * 2 + 0.4, 0.3, HALF_D * 2 + 0.4), WOOD_DARK)
	# Trastos entre zonas: cajas, una maleta, una alfombra enrollada.
	_box(root, "CajaVieja1", Vector3(-0.64, 0.17, -1.3), Vector3(0.36, 0.34, 0.34), CARDBOARD)   # bajo el escritorio
	_box(root, "CajaVieja2", Vector3(-0.62, 0.46, -1.32), Vector3(0.28, 0.24, 0.28), CARDBOARD.darkened(0.08))
	_box(root, "Maleta", Vector3(0.95, 0.14, -1.42), Vector3(0.18, 0.28, 0.4), Color(0.5, 0.3, 0.22))
	_box(root, "AsaMaleta", Vector3(0.95, 0.3, -1.42), Vector3(0.03, 0.04, 0.12), WOOD_DARK)
	var rolled := _cyl(root, "AlfombraEnrollada", Vector3(-2.35, 0.08, 1.35), 0.08, 0.9, Color(0.62, 0.32, 0.28))
	rolled.rotation_degrees = Vector3(0, 0, 90)
	# El baúl viejo del centro, donde va la hucha.
	_box(root, "BaulViejo", Vector3(0.0, 0.2, 1.12), Vector3(0.62, 0.4, 0.4), WOOD)
	_box(root, "HerrajeBaul", Vector3(0.0, 0.2, 1.325), Vector3(0.64, 0.05, 0.02), Color(0.3, 0.28, 0.27))


# --- Sección 1: paredes y tejado, y la hucha --------------------------------------------------

func _build_structure(sec: Node3D) -> void:
	_floor(sec)
	_box(_node(sec, "P_pared_fondo", Vector3(0, 0, -HALF_D + 0.05)), "Pared", Vector3(0, KNEE * 0.5, 0), Vector3(HALF_W * 2, KNEE, 0.1), PLASTER)
	var gable := PackedVector2Array([Vector2(-HALF_D, 0), Vector2(0, 0), Vector2(0, RIDGE), Vector2(-HALF_D, KNEE)])
	_prism(_node(sec, "P_pared_izquierda", Vector3(-HALF_W, 0, 0)), "Pared", gable, 0.1, PLASTER.darkened(0.04))
	_prism(_node(sec, "P_pared_derecha", Vector3(HALF_W, 0, 0)), "Pared", gable, 0.1, PLASTER.darkened(0.04))
	var ridge := _node(sec, "P_cumbrera__after-pared_izquierda__after-pared_derecha", Vector3(0, RIDGE, 0))
	_box(ridge, "Viga", Vector3.ZERO, Vector3(HALF_W * 2 + 0.2, 0.14, 0.14), WOOD_DARK)
	var length := Vector2(HALF_D, RIDGE - KNEE).length() + 0.06
	for i in 3:                                   # el faldón del fondo, en tres paneles iguales
		var panel := _node(sec, "P_tejado__after-cumbrera" + ("" if i == 0 else "_%03d" % i),
			Vector3(-1.8 + i * 1.8, (RIDGE + KNEE) * 0.5, -HALF_D * 0.5))
		panel.rotation.x = -_slope
		_box(panel, "Tablero", Vector3.ZERO, Vector3(1.8, 0.08, length), Color(0.62, 0.42, 0.3))
		for k in 3:
			_box(panel, "Rastrel%d" % k, Vector3(0, -0.05, -0.7 + k * 0.7), Vector3(1.8, 0.03, 0.06), WOOD_DARK)
	for i in 2:                                   # las vigas de los extremos: el desván se ve abierto
		var x := [-2.62, 2.62][i] as float
		var beam := _node(sec, "P_viga__after-cumbrera" + ("" if i == 0 else "_%03d" % i), Vector3(x, (RIDGE + KNEE) * 0.5, HALF_D * 0.5))
		beam.rotation.x = _slope
		_box(beam, "Viga", Vector3.ZERO, Vector3(0.1, 0.1, length), WOOD)
	var window := _node(sec, "P_ventana__after-pared_derecha", Vector3(HALF_W - 0.06, 1.35, -0.75))
	var ring := _cyl(window, "Marco", Vector3.ZERO, 0.24, 0.06, WOOD_DARK)
	ring.rotation_degrees = Vector3(0, 0, 90)
	var glass := _cyl(window, "Cristal", Vector3(-0.01, 0, 0), 0.2, 0.05, Color(0.7, 0.82, 0.92))
	glass.rotation_degrees = Vector3(0, 0, 90)
	_box(window, "Cruceta1", Vector3(-0.035, 0, 0), Vector3(0.02, 0.4, 0.025), WOOD_DARK)
	_box(window, "Cruceta2", Vector3(-0.035, 0, 0), Vector3(0.02, 0.025, 0.4), WOOD_DARK)
	# La hucha: cierra la estructura y abre la historia.
	var pig := _node(sec, "P_hucha__clave", Vector3(0.0, 0.4, 1.12))
	var pink := Color(0.95, 0.62, 0.68)
	var body := _sphere(pig, "Cuerpo", Vector3(0, 0.11, 0), 0.12, pink)
	body.scale = Vector3(1.25, 0.95, 0.95)
	var snout := _cyl(pig, "Hocico", Vector3(0.16, 0.11, 0), 0.04, 0.04, pink.darkened(0.08))
	snout.rotation_degrees = Vector3(0, 0, 90)
	for z in [-0.05, 0.05]:
		_sphere(pig, "Oreja%d" % int(z > 0), Vector3(0.08, 0.21, z), 0.03, pink.darkened(0.05))
		for x in [-0.08, 0.08]:
			_cyl(pig, "Pata%d%d" % [int(x > 0), int(z > 0)], Vector3(x, 0.025, z), 0.025, 0.05, pink.darkened(0.1))
	_box(pig, "Ranura", Vector3(0, 0.225, 0), Vector3(0.016, 0.01, 0.1), Color(0.25, 0.15, 0.15))


## El suelo, a tablones (quinta nota): 6 filas de tres tablones de largos parecidos (2,0 / 1,8 /
## 1,6 m), en otro orden en cada fila. Un tablón largo vale en cualquier hueco largo, pero no en uno
## mediano: hay que fijarse para encontrar dónde va cada uno. Entre tablón y tablón, una rendija.
func _floor(sec: Node3D) -> void:
	var lengths := {"largo": 2.0, "medio": 1.8, "corto": 1.6}
	var rows := [["largo", "medio", "corto"], ["corto", "largo", "medio"], ["medio", "corto", "largo"],
		["largo", "corto", "medio"], ["corto", "medio", "largo"], ["medio", "largo", "corto"]]
	var used := {"largo": 0, "medio": 0, "corto": 0}
	var width := HALF_D * 2.0 / rows.size()
	for r in rows.size():
		var z := -HALF_D + width * (r + 0.5)
		var x := -HALF_W
		for kind: String in rows[r]:
			var length: float = lengths[kind]
			var n: int = used[kind]
			used[kind] = n + 1
			var plank := _node(sec, "P_tablon_%s%s" % [kind, "" if n == 0 else "_%03d" % n], Vector3(x + length * 0.5, 0.0, z))
			var tone := WOOD_LIGHT.darkened(0.03 * ((r + n) % 3)).lightened(0.02 * (r % 2))
			_box(plank, "Tablon", Vector3.ZERO, Vector3(length - 0.014, 0.02, width - 0.014), tone)
			var k := 0
			for end in [-1.0, 1.0]:                # dos clavos en cada punta
				for side in [-1.0, 1.0]:
					_box(plank, "Clavo%d" % k, Vector3(end * (length * 0.5 - 0.06), 0.0105, side * width * 0.28), Vector3(0.012, 0.002, 0.012), WOOD_DARK)
					k += 1
			x += length


# --- Sección 2: la infancia (izquierda) -------------------------------------------------------

func _build_childhood(sec: Node3D) -> void:
	_bulb(sec, Vector3(-1.8, 1.8, -0.35))
	# Baúl de juguetes: la tapa se levanta (OR_ con bisagra horizontal) y dentro están los cubos.
	# Junto a los pies de la cama: a la vista desde la cámara (más adelante lo tapaba la viga).
	var chest := _node(sec, "BaulJuguetes", Vector3(-1.55, 0, -0.55))
	chest.rotation_degrees.y = 90.0
	_box(chest, "Fondo", Vector3(0, 0.02, 0), Vector3(0.56, 0.04, 0.34), PASTEL_BLUE.darkened(0.15))
	_box(chest, "Frente", Vector3(0, 0.15, 0.16), Vector3(0.56, 0.3, 0.02), PASTEL_BLUE)
	_box(chest, "Trasera", Vector3(0, 0.15, -0.16), Vector3(0.56, 0.3, 0.02), PASTEL_BLUE)
	_box(chest, "LadoA", Vector3(-0.27, 0.15, 0), Vector3(0.02, 0.3, 0.34), PASTEL_BLUE)
	_box(chest, "LadoB", Vector3(0.27, 0.15, 0), Vector3(0.02, 0.3, 0.34), PASTEL_BLUE)
	var lid := _node(chest, "OR_tapa_baul__x", Vector3(0, 0.3, -0.17))
	_box(lid, "Tapa", Vector3(0, 0.015, 0.17), Vector3(0.58, 0.03, 0.36), PASTEL_PINK)
	_box(lid, "Estrella", Vector3(0, 0.035, 0.17), Vector3(0.1, 0.01, 0.1), PASTEL_YELLOW)
	var hidden_blocks := _node(chest, "H_cubos", Vector3(0, 0.08, 0))
	_blocks(hidden_blocks)
	# Apoyado en el fondo del baúl (tumbado no se vería desde la cámara: el lado de delante lo tapa).
	var leaning := _node(chest, "C_dibujo_casa", Vector3(0.235, 0.24, 0.0))
	leaning.rotation_degrees = Vector3(-20.0, -90.0, 0.0)
	_kid_drawing(leaning, "casa")
	# Debajo de la cama asoma otro, el de Ana y Lurdes (está desde que la cama está puesta).
	_kid_drawing(_lying(sec, "C_dibujo_amigas__after-cama_infantil", Vector3(-2.08, 0.013, -0.43), 160.0), "amigas")
	# La cuerda de los dibujos (distinta de la de las fotos, encima del escritorio).
	_clothesline(sec)
	# Piezas.
	var rug := _node(sec, "P_alfombra_infancia", Vector3(-1.75, 0.012, 0.45))
	_cyl(rug, "Alfombra", Vector3.ZERO, 0.62, 0.015, PASTEL_PINK)
	_cyl(rug, "Circulo", Vector3(0, 0.002, 0), 0.4, 0.015, PASTEL_BLUE)
	var bed := _node(sec, "P_cama_infantil", Vector3(-2.2, 0, -1.0))
	_box(bed, "Marco", Vector3(0, 0.12, 0), Vector3(0.6, 0.2, 1.0), Color(0.86, 0.8, 0.72))
	_box(bed, "Cabecero", Vector3(0, 0.28, -0.48), Vector3(0.6, 0.5, 0.04), Color(0.86, 0.8, 0.72))
	_box(bed, "Colchon", Vector3(0, 0.25, 0.02), Vector3(0.54, 0.08, 0.92), Color(0.96, 0.95, 0.92))
	_box(bed, "Almohada", Vector3(0, 0.31, -0.34), Vector3(0.36, 0.06, 0.18), Color(0.98, 0.98, 0.96))
	_box(bed, "Manta", Vector3(0, 0.3, 0.2), Vector3(0.56, 0.04, 0.58), PASTEL_YELLOW)
	var dresser := _node(sec, "P_comoda_infantil", Vector3(-1.3, 0, -1.33))
	_box(dresser, "Cuerpo", Vector3(0, 0.23, 0), Vector3(0.46, 0.46, 0.3), PASTEL_MINT)
	for k in 2:
		_box(dresser, "Cajon%d" % k, Vector3(0, 0.13 + k * 0.2, 0.152), Vector3(0.4, 0.16, 0.01), PASTEL_MINT.lightened(0.15))
		_sphere(dresser, "Pomo%d" % k, Vector3(0, 0.13 + k * 0.2, 0.165), 0.018, PASTEL_PINK)
	var box_music := _node(sec, "P_caja_musica__after-comoda_infantil", Vector3(-1.3, 0.46, -1.36))
	_box(box_music, "Caja", Vector3(0, 0.04, 0), Vector3(0.18, 0.08, 0.12), Color(0.82, 0.45, 0.55))
	var lid_music := _box(box_music, "TapaAbierta", Vector3(0, 0.12, -0.065), Vector3(0.18, 0.11, 0.012), Color(0.82, 0.45, 0.55))
	lid_music.rotation_degrees.x = -12.0
	_box(box_music, "Espejito", Vector3(0, 0.12, -0.057), Vector3(0.13, 0.08, 0.004), Color(0.85, 0.9, 0.95))
	_cyl(box_music, "Bailarina", Vector3(0, 0.12, 0.0), 0.008, 0.06, Color(0.98, 0.85, 0.8))
	_sphere(box_music, "Cabeza", Vector3(0, 0.16, 0.0), 0.012, Color(0.98, 0.85, 0.8))
	_cyl(box_music, "Tutu", Vector3(0, 0.125, 0.0), 0.028, 0.008, Color(0.98, 0.75, 0.85))
	var drawing := _node(sec, "P_dibujo__after-caja_musica", Vector3(-1.95, 0.72, WALL_IN + 0.005))
	var wall_size := _sheet(drawing, DIBUJO_PARED, 0.34, false)   # pegado a la pared por el centro
	_box(drawing, "Celo", Vector3(0, wall_size.y * 0.5 - 0.005, 0.004), Vector3(0.06, 0.015, 0.002), Color(0.9, 0.88, 0.8))
	var horse := _node(sec, "P_caballito", Vector3(-1.25, 0, 0.55))
	horse.rotation_degrees.y = 25.0
	for z in [-0.08, 0.08]:
		var rocker := _box(horse, "Balancin%d" % int(z > 0), Vector3(0, 0.04, z), Vector3(0.55, 0.03, 0.02), WOOD)
		rocker.rotation_degrees.z = 0.0
	for x in [-0.12, 0.12]:
		for z in [-0.06, 0.06]:
			_box(horse, "Pata%d%d" % [int(x > 0), int(z > 0)], Vector3(x, 0.16, z), Vector3(0.03, 0.22, 0.03), Color(0.9, 0.88, 0.85))
	_box(horse, "Cuerpo", Vector3(0, 0.3, 0), Vector3(0.36, 0.14, 0.13), Color(0.95, 0.93, 0.9))
	var head := _box(horse, "Cabeza", Vector3(0.2, 0.42, 0), Vector3(0.1, 0.18, 0.09), Color(0.95, 0.93, 0.9))
	head.rotation_degrees.z = -20.0
	_box(horse, "Crin", Vector3(0.17, 0.46, 0), Vector3(0.05, 0.16, 0.1), Color(0.75, 0.45, 0.3))
	_box(horse, "Silla", Vector3(-0.02, 0.38, 0), Vector3(0.12, 0.02, 0.15), Color(0.85, 0.3, 0.3))
	var ball := _node(sec, "P_pelota", Vector3(-2.3, 0.09, 1.2))
	_sphere(ball, "Pelota", Vector3.ZERO, 0.09, Color(0.9, 0.3, 0.3))
	_cyl(ball, "Franja", Vector3.ZERO, 0.092, 0.03, Color(0.98, 0.95, 0.9))
	var train := _node(sec, "P_tren", Vector3(-1.85, 0.03, 0.6))
	train.rotation_degrees.y = -15.0
	_box(train, "Locomotora", Vector3(0.14, 0.05, 0), Vector3(0.14, 0.08, 0.08), Color(0.3, 0.5, 0.8))
	_box(train, "Cabina", Vector3(0.1, 0.11, 0), Vector3(0.06, 0.06, 0.08), Color(0.3, 0.5, 0.8))
	_cyl(train, "Chimenea", Vector3(0.18, 0.11, 0), 0.015, 0.05, Color(0.2, 0.2, 0.22))
	_box(train, "Vagon1", Vector3(-0.02, 0.045, 0), Vector3(0.13, 0.07, 0.08), Color(0.95, 0.75, 0.3))
	_box(train, "Vagon2", Vector3(-0.17, 0.045, 0), Vector3(0.13, 0.07, 0.08), Color(0.6, 0.8, 0.45))
	var shelf := _node(sec, "P_estante_cuentos", Vector3(-2.52, 0, -0.35))
	shelf.rotation_degrees.y = 90.0
	_box(shelf, "Mueble", Vector3(0, 0.25, 0), Vector3(0.6, 0.5, 0.24), Color(0.9, 0.86, 0.78))
	_box(shelf, "Balda", Vector3(0, 0.25, 0.01), Vector3(0.56, 0.02, 0.22), Color(0.82, 0.76, 0.68))
	var colors := [PASTEL_PINK, PASTEL_BLUE, PASTEL_YELLOW, PASTEL_MINT, Color(0.8, 0.6, 0.9)]
	for k in 7:
		_box(shelf, "Cuento%d" % k, Vector3(-0.22 + k * 0.07, 0.36, 0.02), Vector3(0.05, 0.18 - (k % 3) * 0.02, 0.15), colors[k % colors.size()])
	_blocks(_node(sec, "P_cubos", Vector3(-1.55, 0.02, 0.75)))
	# La nutria del hermano (clave): sentada en la cama.
	var otter := _node(sec, "P_peluche__clave", Vector3(-2.2, 0.33, -0.72))
	otter.rotation_degrees.y = 20.0
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


func _blocks(parent: Node3D) -> void:
	var tones := [Color(0.9, 0.35, 0.35), Color(0.35, 0.55, 0.9), Color(0.95, 0.8, 0.3)]
	for k in 3:
		var b := _box(parent, "Cubo%d" % k, Vector3(-0.05 + (k % 2) * 0.09, 0.035 + (k / 2) * 0.07, 0.0), Vector3(0.07, 0.07, 0.07), tones[k])
		b.rotation_degrees.y = k * 12.0


# --- Sección 3: la adolescencia (centro) ----------------------------------------------------

func _build_teen(sec: Node3D) -> void:
	_bulb(sec, Vector3(0.0, 1.95, -0.55))
	# Armario: la puerta (OR_) se abre y en la balda está la cámara (H_, hermana de la puerta).
	var wardrobe := _node(sec, "Armario", Vector3(0.58, 0, -1.3))
	var ww := 0.56
	var wd := 0.4
	_box(wardrobe, "Fondo", Vector3(0, 0.55, -wd * 0.5 + 0.01), Vector3(ww, 1.1, 0.02), TEEN_TEAL.darkened(0.3))
	_box(wardrobe, "LadoIzq", Vector3(-ww * 0.5, 0.55, 0), Vector3(0.02, 1.1, wd), TEEN_TEAL)
	_box(wardrobe, "LadoDer", Vector3(ww * 0.5, 0.55, 0), Vector3(0.02, 1.1, wd), TEEN_TEAL)
	_box(wardrobe, "Techo", Vector3(0, 1.1, 0), Vector3(ww + 0.02, 0.03, wd), TEEN_TEAL)
	_box(wardrobe, "Suelo", Vector3(0, 0.02, 0), Vector3(ww, 0.04, wd), TEEN_TEAL)
	_box(wardrobe, "Balda", Vector3(0, 0.62, 0), Vector3(ww - 0.04, 0.02, wd - 0.04), TEEN_TEAL.lightened(0.2))
	_box(wardrobe, "Ropa", Vector3(0, 0.3, -0.05), Vector3(ww - 0.08, 0.4, 0.2), Color(0.9, 0.7, 0.5))
	var door := _node(wardrobe, "OR_puerta_armario__n", Vector3(-ww * 0.5, 0, wd * 0.5))
	_box(door, "Puerta", Vector3(ww * 0.5, 0.55, 0.0), Vector3(ww, 1.08, 0.02), TEEN_TEAL.lightened(0.08))
	_sphere(door, "Tirador", Vector3(ww - 0.06, 0.55, 0.02), 0.018, Color(0.85, 0.75, 0.5))
	_box(door, "Pegatina", Vector3(ww * 0.5, 0.82, 0.012), Vector3(0.12, 0.12, 0.004), Color(0.98, 0.85, 0.35))
	_retro_camera(_node(wardrobe, "H_camara", Vector3(0, 0.63, 0.0)))
	# Piezas.
	var rug := _node(sec, "P_alfombra_adolescencia", Vector3(0.0, 0.012, 0.35))
	_box(rug, "Alfombra", Vector3.ZERO, Vector3(1.3, 0.015, 0.9), TEEN_PURPLE)
	for k in 3:
		_box(rug, "Raya%d" % k, Vector3(0, 0.002, -0.3 + k * 0.3), Vector3(1.3, 0.015, 0.06), TEEN_PURPLE.lightened(0.25))
	# El escritorio de las artistas, mirando al jugador, y sus cajones, que también hay que poner
	# (piezas after-escritorio: los dos de estrella son iguales, el del pomo redondo va aparte). El de
	# arriba se abre (OD_) y guarda la inscripción a Bellas Artes: su cajón-pieza va dentro del OD_,
	# que no se abre hasta que está puesto.
	var desk := Vector3(-0.34, 0, -1.24)
	var desk_mat := load(KIT_DESK_MAT) as Material
	var desk_piece := _node(sec, "P_escritorio", desk)
	desk_piece.rotation_degrees.y = 180.0
	_kit(desk_piece, KIT_DESK, desk_mat)
	var drawers := _node(sec, "Cajones", desk + Vector3(KIT_DESK_COLUMN.x, 0, KIT_DRAWER_Z))
	var round_knob := _kit_mesh(KIT_DRAWER_PACK, "SM_DeskD")
	for k in 3:
		var y := KIT_DESK_COLUMN.y - 0.003 - (k + 1) * KIT_DRAWER_H - k * 0.003
		var holder := drawers
		var at := Vector3(0, y, 0)
		if k == 0:
			holder = _node(drawers, "OD_cajon_escritorio", at)
			at = Vector3.ZERO
		var drawer := _node(holder, ["P_cajon__after-escritorio", "P_cajon_pomo__after-escritorio",
			"P_cajon__after-escritorio_001"][k], at)
		if k == 1:                                # el del medio, el de pomo redondo
			var m := MeshInstance3D.new()
			m.name = "Modelo"
			m.mesh = round_knob.mesh
			m.transform = Transform3D(Basis(Vector3.UP, PI) * round_knob.basis, Vector3.ZERO)
			m.set_surface_override_material(0, desk_mat)
			drawer.add_child(m)
		else:
			var model := _kit(drawer, KIT_DRAWER, desk_mat)
			model.position.y = KIT_DRAWER_H * 0.5   # este fichero tiene el pivote en el centro
			model.rotation_degrees.y = 180.0
	round_knob.free()
	_application(_node(drawers.get_child(0) as Node3D, "H_solicitud", Vector3(0, 0.03, 0.02)), true)
	_prop(sec, "P_silla", "chair_01", desk + Vector3(-0.17, 0, 0.62), 180.0)   # delante del hueco de las piernas
	var lamp := _prop(sec, "P_lampara__after-escritorio", "lamp_01", desk + Vector3(-0.4, KIT_DESK_TOP, -0.12))
	_lamp_light(lamp)
	_prop(sec, "P_altavoz__after-escritorio", "speaker_01", desk + Vector3(0.4, KIT_DESK_TOP, -0.13))
	_prop(sec, "P_libro__after-escritorio", "book_01", desk + Vector3(-0.15, KIT_DESK_TOP, -0.15), 10.0)
	_prop(sec, "P_libro__after-escritorio_001", "book_01", desk + Vector3(-0.15, KIT_DESK_TOP + 0.035, -0.15), -6.0)
	var mp3 := _node(sec, "P_mp3__after-escritorio", desk + Vector3(-0.02, KIT_DESK_TOP, 0.08))
	_box(mp3, "Cuerpo", Vector3(0, 0.006, 0), Vector3(0.05, 0.012, 0.08), Color(0.95, 0.95, 0.97))
	_cyl(mp3, "Rueda", Vector3(0, 0.013, 0.012), 0.016, 0.003, Color(0.75, 0.75, 0.78))
	_box(mp3, "Pantalla", Vector3(0, 0.013, -0.022), Vector3(0.035, 0.002, 0.025), Color(0.3, 0.55, 0.8))
	for x in [-0.03, 0.03]:
		_sphere(mp3, "Auricular%d" % int(x > 0), Vector3(x * 2.0, 0.01, 0.07), 0.01, Color(0.97, 0.97, 0.97))
		var wire := _box(mp3, "Cable%d" % int(x > 0), Vector3(x, 0.004, 0.06), Vector3(0.004, 0.004, 0.06), Color(0.97, 0.97, 0.97))
		wire.rotation_degrees.y = 30.0 if x > 0 else -30.0
	var cam_piece := _node(sec, "P_camara__clave__flash", desk + Vector3(0.2, KIT_DESK_TOP, 0.06))
	cam_piece.rotation_degrees.y = -20.0
	_retro_camera(cam_piece)
	for k in 3:                                   # las fotos, en abanico junto a la cámara
		var photo := _box(cam_piece, "Foto%d" % k, Vector3(-0.16 + k * 0.02, 0.003 + k * 0.002, 0.06), Vector3(0.07, 0.003, 0.085), Color(0.97, 0.97, 0.95))
		photo.rotation_degrees.y = -15.0 + k * 15.0
		_box(photo, "Imagen", Vector3(0, 0.002, -0.006), Vector3(0.058, 0.002, 0.058), [Color(0.5, 0.7, 0.85), Color(0.9, 0.7, 0.5), Color(0.6, 0.8, 0.55)][k])
	var corkboard := _node(sec, "P_corcho", Vector3(0.1, 0.86, WALL_IN + 0.01))
	_box(corkboard, "Corcho", Vector3.ZERO, Vector3(0.46, 0.22, 0.02), Color(0.78, 0.6, 0.4))
	_box(corkboard, "Marco", Vector3(0, 0, -0.004), Vector3(0.5, 0.26, 0.015), WOOD)
	for k in 3:
		_box(corkboard, "Nota%d" % k, Vector3(-0.17 + k * 0.08, 0.04 - (k % 2) * 0.06, 0.012), Vector3(0.06, 0.06, 0.003), [PASTEL_YELLOW, PASTEL_PINK, PASTEL_BLUE][k])
	var photos := _node(sec, "P_fotos__after-mp3", _on_roof(-0.3, 1.5))
	photos.rotation.x = -_slope
	_box(photos, "Cordel", Vector3(0, -0.012, 0.05), Vector3(1.0, 0.004, 0.006), Color(0.9, 0.85, 0.75))
	for k in 6:
		var p := _box(photos, "Polaroid%d" % k, Vector3(-0.42 + k * 0.17, -0.012, -0.03), Vector3(0.1, 0.006, 0.12), Color(0.97, 0.97, 0.95))
		p.rotation_degrees.y = (k % 3 - 1) * 6.0
		_box(p, "Imagen", Vector3(0, -0.004, 0.012), Vector3(0.08, 0.002, 0.08), [Color(0.5, 0.7, 0.85), Color(0.9, 0.6, 0.5), Color(0.6, 0.8, 0.55)][k % 3])
	var poster_a := _node(sec, "P_poster_estrellas", _on_roof(-0.75, 1.75))
	poster_a.rotation.x = -_slope
	_box(poster_a, "Poster", Vector3.ZERO, Vector3(0.36, 0.008, 0.48), Color(0.15, 0.18, 0.35))
	for k in 5:
		_box(poster_a, "Estrella%d" % k, Vector3(-0.12 + k * 0.06, -0.006, -0.15 + (k * 7 % 5) * 0.07), Vector3(0.025, 0.004, 0.025), Color(1.0, 0.92, 0.6))
	var poster_b := _node(sec, "P_poster_grupo", _on_roof(0.45, 1.6))
	poster_b.rotation.x = -_slope
	_box(poster_b, "Poster", Vector3.ZERO, Vector3(0.4, 0.008, 0.52), Color(0.85, 0.35, 0.4))
	_box(poster_b, "Banda", Vector3(0, -0.006, 0.08), Vector3(0.3, 0.004, 0.18), Color(0.2, 0.15, 0.2))
	var puf := _node(sec, "P_puf", Vector3(0.38, 0, 0.45))
	var bean := _sphere(puf, "Puf", Vector3(0, 0.16, 0), 0.26, TEEN_TEAL.lightened(0.1))
	bean.scale = Vector3(1.0, 0.62, 1.0)
	# Debajo del puf asoma un dibujo suyo, el monstruo (sobre la alfombra; está desde que el puf está puesto).
	_kid_drawing(_lying(sec, "C_dibujo_monstruo__after-puf", Vector3(0.3, 0.024, 0.6), 15.0), "monstruo")
	var guitar := _node(sec, "P_guitarra", Vector3(0.22, 0, -1.42))
	guitar.rotation_degrees = Vector3(-12, 15, 0)
	var g1 := _sphere(guitar, "Caja", Vector3(0, 0.18, 0), 0.14, Color(0.85, 0.35, 0.22))
	g1.scale = Vector3(1, 1, 0.35)
	var g2 := _sphere(guitar, "Caja2", Vector3(0, 0.36, 0), 0.1, Color(0.85, 0.35, 0.22))
	g2.scale = Vector3(1, 1, 0.35)
	var hole := _cyl(guitar, "Boca", Vector3(0, 0.3, 0.035), 0.035, 0.004, Color(0.15, 0.1, 0.08))
	hole.rotation_degrees.x = 90.0
	_box(guitar, "Mastil", Vector3(0, 0.62, 0), Vector3(0.05, 0.42, 0.025), WOOD_DARK)
	_box(guitar, "Pala", Vector3(0, 0.86, 0), Vector3(0.07, 0.1, 0.025), WOOD_DARK)
	# La solicitud de Bellas Artes (después del MP3): en el corcho, cuando se encuentra en el cajón.
	_application(_node(sec, "P_solicitud__after-mp3", Vector3(0.1, 0.86, WALL_IN + 0.035)), false)


func _retro_camera(n: Node3D) -> void:
	_box(n, "Cuerpo", Vector3(0, 0.045, 0), Vector3(0.13, 0.08, 0.06), Color(0.2, 0.2, 0.22))
	_box(n, "Piel", Vector3(0, 0.045, 0.002), Vector3(0.132, 0.05, 0.058), Color(0.55, 0.38, 0.25))
	var lens := _cyl(n, "Objetivo", Vector3(0, 0.045, 0.045), 0.028, 0.04, Color(0.12, 0.12, 0.14))
	lens.rotation_degrees.x = 90.0
	var glass := _cyl(n, "Cristal", Vector3(0, 0.045, 0.066), 0.02, 0.004, Color(0.5, 0.65, 0.8))
	glass.rotation_degrees.x = 90.0
	_box(n, "Flash", Vector3(-0.04, 0.1, 0), Vector3(0.04, 0.025, 0.04), Color(0.85, 0.85, 0.88))
	_cyl(n, "Disparador", Vector3(0.045, 0.09, 0), 0.008, 0.012, Color(0.75, 0.75, 0.78))


## La inscripción: un folio con "BELLAS ARTES". on_floor = tumbada (en el cajón); si no, de pie (en el corcho).
func _application(n: Node3D, on_floor: bool) -> void:
	var sheet := _node(n, "Folio", Vector3.ZERO)
	if on_floor:
		sheet.rotation_degrees.x = -90.0
	_box(sheet, "Papel", Vector3.ZERO, Vector3(0.15, 0.2, 0.004), Color(0.98, 0.97, 0.94))
	var title := MeshInstance3D.new()
	title.name = "Titulo"
	var tm := TextMesh.new()
	tm.text = "BELLAS\nARTES"
	tm.font_size = 32
	tm.pixel_size = 0.0012
	tm.depth = 0.001
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color(0.25, 0.22, 0.45)
	tm.material = ink
	title.mesh = tm
	title.position = Vector3(0, 0.045, 0.004)
	sheet.add_child(title)
	for k in 4:
		_box(sheet, "Linea%d" % k, Vector3(0, -0.02 - k * 0.025, 0.003), Vector3(0.11, 0.006, 0.002), Color(0.6, 0.6, 0.65))
	_box(sheet, "Chincheta", Vector3(0, 0.09, 0.006), Vector3(0.015, 0.015, 0.008), Color(0.9, 0.3, 0.3))


# --- Sección 4: la adultez (derecha) ----------------------------------------------------------

func _build_adult(sec: Node3D) -> void:
	_bulb(sec, Vector3(1.8, 1.8, -0.35))
	# Mesita con un cajón: dentro, los pinceles.
	var side := _node(sec, "Mesita", Vector3(2.35, 0, 0.1))
	_box(side, "Tablero", Vector3(0, 0.5, 0), Vector3(0.42, 0.03, 0.36), WOOD)
	for x in [-0.18, 0.18]:
		for z in [-0.15, 0.15]:
			_box(side, "Pata%d%d" % [int(x > 0), int(z > 0)], Vector3(x, 0.25, z), Vector3(0.03, 0.5, 0.03), WOOD_DARK)
	var side_drawer := _node(side, "OD_cajon_mesita__nx", Vector3(0, 0.42, 0))
	_box(side_drawer, "Cajon", Vector3(0, 0, 0), Vector3(0.36, 0.1, 0.32), WOOD.lightened(0.1))
	_box(side_drawer, "Tirador", Vector3(-0.185, 0, 0), Vector3(0.012, 0.02, 0.08), Color(0.3, 0.3, 0.32))
	_brushes(_node(side_drawer, "H_pinceles", Vector3(0.02, 0.05, 0)), true)
	# Piezas.
	var rug := _node(sec, "P_alfombra_adultez", Vector3(1.75, 0.012, 0.35))
	_box(rug, "Alfombra", Vector3.ZERO, Vector3(1.25, 0.015, 0.9), ADULT_GREY)
	_box(rug, "Borde", Vector3(0, 0.002, 0), Vector3(1.1, 0.015, 0.75), ADULT_GREY.lightened(0.2))
	var keys := _node(sec, "P_llaves", Vector3(1.3, 0.62, WALL_IN + 0.01))
	_box(keys, "Tablilla", Vector3.ZERO, Vector3(0.24, 0.1, 0.02), WOOD)
	var hook := _cyl(keys, "Gancho", Vector3(0, -0.02, 0.02), 0.006, 0.03, Color(0.6, 0.6, 0.62))
	hook.rotation_degrees.x = 90.0
	var ring := _cyl(keys, "Llavero", Vector3(0, -0.05, 0.035), 0.022, 0.004, Color(0.75, 0.72, 0.6))
	ring.rotation_degrees.x = 90.0
	for k in 3:
		var key := _box(keys, "Llave%d" % k, Vector3(-0.02 + k * 0.02, -0.1, 0.035), Vector3(0.012, 0.07, 0.003), Color(0.82, 0.72, 0.4))
		key.rotation_degrees.z = -15.0 + k * 15.0
	var easel := _node(sec, "P_caballete__after-llaves", Vector3(1.7, 0, 0.0))
	easel.rotation_degrees.y = -15.0
	for x in [-0.22, 0.22]:
		var leg := _box(easel, "Pata%d" % int(x > 0), Vector3(x, 0.62, 0.05), Vector3(0.035, 1.25, 0.035), WOOD_LIGHT)
		leg.rotation_degrees = Vector3(-6, 0, -8.0 if x < 0 else 8.0)
	var back_leg := _box(easel, "PataTrasera", Vector3(0, 0.6, -0.18), Vector3(0.035, 1.2, 0.035), WOOD_LIGHT)
	back_leg.rotation_degrees.x = 18.0
	_box(easel, "Bandeja", Vector3(0, 0.45, 0.1), Vector3(0.52, 0.025, 0.07), WOOD_LIGHT)
	_box(easel, "Travesano", Vector3(0, 1.12, 0.03), Vector3(0.3, 0.03, 0.03), WOOD_LIGHT)
	var canvas := _node(sec, "P_lienzo__after-caballete", Vector3(1.7, 0.78, 0.07))
	canvas.rotation_degrees = Vector3(-6, -15, 0)
	_box(canvas, "Lienzo", Vector3.ZERO, Vector3(0.46, 0.58, 0.025), Color(0.97, 0.96, 0.93))
	_painting(canvas, CUADRO_LIENZO, Vector2(0.44, 0.56), 0.0126)
	_brushes(_node(sec, "P_pinceles__after-caballete", Vector3(1.98, 0.0, 0.32)), false)
	var mirror := _node(sec, "P_espejo__clave__reflejo", Vector3(2.35, 0, -1.12))
	mirror.rotation_degrees.y = -38.0
	var frame := _cyl(mirror, "Marco", Vector3(0, 0.78, 0), 0.3, 0.04, Color(0.72, 0.58, 0.3))
	frame.rotation_degrees.x = 90.0
	frame.scale = Vector3(1.0, 1.0, 1.55)
	var glass := _cyl(mirror, "Luna", Vector3(0, 0.78, 0.022), 0.26, 0.006, Color(0.82, 0.86, 0.9))
	glass.rotation_degrees.x = 90.0
	glass.scale = Vector3(1.0, 1.0, 1.55)
	_shiny(glass, 1.0, 0.05)
	for x in [-0.18, 0.18]:
		var foot := _box(mirror, "Pie%d" % int(x > 0), Vector3(x, 0.25, -0.12), Vector3(0.03, 0.55, 0.03), Color(0.72, 0.58, 0.3))
		foot.rotation_degrees.x = 20.0
	var rack := _node(sec, "P_perchero", Vector3(2.45, 0, 0.95))
	_cyl(rack, "Palo", Vector3(0, 0.75, 0), 0.02, 1.5, WOOD_DARK)
	_cyl(rack, "Base", Vector3(0, 0.02, 0), 0.18, 0.04, WOOD_DARK)
	for k in 3:
		var peg := _box(rack, "Gancho%d" % k, Vector3(0.0, 1.42, 0.0), Vector3(0.22, 0.02, 0.02), WOOD_DARK)
		peg.rotation_degrees.y = k * 60.0
	var coat := _node(sec, "P_abrigo__after-perchero", Vector3(2.45, 0.95, 1.02))
	_box(coat, "Abrigo", Vector3(0, 0.05, 0), Vector3(0.32, 0.65, 0.1), ADULT_OLIVE)
	_box(coat, "Cuello", Vector3(0, 0.36, 0), Vector3(0.2, 0.08, 0.12), ADULT_OLIVE.darkened(0.15))
	_box(coat, "Bufanda", Vector3(0.06, 0.2, 0.06), Vector3(0.06, 0.4, 0.02), Color(0.75, 0.3, 0.3))
	var boxes := _node(sec, "P_cajas_tienda", Vector3(1.08, 0, -1.25))
	for k in 3:
		var bx := _box(boxes, "Caja%d" % k, Vector3(0.02 * (k % 2), 0.16 + k * 0.3, 0), Vector3(0.42 - k * 0.05, 0.3, 0.36 - k * 0.04), CARDBOARD.darkened(0.04 * k))
		bx.rotation_degrees.y = k * 5.0
	_kid_drawing(_lying(sec, "C_dibujo_gato__after-cajas_tienda", Vector3(1.0, 0.913, -1.33), 20.0), "gato")
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
	_prop(sec, "P_taza", "mug_01", Vector3(2.28, 0.515, 0.18))
	_prop(sec, "P_reloj", "clock_01", Vector3(2.42, 0.515, 0.02), -30.0)
	var plant := _node(sec, "P_planta", Vector3(1.1, 0, 0.95))
	_cyl(plant, "Maceta", Vector3(0, 0.12, 0), 0.12, 0.24, Color(0.75, 0.42, 0.3))
	for k in 5:
		var leaf := _sphere(plant, "Hoja%d" % k, Vector3(cos(k * 1.3) * 0.08, 0.32 + (k % 2) * 0.1, sin(k * 1.3) * 0.08), 0.1, Color(0.32, 0.55, 0.32))
		leaf.scale = Vector3(0.6, 1.1, 0.6)


func _brushes(n: Node3D, lying: bool) -> void:
	var jar := _node(n, "Bote", Vector3.ZERO)
	if lying:
		jar.rotation_degrees.z = 90.0
	_cyl(jar, "Bote", Vector3(0, 0.06, 0), 0.04, 0.12, Color(0.7, 0.8, 0.85))
	for k in 3:
		var brush := _cyl(jar, "Pincel%d" % k, Vector3(-0.015 + k * 0.015, 0.16, 0), 0.005, 0.18, WOOD_LIGHT)
		brush.rotation_degrees.z = -8.0 + k * 8.0
		_sphere(jar, "Punta%d" % k, Vector3(-0.025 + k * 0.025, 0.25, 0), 0.01, [Color(0.85, 0.3, 0.3), Color(0.3, 0.5, 0.85), Color(0.95, 0.8, 0.3)][k])


# --- Dibujos escondidos y su cuerda -----------------------------------------------------------

## Un modelo del kit de las artistas (assets/kit/): el .fbx instanciado (en el .tscn queda como
## referencia al fichero, no copiado) con el material de su conjunto en cada superficie. Va en
## surface override, no en material_override: ese lo usa el hueco para la silueta y lo vacía al colocar.
func _kit(parent: Node3D, path: String, material: Material) -> Node3D:
	var inst := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	inst.name = "Modelo"
	parent.add_child(inst)
	_root.set_editable_instance(inst, true)      # para guardar el material de sus mallas
	for m: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		for s in m.mesh.get_surface_count():
			m.set_surface_override_material(s, material)
	return inst


## Una malla suelta de un .fbx de varias piezas (sin instanciar el resto): su MeshInstance3D, fuera
## del árbol (hay que liberarla). Su malla se copia dentro del .tscn.
func _kit_mesh(path: String, node_name: String) -> MeshInstance3D:
	var scene := (load(path) as PackedScene).instantiate() as Node3D
	var m := scene.find_child(node_name, true, false) as MeshInstance3D
	m.owner = null
	m.get_parent().remove_child(m)
	scene.free()
	return m


## Un nodo con un dibujo tumbado (la cara pintada hacia arriba), girado `yaw` grados: el papel se
## extiende desde `pos` (su borde de arriba) hacia delante.
func _lying(parent: Node3D, n: String, pos: Vector3, yaw: float) -> Node3D:
	var d := _node(parent, n, pos)
	d.rotation_degrees = Vector3(-90.0, yaw, 0.0)
	return d


## Un dibujo de cuando era pequeña: el de las artistas (DIBUJOS[cual]) sobre su folio, con su trozo
## de celo. El origen es el borde de arriba, donde lo coge la pinza; la cara mira a +Z. Guarda en
## "color" el color dominante del dibujo (los puntos y acentos de la interfaz): así no hay que leer
## la textura en el juego.
func _kid_drawing(n: Node3D, cual: String) -> void:
	var path: String = DIBUJOS[cual]
	_sheet(n, path, DRAWING_LONG, true)
	_box(n, "Celo", Vector3(0, -0.006, 0.0025), Vector3(0.04, 0.012, 0.002), Color(0.92, 0.9, 0.8))
	n.set_meta("color", _dominant_color(Image.load_from_file(ProjectSettings.globalize_path(path))))


## Un folio con una imagen encima (la malla "Dibujo", que es la que lee la interfaz), a la medida de
## la imagen con su lado largo = `long_side`; la cara mira a +Z. top_origin: el origen es el borde
## de arriba (lo que cuelga de una pinza); si no, el centro. Devuelve su tamaño.
func _sheet(n: Node3D, path: String, long_side: float, top_origin: bool) -> Vector2:
	var tex := load(path) as Texture2D
	var aspect := tex.get_width() / float(tex.get_height())
	var size := Vector2(long_side, long_side / aspect) if aspect >= 1.0 else Vector2(long_side * aspect, long_side)
	var center := Vector3(0, -size.y * 0.5 if top_origin else 0.0, 0)
	_box(n, "Papel", center, Vector3(size.x, size.y, 0.004), Color(0.97, 0.96, 0.92))
	var quad := QuadMesh.new()
	quad.size = size - Vector2(0.008, 0.008)
	# En el material de la malla, no en material_override: un hueco usa ese para la silueta y lo
	# vacía al colocar la pieza (el dibujo de la pared se quedaba en blanco).
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.85
	quad.material = mat
	var drawing := MeshInstance3D.new()
	drawing.name = "Dibujo"
	drawing.mesh = quad
	drawing.position = center + Vector3(0, 0, 0.0021)
	n.add_child(drawing)
	return size


## Un cuadro pintado sobre la cara de delante (+Z) de un lienzo: la imagen, lo más grande que quepa
## en `fit` sin deformarse, a `front` del centro. Como en _sheet, la imagen va en el material de la
## malla (no en material_override, que el hueco vacía al colocar).
func _painting(n: Node3D, path: String, fit: Vector2, front: float) -> void:
	var tex := load(path) as Texture2D
	var aspect := tex.get_width() / float(tex.get_height())
	var quad := QuadMesh.new()
	quad.size = Vector2(fit.x, fit.x / aspect) if fit.x / aspect <= fit.y else Vector2(fit.y * aspect, fit.y)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.9
	quad.material = mat
	var picture := MeshInstance3D.new()
	picture.name = "Cuadro"
	picture.mesh = quad
	picture.position = Vector3(0, 0, front)
	n.add_child(picture)


## El color que más se ve en un dibujo (el fondo blanco del papel no cuenta): los píxeles con color
## se reparten en 12 tonos, pesando más los más saturados, y sale la media del tono que gana.
func _dominant_color(img: Image) -> Color:
	img.resize(48, 48, Image.INTERPOLATE_BILINEAR)
	var weight: Array[float] = []
	var sum: Array[Color] = []
	for i in 12:
		weight.append(0.0)
		sum.append(Color(0, 0, 0, 0))
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var w := c.s * c.s * c.v
			if c.s < 0.25 or c.v < 0.2:
				continue
			var bin := int(c.h * 12.0) % 12
			weight[bin] += w
			sum[bin] += c * w
	var best := 0
	for i in 12:
		if weight[i] > weight[best]:
			best = i
	if weight[best] <= 0.0:
		return Color(0.35, 0.72, 0.32)
	var out := sum[best] / weight[best]
	out.a = 1.0
	return out


## La cuerda de los dibujos (T_): un cordel que cuelga de la pared izquierda hasta el faldón, con
## una pinza vacía por dibujo (Pinza1..n) esperando su dibujo.
func _clothesline(sec: Node3D) -> void:
	var line := _node(sec, "T_dibujos", Vector3(0, 0, LINE_Z))
	var height := func(x: float) -> float:
		var k := (x - (LINE_X.x + LINE_X.y) * 0.5) / ((LINE_X.y - LINE_X.x) * 0.5)
		return LINE_Y - LINE_SAG * (1.0 - k * k)
	var twine := Color(0.9, 0.84, 0.7)
	var steps := 12
	for i in steps:
		var x0 := lerpf(LINE_X.x, LINE_X.y, float(i) / steps)
		var x1 := lerpf(LINE_X.x, LINE_X.y, float(i + 1) / steps)
		var a := Vector3(x0, height.call(x0), 0)
		var b := Vector3(x1, height.call(x1), 0)
		var seg := _box(line, "Cordel%d" % i, (a + b) * 0.5, Vector3(a.distance_to(b) + 0.002, 0.004, 0.004), twine)
		seg.rotation.z = atan2(b.y - a.y, b.x - a.x)
	for x in [LINE_X.x, LINE_X.y]:
		_sphere(line, "Clavo%d" % int(x > -2.0), Vector3(x, height.call(x), 0), 0.008, Color(0.35, 0.33, 0.3))
	var tilts := [-4.0, 3.0, -2.0, 5.0, -3.0, 2.0, -5.0]
	for k in DIBUJOS.size():                     # una pinza por dibujo, repartidas por la cuerda
		var x := lerpf(LINE_X.x + 0.3, LINE_X.y - 0.3, k / maxf(DIBUJOS.size() - 1.0, 1.0))
		var pin := _node(line, "Pinza%d" % (k + 1), Vector3(x, height.call(x) - 0.006, 0))
		pin.rotation_degrees.z = tilts[k]
		_box(pin, "Pinza", Vector3(0, 0.004, 0.006), Vector3(0.012, 0.04, 0.008), WOOD_LIGHT)


# --- Utilidades -------------------------------------------------------------------------------

## Una bombilla colgada de la cumbrera, con la luz de la zona (se enciende al abrirse la sección).
func _bulb(parent: Node3D, pos: Vector3) -> void:
	var bulb := _node(parent, "Bombilla", pos)
	_cyl(bulb, "Cable", Vector3(0, (RIDGE - pos.y) * 0.5, 0), 0.006, RIDGE - pos.y, Color(0.15, 0.15, 0.15))
	_cyl(bulb, "Casquillo", Vector3(0, 0.05, 0), 0.025, 0.05, Color(0.3, 0.28, 0.25))
	_sphere(bulb, "Cristal", Vector3.ZERO, 0.045, Color(1.0, 0.92, 0.75))
	var light := OmniLight3D.new()
	light.name = "LuzZona"
	light.position = Vector3(0, -0.08, 0)
	light.light_color = WARM_BULB
	light.light_energy = 0.8                       # quinta nota: las luces quemaban (medido: techo y mesa)
	light.omni_range = 2.6
	light.omni_attenuation = 1.2
	bulb.add_child(light)


## Punto del faldón del fondo a esa altura, un poco hacia dentro (para pósters y fotos en el tejado).
func _on_roof(x: float, y: float) -> Vector3:
	var z := -HALF_D + (y - KNEE) / tan(_slope)
	var inward := Vector3(0, -cos(_slope), sin(_slope))
	return Vector3(x, y, z) + inward * 0.05


## Prisma: el polígono (z, y) extruido a lo largo de X con grosor `thickness`, centrado en x=0.
## El polígono va en sentido antihorario (z a la derecha, y arriba). Caras con su normal.
func _prism(parent: Node3D, n: String, poly: PackedVector2Array, thickness: float, color: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := thickness * 0.5
	var count := poly.size()
	for i in range(1, count - 1):                 # cara +x (abanico) y cara -x (al revés)
		_tri(st, Vector3.RIGHT, [_p3(h, poly[0]), _p3(h, poly[i]), _p3(h, poly[i + 1])])
		_tri(st, Vector3.LEFT, [_p3(-h, poly[0]), _p3(-h, poly[i + 1]), _p3(-h, poly[i])])
	for i in count:                               # cantos
		var a := poly[i]
		var b := poly[(i + 1) % count]
		var d := b - a
		var normal := Vector3(0, -d.x, d.y).normalized()
		_tri(st, normal, [_p3(h, a), _p3(-h, a), _p3(-h, b)])
		_tri(st, normal, [_p3(h, a), _p3(-h, b), _p3(h, b)])
	var mesh := st.commit()
	return _mesh(parent, n, Vector3.ZERO, mesh, color)


static func _p3(x: float, zy: Vector2) -> Vector3:
	return Vector3(x, zy.y, zy.x)


static func _tri(st: SurfaceTool, normal: Vector3, pts: Array) -> void:
	for p: Vector3 in pts:
		st.set_normal(normal)
		st.add_vertex(p)


## Metal o cristal: más brillo que el resto (la moneda, la luna del espejo).
func _shiny(m: MeshInstance3D, metallic: float, roughness: float) -> void:
	var mat := m.mesh.surface_get_material(0) as StandardMaterial3D
	if mat == null:
		return
	mat.metallic = metallic
	mat.roughness = roughness
