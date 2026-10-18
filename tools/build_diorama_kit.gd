extends SceneTree
## Monta el diorama de prueba (preview/diorama_kit.tscn) COPIANDO LA ESCENA DE REFERENCIA de las
## artistas, el blocking de 3ds Max exportado a .fbx (assets/kit/referencia/), con las piezas del
## tileset (assets/kit/piezas/, lo hace piezas_kit.gd), para EDITARLO A MANO en el editor: cada pieza es
## una instancia de su escena (escala 1; solo se mueve y se gira), en Arquitectura y Muebles.
## Cada objeto de la referencia que está sobre su suelo se empareja con la pieza del kit que tiene su
## forma (las medidas de su planta mínima y su alto: los nombres de 3ds Max no sirven) y se pone donde
## está: el giro y la posición salen de ajustar la geometría de la pieza a la del objeto. NUNCA se escala
## una pieza (pedido del equipo): si en la referencia está estirada o es otro modelo, va la del kit con
## su medida, ajustada a donde estaba. Lo que la referencia trae en trozos (tablas del tejado, ventana,
## lámpara, pilares, cámara de fotos) es una pieza del kit: GRUPOS. Lo que es un modelo viejo, con otra
## forma, se dice a mano: A_MANO (con varias, la que mejor encaja). Los cajones del escritorio y de la
## cómoda, los pinceles del jarrón y las tapas de las cajas no están sueltos en la referencia: van dentro
## de su mueble (DENTRO, CON_TAPA). Y para llenar más la escena, ADORNOS: más piezas del kit que no
## están en la referencia (en el grupo Adornos o encima de su mueble).
## La referencia mira hacia +z; aquí, como en el desván del juego, el fondo queda hacia -z con el faldón
## a la izquierda: se gira 180° y el suelo se centra en el origen (su altura no cambia: de 0 a 0,15 m).
## Escribe la tabla de lo emparejado (y lo que no) en la salida.
## NO pisa la escena si ya existe (puede tener cambios a mano); para rehacerla desde cero:
##   godot --headless --path . --script res://tools/build_diorama_kit.gd -- --forzar
## Solo la tabla, sin escribir nada: -- --analizar

