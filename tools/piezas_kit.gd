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
## El MP3 es el de Pack05 (sus trozos, con las UV de T_Pack05); el MP3 montado de la escena de referencia
## es otro modelo con otras UV (con T_Pack05 encima salía la textura rota, 18-oct). Pack05 trae algunos
## trozos separados en Z para texturizar: MP3_JUNTAR los devuelve a su sitio.
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
## trae en trozos: van antes que esos trozos (con su nombre de GRUPOS) y los trozos ya no se usan. Ninguna
## ahora: el MP3 de la referencia no lleva las UV de su textura (se usa el de Pack05).
const REFERENCIA := KIT + "referencia/Blocking3.fbx"   ## la misma que tools/build_diorama_kit.gd
const MONTADAS: Array[String] = []
## Cuánto se mueve cada trozo del MP3 de Pack05 para volver a su sitio (medido en el fichero: la rueda y sus
## letras, centradas en el cuerpo y hundidas en su hueco; las placas de los lados, a caballo de su cara; el
## cable, con la clavija en el cuerpo, todo lo de ese lado separado lo mismo).
const MP3_JUNTAR := {"MP309": Vector3(0, 0, -0.1304), "MP3011": Vector3(0, 0, -0.1304),
	"MP3012": Vector3(0, 0, -0.1304), "MP3013": Vector3(0, 0, -0.1304), "MP3014": Vector3(0, 0, -0.1304),
	"MP302": Vector3(0, 0, -0.1304), "MP307": Vector3(0, 0, -0.1304),
	"MP304": Vector3(0, 0, 0.0672), "MP305": Vector3(0, 0, 0.0672)}
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
## (SM_PigA..L de Pack07: patas, cuerpo, orejas, hocico, corona, cola) va montada en una pieza (HUCHA_COMPO).
const GRUPOS := {"MP3": "SM_MP3", "Pillar00": "SM_Pillar", "SM_Pig": "SM_Pig"}
## El Pack07 del 18-oct por la tarde trae la hucha "explotada" (los trozos separados del cuerpo, para
## pintarla) y sus pegatinas pegadas al cuerpo. La montada es la de las artistas, SM_pig_compo.fbx (18-oct:
## una sola malla con los trozos en su sitio, sin ojos ni pegatinas): cada trozo va donde casan sus
## vértices con los de ella (al milímetro); los ojos, que no están en ella, donde los traía la hucha montada
## de la mañana (OJOS: su origen respecto al del cuerpo); las pegatinas, con el cuerpo, y el arcoíris
## (ARCOIRIS), girado alrededor del cuerpo hasta su costado (venía encima de la oreja). Si llega otra
## montada, basta con dejarla en su sitio y rehacer el tileset.
const HUCHA_COMPO := KIT + "referencia/SM_pig_compo.fbx"
const OJOS := {"SM_PigI": Vector3(0.0621, 0.0248, -0.1640), "SM_PigJ": Vector3(-0.0621, 0.0248, -0.1640)}
const ARCOIRIS := "Plane006"
const ARCOIRIS_GIRO := -51.0                     ## grados alrededor del eje vertical del cuerpo (hacia atrás)
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
	var hucha := _hucha_compo(mallas, escena) if nombre == "SM_Pig" else {}   # (cada trozo, a su sitio)
	var primera := true
	for i in mallas.size():
		var src: MeshInstance3D = mallas[i]
		if nombre == "SM_Pig" and hucha.get(src) == null:
			continue                             # (no casa con la montada)
		var m := MeshInstance3D.new()
		m.name = src.name if mallas.size() > 1 else "Malla"
		m.mesh = src.mesh
		m.transform = hucha[src] if nombre == "SM_Pig" else _xf_en_fichero(src, escena)
		if nombre == "SM_MP3":
			m.transform.origin += MP3_JUNTAR.get(String(src.name), Vector3.ZERO) as Vector3
		var mat := _material(nombre, kit)
		for s in m.mesh.get_surface_count():
			m.set_surface_override_material(s, mat)
		raiz.add_child(m)
		m.owner = raiz
		var b := m.transform * m.mesh.get_aabb()
		caja = b if primera else caja.merge(b)
		primera = false
	var pivote := Vector3(caja.get_center().x, caja.position.y, caja.get_center().z)
	for m in raiz.get_children():
		(m as Node3D).position -= pivote
	var packed := PackedScene.new()
	var err := packed.pack(raiz)
	if err == OK:
		err = ResourceSaver.save(packed, SALIDA + nombre + ".scn")
	raiz.free()
	return err


