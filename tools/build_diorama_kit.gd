extends SceneTree
## Monta el diorama de prueba con el "tileset" del kit (assets/kit/piezas/, lo hace piezas_kit.gd) y
## lo guarda en preview/diorama_kit.tscn PARA EDITARLO A MANO en el editor: cada pieza es una
## instancia de su escena (escala 1; solo se mueve y se gira), agrupadas en Arquitectura y Muebles.
## La preview (Tab) lo enseña con la luz, la cámara y el enfoque del juego.
## Sigue la referencia de 3ds Max de las artistas: suelo de tablones en L con su zócalo; a la
## izquierda el faldón (tablas, cabios, dos correas, postes y viga de base); al fondo el hastial con
## la ventana redonda, el entrante (SM_WallC) y el lateral (SM_WallB) con pilares; y los muebles.
## Las piezas inclinadas bajan hacia +x en su fichero; aquí el faldón está a la izquierda: van giradas
## 180°. Las alturas son las de la escena de las artistas (el suelo, de 0 a 0,15 m).
## NO pisa la escena si ya existe (tendría tus cambios a mano); para rehacerla desde cero:
##   godot --headless --path . --script res://tools/build_diorama_kit.gd -- --forzar

const SALIDA := "res://preview/diorama_kit.tscn"
const PIEZAS := "res://assets/kit/piezas/"
const SUELO := 0.15                         ## altura de la cara de arriba del suelo
const RODILLA := -3.04                      ## x del pie del faldón (a la altura de los cabios, 0,65 m)
const PENDIENTE := 4.02 / 2.9               ## subida del faldón por metro (la de los cabios y el hastial)
const FONDO := -2.6                         ## z del hastial (el fondo de la parte izquierda del suelo)
const FONDO_HONDO := -3.56                  ## z de la pared del entrante del fondo derecho
const TECHO_LARGO := 5.14                   ## lo que mide el faldón de fondo a delante

var _raiz: Node3D
var _grupo: Node3D                          ## dónde se añade lo que se pone (Arquitectura o Muebles)


func _init() -> void:
	if FileAccess.file_exists(SALIDA) and not "--forzar" in OS.get_cmdline_user_args():
		print("DIORAMA KIT: %s ya existe y no se pisa (puede tener cambios a mano). Con --forzar se rehace." % SALIDA)
		quit(0)
		return
	_raiz = Node3D.new()
	_raiz.name = "DioramaKit"
	_grupo = _nuevo_grupo("Arquitectura")
	_arquitectura()
	_grupo = _nuevo_grupo("Muebles")
	_muebles()
	_duenos(_raiz)
	var packed := PackedScene.new()
	var err := packed.pack(_raiz)
	if err == OK:
		err = ResourceSaver.save(packed, SALIDA)
	print("DIORAMA KIT %s err=%d" % [SALIDA, err])
	_raiz.free()
	quit(0 if err == OK else 1)