const SALIDA := "res://preview/diorama_kit.tscn"
const PIEZAS := "res://assets/kit/piezas/"
const REFERENCIA := "res://assets/kit/referencia/Blocking3.fbx"
const SUELO_REF := "FloorPlanks"            ## los objetos del suelo de la referencia (lo de fuera, como la fila de assets sueltos de su derecha, no se pone)
const GIRO := 180.0                         ## giro en y de la referencia para que el fondo quede hacia -z
## Trozos de la referencia que son UNA pieza del kit (por cómo empieza su nombre): los que se tocan
## forman una pieza (los pilares son caña + capitel, cada uno en su sitio).
const GRUPOS := {
	"CeilingPlanks": "SM_Ceiling", "Window": "SM_Window", "Lamp": "SM_Lamp", "Object002": "SM_Lamp",
	"Pillar": "SM_Pillar", "Cylinder006": "SM_Polaroid", "Cylinder007": "SM_Polaroid",
	"Cylinder008": "SM_Polaroid", "Box078": "SM_Polaroid", "Object013": "SM_Polaroid",
	"Object014": "SM_Polaroid", "Object015": "SM_Polaroid", "Object016": "SM_Polaroid",
}
## Objetos de la referencia que son un modelo viejo, fundido con otros o inclinado (no tienen la forma
## de la pieza): su pieza, dicha a mano; con una lista, la que mejor encaja.
const A_MANO := {
	"SM_ComodaD": "SM_ComodaA",             # la cómoda entera fundida en una malla (mal nombrada)
	"Desk": "SM_DeskA",                     # el escritorio con sus cajones fundidos
	"Cylinder004": "SM_Caballete",          # el caballete viejo
	"Object010": "SM_Hat",                  # el sombrero, colgado del burro (inclinado)
	"MP3": "SM_MP3", "Vase": "SM_Vase", "TV019": "SM_TV", "Box071": "SM_Burro", "Box073": "SM_LitterBox",
	"CoverDesk02": "SM_CoverDesk",
	# las cajas son el modelo viejo (las de 812 vértices, con su tapa fundida: CON_TAPA)
	"1": ["SM_BoxA", "SM_BoxB"], "2": ["SM_BoxA", "SM_BoxB"], "3": ["SM_BoxC", "SM_BoxD"],
	"4": ["SM_BoxD", "SM_BoxE"], "5": ["SM_BoxC", "SM_BoxD"], "6": ["SM_BoxC", "SM_BoxD"],
}
## Cajas de la referencia que llevan la tapa puesta (SM_CoverBox<letra> sobre su SM_Box<letra>).
const CON_TAPA := ["1", "2", "4", "5"]
## Lo que no se pone: la arena del arenero (va con él) y mallas vacías.
const IGNORAR := ["Plane002", "Cylinder013"]
## Piezas que van dentro de otra, en su espacio (pivote abajo en el centro): [pieza, posición, si cuenta
## para ajustar el mueble a la referencia (allí van fundidos)]. Los cajones del escritorio (columna
## derecha; SM_DeskB aún no está: se repite el C), los de la cómoda (de abajo arriba) y los pinceles del
## jarrón (en la referencia el jarrón está vacío: no cuentan).
const DENTRO := {
	"SM_DeskA": [["SM_DeskC", Vector3(-0.385, 0.4486, -0.064), true], ["SM_DeskD", Vector3(-0.385, 0.2372, -0.064), true],
		["SM_DeskC", Vector3(-0.385, 0.0258, -0.064), true]],
	"SM_ComodaA": [["SM_ComodaB", Vector3(0, 0.1667, 0), true], ["SM_ComodaC", Vector3(0, 0.36, 0), true],
		["SM_ComodaD", Vector3(0, 0.5533, 0), true]],
	"SM_Vase": [["SM_BrushA", Vector3(-0.015, 0.02, 0), false], ["SM_BrushB", Vector3(0, 0.02, 0), false],
		["SM_BrushC", Vector3(0.015, 0.02, 0), false]],
}
## Adornos que no están en la referencia, para llenar más la escena con piezas del kit (pedido del
## 18-oct: «llenar un poco más la escena conservando los assets»): [pieza, sobre, posición, giro (grados
## en x, y, z), con tapa]. `sobre` es un mueble ya puesto (la primera pieza con ese nombre): la posición
## va en su espacio, con la y desde su parte de arriba, y el adorno cuelga de él (se mueve con el mueble);
## con "" la posición es la del diorama. Medidas de las paredes en el diorama: suelo a 0,15 m; cara del
## hastial z = -1,585; del fondo del entrante z = -3,541 (entre pilares, x de 1,19 a 2,72); de su pared
## lateral x = 0,888 (entre pilares, z de -3,23 a -1,82); la correa alta del faldón, x = -1,32, por debajo
## a 2,755 m.
## La cuerda de bombillitas: SM_Lights es UN tramo (la cuerda cae en curva con una bombilla en medio);
## piezas_kit.gd lo parte en la cuerda sola (SM_LightsCuerda) y la bombilla sola (SM_LightsBombilla), y
## CUERDAS pone tramos de cuerda seguidos, punta con punta, con bombillas colgando a lo largo.
const ADORNOS := [
	# encima de la cómoda: la caja de música de la abuela y la hucha
	["SM_MusicBox", "SM_ComodaA", Vector3(-0.25, 0, 0), Vector3(0, 10, 0), false],
	["SM_Pig", "SM_ComodaA", Vector3(0.29, 0, 0), Vector3(0, -15, 0), false],
	# en la pared lateral del entrante, las polaroids (con su cuerda de bombillas encima)
	["SM_PolaroidA", "", Vector3(0.895, 1.6, -2.05), Vector3(0, 90, 6), false],
	["SM_PolaroidB", "", Vector3(0.895, 1.64, -2.33), Vector3(0, 90, -4), false],
	["SM_PolaroidC", "", Vector3(0.895, 1.3, -2.12), Vector3(0, 90, -7), false],
	["SM_PolaroidD", "", Vector3(0.895, 1.34, -2.41), Vector3(0, 90, 3), false],
	# el dibujo de la bailarina y su abuela, pegado en el hastial, en el rincón del gato
	["Dibujo_t_draw_03", "", Vector3(-1.82, 1.2, -1.583), Vector3.ZERO, false],
	# una alfombra más en el centro y otra lámpara de pie junto al escritorio, para leer
	["SM_Rug", "", Vector3(-0.15, 0.15, 0.55), Vector3(0, 30, 0), false],
	["SM_Lamp", "", Vector3(0.43, 0.15, -1.15), Vector3(0, 30, 0), false],
	# cajas apiladas entre el poste y la tele, bajo el faldón
	["SM_BoxC", "", Vector3(-2.55, 0.15, 1.92), Vector3(0, 20, 0), true],
	["SM_BoxE", "SM_BoxC", Vector3(0.02, 0, -0.02), Vector3(0, -25, 0), true],
	# junto al caballete, una caja con un jarrón de pinceles encima
	["SM_BoxB", "", Vector3(-0.95, 0.15, -0.45), Vector3(0, 15, 0), true],
	["SM_Vase", "", Vector3(-0.98, 0.601, -0.43), Vector3(0, 40, 0), false],
]
## Cuerdas de bombillitas (apagadas: pedido del 18-oct): [nombre, primera punta, dirección (en planta),
## tramos, separación entre bombillas]. Las puntas de cada tramo, a la altura de la primera (contra la
## pared o bajo la viga donde se clava); las bombillas, a lo largo de la cuerda (hasta 0,5 m del centro
## de cada tramo, donde aún no sube demasiado), colgando rectas con el casquillo abrazando la cuerda.
const CUERDAS := [
	# bajo la correa alta del faldón, a lo largo del tejado (una punta junto al caballete, que no lo toque)
	["CuerdaFaldon", Vector3(-1.32, 2.745, 2.84), Vector3(0, 0, -1), 3, 0.25],
	# en la pared lateral del entrante, encima de las polaroids
	["CuerdaEntrante", Vector3(0.957, 2.8, -1.913), Vector3(0, 0, -1), 1, 0.25],
	# en la pared del fondo del entrante, alta y SIN NADA DEBAJO: el sitio para colgar los dibujos (con
	# las bombillas más separadas, para que quepan entre ellas)
	["CuerdaDibujos", Vector3(1.345, 3.3, -3.47), Vector3(1, 0, 0), 1, 0.45],
]
const BOMBILLA_SOLAPE := 0.02               ## lo que el casquillo abraza la cuerda (medido en SM_Lights)
## Piezas que van en Arquitectura (por cómo empieza su nombre); el resto, en Muebles.
const ARQUITECTURA := ["FloorPlanks", "SM_Floor", "SB0", "SM_Skirting", "CeilingSupport", "SM_CeilingSupport",
	"SM_Ceiling", "SM_Wall", "SM_Window", "SM_Pillar"]
