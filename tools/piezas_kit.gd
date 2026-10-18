extends SceneTree
## Hace el "tileset" del kit de las artistas: una escena por pieza en assets/kit/piezas/<Pieza>.scn,
## para montar dioramas a mano en el editor (arrastrar, duplicar, mover, girar; nunca escalar).
## Cada escena: un Node3D con el nombre de la pieza (escala 1, el pivote abajo en el centro de la
## pieza, para apoyarla en el suelo) y dentro su malla tal como viene en su .fbx (orientación y
## escala del fichero, sin tocar), con su material:
##  - el del kit (assets/kit/materiales/M_<conjunto>.tres) si la pieza es de un conjunto con texturas
##    (CONJUNTOS: qué piezas lleva cada carpeta de TexturasFinales; si no está, SM_<conjunto>...);
##  - si no, un color PROVISIONAL compartido (assets/kit/materiales/provisional/<grupo>.tres), que se
##    puede retocar en el editor y vale para todas las piezas de su grupo.
## Todos con el estilo cozy del kit (tools/estilo_kit.gd: su paleta y su capa de tono).
## Las piezas se cogen de modelos/ (sueltas, con su nombre bueno) y de paquetes/ (varias por fichero;
## las que llegan con el nombre de 3ds Max se renombran: ALIAS; las que ya están sueltas no se
## repiten: REPETIDAS; las que vienen en trozos colocados entre sí, como el MP3, son una pieza: GRUPOS).
## El MP3 de Pack05 viene despiezado (sus partes separadas, para texturizar): montado solo está en la
## escena de referencia de las artistas (referencia/), y de ahí se coge (MONTADAS).
## Y los dibujos 2D de las artistas (dibujos/), cada uno como un plano con su textura (Dibujo_<fichero>,
## DIBUJO_ANCHO de ancho, de pie, mirando a +z, con el pivote abajo en el centro): para ponerlos en una
## pared o colgarlos de la cuerda.
## Ejecutar otra vez si cambia un .fbx del kit o llegan texturas (después de materiales_kit.gd):
##   godot --headless --path . --script res://tools/piezas_kit.gd

const KIT := "res://assets/kit/"
const SALIDA := KIT + "piezas/"
const PROVISIONAL := KIT + "materiales/provisional/"
const MODEL_EXT := ["fbx", "glb", "gltf"]
const IMAGE_EXT := ["png", "jpg", "jpeg", "webp"]
const DIBUJO_ANCHO := 0.42                  ## ancho de cada dibujo (m): un A3, como una lámina de la pared
const Estilo := preload("res://tools/estilo_kit.gd")
## Duplicados de piezas que ya están sueltas (las cajas de Boxes.fbx = SM_BoxA..E; la tele de Pack04
## = SM_TV). Las de nombre SM_ repetido se descartan solas (la primera que se encuentra es la buena).
const REPETIDAS := ["Box01", "Box073", "Box074", "Box075", "Box077", "TV01", "TV05"]
## Ficheros de los que solo vale alguna malla: SM_bombilla.fbx trae la escena entera de 3ds Max (el
## blocking y más) y de él solo es la bombilla. Con SM_cuerda.fbx, la guirnalda de bombillitas (18-oct).
const SOLO := {"SM_bombilla.fbx": ["bombilla"]}
## Ficheros de una sola malla con el nombre de 3ds Max (ObjectNNN): la pieza se llama como el fichero
## (los de Pack09, 18-oct: los papeles y la peana).
const POR_FICHERO := ["SM_Paper01.fbx", "SM_PaperBroken.fbx", "SM_PaperStack.fbx", "SM_PaperUniversidad.fbx",
	"SM_Peana.fbx"]