func _arquitectura() -> void:
	_pon("Suelo", [_p("SM_Floor")], 0.0, Vector3(0, 0, 0), Vector3(0.5, 0, 0.5))
	_pon("Zocalo", [_p("SM_SkirtingBoardBottom")], 0.0, Vector3(0, -0.02, 0), Vector3(0.5, 0, 0.5))
	# El faldón: los cabios con su pie en la rodilla, y encima las tablas (en el fichero de las artistas,
	# 0,4 m más allá del pie de los cabios: el alero).
	var techo_z := FONDO + TECHO_LARGO * 0.5
	var techo := _pon("Techo", [_p("SM_Ceiling")], 180.0, Vector3(RODILLA - 0.4, 0.67, techo_z), Vector3(0, 0, 0.5))
	var cabios := ["A", "B", "C", "D"]
	for i in cabios.size():
		var z := lerpf(FONDO + 0.35, FONDO + TECHO_LARGO - 0.35, i / float(cabios.size() - 1))
		_pon("Cabio" + cabios[i], [_p("SM_CeilingSupportVertical" + cabios[i])], 180.0, Vector3(RODILLA, 0.65, z), Vector3(0, 0, 0.5))
	# Las dos correas y la viga de base, por dentro de los cabios, a su altura; y los postes bajo la correa baja.
	for viga: Array in [["VigaBase", "CeilingSupport020", 0.6], ["CorreaBaja", "CeilingSupport018", 1.6], ["CorreaAlta", "CeilingSupport021", 2.93]]:
		var x := RODILLA + (float(viga[2]) - 0.65) / PENDIENTE + 0.22
		_pon(viga[0], [_p(viga[1])], 0.0, Vector3(x, float(viga[2]), techo_z), Vector3(0.5, 0.5, 0.5))
	var x_postes := RODILLA + (1.6 - 0.65) / PENDIENTE + 0.22
	for i in 3:
		var z := lerpf(FONDO + 1.3, FONDO + TECHO_LARGO - 0.5, i / 2.0)
		_pon("Poste%d" % i, [_p("CeilingSupport01%d" % (4 + i))], 0.0, Vector3(x_postes, SUELO, z), Vector3(0.5, 0, 0.5))
	# El hastial (su lado alto, a la derecha; su pendiente baja hacia el faldón) con la ventana en su
	# hueco. Su borde inclinado tiene que quedar dentro de las tablas (son tablas solapadas, en escalera:
	# si solo las toca, entre una y otra se ve el cielo): se mide en las mallas y se mueve en x hasta
	# que el borde quede a media tabla.
	var hastial := _pon("Hastial", [_p("SM_WallA")], 180.0, Vector3(RODILLA, 0, FONDO), Vector3(0, 0, 0.5))
	var media_tabla := (_linea(techo, false) + _linea(techo, true)) * 0.5
	hastial.position.x += (_linea(hastial, true) - media_tabla) / PENDIENTE
	var x_hastial := _caja(hastial).position.x
	var hueco := Vector3(0.637, -0.261, 0.0)    # centro del agujero redondo de SM_WallA, medido en su fichero (girado)
	_pon("Ventana", [_p("SM_Window")], 180.0, _caja(hastial).get_center() + hueco, Vector3(0.5, 0.5, 0.5))
	# El entrante del fondo derecho (SM_WallC, desde el pilar del hastial), su costado (otro SM_WallB,
	# metido por detrás) y el lateral (SM_WallB), con pilares en las esquinas.
	var x_pilar := x_hastial + 4.04 + 0.05
	_pon("ParedFondo", [_p("SM_WallC")], 0.0, Vector3(x_pilar, 0, FONDO_HONDO), Vector3(0, 0, 0.5))
	var x_derecha := x_pilar + 2.05 + 0.04
	_pon("ParedEscalon", [_p("SM_WallB")], 0.0, Vector3(x_pilar, 0, FONDO), Vector3(0.5, 0, 1))
	_pon("ParedLado", [_p("SM_WallB")], 0.0, Vector3(x_derecha, 0, FONDO_HONDO), Vector3(0.5, 0, 0))
	for i in 3:
		var p: Vector3 = [Vector3(x_pilar, 0, FONDO), Vector3(x_derecha, 0, FONDO_HONDO), Vector3(x_derecha, 0, FONDO_HONDO + 1.82)][i]
		_pon("Pilar%d" % i, [_p("SM_Pillar")], 0.0, Vector3(p.x, SUELO, p.z), Vector3(0.5, 0, 0.5))


func _muebles() -> void:
	# El escritorio bajo la ventana, de cara a la habitación, con sus tres cajones en la columna (como
	# en el desván del juego; SM_DeskB aún no está: se repite el C) y el MP3 encima.
	var mesa_pos := Vector3(-0.25, SUELO, FONDO + 0.07 + 0.306)
	_pon("Escritorio", [_p("SM_DeskA")], 180.0, mesa_pos, Vector3(0.5, 0, 0.5))
	var cajones := ["SM_DeskC", "SM_DeskD", "SM_DeskC"]
	for k in cajones.size():
		var y := SUELO + 0.66 - 0.003 - (k + 1) * 0.2084 - k * 0.003
		_pon("CajonEscritorio%d" % k, [_p(cajones[k])], 180.0, Vector3(mesa_pos.x + 0.385, y, mesa_pos.z + 0.064), Vector3(0.5, 0, 0.5))
	_pon("MP3", [_p("SM_MP3")], -20.0, mesa_pos + Vector3(-0.25, 0.745, 0.05), Vector3(0.5, 0, 0.5))
	_pon("Lampara", [_p("SM_Lamp")], 0.0, Vector3(0.68, SUELO, FONDO + 0.45), Vector3(0.5, 0, 0.5))
	# La cómoda contra la pared del entrante, de cara a la habitación: su cuerpo es un armazón abierto
	# (hueco de 0,58 m desde 0,17 m) y los tres cajones lo llenan (SM_ComodaC aún no está: se repite el B).
	var comoda_z := FONDO_HONDO + 0.07 + 0.21 + 0.02
	var comoda_x := 2.1
	var comoda: Array[Node3D] = [_p("SM_ComodaA")]
	for k in 3:
		var cajon := _p(["SM_ComodaB", "SM_ComodaB", "SM_ComodaD"][k])
		cajon.name = "Cajon%d" % k
		cajon.position = Vector3(0, 0.1667 + k * 0.1933, 0)
		comoda.append(cajon)
	_pon("Comoda", comoda, 0.0, Vector3(comoda_x, SUELO, comoda_z), Vector3(0.5, 0, 0.5))
	var pinceles: Array[Node3D] = [_p("SM_Vase")]
	for k in 3:
		var pincel := _p("SM_Brush" + ["A", "B", "C"][k])
		pincel.position = Vector3((k - 1) * 0.015, 0.02, 0)
		pinceles.append(pincel)
	_pon("Pinceles", pinceles, 0.0, Vector3(comoda_x + 0.3, SUELO + 0.82, comoda_z), Vector3(0.5, 0, 0.5))
	_pon("Taburete", [_p("SM_Stool")], 0.0, Vector3(1.55, SUELO, comoda_z + 0.75), Vector3(0.5, 0, 0.5))
	# Bajo el faldón: las cajas con su tapa, apiladas; la tele delante, mirando a la habitación; y en
	# el suelo, un cajón suelto con el CoverDesk dentro.
	_caja_con_tapa("A", Vector3(-2.45, SUELO, -1.95), 90.0)
	_caja_con_tapa("B", Vector3(-2.45, SUELO + 0.45, -1.95), 80.0)
	_caja_con_tapa("C", Vector3(-2.5, SUELO, -1.2), 10.0)
	_caja_con_tapa("D", Vector3(-2.15, SUELO, -0.55), -15.0)
	_caja_con_tapa("E", Vector3(-2.5, SUELO + 0.31, -1.2), 30.0, 0.03)
	_pon("Tele", [_p("SM_TV")], 35.0, Vector3(-2.15, SUELO, 1.2), Vector3(0.5, 0, 0.5))
	var tapete := _p("SM_CoverDesk")
	tapete.position = Vector3(0, 0.03, 0)
	_pon("CajonSuelto", [_p("SM_DeskC"), tapete], 25.0, Vector3(-1.25, SUELO, -0.4), Vector3(0.5, 0, 0.5))
	_pon("Burro", [_p("SM_Burro")], 60.0, Vector3(0.6, SUELO, 0.75), Vector3(0.5, 0, 0.5))