const MUESTRAS := 700                       ## puntos por superficie para comparar formas
const TOLERANCIA := 0.04                    ## diferencia de forma aceptada: 4 cm + 3 % de lo que mide

var _raiz: Node3D
var _mallas_kit := {}                       ## pieza -> [[malla, transformación en la pieza], ...]
var _kit := {}                              ## pieza (+ lo que lleva dentro) -> Nube, en el espacio de la pieza
var _usos := {}                             ## pieza -> veces puesta (entre piezas iguales se reparte)
var _base_kit := {}                         ## pieza de una malla -> el giro de esa malla en la pieza


## Una nube de puntos de una o varias mallas: sus vértices (para medidas) y puntos repartidos por su
## superficie (para comparar formas aunque estén hechas con distintos triángulos).
class Nube:
	var vertices := PackedVector3Array()
	var muestras := PackedVector3Array()
	var firma := Vector3.ZERO               ## (largo, ancho) de su planta mínima girando en y, y alto

	func anadir(mesh: Mesh, xf: Transform3D) -> void:
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for p in v:
				vertices.append(xf * p)

	## Reparte n puntos por la superficie de las mallas (por área), siempre los mismos.
	func muestrear(mallas: Array, n: int) -> void:
		var tris := PackedVector3Array()
		var areas := PackedFloat32Array()
		var total := 0.0
		for par: Array in mallas:
			var mesh: Mesh = par[0]
			var xf: Transform3D = par[1]
			for s in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(s)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var cuenta := idx.size() if idx.size() > 0 else v.size()
				for i in range(0, cuenta - 2, 3):
					var a := xf * v[idx[i] if idx.size() > 0 else i]
					var b := xf * v[idx[i + 1] if idx.size() > 0 else i + 1]
					var c := xf * v[idx[i + 2] if idx.size() > 0 else i + 2]
					var area := (b - a).cross(c - a).length() * 0.5
					tris.append_array([a, b, c])
					areas.append(area)
					total += area
		if total <= 0.0:
			muestras = vertices.duplicate()
			return
		var acumulado := 0.0
		var k := 0
		for t in areas.size():
			acumulado += areas[t] / total * n
			while acumulado >= 1.0:
				acumulado -= 1.0
				k += 1
				var r1 := fmod(k * 0.7548776662, 1.0)        # secuencia de baja discrepancia (R2)
				var r2 := fmod(k * 0.5698402910, 1.0)
				if r1 + r2 > 1.0:
					r1 = 1.0 - r1
					r2 = 1.0 - r2
				var a := tris[t * 3]
				muestras.append(a + (tris[t * 3 + 1] - a) * r1 + (tris[t * 3 + 2] - a) * r2)
		for p in vertices:                      # los vértices también: marcan esquinas y bordes
			if muestras.size() >= n * 2:
				break
			muestras.append(p)

	func caja() -> AABB:
		var out := AABB(vertices[0], Vector3.ZERO)
		for p in vertices:
			out = out.expand(p)
		return out

	## (largo, ancho, alto): el rectángulo de área mínima de su planta (girando en y de grado en grado).
	func calcular_firma() -> void:
		var area := INF
		var alto := caja().size.y
		var v := _reducidos(1500)
		for g in 90:
			var ang := deg_to_rad(g)
			var co := cos(ang)
			var si := sin(ang)
			var x0 := INF
			var x1 := -INF
			var z0 := INF
			var z1 := -INF
			for p in v:
				var x := p.x * co - p.z * si
				var z := p.x * si + p.z * co
				x0 = minf(x0, x)
				x1 = maxf(x1, x)
				z0 = minf(z0, z)
				z1 = maxf(z1, z)
			if (x1 - x0) * (z1 - z0) < area - 1e-9:
				area = (x1 - x0) * (z1 - z0)
				firma = Vector3(maxf(x1 - x0, z1 - z0), minf(x1 - x0, z1 - z0), alto)

	## Como mucho n vértices (uno de cada tantos), para las búsquedas de giro.
	func _reducidos(n: int) -> PackedVector3Array:
		if vertices.size() <= n:
			return vertices
		var out := PackedVector3Array()
		var paso := float(vertices.size()) / n
		for i in n:
			out.append(vertices[int(i * paso)])
		return out


