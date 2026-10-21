class_name Fondos
extends RefCounted
## Los fondos que puede elegir el jugador en Opciones (quinta nota: "darle al jugador la opción de
## cambiar el color y los motivos del fondo"). Un color pastel y un motivo que se repite en diagonal
## (iluminacion/fondo.gdshader). Lo aplica main.gd al fondo de cada escena de luz y ui/creditos.gd
## al de los créditos.
##
## Cada color va como se ve (centro, borde, forma: los créditos y la muestra de Opciones). El fondo del 3D
## pasa por el tonemap, el resplandor y los ajustes de su luz y por el postproceso de cine (que dora las
## luces): lo que hay que meterle para que se vea igual (valores por encima de 1, con HDR 2D) está medido
## por escena de luz en data/fondo_calibrado.json, que escribe tools/calibrar_fondo.gd (no a ojo:
## trampas 17 y 54). Al cambiar o añadir un color, o tocar una luz o el postproceso, volver a correrlo.

const COLORES := [
	{"nombre": "Azul", "centro": Color8(208, 226, 246), "borde": Color8(180, 204, 236), "forma": Color8(226, 238, 252)},
	{"nombre": "Rosa", "centro": Color8(246, 216, 226), "borde": Color8(236, 188, 206), "forma": Color8(252, 234, 240)},
	{"nombre": "Menta", "centro": Color8(208, 240, 224), "borde": Color8(178, 226, 204), "forma": Color8(230, 250, 240)},
	{"nombre": "Lavanda", "centro": Color8(228, 216, 246), "borde": Color8(206, 190, 236), "forma": Color8(242, 234, 252)},
	{"nombre": "Melocotón", "centro": Color8(250, 226, 206), "borde": Color8(242, 202, 174), "forma": Color8(254, 240, 226)},
]
## forma: la del shader (0 estrella, 1 círculo, 2 corazón); -1 = sin motivo, solo el color.
const MOTIVOS := [
	{"nombre": "Estrellas", "forma": 0},
	{"nombre": "Corazones", "forma": 2},
	{"nombre": "Lunares", "forma": 1},
	{"nombre": "Liso", "forma": -1},
]
const ALFA_FORMA := 0.35                     ## lo que se nota el motivo (poco: no compite con el diorama)
const CALIBRATED := "res://data/fondo_calibrado.json"
const DEFAULT_LIGHT := "luz_por_defecto"

static var _calibrated: Dictionary = {}


static func color(i: int) -> Dictionary:
	return COLORES[clampi(i, 0, COLORES.size() - 1)]


static func motivo(i: int) -> Dictionary:
	return MOTIVOS[clampi(i, 0, MOTIVOS.size() - 1)]


## El oscuro de ese fondo (la viñeta y el foco de los momentos, sexta nota: "oscuro pero con la misma
## tonalidad que el fondo"): su mismo tono, más saturado y muy oscuro.
static func dark(i: int) -> Color:
	var c: Color = color(i).borde
	return Color.from_hsv(c.h, maxf(c.s, 0.45), 0.22)


## Lo que hay que meter en el fondo del 3D con la escena de luz `light` (su nombre: "desvan_tarde") para
## que se vea el color i: {centro, borde, forma}. Sin calibrado para esa luz, el de la luz por defecto; sin
## ninguno, el color tal cual.
static func calibrated(i: int, light: String) -> Dictionary:
	if _calibrated.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CALIBRATED))
		_calibrated = data if data is Dictionary else {"": []}
	var table: Array = _calibrated.get(light, _calibrated.get(DEFAULT_LIGHT, []))
	var c := color(i)
	if i < 0 or i >= table.size():
		return {"centro": c.centro, "borde": c.borde, "forma": c.forma}
	var out := {}
	for key: String in ["centro", "borde", "forma"]:
		var v: Array = table[i][key]
		out[key] = Color(float(v[0]), float(v[1]), float(v[2]))
	return out


## Pone en el material del fondo el color y el motivo elegidos (índices de COLORES y MOTIVOS: los de
## Settings fondo_color y fondo_motivo). light = la escena de luz del fondo del 3D ("" = no es del 3D: los
## créditos, que no pasan por el tonemap ni el postproceso).
static func apply(mat: ShaderMaterial, light: String, color_i: int, motivo_i: int) -> void:
	if mat == null:
		return
	var c := color(color_i) if light == "" else calibrated(color_i, light)
	var m := motivo(motivo_i)
	mat.set_shader_parameter("color_centro", c.centro)
	mat.set_shader_parameter("color_borde", c.borde)
	var forma: Color = c.forma
	forma.a = ALFA_FORMA if int(m.forma) >= 0 else 0.0
	mat.set_shader_parameter("color_forma", forma)
	mat.set_shader_parameter("forma", maxi(int(m.forma), 0))
