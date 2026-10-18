extends SceneTree
## Estilo "cozy" de todo el kit (pedido del 18-oct: colores menos saturados y con menos contraste, como
## en un juego cozy, y el mismo estilo en todas las piezas). Sin tocar las texturas de las artistas: a cada
## material del kit (los de sus texturas, materiales/M_*.tres, y los provisionales) le pone una capa de
## detalle que mezcla su color con un tono cálido (materiales/estilo/tono.tres) en la proporción de
## materiales/estilo/mezcla.tres (el rojo de su color: 0 = nada, 1 = todo el tono). Eso baja a la vez la
## saturación y el contraste (lo oscuro sube, lo muy vivo se apaga) y suaviza sus normales en la misma
## medida. Además, reflejos más suaves (especular) y los colores provisionales de una paleta apagada (PALETA).
## Para retocar el estilo de todo el kit de golpe: cambiar tono.tres y mezcla.tres en el editor (o TONO y
## MEZCLA aquí y volver a pasar este script). materiales_kit.gd y piezas_kit.gd lo aplican al crear.
##   godot --headless --path . --script res://tools/estilo_kit.gd

const MATERIALES := "res://assets/kit/materiales/"
const PROVISIONAL := MATERIALES + "provisional/"
const TONO_PATH := MATERIALES + "estilo/tono.tres"
const MEZCLA_PATH := MATERIALES + "estilo/mezcla.tres"
const TONO := Color(0.86, 0.77, 0.67)       ## el tono cálido hacia el que se lleva todo (crema tostado)
const MEZCLA := 0.38                         ## cuánto: 0,38 = un 38 % de ese tono en cada color
const ESPECULAR := 0.3                       ## brillo especular (0,5 por defecto): reflejos más suaves
## Colores provisionales (piezas sin texturas todavía): una paleta apagada y cálida, la misma familia.
const PALETA := {
	"suelo": Color(0.78, 0.62, 0.47), "estructura": Color(0.56, 0.42, 0.32), "pared": Color(0.93, 0.87, 0.78),
	"techo": Color(0.66, 0.5, 0.38), "comoda": Color(0.7, 0.78, 0.68), "caja": Color(0.78, 0.64, 0.48),
	"tele": Color(0.66, 0.74, 0.8), "metal": Color(0.8, 0.78, 0.74), "madera": Color(0.8, 0.66, 0.5),
	"blanco": Color(0.93, 0.91, 0.88), "jarron": Color(0.9, 0.79, 0.57), "naranja": Color(0.88, 0.65, 0.47),
	"foto": Color(0.95, 0.93, 0.88), "rosa": Color(0.9, 0.7, 0.71), "tela": Color(0.8, 0.6, 0.54),
	"luces": Color(0.93, 0.9, 0.82), "otro": Color(0.8, 0.78, 0.75),
}


func _init() -> void:
	# pasar este script deja tono.tres y mezcla.tres con TONO y MEZCLA (se cambian en su sitio: los
	# materiales los usan)
	_poner_color(TONO_PATH, TONO)
	_poner_color(MEZCLA_PATH, Color(MEZCLA, MEZCLA, MEZCLA))
	var n := 0
	for dir in [MATERIALES, PROVISIONAL]:
		for f in DirAccess.get_files_at(dir):
			if f.get_extension() != "tres":
				continue
			var m := load(dir + f) as BaseMaterial3D
			if m == null:
				continue
			if dir == PROVISIONAL and PALETA.has(f.get_basename()):
				pintar(m, f.get_basename())
			aplicar(m)
			var err := ResourceSaver.save(m, dir + f)
			print("ESTILO %s err=%d" % [dir + f, err])
			n += 1
	print("ESTILO OK (%d materiales)" % n)
	quit(0)


## El color provisional de un grupo (PALETA). Ninguno brilla: las bombillas de la cuerda, apagadas
## (pedido del 18-oct).
static func pintar(m: BaseMaterial3D, grupo: String) -> void:
	m.albedo_color = PALETA.get(grupo, PALETA["otro"])
	m.emission_enabled = false
	m.emission = Color.BLACK
	m.emission_energy_multiplier = 1.0


## Pone el estilo del kit en un material (y crea tono.tres y mezcla.tres si aún no están).
static func aplicar(m: BaseMaterial3D) -> void:
	m.detail_enabled = true
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.detail_albedo = _textura(TONO_PATH, TONO)
	m.detail_mask = _textura(MEZCLA_PATH, Color(MEZCLA, MEZCLA, MEZCLA))
	m.metallic_specular = ESPECULAR


## Una textura de un solo color (un degradado de un punto: se cambia en el Inspector). Si ya existe, la
## que hay (puede estar retocada a mano).
static func _textura(path: String, color: Color) -> Texture2D:
	if not ResourceLoader.exists(path):
		_poner_color(path, color)
	return load(path)


## Deja la textura de un color en `path` con ese color (la crea si no está).
static func _poner_color(path: String, color: Color) -> void:
	var t: GradientTexture1D = load(path) if ResourceLoader.exists(path) else GradientTexture1D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0])
	g.colors = PackedColorArray([color])
	t.gradient = g
	t.width = 4
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	ResourceSaver.save(t, path)
