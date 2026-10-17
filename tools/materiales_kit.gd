extends SceneTree
## Crea un material por cada carpeta de assets/kit/texturas/ (assets/kit/materiales/M_<carpeta>.tres)
## con las texturas que encuentre, según su sufijo (convención de las artistas, la de Unreal):
##   T_<x>_BC      color base
##   T_<x>_ARM     empaquetada: R = oclusión (AO), G = rugosidad, B = metálico
##   T_<x>_Normal  normales (vienen en DirectX: se importa con el verde invertido)
##   T_<x>_E       emisión (opcional)
## y deja la importación de esas texturas como debe (VRAM comprimida y mipmaps: van en 3D; la de
## normales, como normal map). Después hay que reimportar: bash tools/check.sh lo hace.
## Ejecutar:
##   godot --headless --path . --script res://tools/materiales_kit.gd

const TEXTURAS := "res://assets/kit/texturas"
const MATERIALES := "res://assets/kit/materiales"


func _init() -> void:
	var d := DirAccess.open(TEXTURAS)
	if d == null:
		print("MATERIALES: no hay %s" % TEXTURAS)
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATERIALES))
	var hechos := 0
	for carpeta in d.get_directories():
		var tex := _texturas(TEXTURAS + "/" + carpeta)
		if not tex.has("BC"):
			print("MATERIALES: %s no tiene T_*_BC: no hago material" % carpeta)
			continue
		var m := StandardMaterial3D.new()
		m.resource_name = "M_" + carpeta
		m.albedo_texture = load(tex.BC)
		if tex.has("ARM"):
			var arm: Texture2D = load(tex.ARM)
			m.ao_enabled = true
			m.ao_texture = arm
			m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			m.roughness = 1.0
			m.roughness_texture = arm
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			m.metallic = 1.0
			m.metallic_texture = arm
			m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		if tex.has("Normal"):
			m.normal_enabled = true
			m.normal_texture = load(tex.Normal)
		if tex.has("E"):
			m.emission_enabled = true
			m.emission_texture = load(tex.E)
		var out := "%s/M_%s.tres" % [MATERIALES, carpeta]
		var err := ResourceSaver.save(m, out)
		print("MATERIALES: %s (%s) err=%d" % [out, ", ".join(PackedStringArray(tex.keys())), err])
		for rol: String in tex:
			_importar_3d(tex[rol], rol == "Normal")
		hechos += 1
	print("MATERIALES OK (%d)" % hechos)
	quit(0)


## {"BC": ruta, "ARM": ruta, ...} según el sufijo del nombre del fichero.
func _texturas(dir: String) -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() not in ["png", "jpg", "jpeg", "tga", "webp"]:
			continue
		var rol := f.get_basename().get_slice("_", f.get_basename().get_slice_count("_") - 1)
		if rol in ["BC", "ARM", "Normal", "E"]:
			out[rol] = dir + "/" + f
	return out


## Ajusta el .import de una textura: comprimida en VRAM con mipmaps; la de normales, como normal map
## con el verde invertido (DirectX -> OpenGL).
func _importar_3d(path: String, normal: bool) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path + ".import") != OK:
		print("MATERIALES: %s aún no está importada (abre el proyecto o pasa check.sh y repite)" % path)
		return
	cfg.set_value("params", "compress/mode", 2)
	cfg.set_value("params", "mipmaps/generate", true)
	if normal:
		cfg.set_value("params", "compress/normal_map", 1)
		cfg.set_value("params", "process/normal_map_invert_y", true)
	cfg.save(path + ".import")
