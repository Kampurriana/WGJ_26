extends Node3D
## El diorama de prueba de la preview (aparte del juego): un rincón del desván montado SOLO con el arte
## de las artistas (assets/kit/), siguiendo su referencia de 3ds Max:
##  - suelo de tablones en L con su zócalo (SM_Floor, SM_SkirtingBoardBottom), a su altura (0 - 0,15 m);
##  - a la izquierda, el faldón (SM_Ceiling) con sus cabios (SM_CeilingSupportVertical A-D), las dos
##    correas y la viga de base del paquete FloorCeilingPlanks... y los postes debajo de la correa baja;
##  - al fondo, el hastial con la ventana redonda (SM_WallA + SM_Window), el entrante del fondo derecho
##    (SM_WallC) y el lateral (SM_WallB), con pilares y su capitel (Pillar007 + Pillar008);
##  - muebles: el escritorio con sus cajones y el MP3, la lámpara, la cómoda con sus cajones, el jarrón
##    con los pinceles y el taburete; la tele, las cajas con tapa, un cajón suelto con el CoverDesk y el
##    burro de la ropa.
## Las piezas inclinadas bajan hacia +x en su fichero; aquí el faldón está a la izquierda, así que van
## giradas 180°. Las alturas de los paquetes ya son las de la escena de las artistas y se respetan.
## Material: el del kit si la pieza tiene (M_Desk...); si no, un color PROVISIONAL (COLORES) hasta que
## lleguen sus texturas.

const KIT := "res://assets/kit/"
const MODELOS := KIT + "modelos/"
const PAQUETES := KIT + "paquetes/"
const SUELO := 0.15                         ## altura de la cara de arriba del suelo
const RODILLA := -3.04                      ## x del pie del faldón (a la altura de los cabios, 0,65 m)
const PENDIENTE := 4.02 / 2.9               ## subida del faldón por metro (la de los cabios y el hastial)
const FONDO := -2.6                         ## z del hastial (el fondo de la parte izquierda del suelo)
const FONDO_HONDO := -3.56                  ## z de la pared del entrante del fondo derecho
const TECHO_LARGO := 5.14                   ## lo que mide el faldón de fondo a delante
## Colores provisionales (sin textura todavía), por grupo de piezas.
const COLORES := {
	"suelo": Color(0.8, 0.62, 0.43),
	"estructura": Color(0.45, 0.3, 0.2),
	"pared": Color(0.9, 0.84, 0.74),
	"techo": Color(0.66, 0.47, 0.31),
	"comoda": Color(0.66, 0.85, 0.74),
	"caja": Color(0.7, 0.55, 0.38),
	"tele": Color(0.62, 0.76, 0.9),
	"metal": Color(0.85, 0.85, 0.82),
	"madera": Color(0.76, 0.6, 0.42),
	"blanco": Color(0.95, 0.95, 0.97),
	"jarron": Color(0.98, 0.88, 0.58),
	"naranja": Color(0.95, 0.6, 0.3),
}

var materiales: Dictionary = {}             ## {"Desk": M_Desk.tres, ...} (los del kit, de la preview)
var _escenas: Dictionary = {}               ## ruta del .fbx -> su escena instanciada (para sacar mallas)
var _colores: Dictionary = {}               ## grupo -> material provisional (uno por color)


func montar(p_materiales: Dictionary) -> void:
	materiales = p_materiales
	_arquitectura()
	_muebles()
	for e: Node in _escenas.values():
		e.free()
	_escenas.clear()