## Puntos repartidos en celdas, para encontrar rápido el más cercano a otro.
class Rejilla:
	var celda: float
	var mapa := {}

	func _init(puntos: PackedVector3Array, c: float) -> void:
		celda = c
		for p in puntos:
			var k := _clave(p)
			if not mapa.has(k):
				mapa[k] = []
			mapa[k].append(p)

	func _clave(p: Vector3) -> Vector3i:
		return Vector3i(floori(p.x / celda), floori(p.y / celda), floori(p.z / celda))

	## El punto más cercano a p a menos de una celda (o null).
	func cercano(p: Vector3) -> Variant:
		var k := _clave(p)
		var mejor: Variant = null
		var d2 := celda * celda
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for dz in range(-1, 2):
					var cubo: Variant = mapa.get(k + Vector3i(dx, dy, dz))
					if cubo == null:
						continue
					for q: Vector3 in cubo:
						var d := p.distance_squared_to(q)
						if d < d2:
							d2 = d
							mejor = q
		return mejor


func _init() -> void:
	var analizar := "--analizar" in OS.get_cmdline_user_args()
	if FileAccess.file_exists(SALIDA) and not analizar and not "--forzar" in OS.get_cmdline_user_args():
		print("DIORAMA KIT: %s ya existe y no se pisa (puede tener cambios a mano). Con --forzar se rehace." % SALIDA)
		quit(0)
		return
	_cargar_kit()
	var objetos := _objetos_referencia()
	var puestas := _emparejar(objetos)
	if analizar:
		print("DIORAMA KIT: análisis hecho (%d piezas); no se escribe nada" % puestas.size())
		quit(0)
		return
	_raiz = Node3D.new()
	_raiz.name = "DioramaKit"
	var arquitectura := _nuevo_grupo("Arquitectura")
	var muebles := _nuevo_grupo("Muebles")
	var nombres := {}
	var primeras := {}                      # pieza -> la primera puesta: {nodo, dentro}
	for p: Dictionary in puestas:
		var pieza: String = p.pieza
		var n := _instancia(pieza)
		var es_arq := ARQUITECTURA.any(func(pre: String) -> bool: return pieza.begins_with(pre))
		nombres[pieza] = int(nombres.get(pieza, 0)) + 1
		n.name = pieza if nombres[pieza] == 1 else "%s_%d" % [pieza, nombres[pieza]]
		n.transform = p.xf
		(arquitectura if es_arq else muebles).add_child(n)
		_poner_dentro(n, p.dentro)
		if not primeras.has(pieza):
			primeras[pieza] = {"nodo": n, "dentro": p.dentro}
	var adornos := _nuevo_grupo("Adornos")
	for a: Array in ADORNOS:
		var pieza: String = a[0]
		var n := _instancia(pieza)
		n.name = pieza
		var dentro := _dentro(pieza, a[4])
		var pos: Vector3 = a[2]
		var padre: Node3D = adornos
		if a[1] != "":
			assert(primeras.has(a[1]), "Adorno %s: no hay ningún %s puesto" % [pieza, a[1]])
			padre = primeras[a[1]].nodo
			pos.y += _nube_kit(a[1], primeras[a[1]].dentro).caja().end.y
		n.transform = Transform3D(Basis.from_euler((a[3] as Vector3) * PI / 180.0), pos)
		padre.add_child(n, true)
		_poner_dentro(n, dentro)
		if not primeras.has(pieza):
			primeras[pieza] = {"nodo": n, "dentro": dentro}
	for c: Array in CUERDAS:
		_poner_cuerda(_nuevo_grupo(c[0], adornos), c[1], c[2], c[3], c[4])
	_duenos(_raiz)
	var packed := PackedScene.new()
	var err := packed.pack(_raiz)
	if err == OK:
		err = ResourceSaver.save(packed, SALIDA)
	print("DIORAMA KIT %s (%d piezas de la referencia, %d adornos y %d cuerdas de bombillas) err=%d" % [
		SALIDA, puestas.size(), ADORNOS.size(), CUERDAS.size(), err])
	_raiz.free()
	quit(0 if err == OK else 1)


# --- La referencia y el kit ---------------------------------------------------------------------

## Las mallas de cada pieza del tileset y su nube de puntos (con lo que lleva DENTRO y cuenta).
func _cargar_kit() -> void:
	for f in DirAccess.get_files_at(PIEZAS):
		if f.get_extension() != "scn":
			continue
		var pieza := f.get_basename()
		_mallas_kit[pieza] = _mallas_pieza(pieza)
		if _mallas_kit[pieza].size() == 1:
			_base_kit[pieza] = (_mallas_kit[pieza][0][1] as Transform3D).basis.orthonormalized()
		_usos[pieza] = 0
	for pieza: String in _mallas_kit:
		_nube_kit(pieza, _dentro(pieza, false))