## Ficheros que no se usan (Comoda.fbx es la cómoda fundida en una malla: están sus piezas sueltas; la
## referencia es una escena entera: de ella solo se cogen las MONTADAS).
const EXCLUIDOS := ["Comoda.fbx", "SM_otter.fbx"]   ## (la nutria la monta build_kit_level.gd con su malla entera)
## Mallas de la escena de referencia (el blocking de 3ds Max) que son una pieza montada que el kit solo
## trae en trozos: van antes que esos trozos (con su nombre de GRUPOS) y los trozos ya no se usan.
const REFERENCIA := KIT + "referencia/Blocking3.fbx"   ## la misma que tools/build_diorama_kit.gd
const MONTADAS := ["MP3"]
## Nombres buenos para las piezas que llegan con el nombre por defecto de 3ds Max.
const ALIAS := {"Box072": "SM_Burro", "CoverDesk": "SM_CoverDesk", "Vase001": "SM_Vase",
	"SM_Lights001": "SM_Cuerda", "bombilla": "SM_Bombilla",
	"Cylinder025": "SM_BrushA", "Cylinder026": "SM_BrushB", "Cylinder027": "SM_BrushC",
	"Object006": "SM_CoverBoxA", "Object007": "SM_CoverBoxB", "Object008": "SM_CoverBoxC",
	"Object009": "SM_CoverBoxD", "Object010": "SM_CoverBoxE",
	# Las pegatinas de la hucha (Pack07 del 18-oct, pegadas al cuerpo): con la hucha, en su pieza (GRUPOS).
	"Plane001": "SM_PigPegatina1", "Plane002": "SM_PigPegatina2", "Plane003": "SM_PigPegatina3",
	"Plane005": "SM_PigPegatina5", "Plane006": "SM_PigPegatina6"}
## Piezas en trozos (prefijo -> una sola pieza, con sus trozos colocados como en el fichero). La hucha
## (SM_PigA..L de Pack07: patas, cuerpo, orejas, hocico, ojos, ranura, cola) va montada en una pieza.
const GRUPOS := {"MP3": "SM_MP3", "Pillar00": "SM_Pillar", "SM_Pig": "SM_Pig"}
## El Pack07 del 18-oct por la tarde trae la hucha "explotada" (los trozos separados del cuerpo, para
## pintarla; mismas mallas y UV que la de la mañana, que venía montada) y sus pegatinas pegadas al cuerpo.
## Cada trozo va donde estaba montado, respecto al cuerpo (SM_PigE; medido en la de la mañana); las
## pegatinas, donde vienen.
const HUCHA_MONTADA := {"SM_PigA": Vector3(-0.1040, -0.1178, -0.0909), "SM_PigB": Vector3(0.1040, -0.1178, -0.0909),
	"SM_PigC": Vector3(-0.1040, -0.1178, 0.0957), "SM_PigD": Vector3(0.1040, -0.1178, 0.0957),
	"SM_PigF": Vector3(0.1158, 0.0895, -0.0680), "SM_PigG": Vector3(-0.1158, 0.0895, -0.0680),
	"SM_PigH": Vector3(0.0000, -0.0285, -0.1738), "SM_PigI": Vector3(0.0621, 0.0248, -0.1640),
	"SM_PigJ": Vector3(-0.0621, 0.0248, -0.1640), "SM_PigK": Vector3(0.0000, 0.1495, -0.0980),
	"SM_PigL": Vector3(0.0000, -0.0252, 0.1867)}