## Una caja (SM_Box<letra>) con su tapa (SM_CoverBox<letra>) encima, encajada bajando `hundida` (sus pestañas).
func _caja_con_tapa(letra: String, pos: Vector3, giro: float, hundida := 0.1) -> void:
	var caja := _p("SM_Box" + letra)
	var tapa := _p("SM_CoverBox" + letra)
	tapa.position = Vector3(0, _caja_propia(caja).size.y - hundida, 0)
	_pon("Caja" + letra, [caja, tapa], giro, pos, Vector3(0.5, 0, 0.5))


# --- Piezas -------------------------------------------------------------------------------------

## Una instancia de la escena de una pieza del kit (pivote abajo en el centro, escala 1).
func _p(pieza: String) -> Node3D:
	var escena := load(PIEZAS + pieza + ".scn") as PackedScene
	assert(escena != null, "Diorama del kit: falta la pieza %s (¿has pasado tools/piezas_kit.gd?)" % pieza)
	return escena.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D


## Pone una pieza (o varias, agrupadas en un nodo) llamada `nombre`, girada `giro` grados en y, con el
## punto `ancla` de su caja (fracción de la caja: (0.5, 0, 0.5) = el centro de abajo) en `pos`.
func _pon(nombre: String, piezas: Array, giro: float, pos: Vector3, ancla: Vector3) -> Node3D:
	var n: Node3D = piezas[0] if piezas.size() == 1 else Node3D.new()
	n.name = nombre
	if piezas.size() > 1:
		for p: Node3D in piezas:
			n.add_child(p)
	n.rotation_degrees.y = giro
	_grupo.add_child(n)
	var caja := _caja(n)
	n.position += pos - (caja.position + caja.size * ancla)
	return n


func _nuevo_grupo(nombre: String) -> Node3D:
	var g := Node3D.new()
	g.name = nombre
	_raiz.add_child(g)
	return g


## La caja de un nodo y lo que cuelga de él, en el espacio del diorama (transformaciones encadenadas:
## sin árbol).
func _caja(n: Node3D) -> AABB:
	return _caja_hasta(n, _raiz)


## La caja de una pieza en su propio espacio (sin su posición ni su giro).
func _caja_propia(n: Node3D) -> AABB:
	return _caja_hasta(n, n)


func _caja_hasta(n: Node3D, hasta: Node) -> AABB:
	var out := AABB()
	var primera := true
	for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b := _xf(m, hasta) * m.get_aabb()
		out = b if primera else out.merge(b)
		primera = false
	return out


## Para piezas del faldón: el valor de y - PENDIENTE·x (constante a lo largo de la pendiente) de su
## vértice más alto (`arriba`) o más bajo: dice a qué altura queda su borde o su cara inclinada.
func _linea(n: Node3D, arriba: bool) -> float:
	var out := -INF if arriba else INF
	for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var xf := _xf(m, _raiz)
		for s in m.mesh.get_surface_count():
			for v: Vector3 in m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var q := xf * v
				var c := q.y - PENDIENTE * q.x
				out = maxf(out, c) if arriba else minf(out, c)
	return out


func _xf(n: Node, hasta: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var p: Node = n
	while p != hasta and p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Todo lo creado es de la escena; lo de dentro de cada pieza no (queda como referencia a su .scn).
func _duenos(n: Node) -> void:
	for c in n.get_children():
		c.owner = _raiz
		if c.scene_file_path == "":
			_duenos(c)