## Lo que va dentro de una pieza: [[pieza, posición, cuenta], ...] (DENTRO, y si `con_tapa` y es una
## caja, su tapa: encajada sobre la caja, con su borde de arriba 2 cm por encima).
func _dentro(pieza: String, con_tapa: bool) -> Array:
	var out: Array = DENTRO.get(pieza, []).duplicate()
	if con_tapa and pieza.begins_with("SM_Box"):
		var tapa := "SM_CoverBox" + pieza.trim_prefix("SM_Box")
		var alto_caja := _nube_kit(pieza, []).caja().size.y
		var alto_tapa := _nube_kit(tapa, []).caja().size.y
		out.append([tapa, Vector3(0, alto_caja + 0.02 - alto_tapa, 0), true])
	return out


## La nube de una pieza con lo que lleva dentro (lo que cuenta para ajustar), guardada para no repetirla.
func _nube_kit(pieza: String, dentro: Array) -> Nube:
	var mallas: Array = _mallas_kit[pieza].duplicate()
	var clave := pieza
	for d: Array in dentro:
		if d[2]:
			for par: Array in _mallas_kit[d[0]]:
				mallas.append([par[0], Transform3D(Basis.IDENTITY, d[1]) * par[1]])
			clave += "|%s@%s" % [d[0], d[1]]
	if not _kit.has(clave):
		var nube := Nube.new()
		for par: Array in mallas:
			nube.anadir(par[0], par[1])
		nube.muestrear(mallas, MUESTRAS)
		nube.calcular_firma()
		_kit[clave] = nube
	return _kit[clave]


## [[malla, transformación en el espacio de la pieza], ...] de una pieza del tileset (leídas de su
## escena sin instanciarla: sus MeshInstance3D cuelgan de la raíz).
func _mallas_pieza(pieza: String) -> Array:
	var out := []
	var escena := load(PIEZAS + pieza + ".scn") as PackedScene
	assert(escena != null, "Diorama del kit: no carga la pieza %s" % pieza)
	var estado := escena.get_state()
	for i in estado.get_node_count():
		if estado.get_node_type(i) != "MeshInstance3D":
			continue
		var malla: Mesh = null
		var xf := Transform3D.IDENTITY
		for k in estado.get_node_property_count(i):
			match estado.get_node_property_name(i, k):
				"mesh":
					malla = estado.get_node_property_value(i, k)
				"transform":
					xf = estado.get_node_property_value(i, k)
		if malla != null:
			out.append([malla, xf])
	return out


## Los objetos de la referencia sobre su suelo, ya girados y centrados como el diorama:
## [{nombre, nube, mallas, base (giro de su nodo)}].
func _objetos_referencia() -> Array:
	var escena := (load(REFERENCIA) as PackedScene).instantiate() as Node3D
	var todas := []
	var suelo := AABB()
	var hay_suelo := false
	for m: MeshInstance3D in escena.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null:
			continue
		var xf := _xf(m, escena)
		var b := xf * m.mesh.get_aabb()
		todas.append([m, xf, b])
		if String(m.name).begins_with(SUELO_REF):
			suelo = b if not hay_suelo else suelo.merge(b)
			hay_suelo = true
	assert(hay_suelo, "La referencia no tiene objetos %s* (su suelo)" % SUELO_REF)
	var centro := suelo.get_center()
	var marco := Transform3D(Basis(Vector3.UP, deg_to_rad(GIRO)), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -Vector3(centro.x, 0, centro.z))
	var dentro := suelo.grow(0.6)
	var out := []
	var fuera := PackedStringArray()
	for t: Array in todas:
		var m: MeshInstance3D = t[0]
		var c: Vector3 = (t[2] as AABB).get_center()
		if c.x < dentro.position.x or c.x > dentro.end.x or c.z < dentro.position.z or c.z > dentro.end.z:
			fuera.append(String(m.name))
			continue
		if String(m.name) in IGNORAR:
			continue
		var xf: Transform3D = marco * t[1]
		var nube := Nube.new()
		nube.anadir(m.mesh, xf)
		out.append({"nombre": String(m.name), "nube": nube, "mallas": [[m.mesh, xf]], "base": xf.basis})
	print("REFERENCIA %s: %d objetos sobre el suelo; fuera (no se ponen): %s" % [REFERENCIA, out.size(), ", ".join(fuera)])
	escena.free()
	return out


# --- Emparejar ----------------------------------------------------------------------------------

