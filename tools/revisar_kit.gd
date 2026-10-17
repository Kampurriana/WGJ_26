extends SceneTree
## Revisa el arte importado en assets/kit/ (modelos de las artistas, .fbx/.glb): que cada fichero se
## cargue, y de cada pieza su tamaño (m), triángulos, si tiene UV (sin UV las texturas no se ven) y
## qué material trae. Al final, las texturas con su tamaño. Sirve para ver de un vistazo si un asset
## llega roto, a otra escala o sin UV antes de montarlo en un nivel.
## Ejecutar:
##   godot --headless --path . --script res://tools/revisar_kit.gd

const KIT := "res://assets/kit"
const MODEL_EXT := ["fbx", "glb", "gltf"]
const TEXTURE_EXT := ["png", "jpg", "jpeg", "webp"]


func _init() -> void:
	var fails := 0
	for path in _files(KIT, MODEL_EXT):
		var scene := load(path) as PackedScene
		if scene == null:
			print("ROTO  %s: no se carga" % path)
			fails += 1
			continue
		var root := scene.instantiate() as Node3D
		print("MODELO %s" % path.trim_prefix(KIT + "/"))
		for m in _meshes(root):
			var box := _local_box(m, root)
			var tris := 0
			var uv := true
			var mats := PackedStringArray()
			for s in m.mesh.get_surface_count():
				var arrays := m.mesh.surface_get_arrays(s)
				var idx: Variant = arrays[Mesh.ARRAY_INDEX]
				tris += (idx.size() if idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
				uv = uv and arrays[Mesh.ARRAY_TEX_UV] != null
				var mat := m.get_active_material(s)
				mats.append(mat.resource_name if mat != null and mat.resource_name != "" else ("(sin nombre)" if mat != null else "(ninguno)"))
			print("   %-36s %5.2f x %5.2f x %5.2f m  %6d tri  UV:%s  mat: %s" % [m.name, box.size.x, box.size.y, box.size.z,
				tris, "sí" if uv else "NO", ", ".join(mats)])
			if not uv:
				fails += 1
		root.free()
	for path in _files(KIT, TEXTURE_EXT):
		var tex := load(path) as Texture2D
		print("TEXTURA %-44s %s" % [path.trim_prefix(KIT + "/"), ("%dx%d" % [tex.get_width(), tex.get_height()]) if tex else "NO SE CARGA"])
		if tex == null:
			fails += 1
	print("REVISION %s" % ("OK" if fails == 0 else "CON %d PROBLEMAS" % fails))
	quit(0 if fails == 0 else 1)


func _files(dir: String, exts: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_files(dir + "/" + sub, exts))
	for f in d.get_files():
		if f.get_extension().to_lower() in exts:
			out.append(dir + "/" + f)
	return out


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


## La caja de la pieza en el espacio del modelo (sin árbol: transformaciones encadenadas a mano).
func _local_box(m: MeshInstance3D, root: Node) -> AABB:
	var xf := Transform3D.IDENTITY
	var n: Node = m
	while n != root and n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf * m.get_aabb()