func _arquitectura() -> void:
	_pon("Suelo", [_m(MODELOS + "Pack01/SM_Floor.fbx", "SM_Floor", "suelo")], 0.0, Vector3(0, 0, 0), Vector3(0.5, 0, 0.5))
	_pon("Zocalo", [_m(MODELOS + "Pack01/SM_SkirtingBoardBottom.fbx", "SM_SkirtingBoardBottom", "estructura")], 0.0, Vector3(0, -0.02, 0), Vector3(0.5, 0, 0.5))
	# El faldón: los cabios con su pie en la rodilla, y encima las tablas (en el fichero de las artistas,
	# 0,4 m más allá del pie de los cabios: el alero).
	var techo_z := FONDO + TECHO_LARGO * 0.5
	var techo := _pon("Techo", [_m(PAQUETES + "Pack02.fbx", "SM_Ceiling", "techo")], 180.0, Vector3(RODILLA - 0.4, 0.67, techo_z), Vector3(0, 0, 0.5))
	var cabios := ["A", "B", "C", "D"]
	for i in cabios.size():
		var z := lerpf(FONDO + 0.35, FONDO + TECHO_LARGO - 0.35, i / float(cabios.size() - 1))
		_pon("Cabio" + cabios[i], [_m(PAQUETES + "Pack02.fbx", "SM_CeilingSupportVertical" + cabios[i], "estructura")], 180.0, Vector3(RODILLA, 0.65, z), Vector3(0, 0, 0.5))
	# Las dos correas y la viga de base, por dentro de los cabios, a su altura; y los postes bajo la correa baja.
	var paquete := PAQUETES + "FloorCeilingPlanksCajonesqueFaltan.fbx"
	for viga: Array in [["VigaBase", "CeilingSupport020", 0.6], ["CorreaBaja", "CeilingSupport018", 1.6], ["CorreaAlta", "CeilingSupport021", 2.93]]:
		var x := RODILLA + (float(viga[2]) - 0.65) / PENDIENTE + 0.22
		_pon(viga[0], [_m(paquete, viga[1], "estructura")], 0.0, Vector3(x, float(viga[2]), techo_z), Vector3(0.5, 0.5, 0.5))
	var x_postes := RODILLA + (1.6 - 0.65) / PENDIENTE + 0.22
	for i in 3:
		var z := lerpf(FONDO + 1.3, FONDO + TECHO_LARGO - 0.5, i / 2.0)
		_pon("Poste%d" % i, [_m(paquete, "CeilingSupport01%d" % (4 + i), "estructura")], 0.0, Vector3(x_postes, SUELO, z), Vector3(0.5, 0, 0.5))
	# El hastial (su lado alto, a la derecha; su pendiente baja hacia el faldón) con la ventana en su
	# hueco. Su borde inclinado tiene que quedar dentro de las tablas (son tablas solapadas, en escalera:
	# si solo las toca, entre una y otra se ve el cielo): se mide en las mallas y se mueve en x hasta
	# que el borde quede a media tabla.
	var hastial := _pon("Hastial", [_m(PAQUETES + "Pack03.fbx", "SM_WallA", "pared")], 180.0, Vector3(RODILLA, 0, FONDO), Vector3(0, 0, 0.5))
	var media_tabla := (_linea(techo, false) + _linea(techo, true)) * 0.5
	hastial.position.x += (_linea(hastial, true) - media_tabla) / PENDIENTE
	var x_hastial := _caja(hastial).position.x
	var hueco := Vector3(0.637, -0.261, 0.0)    # centro del agujero redondo de SM_WallA, medido en su fichero (girado)
	_pon("Ventana", [_m(PAQUETES + "Pack03.fbx", "SM_Window", "estructura")], 180.0, _caja(hastial).get_center() + hueco, Vector3(0.5, 0.5, 0.5))
	# El entrante del fondo derecho (SM_WallC, desde el pilar del hastial), su costado (otro SM_WallB,
	# metido por detrás) y el lateral (SM_WallB), con pilares en las esquinas.
	var x_pilar := x_hastial + 4.04 + 0.05
	_pon("ParedFondo", [_m(PAQUETES + "Pack03.fbx", "SM_WallC", "pared")], 0.0, Vector3(x_pilar, 0, FONDO_HONDO), Vector3(0, 0, 0.5))
	var x_derecha := x_pilar + 2.05 + 0.04
	_pon("ParedEscalon", [_m(PAQUETES + "Pack03.fbx", "SM_WallB", "pared")], 0.0, Vector3(x_pilar, 0, FONDO), Vector3(0.5, 0, 1))
	_pon("ParedLado", [_m(PAQUETES + "Pack03.fbx", "SM_WallB", "pared")], 0.0, Vector3(x_derecha, 0, FONDO_HONDO), Vector3(0.5, 0, 0))
	for i in 3:
		var p: Vector3 = [Vector3(x_pilar, 0, FONDO), Vector3(x_derecha, 0, FONDO_HONDO), Vector3(x_derecha, 0, FONDO_HONDO + 1.82)][i]
		_pon("Pilar%d" % i, [_m(paquete, "Pillar007", "estructura", true), _m(paquete, "Pillar008", "estructura", true)],
			0.0, Vector3(p.x, SUELO, p.z), Vector3(0.5, 0, 0.5))