## Junta los trozos (GRUPOS), elige la pieza de cada objeto y la ajusta. [{pieza, xf, refs}]
func _emparejar(objetos: Array) -> Array:
	var sueltos := []
	var grupos := {}                        # pieza -> [objeto...]
	for o: Dictionary in objetos:
		var pieza := ""
		for pre: String in GRUPOS:
			if o.nombre.begins_with(pre):
				pieza = GRUPOS[pre]
		if pieza == "":
			sueltos.append(o)
		else:
			if not grupos.has(pieza):
				grupos[pieza] = []
			grupos[pieza].append(o)
	var piezas := []
	for pieza: String in grupos:
		for racimo: Array in _racimos(grupos[pieza]):
			var nube := Nube.new()
			var mallas := []
			var nombres := PackedStringArray()
			for o: Dictionary in racimo:
				nube.vertices.append_array(o.nube.vertices)
				mallas.append_array(o.mallas)
				nombres.append(o.nombre)
			piezas.append({"nombre": "+".join(nombres), "nube": nube, "mallas": mallas, "pieza": pieza,
				"base": null, "como": "trozos"})
	for o: Dictionary in sueltos:
		var a_mano: Variant = A_MANO.get(o.nombre, "")
		o["pieza"] = a_mano if a_mano is String else ""
		o["opciones"] = a_mano if a_mano is Array else []
		o["como"] = "a mano"
		piezas.append(o)
	var out := []
	var sin_pieza := PackedStringArray()
	for o: Dictionary in piezas:
		var nube: Nube = o.nube
		nube.muestrear(o.mallas, MUESTRAS)
		nube.calcular_firma()
		var opciones: Array = [o.pieza] if o.pieza != "" else o.get("opciones", []).duplicate()
		var como: String = o.como
		if opciones.is_empty():
			var por_forma := _por_forma(nube.firma)
			if por_forma != "":
				opciones = [por_forma]
			como = "forma"
		if opciones.is_empty():
			sin_pieza.append("%s %s" % [o.nombre, _v(nube.firma)])
			continue
		var mejor := {}
		for pieza: String in opciones:
			var dentro := _dentro(pieza, o.nombre in CON_TAPA)
			var base: Variant = null
			if o.base is Basis and _base_kit.has(pieza) and (o.base as Basis).determinant() > 0.0:
				base = (o.base as Basis).orthonormalized() * (_base_kit[pieza] as Basis).inverse()
			var ajuste := _ajustar(_nube_kit(pieza, dentro), nube, base)
			if mejor.is_empty() or ajuste.distancia < mejor.distancia:
				mejor = ajuste
				mejor["pieza"] = pieza
				mejor["dentro"] = dentro
		_usos[mejor.pieza] += 1
		out.append({"pieza": mejor.pieza, "xf": mejor.xf, "dentro": mejor.dentro, "refs": o.nombre})
		var euler: Vector3 = mejor.xf.basis.get_euler() * 180.0 / PI
		print("  %-34s -> %-26s (%s) forma %s / %s  giro %s  pos %s  separación %.3f m" % [
			o.nombre.left(34), mejor.pieza + (" + tapa" if mejor.dentro.size() > DENTRO.get(mejor.pieza, []).size() else ""),
			como, _v(nube.firma), _v(_nube_kit(mejor.pieza, mejor.dentro).firma), _v(euler),
			_v(mejor.xf.origin), mejor.distancia])
	if not sin_pieza.is_empty():
		print("SIN PIEZA (no hay ninguna con su forma; decirlo en A_MANO): %s" % ", ".join(sin_pieza))
	return out


## Los objetos que se tocan (cajas a menos de 5 cm), juntos.
func _racimos(objetos: Array) -> Array:
	var padre := range(objetos.size())
	var raiz := func(i: int) -> int:
		while padre[i] != i:
			i = padre[i]
		return i
	for i in objetos.size():
		for j in range(i + 1, objetos.size()):
			if objetos[i].nube.caja().grow(0.05).intersects(objetos[j].nube.caja()):
				padre[raiz.call(i)] = raiz.call(j)
	var out := {}
	for i in objetos.size():
		var r: int = raiz.call(i)
		if not out.has(r):
			out[r] = []
		out[r].append(objetos[i])
	return out.values()


## La pieza del kit con la forma más parecida (o "" si ninguna se parece lo bastante). Entre iguales,
## la menos usada (así se reparten las variantes: cabios A-D, postes, tacos de las esquinas).
func _por_forma(firma: Vector3) -> String:
	var mejor := ""
	var mejor_coste := INF
	var tope := TOLERANCIA + 0.03 * (firma.x + firma.y + firma.z)
	for pieza: String in _mallas_kit:
		var f: Vector3 = _nube_kit(pieza, _dentro(pieza, false)).firma
		var coste := absf(f.x - firma.x) + absf(f.y - firma.y) + absf(f.z - firma.z)
		if coste > tope:
			continue
		coste += 0.002 * _usos[pieza]       # a igualdad de forma, la menos usada
		if coste < mejor_coste:
			mejor_coste = coste
			mejor = pieza
	return mejor


# --- Ajustar ------------------------------------------------------------------------------------