## Qué piezas pinta cada conjunto de texturas (carpeta de assets/kit/texturas/ = de TexturasFinales):
## por cómo empieza su nombre. El reparto es el de Eva (18-oct): en TexturasFinales se ignoran
## CON_LINEART, Hat, Lights, LitterBox, Music_Box, Otter y POLAROIDS (lo suyo va ahora en los Pack).
## Las de nombre de 3ds Max (FloorPlanks, SB0, CeilingSupport0: las de FloorCeilingPlanks...) son de
## Pack01. Pack06 (caja de música y polaroids A-D), Pack08 (caballete, cama del gato, espejo y
## alfombra) y Pack09 (llavero, papeles y peana) llegaron el 18-oct por la tarde.
const CONJUNTOS := {
	"Boxes": ["SM_Box", "SM_CoverBox"],
	"Comoda": ["SM_Comoda"],
	"Desk": ["SM_Desk"],
	"LampStool": ["SM_Lamp", "SM_Stool"],
	"Pack01": ["SM_CeilingSupporDiagonal", "SM_CeilingSupportDiagonal", "SM_CeilingSupportSmallPillars",
		"SM_CeilingSupportA", "SM_CeilingSupportB", "SM_CeilingSupportC", "SM_CeilingSupportD",
		"SM_CeilingSupportE", "SM_CeilingSupportF", "SM_CeilingSupportG", "SM_Floor", "SM_Pillar", "SM_SkirtingBoardA", "SM_SkirtingBoardBottom",
		"SM_SkirtingBoards", "FloorPlanks", "SB0", "CeilingSupport0"],
	"Pack_02": ["SM_Ceiling"],                    # (y SM_CeilingSupportVertical*: empiezan igual)
	"Pack_03": ["SM_SkirtingBoardBack", "SM_SkirtingBoardI", "SM_SkirtingBoardJ", "SM_SkirtingBoardK",
		"SM_SkirtingBoardL", "SM_SkirtingBoardTop", "SM_Wall", "SM_Window"],
	"Pack_04": ["SM_Burro", "SM_CoverDesk", "SM_TV"],
	"Pack_05": ["SM_Brush", "SM_MP3", "SM_Vase"],
	"Pack06": ["SM_MusicBox", "SM_PolaroidA", "SM_PolaroidB", "SM_PolaroidC", "SM_PolaroidD"],
	"Pack07": ["SM_Lights", "SM_Cuerda", "SM_Bombilla", "SM_LitterBox", "SM_Pig", "SM_Sticker", "SN_Hat", "SM_Hat"],
	"Pack08": ["SM_Caballete", "SM_CatBed", "SM_Mirror", "SM_Rug"],
	"Pack09": ["SM_Keyholder", "SM_Paper", "SM_Peana"],
}
## Las que tienen que llamarse exactamente así (SM_Polaroid, la cámara, es de Pack07; SM_PolaroidA..D,
## las fotos, de Pack06: por el principio del nombre se confundirían).
const EXACTAS := {"SM_Polaroid": "Pack07"}
## Piezas que llevan otro color base de su conjunto (T_<x>_BC_<nn>: M_<x>_<nn>). El espejo, con la luna
## vacía (T_Pack08_BC_02); en el primer plano del espejo pasa a la de su conjunto, con ella pintada en la
## luna (Momentos: la marca ReflejoPintado de tools/build_kit_level.gd).
const VARIANTES := {"SM_Mirror": "Pack08_02"}
## Grupo de color provisional según cómo empieza el nombre (el primero que encaja).
const CATEGORIAS := [
	["SM_CeilingSupport", "estructura"], ["CeilingSupport", "estructura"], ["SM_Ceiling", "techo"],
	["SM_Floor", "suelo"], ["FloorPlanks", "suelo"], ["SM_Skirting", "estructura"], ["SB0", "estructura"],
	["SM_Pillar", "estructura"], ["SM_Window", "estructura"], ["SM_Wall", "pared"],
	["SM_Comoda", "comoda"], ["SM_CoverBox", "caja"], ["SM_Box", "caja"], ["SM_TV", "tele"],
	["SM_Burro", "metal"], ["SM_Lamp", "metal"], ["SM_Stool", "madera"], ["SM_Desk", "madera"],
	["SM_MP3", "blanco"], ["SM_Vase", "jarron"], ["SM_Brush", "madera"], ["SM_CoverDesk", "naranja"],
	["SM_PolaroidA", "foto"], ["SM_PolaroidB", "foto"], ["SM_PolaroidC", "foto"], ["SM_PolaroidD", "foto"],
	["SM_Polaroid", "tele"], ["SM_MusicBox", "rosa"], ["SM_Pig", "rosa"], ["SM_Hat", "naranja"],
	["SM_Lights", "luces"], ["SM_Cuerda", "luces"], ["SM_Bombilla", "luces"],
	["SM_LitterBox", "tele"], ["SM_Caballete", "madera"], ["SM_CatBed", "tela"],
	["SM_Rug", "tela"], ["SM_Mirror", "madera"],
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROVISIONAL))
	var kit := _materiales_kit()
	var hechas: Array[String] = []
	var fallos := 0
	var ficheros := PackedStringArray([REFERENCIA]) if ResourceLoader.exists(REFERENCIA) else PackedStringArray()
	ficheros.append_array(_ficheros(KIT + "modelos", MODEL_EXT))
	ficheros.append_array(_ficheros(KIT + "paquetes", MODEL_EXT))
	for path in ficheros:
		if path.get_file() in EXCLUIDOS:
			continue
		var escena := (load(path) as PackedScene).instantiate()
		var piezas := {}                     # nombre -> [MeshInstance3D...] de este fichero
		for m: MeshInstance3D in escena.find_children("*", "MeshInstance3D", true, false):
			if path == REFERENCIA and not String(m.name) in MONTADAS:
				continue
			if SOLO.has(path.get_file()) and not String(m.name) in SOLO[path.get_file()]:
				continue
			var nombre := String(ALIAS.get(String(m.name), String(m.name)))
			if path.get_file() in POR_FICHERO:
				nombre = path.get_file().get_basename()
			for prefijo: String in GRUPOS:
				if nombre.begins_with(prefijo):
					nombre = GRUPOS[prefijo]
			if nombre in REPETIDAS or nombre in hechas:
				continue
			if not piezas.has(nombre):
				piezas[nombre] = []
			piezas[nombre].append(m)
		for nombre: String in piezas:
			var err := _guardar(nombre, piezas[nombre], escena, kit)
			print("PIEZA %-28s %s  err=%d" % [nombre, path.trim_prefix(KIT), err])
			if err == OK:
				hechas.append(nombre)
			else:
				fallos += 1
		escena.free()
	for path in _ficheros(KIT + "dibujos", IMAGE_EXT):
		var nombre := "Dibujo_" + path.get_file().get_basename()
		var err := _guardar_dibujo(nombre, path)
		print("PIEZA %-28s %s  err=%d" % [nombre, path.trim_prefix(KIT), err])
		if err == OK:
			hechas.append(nombre)
		else:
			fallos += 1
	print("PIEZAS %s (%d)" % ["OK" if fallos == 0 else "CON %d FALLOS" % fallos, hechas.size()])
	quit(0 if fallos == 0 else 1)


