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
## Ficheros que no se usan (Comoda.fbx es la cómoda fundida en una malla: están sus piezas sueltas; la
## referencia es una escena entera: de ella solo se cogen las MONTADAS).
const EXCLUIDOS := ["Comoda.fbx"]
## Mallas de la escena de referencia (el blocking de 3ds Max) que son una pieza montada que el kit solo
## trae en trozos: van antes que esos trozos (con su nombre de GRUPOS) y los trozos ya no se usan.
const REFERENCIA := KIT + "referencia/Blocking3.fbx"   ## la misma que tools/build_diorama_kit.gd
const MONTADAS := ["MP3"]
## Nombres buenos para las piezas que llegan con el nombre por defecto de 3ds Max.
const ALIAS := {"Box072": "SM_Burro", "CoverDesk": "SM_CoverDesk", "Vase001": "SM_Vase",
	"Cylinder025": "SM_BrushA", "Cylinder026": "SM_BrushB", "Cylinder027": "SM_BrushC",
	"Object006": "SM_CoverBoxA", "Object007": "SM_CoverBoxB", "Object008": "SM_CoverBoxC",
	"Object009": "SM_CoverBoxD", "Object010": "SM_CoverBoxE"}
## Piezas en trozos (prefijo -> una sola pieza, con sus trozos colocados como en el fichero). La hucha
## (SM_PigA..L de Pack07: patas, cuerpo, orejas, hocico, ojos, ranura, cola) va montada en una pieza.
const GRUPOS := {"MP3": "SM_MP3", "Pillar00": "SM_Pillar", "SM_Pig": "SM_Pig"}
## Piezas que además se parten en dos por sus trozos sueltos (islas de la malla): [la del trozo más
## ancho, la del resto]. SM_Lights es un tramo de cuerda con UNA bombilla (casquillo y cristal): la cuerda
## sola y la bombilla sola sirven para montar cuerdas con bombillas a lo largo (tools/build_diorama_kit.gd).
const PARTIR := {"SM_Lights": ["SM_LightsCuerda", "SM_LightsBombilla"]}
## Qué piezas pinta cada conjunto de texturas (carpeta de assets/kit/texturas/ = de TexturasFinales):
## por cómo empieza su nombre. Son las carpetas de Assets/ de Drive: Pack01 (suelo, zócalos, correas,
## pilar; las de nombre de 3ds Max de FloorCeilingPlanks... son las mismas), Pack02 (techo y postes).
## Pack03 (paredes, ventana, zócalos de arriba) y Pack04/05 aún no tienen texturas.
const CONJUNTOS := {
	"Desk": ["SM_Desk"],
	"Boxes": ["SM_Box", "SM_CoverBox"],
	"LampStool": ["SM_Lamp", "SM_Stool"],
	"Pack01": ["SM_Floor", "FloorPlanks", "SM_SkirtingBoardBottom", "SB0", "CeilingSupport0", "SM_Pillar"],
	"Pack_02": ["SM_Ceiling"],
}
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
	["SM_Lights", "luces"], ["SM_LitterBox", "tele"], ["SM_Caballete", "madera"], ["SM_CatBed", "tela"],
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
			var nombre := String(ALIAS.get(String(m.name), String(m.name)))
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
			if PARTIR.has(nombre) and piezas[nombre].size() == 1:
				var partes := _partir(piezas[nombre][0])
				for k in 2:
					var parte: String = PARTIR[nombre][k]
					err = _guardar(parte, [partes[k]], escena, kit)
					print("PIEZA %-28s %s (de %s)  err=%d" % [parte, path.trim_prefix(KIT), nombre, err])
					if err == OK:
						hechas.append(parte)
					else:
						fallos += 1
					partes[k].free()
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
	for i in mallas.size():
		var src: MeshInstance3D = mallas[i]
		var m := MeshInstance3D.new()
		m.name = src.name if mallas.size() > 1 else "Malla"
		m.mesh = src.mesh
		m.transform = _xf_en_fichero(src, escena)
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


## Parte la malla de `m` por sus trozos sueltos (triángulos unidos por vértices en la misma posición):
## [el trozo más ancho en x, todos los demás juntos], cada uno en un MeshInstance3D con la transformación de
## `m` y colgado de su mismo padre (para que su transformación en el fichero sea la misma; se liberan después).
func _partir(m: MeshInstance3D) -> Array[MeshInstance3D]:
	var arr := m.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var punto := PackedInt32Array()          # vértice -> su posición (los repetidos por normales, uno)
	var posiciones := {}
	for p in v:
		var q := Vector3i((p * 10000.0).round())
		if not posiciones.has(q):
			posiciones[q] = posiciones.size()
		punto.append(posiciones[q])
	var padre := range(posiciones.size())
	var raiz := func(a: int) -> int:
		while padre[a] != a:
			a = padre[a]
		return a
	for t in range(0, idx.size(), 3):
		for k in 2:
			padre[raiz.call(punto[idx[t + k]])] = raiz.call(punto[idx[t + k + 1]])
	var islas := {}                          # raíz -> [triángulos]
	for t in range(0, idx.size(), 3):
		var r: int = raiz.call(punto[idx[t]])
		if not islas.has(r):
			islas[r] = PackedInt32Array()
		islas[r].append(t / 3)
	var ancha: Variant = null
	var ancho := -1.0
	for r: int in islas:
		var x0 := INF
		var x1 := -INF
		for t: int in islas[r]:
			for k in 3:
				x0 = minf(x0, v[idx[t * 3 + k]].x)
				x1 = maxf(x1, v[idx[t * 3 + k]].x)
		if x1 - x0 > ancho:
			ancho = x1 - x0
			ancha = r
	var resto := PackedInt32Array()
	for r: int in islas:
		if r != ancha:
			resto.append_array(islas[r])
	var out: Array[MeshInstance3D] = []
	for tris: PackedInt32Array in [islas[ancha], resto]:
		var parte := MeshInstance3D.new()
		parte.mesh = _submalla(arr, tris)
		parte.transform = m.transform
		m.get_parent().add_child(parte)
		out.append(parte)
	return out


## Una malla con solo los triángulos `tris` de una superficie (sus arrays), con sus vértices renumerados.
func _submalla(arr: Array, tris: PackedInt32Array) -> ArrayMesh:
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var nv := (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var nuevo := {}
	var orden := PackedInt32Array()
	var idx2 := PackedInt32Array()
	for t in tris:
		for k in 3:
			var i := idx[t * 3 + k]
			if not nuevo.has(i):
				nuevo[i] = orden.size()
				orden.append(i)
			idx2.append(nuevo[i])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for a in Mesh.ARRAY_MAX:
		var src: Variant = arr[a]
		if src == null or a == Mesh.ARRAY_INDEX or a >= Mesh.ARRAY_BONES:
			continue
		var dst: Variant = src.duplicate()
		dst.resize(0)
		var paso: int = src.size() / nv        # tangentes: 4 números por vértice
		for i in orden:
			for k in paso:
				dst.append(src[i * paso + k])
		out[a] = dst
	out[Mesh.ARRAY_INDEX] = idx2
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return malla


func _material(nombre: String, kit: Dictionary) -> Material:
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