## Dónde y con qué giro va la pieza (nube `kit`, en su espacio) para quedar como el objeto (nube `ref`).
## Candidatos: cada giro en y que deja su caja con las medidas de la del objeto (una pieza simétrica
## tiene varios) y, si el objeto es suelto, el giro de su nodo en la referencia (lo inclinado, como un
## sombrero colgado: `base`, el giro que lleva la pieza si su malla es la misma). Cada candidato se coloca caja con caja (centro en planta, base con base), se
## afina acercando las dos superficies, y gana el que queda más pegado. {xf, distancia}
func _ajustar(kit: Nube, ref: Nube, base: Variant) -> Dictionary:
	var caja_ref := ref.caja()
	var tope := clampf(caja_ref.size.length() * 0.05, 0.01, 0.15)
	var rejilla_ref := Rejilla.new(ref.muestras, tope)
	var v := kit._reducidos(600)
	var errores := PackedFloat32Array()
	for g in 360:
		errores.append(_error_caja(v, Basis(Vector3.UP, deg_to_rad(g)), caja_ref))
	var minimo := INF
	for e in errores:
		minimo = minf(minimo, e)
	var giros: Array[Basis] = []
	for g in 360:
		var e := errores[g]
		if e <= minimo + maxf(0.05, minimo * 0.3) and e <= errores[(g + 359) % 360] and e <= errores[(g + 1) % 360]:
			var fino := float(g)
			for d in range(-9, 10):
				var prueba := g + d * 0.1
				if _error_caja(v, Basis(Vector3.UP, deg_to_rad(prueba)), caja_ref) < _error_caja(v, Basis(Vector3.UP, deg_to_rad(fino)), caja_ref):
					fino = prueba
			giros.append(Basis(Vector3.UP, deg_to_rad(fino)))
	if base is Basis:
		giros.append(base as Basis)
	var mejor := {"xf": Transform3D(), "distancia": INF}
	for giro in giros:
		var xf := _caja_con_caja(kit, giro, caja_ref)
		xf = _afinar(kit, xf, ref, rejilla_ref, tope, true)
		var d := _distancia(kit, xf, ref, rejilla_ref, tope)
		if d < mejor.distancia:
			mejor = {"xf": xf, "distancia": d}
	# Si solo está girada en y, el giro se endereza: a escuadra (múltiplo de 90°) si le faltan menos de 2°
	# (paredes, vigas, tablas: un grado de más abre rendijas de 3 cm en las puntas de una tabla de 5 m) o
	# al grado; se vuelve a acercar sin girar, y si encaja casi igual, vale.
	var xf: Transform3D = mejor.xf
	if xf.basis.y.is_equal_approx(Vector3.UP):
		var grados := rad_to_deg(xf.basis.get_euler().y)
		var escuadra := roundf(grados / 90.0) * 90.0
		for g in [escuadra, roundf(grados)]:
			if absf(g - grados) > 2.0:
				continue
			var recto := Transform3D(Basis(Vector3.UP, deg_to_rad(g)), xf.origin)
			recto = _afinar(kit, recto, ref, rejilla_ref, tope, false)
			var d := _distancia(kit, recto, ref, rejilla_ref, tope)
			if d <= mejor.distancia * 1.15 + 0.002:
				mejor = {"xf": recto, "distancia": d}
				break
	return mejor


## Cuánto se diferencian (suma de los tres lados) la caja de los puntos girados y la del objeto.
func _error_caja(v: PackedVector3Array, giro: Basis, caja: AABB) -> float:
	var b := AABB(giro * v[0], Vector3.ZERO)
	for p in v:
		b = b.expand(giro * p)
	var d := b.size - caja.size
	return absf(d.x) + absf(d.y) + absf(d.z)


## La pieza girada y puesta con su caja sobre la del objeto: centro en planta y base con base.
func _caja_con_caja(kit: Nube, giro: Basis, caja: AABB) -> Transform3D:
	var b := AABB(giro * kit.vertices[0], Vector3.ZERO)
	for p in kit._reducidos(3000):
		b = b.expand(giro * p)
	var c := caja.get_center()
	var cb := b.get_center()
	return Transform3D(giro, Vector3(c.x - cb.x, caja.position.y - b.position.y, c.z - cb.z))


## Acerca la pieza a la superficie del objeto: unas vueltas de mover (y, si `girar`, girar en y) hacia
## los puntos más cercanos de cada nube a la otra (los que están a menos de `tope`).
func _afinar(kit: Nube, xf: Transform3D, ref: Nube, rejilla_ref: Rejilla, tope: float, girar: bool) -> Transform3D:
	for vuelta in 8:
		var pares_p := PackedVector3Array()
		var pares_q := PackedVector3Array()
		var movidos := PackedVector3Array()
		for p in kit.muestras:
			movidos.append(xf * p)
		for p in movidos:
			var q: Variant = rejilla_ref.cercano(p)
			if q != null:
				pares_p.append(p)
				pares_q.append(q)
		var rejilla_kit := Rejilla.new(movidos, tope)
		for q in ref.muestras:
			var p: Variant = rejilla_kit.cercano(q)
			if p != null:
				pares_p.append(p)
				pares_q.append(q)
		if pares_p.size() < 8:
			return xf
		var mp := Vector3.ZERO
		var mq := Vector3.ZERO
		for i in pares_p.size():
			mp += pares_p[i]
			mq += pares_q[i]
		mp /= pares_p.size()
		mq /= pares_q.size()
		var sc := 0.0
		var ss := 0.0
		for i in pares_p.size():
			var a := pares_p[i] - mp
			var b := pares_q[i] - mq
			sc += b.x * a.x + b.z * a.z
			ss += b.x * a.z - b.z * a.x
		var giro := Basis(Vector3.UP, atan2(ss, sc)) if girar else Basis.IDENTITY
		# girar alrededor del centro de los pares y llevar ese centro a su sitio
		xf = Transform3D(giro, mq - giro * mp) * xf
	return xf


