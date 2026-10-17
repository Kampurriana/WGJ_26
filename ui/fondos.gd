class_name Fondos
extends RefCounted
## Los fondos que puede elegir el jugador en Opciones (quinta nota: "darle al jugador la opción de
## cambiar el color y los motivos del fondo"). Un color pastel y un motivo que se repite en diagonal
## (iluminacion/fondo.gdshader). Lo aplica main.gd al fondo de cada escena de luz y ui/creditos.gd
## al de los créditos.
##
## Cada color va dos veces: tal como se ve (centro, borde, forma: los créditos y la muestra de
## Opciones) y ya corregido para el fondo del 3D, que pasa por el tonemap (centro_3d...: valores por
## encima de 1, con HDR 2D). Para añadir o cambiar un color: poner el que se quiere ver y calcular el
## del 3D con tools/calibrar_fondo.gd (no a ojo: trampa 17).

const COLORES := [
	{"nombre": "Azul", "centro": Color8(208, 226, 246), "borde": Color8(180, 204, 236), "forma": Color8(226, 238, 252),
		"centro_3d": Color(0.895, 1.143, 1.584), "borde_3d": Color(0.711, 0.894, 1.318), "forma_3d": Color(1.104, 1.363, 1.823)},
	{"nombre": "Rosa", "centro": Color8(246, 216, 226), "borde": Color8(236, 188, 206), "forma": Color8(252, 234, 240),
		"centro_3d": Color(1.562, 0.994, 1.195), "borde_3d": Color(1.293, 0.751, 0.967), "forma_3d": Color(1.828, 1.269, 1.46)},
	{"nombre": "Menta", "centro": Color8(208, 240, 224), "borde": Color8(178, 226, 204), "forma": Color8(230, 250, 240),
		"centro_3d": Color(0.781, 1.503, 1.16), "borde_3d": Color(0.552, 1.226, 0.943), "forma_3d": Color(1.096, 1.815, 1.455)},
	{"nombre": "Lavanda", "centro": Color8(228, 216, 246), "borde": Color8(206, 190, 236), "forma": Color8(242, 234, 252),
		"centro_3d": Color(1.229, 0.962, 1.588), "borde_3d": Color(0.969, 0.739, 1.32), "forma_3d": Color(1.522, 1.245, 1.843)},
	{"nombre": "Melocotón", "centro": Color8(250, 226, 206), "borde": Color8(242, 202, 174), "forma": Color8(254, 240, 226),
		"centro_3d": Color(1.666, 1.171, 0.849), "borde_3d": Color(1.384, 0.903, 0.647), "forma_3d": Color(1.897, 1.454, 1.086)},
]
## forma: la del shader (0 estrella, 1 círculo, 2 corazón); -1 = sin motivo, solo el color.
const MOTIVOS := [
	{"nombre": "Estrellas", "forma": 0},
	{"nombre": "Corazones", "forma": 2},
	{"nombre": "Lunares", "forma": 1},
	{"nombre": "Liso", "forma": -1},
]
const ALFA_FORMA := 0.35                     ## lo que se nota el motivo (poco: no compite con el diorama)


static func color(i: int) -> Dictionary:
	return COLORES[clampi(i, 0, COLORES.size() - 1)]


static func motivo(i: int) -> Dictionary:
	return MOTIVOS[clampi(i, 0, MOTIVOS.size() - 1)]


## El oscuro de ese fondo (la viñeta y el foco de los momentos, sexta nota: "oscuro pero con la misma
## tonalidad que el fondo"): su mismo tono, más saturado y muy oscuro.
static func dark(i: int) -> Color:
	var c: Color = color(i).borde
	return Color.from_hsv(c.h, maxf(c.s, 0.45), 0.22)


## Pone en el material del fondo el color y el motivo elegidos (índices de COLORES y MOTIVOS: los de
## Settings fondo_color y fondo_motivo). tonemapped = es el fondo del 3D.
static func apply(mat: ShaderMaterial, tonemapped: bool, color_i: int, motivo_i: int) -> void:
	if mat == null:
		return
	var c := color(color_i)
	var m := motivo(motivo_i)
	var suffix := "_3d" if tonemapped else ""
	mat.set_shader_parameter("color_centro", c["centro" + suffix])
	mat.set_shader_parameter("color_borde", c["borde" + suffix])
	var forma: Color = c["forma" + suffix]
	forma.a = ALFA_FORMA if int(m.forma) >= 0 else 0.0
	mat.set_shader_parameter("color_forma", forma)
	mat.set_shader_parameter("forma", maxi(int(m.forma), 0))