## Guarda la escena de una pieza: sus mallas (con la transformación que traen en el fichero) dentro
## de un Node3D con el pivote abajo en el centro de la pieza.
func _guardar(nombre: String, mallas: Array, escena: Node, kit: Dictionary) -> Error:
	var raiz := Node3D.new()
	raiz.name = nombre
	var caja := AABB()
	var cuerpo := Vector3.ZERO                   # (la hucha: dónde está su cuerpo, para montar los trozos)
	for src: MeshInstance3D in mallas:
		if src.name == &"SM_PigE":
			cuerpo = _xf_en_fichero(src, escena).origin
	for i in mallas.size():
		var src: MeshInstance3D = mallas[i]
		var m := MeshInstance3D.new()
		m.name = src.name if mallas.size() > 1 else "Malla"
		m.mesh = src.mesh
		m.transform = _xf_en_fichero(src, escena)
		if nombre == "SM_Pig" and HUCHA_MONTADA.has(String(src.name)):
			m.transform.origin = cuerpo + HUCHA_MONTADA[String(src.name)]
		var mat := _material(nombre, kit)
		for s in m.mesh.get_surface_count():
			m.set_surface_override_material(s, mat)
		raiz.add_child(m)
		m.owner = raiz
		var b := m.transform * m.mesh.get_aabb()
		caja = b if i == 0 else caja.merge(b)
	var pivote := Vector3(caja.get_center().x, caja.position.y, caja.get_center().z)
	for m in raiz.get_children():
		(m as Node3D).position -= pivote
	var packed := PackedScene.new()
	var err := packed.pack(raiz)
	if err == OK:
		err = ResourceSaver.save(packed, SALIDA + nombre + ".scn")
	raiz.free()
	return err