## Lo separadas que quedan las dos superficies: la media de la distancia de cada punto de una al más
## cercano de la otra (en las dos direcciones; como mucho `tope` por punto).
func _distancia(kit: Nube, xf: Transform3D, ref: Nube, rejilla_ref: Rejilla, tope: float) -> float:
	var suma := 0.0
	var movidos := PackedVector3Array()
	for p in kit.muestras:
		var m := xf * p
		movidos.append(m)
		var q: Variant = rejilla_ref.cercano(m)
		suma += tope if q == null else m.distance_to(q)
	var rejilla_kit := Rejilla.new(movidos, tope)
	for q in ref.muestras:
		var p: Variant = rejilla_kit.cercano(q)
		suma += tope if p == null else q.distance_to(p)
	return suma / (kit.muestras.size() + ref.muestras.size())


# --- Escena -------------------------------------------------------------------------------------

## Una instancia de la escena de una pieza del kit (pivote abajo en el centro, escala 1).
func _instancia(pieza: String) -> Node3D:
	var escena := load(PIEZAS + pieza + ".scn") as PackedScene
	assert(escena != null, "Diorama del kit: falta la pieza %s (¿has pasado tools/piezas_kit.gd?)" % pieza)
	return escena.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D


func _nuevo_grupo(nombre: String, padre: Node3D = null) -> Node3D:
	var g := Node3D.new()
	g.name = nombre
	(padre if padre != null else _raiz).add_child(g)
	return g


## Una cuerda de bombillitas: `tramos` SM_LightsCuerda seguidos, punta con punta, desde `punta` hacia
## `dir` (cada tramo girado para que su cuerda vaya en esa dirección), y en cada tramo una SM_LightsBombilla
## cada `paso` metros a lo largo, colgando de la cuerda (hija del tramo: se mueve con él).
func _poner_cuerda(grupo: Node3D, punta: Vector3, dir: Vector3, tramos: int, paso: float) -> void:
	var cuerda := _nube_kit("SM_LightsCuerda", [])
	var caja := cuerda.caja()
	var alto_bombilla := _nube_kit("SM_LightsBombilla", []).caja().size.y
	var giro := Basis(Vector3.UP, atan2(-dir.z, dir.x))   # el eje x del tramo, a lo largo de dir
	var largo := _punta_cuerda(cuerda, 1.0).x - _punta_cuerda(cuerda, -1.0).x
	for i in tramos:
		var tramo := _instancia("SM_LightsCuerda")
		tramo.name = "SM_LightsCuerda"
		var centro := punta + dir * largo * (i + 0.5)
		tramo.transform = Transform3D(giro, centro - Vector3(0, _punta_cuerda(cuerda, 1.0).y, 0))
		grupo.add_child(tramo, true)
		var n := floori(0.5 / paso + 0.001)
		for k in range(-n, n + 1):
			var debajo := _bajo_cuerda(cuerda, k * paso)
			var bombilla := _instancia("SM_LightsBombilla")
			bombilla.name = "SM_LightsBombilla"
			bombilla.position = Vector3(k * paso, debajo.y + BOMBILLA_SOLAPE - alto_bombilla, debajo.z)
			tramo.add_child(bombilla, true)
	assert(caja.size.x > 0.5, "SM_LightsCuerda no parece una cuerda (¿has pasado tools/piezas_kit.gd?)")


## La punta de la cuerda de un lado (`lado` = 1 derecha, -1 izquierda): su vértice más alto.
func _punta_cuerda(cuerda: Nube, lado: float) -> Vector3:
	var out := Vector3(0, -INF, 0)
	for p in cuerda.vertices:
		if p.x * lado > 0 and p.y > out.y:
			out = p
	return out


## El punto de abajo de la cuerda en x (el más bajo de sus vértices a menos de 2 cm; z, el del medio).
func _bajo_cuerda(cuerda: Nube, x: float) -> Vector3:
	var y := INF
	var z := 0.0
	var n := 0
	for p in cuerda.vertices:
		if absf(p.x - x) < 0.02:
			y = minf(y, p.y)
			z += p.z
			n += 1
	return Vector3(x, y, z / maxi(n, 1))


func _xf(n: Node, hasta: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var p: Node = n
	while p != hasta and p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Las piezas que van dentro de una puesta (cajones, tapa, pinceles), como hijas suyas.
func _poner_dentro(n: Node3D, dentro: Array) -> void:
	for d: Array in dentro:
		var hijo := _instancia(d[0])
		hijo.name = d[0]
		hijo.position = d[1]
		n.add_child(hijo, true)              # nombre legible si se repite (SM_DeskC2)


## Todo lo creado es de la escena (también lo que cuelga de una pieza: cajones, tapas, adornos); lo de
## dentro de cada pieza no (ya tiene dueño: queda como referencia a su .scn).
func _duenos(n: Node) -> void:
	for c in n.get_children():
		if c.owner == null:
			c.owner = _raiz
			_duenos(c)


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
