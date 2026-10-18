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
## Las piezas se cogen de modelos/ (sueltas, con su nombre bueno) y de paquetes/ (varias por fichero;
## las que llegan con el nombre de 3ds Max se renombran: ALIAS; las que ya están sueltas no se
## repiten: REPETIDAS; las que vienen en trozos colocados entre sí, como el MP3, son una pieza: GRUPOS).
## Ejecutar otra vez si cambia un .fbx del kit o llegan texturas (después de materiales_kit.gd):
##   godot --headless --path . --script res://tools/piezas_kit.gd

const KIT := "res://assets/kit/"
const SALIDA := KIT + "piezas/"
const PROVISIONAL := KIT + "materiales/provisional/"
const MODEL_EXT := ["fbx", "glb", "gltf"]
## Duplicados de piezas que ya están sueltas (las cajas de Boxes.fbx = SM_BoxA..E; la tele de Pack04
## = SM_TV). Las de nombre SM_ repetido se descartan solas (la primera que se encuentra es la buena).
const REPETIDAS := ["Box01", "Box073", "Box074", "Box075", "Box077", "TV01", "TV05"]
## Ficheros que no se usan (Comoda.fbx es la cómoda fundida en una malla: están sus piezas sueltas).
const EXCLUIDOS := ["Comoda.fbx"]
## Nombres buenos para las piezas que llegan con el nombre por defecto de 3ds Max.
const ALIAS := {"Box072": "SM_Burro", "CoverDesk": "SM_CoverDesk", "Vase001": "SM_Vase",
	"Cylinder025": "SM_BrushA", "Cylinder026": "SM_BrushB", "Cylinder027": "SM_BrushC",
	"Object006": "SM_CoverBoxA", "Object007": "SM_CoverBoxB", "Object008": "SM_CoverBoxC",
	"Object009": "SM_CoverBoxD", "Object010": "SM_CoverBoxE"}
## Piezas en trozos (prefijo -> una sola pieza, con sus trozos colocados como en el fichero).
const GRUPOS := {"MP3": "SM_MP3", "Pillar00": "SM_Pillar"}
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
]
const COLORES := {
	"suelo": Color(0.8, 0.62, 0.43), "estructura": Color(0.45, 0.3, 0.2), "pared": Color(0.9, 0.84, 0.74),
	"techo": Color(0.66, 0.47, 0.31), "comoda": Color(0.66, 0.85, 0.74), "caja": Color(0.7, 0.55, 0.38),
	"tele": Color(0.62, 0.76, 0.9), "metal": Color(0.85, 0.85, 0.82), "madera": Color(0.76, 0.6, 0.42),
	"blanco": Color(0.95, 0.95, 0.97), "jarron": Color(0.98, 0.88, 0.58), "naranja": Color(0.95, 0.6, 0.3),
	"otro": Color(0.8, 0.8, 0.8),
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROVISIONAL))
	var kit := _materiales_kit()
	var hechas: Array[String] = []
	var fallos := 0
	for carpeta in ["modelos", "paquetes"]:
		for path in _ficheros(KIT + carpeta, MODEL_EXT):
			if path.get_file() in EXCLUIDOS:
				continue
			var escena := (load(path) as PackedScene).instantiate()
			var piezas := {}                     # nombre -> [MeshInstance3D...] de este fichero
			for m: MeshInstance3D in escena.find_children("*", "MeshInstance3D", true, false):
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
			escena.free()
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
		mat.albedo_color = COLORES[grupo]
		mat.roughness = 0.85
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