## Un dibujo 2D como pieza: un plano de pie (mirando a +z) con su imagen, DIBUJO_ANCHO de ancho y el alto
## de su proporción, con el pivote abajo en el centro; papel mate, con el estilo del kit.
func _guardar_dibujo(nombre: String, imagen: String) -> Error:
	var tex := load(imagen) as Texture2D
	if tex == null:
		return ERR_CANT_OPEN
	var raiz := Node3D.new()
	raiz.name = nombre
	var m := MeshInstance3D.new()
	m.name = "Malla"
	var quad := QuadMesh.new()
	quad.size = Vector2(DIBUJO_ANCHO, DIBUJO_ANCHO * tex.get_height() / float(tex.get_width()))
	m.mesh = quad
	m.position = Vector3(0, quad.size.y * 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.resource_name = nombre
	mat.albedo_texture = tex
	mat.roughness = 0.95
	Estilo.aplicar(mat)
	m.set_surface_override_material(0, mat)
	raiz.add_child(m)
	m.owner = raiz
	var packed := PackedScene.new()
	var err := packed.pack(raiz)
	if err == OK:
		err = ResourceSaver.save(packed, SALIDA + nombre + ".scn")
	raiz.free()
	return err


func _material(nombre: String, kit: Dictionary) -> Material:
	if VARIANTES.has(nombre) and kit.has(VARIANTES[nombre]):
		return kit[VARIANTES[nombre]]
	if EXACTAS.has(nombre):
		if kit.has(EXACTAS[nombre]):
			return kit[EXACTAS[nombre]]
	for conjunto: String in CONJUNTOS:
		for prefijo: String in CONJUNTOS[conjunto]:
			if nombre.begins_with(prefijo) and kit.has(conjunto):
				return kit[conjunto]
	for conjunto: String in kit:
		if nombre.begins_with("SM_" + conjunto):
			return kit[conjunto]
	var grupo := "otro"
	for c: Array in CATEGORIAS:
		if nombre.begins_with(c[0]):
			grupo = c[1]
			break
	var path := PROVISIONAL + grupo + ".tres"
	if not ResourceLoader.exists(path):
		var mat := StandardMaterial3D.new()
		mat.resource_name = "Provisional_" + grupo
		Estilo.pintar(mat, grupo)
		mat.roughness = 0.85
		Estilo.aplicar(mat)
		ResourceSaver.save(mat, path)
	return load(path)


## {"Desk": M_Desk.tres, ...}: los materiales del kit (uno por conjunto de texturas).
func _materiales_kit() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at(KIT + "materiales"):
		if f.begins_with("M_") and f.get_extension() == "tres":
			out[f.get_basename().trim_prefix("M_")] = load(KIT + "materiales/" + f)
	return out


## La transformación de una malla dentro de su fichero (sin árbol: encadenada a mano).
func _xf_en_fichero(m: Node3D, escena: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var p: Node = m
	while p != escena and p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


func _ficheros(dir: String, exts: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_ficheros(dir + "/" + sub, exts))
	for f in d.get_files():
		if f.get_extension().to_lower() in exts:
			out.append(dir + "/" + f)
	return out