func _muebles() -> void:
	# El escritorio bajo la ventana, de cara a la habitación, con sus tres cajones en la columna (como
	# en el desván del juego) y el MP3 encima.
	var mesa_pos := Vector3(-0.25, SUELO, FONDO + 0.07 + 0.306)
	_pon("Escritorio", [_m(MODELOS + "Desk/SM_DeskA.fbx", "SM_DeskA", "madera")], 180.0, mesa_pos, Vector3(0.5, 0, 0.5))
	var cajones := [_m(MODELOS + "Desk/SM_DeskC.fbx", "SM_DeskC", "madera"),
		_m(PAQUETES + "FloorCeilingPlanksCajonesqueFaltan.fbx", "SM_DeskD", "madera"),
		_m(MODELOS + "Desk/SM_DeskC.fbx", "SM_DeskC", "madera")]
	for k in cajones.size():
		var y := SUELO + 0.66 - 0.003 - (k + 1) * 0.2084 - k * 0.003
		_pon("CajonEscritorio%d" % k, [cajones[k]], 180.0, Vector3(mesa_pos.x + 0.385, y, mesa_pos.z + 0.064), Vector3(0.5, 0, 0.5))
	_pon("MP3", _grupo(PAQUETES + "Pack05.fbx", "MP3", "blanco"), -20.0, mesa_pos + Vector3(-0.25, 0.745, 0.05), Vector3(0.5, 0, 0.5))
	_pon("Lampara", [_m(MODELOS + "Lamp/SM_Lamp.fbx", "SM_Lamp", "metal")], 0.0, Vector3(0.68, SUELO, FONDO + 0.45), Vector3(0.5, 0, 0.5))
	# La cómoda contra la pared del entrante, de cara a la habitación: su cuerpo es un armazón abierto
	# (hueco de 0,58 m) y los tres cajones lo llenan (SM_ComodaC aún no está: se repite el B).
	var comoda_z := FONDO_HONDO + 0.07 + 0.21 + 0.02
	var comoda_x := 2.1
	var cuerpo := _m(MODELOS + "Comoda/SM_ComodaA.fbx", "SM_ComodaA", "comoda")
	var piezas: Array[MeshInstance3D] = [cuerpo]
	for k in 3:
		var cajon := _m(MODELOS + "Comoda/%s.fbx" % ["SM_ComodaB", "SM_ComodaB", "SM_ComodaD"][k], ["SM_ComodaB", "SM_ComodaB", "SM_ComodaD"][k], "comoda")
		cajon.position += Vector3(0, -0.24 + 0.0967 + k * 0.1933, 0.0)
		piezas.append(cajon)
	_pon("Comoda", piezas, 0.0, Vector3(comoda_x, SUELO, comoda_z), Vector3(0.5, 0, 0.5))
	var jarron := _m(PAQUETES + "Pack05.fbx", "Vase001", "jarron")
	var pinceles: Array[MeshInstance3D] = [jarron]
	var c := _caja_malla(jarron).get_center()
	for k in 3:
		var pincel := _m(PAQUETES + "Pack05.fbx", "Cylinder02%d" % (5 + k), "madera")
		var cp := _caja_malla(pincel)
		pincel.position += Vector3(c.x - cp.get_center().x + (k - 1) * 0.015, _caja_malla(jarron).position.y + 0.02 - cp.position.y, c.z - cp.get_center().z)
		pinceles.append(pincel)
	_pon("Pinceles", pinceles, 0.0, Vector3(comoda_x + 0.3, SUELO + 0.82, comoda_z), Vector3(0.5, 0, 0.5))
	_pon("Taburete", [_m(MODELOS + "Stool/SM_Stool.fbx", "SM_Stool", "madera")], 0.0, Vector3(1.55, SUELO, comoda_z + 0.75), Vector3(0.5, 0, 0.5))
	# Bajo el faldón: las cajas con su tapa, apiladas; la tele delante, mirando a la habitación; y en
	# el suelo, un cajón suelto con el CoverDesk dentro.
	_caja_con_tapa("A", "Object006", Vector3(-2.45, SUELO, -1.95), 90.0)
	_caja_con_tapa("B", "Object007", Vector3(-2.45, SUELO + 0.45, -1.95), 80.0)
	_caja_con_tapa("C", "Object008", Vector3(-2.5, SUELO, -1.2), 10.0)
	_caja_con_tapa("D", "Object009", Vector3(-2.15, SUELO, -0.55), -15.0)
	_caja_con_tapa("E", "Object010", Vector3(-2.5, SUELO + 0.31, -1.2), 30.0, 0.03)
	_pon("Tele", [_m(MODELOS + "TV/SM_TV.fbx", "SM_TV", "tele")], 35.0, Vector3(-2.15, SUELO, 1.2), Vector3(0.5, 0, 0.5))
	var bandeja := _m(MODELOS + "Desk/SM_DeskC.fbx", "SM_DeskC", "madera")
	var tapete := _m(PAQUETES + "Pack04.fbx", "CoverDesk", "naranja")
	var cb := _caja_malla(bandeja)
	var ct := _caja_malla(tapete)
	tapete.position += cb.get_center() - ct.get_center() + Vector3(0, -cb.size.y * 0.5 + 0.03 + ct.size.y * 0.5, 0)
	_pon("CajonSuelto", [bandeja, tapete], 25.0, Vector3(-1.25, SUELO, -0.4), Vector3(0.5, 0, 0.5))
	_pon("Burro", [_m(PAQUETES + "Pack04.fbx", "Box072", "metal")], 60.0, Vector3(0.6, SUELO, 0.75), Vector3(0.5, 0, 0.5))