## Dónde va cada trozo de la hucha (en su fichero) para que quede donde está en la montada de las artistas
## (HUCHA_COMPO): movido con la traslación con la que sus vértices caen sobre los de ella. Los ojos, a OJOS
## del cuerpo; las pegatinas, con el cuerpo (van pegadas a él); el arcoíris, además, girado. null = no casa.
func _hucha_compo(mallas: Array, escena: Node) -> Dictionary:
	var compo: Node = (load(HUCHA_COMPO) as PackedScene).instantiate()
	var montada := compo.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var puntos := _vertices(montada, _xf_en_fichero(montada, compo))
	compo.free()
	var celdas := {}
	for v in puntos:
		celdas[_celda(v)] = true
	var mover := {}
	var cuerpo: MeshInstance3D = null
	for src: MeshInstance3D in mallas:
		if String(src.name).begins_with("SM_Pig") and not OJOS.has(String(src.name)):
			mover[src] = _casar(_vertices(src, _xf_en_fichero(src, escena)), puntos, celdas)
			if src.name == &"SM_PigE":
				cuerpo = src
	var out := {}
	if cuerpo == null or mover[cuerpo] == null:
		return out
	var xf_cuerpo := _xf_en_fichero(cuerpo, escena)
	xf_cuerpo.origin += mover[cuerpo] as Vector3
	var centro := xf_cuerpo * cuerpo.mesh.get_aabb().get_center()
	for src: MeshInstance3D in mallas:
		var xf := _xf_en_fichero(src, escena)
		if OJOS.has(String(src.name)):
			xf.origin = xf_cuerpo.origin + (OJOS[String(src.name)] as Vector3)
		elif mover.has(src):
			if mover[src] == null:
				out[src] = null
				continue
			xf.origin += mover[src] as Vector3
		else:
			xf.origin += mover[cuerpo] as Vector3
			if src.name == StringName(ARCOIRIS):
				xf = _girar_en_cuerpo(xf, src, centro, _vertices(cuerpo, xf_cuerpo))
		out[src] = xf
	return out


## Una pegatina girada ARCOIRIS_GIRO alrededor del eje vertical del cuerpo y llevada a ras de él (el cuerpo
## no es una esfera: donde acaba tiene otro radio que donde estaba).
func _girar_en_cuerpo(xf: Transform3D, m: MeshInstance3D, centro: Vector3, cuerpo: PackedVector3Array) -> Transform3D:
	var antes := (xf * m.mesh.get_aabb().get_center()) - centro
	var giro := Transform3D(Basis(Vector3.UP, deg_to_rad(ARCOIRIS_GIRO)), Vector3.ZERO)
	var nuevo := Transform3D(Basis(), centro) * giro * Transform3D(Basis(), -centro) * xf
	var despues := giro.basis * antes
	var dir := Vector3(despues.x, 0, despues.z).normalized()
	nuevo.origin += dir * (_radio(cuerpo, centro, despues) - _radio(cuerpo, centro, antes))
	return nuevo


## El radio medio del cuerpo en la dirección `d` (los vértices a menos de 12° de ella), en horizontal.
func _radio(cuerpo: PackedVector3Array, centro: Vector3, d: Vector3) -> float:
	var suma := 0.0
	var n := 0
	for v in cuerpo:
		var r := v - centro
		if r.angle_to(d) < deg_to_rad(12.0):
			suma += Vector2(r.x, r.z).length()
			n += 1
	return suma / n if n > 0 else 0.0


func _vertices(m: MeshInstance3D, xf: Transform3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in m.mesh.get_surface_count():
		for v: Vector3 in m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			out.append(xf * v)
	return out


func _celda(v: Vector3) -> Vector3i:
	return Vector3i(roundi(v.x * 500.0), roundi(v.y * 500.0), roundi(v.z * 500.0))   # (de 2 mm)


## La traslación que lleva `trozo` sobre `puntos` (casi todos sus vértices sobre alguno de ellos); null si no.
func _casar(trozo: PackedVector3Array, puntos: PackedVector3Array, celdas: Dictionary) -> Variant:
	var muestra := trozo.slice(0, 40)
	var mejor := 0
	var t := Vector3.ZERO
	for p in puntos:
		var prueba := p - trozo[0]
		var n := 0
		for v in muestra:
			n += 1 if celdas.has(_celda(v + prueba)) else 0
		if n > mejor:
			mejor = n
			t = prueba
	var casan := 0
	for v in trozo:
		casan += 1 if celdas.has(_celda(v + t)) else 0
	return t if casan >= trozo.size() * 0.9 else null


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