## Una caja (SM_Box<letra>) con su tapa encima: las de Boxes.fbx encajan bajando `hundida` (sus pestañas).
func _caja_con_tapa(letra: String, tapa: String, pos: Vector3, giro: float, hundida := 0.1) -> void:
	var caja := _m(MODELOS + "Box/SM_Box%s.fbx" % letra, "SM_Box" + letra, "caja")
	var t := _m(PAQUETES + "Boxes.fbx", tapa, "caja")
	var cc := _caja_malla(caja)
	var ct := _caja_malla(t)
	t.position += Vector3(cc.get_center().x - ct.get_center().x, cc.end.y - hundida - ct.position.y, cc.get_center().z - ct.get_center().z)
	_pon("Caja" + letra, [caja, t], giro, pos, Vector3(0.5, 0, 0.5))


# --- Piezas -------------------------------------------------------------------------------------

## Agrupa unas mallas en un nodo `nombre`, girado `giro` grados en y, y lo mueve para que el punto
## `ancla` de su caja (fracción de la caja: (0.5, 0, 0.5) = el centro de abajo) quede en `pos`.
func _pon(nombre: String, mallas: Array, giro: float, pos: Vector3, ancla: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = nombre
	n.rotation_degrees.y = giro
	for m: MeshInstance3D in mallas:
		n.add_child(m)
	add_child(n)
	var caja := _caja(n)
	n.position += pos - (caja.position + caja.size * ancla)
	return n


## La caja de un nodo y lo que cuelga de él, en el espacio de este diorama (sin depender del árbol).
func _caja(n: Node3D) -> AABB:
	var out := AABB()
	var primera := true
	for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var p: Node = m
		while p != self and p is Node3D:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b := xf * m.get_aabb()
		out = b if primera else out.merge(b)
		primera = false
	return out


## Para piezas del faldón: el valor de y - PENDIENTE·x (constante a lo largo de la pendiente) de su
## vértice más alto (`arriba`) o más bajo, en el espacio del diorama: dice a qué altura queda su borde
## o su cara inclinada.
func _linea(n: Node3D, arriba: bool) -> float:
	var out := -INF if arriba else INF
	for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var p: Node = m
		while p != self and p is Node3D:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		for s in m.mesh.get_surface_count():
			for v: Vector3 in m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var q := xf * v
				var c := q.y - PENDIENTE * q.x
				out = maxf(out, c) if arriba else minf(out, c)
	return out


## La caja de una malla suelta en su propio espacio de colocación (su transformación local).
func _caja_malla(m: MeshInstance3D) -> AABB:
	return m.transform * m.get_aabb()


## Una copia de la malla `nodo` del fichero `ruta` (comparte la malla, no la copia), con la orientación
## que trae (y su posición en el fichero si `colocada`: para piezas que vienen juntas, como el pilar y
## su capitel); con el material del kit si tiene, o el provisional.
func _m(ruta: String, nodo: String, grupo: String, colocada := false) -> MeshInstance3D:
	var src := _malla_de(ruta, nodo)
	var m := MeshInstance3D.new()
	m.name = nodo
	m.mesh = src.mesh
	m.transform = _xf_en_fichero(src)
	if not colocada:
		m.position = Vector3.ZERO
	_material(m, nodo, grupo)
	return m


## Todas las mallas del fichero cuyo nombre empieza por `prefijo`, como vienen colocadas entre sí
## (el MP3 llega en piezas: cuerpo, cable, auriculares...).
func _grupo(ruta: String, prefijo: String, grupo: String) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var escena := _escena(ruta)
	for src: MeshInstance3D in escena.find_children(prefijo + "*", "MeshInstance3D", true, false):
		var m := MeshInstance3D.new()
		m.name = src.name
		m.mesh = src.mesh
		m.transform = _xf_en_fichero(src)
		_material(m, src.name, grupo)
		out.append(m)
	return out


func _material(m: MeshInstance3D, nombre: String, grupo: String) -> void:
	var mat: Material = null
	for clave: String in materiales:
		if nombre.begins_with("SM_" + clave):
			mat = materiales[clave]
	if mat == null:
		if not _colores.has(grupo):
			var nuevo := StandardMaterial3D.new()
			nuevo.albedo_color = COLORES[grupo]
			nuevo.roughness = 0.85
			_colores[grupo] = nuevo
		mat = _colores[grupo]
	for s in m.mesh.get_surface_count():
		m.set_surface_override_material(s, mat)


func _malla_de(ruta: String, nodo: String) -> MeshInstance3D:
	var m := _escena(ruta).find_child(nodo, true, false) as MeshInstance3D
	assert(m != null, "Diorama del kit: no está %s en %s" % [nodo, ruta])
	return m


func _escena(ruta: String) -> Node3D:
	if not _escenas.has(ruta):
		_escenas[ruta] = (load(ruta) as PackedScene).instantiate()
	return _escenas[ruta]


## La transformación de una malla dentro de su fichero (sin árbol: encadenada a mano).
func _xf_en_fichero(m: MeshInstance3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var p: Node = m
	while p != null and p.get_parent() != null and p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
