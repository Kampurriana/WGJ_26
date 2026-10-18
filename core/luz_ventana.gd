class_name LuzVentana
extends Node3D
## La luz de una cálida tarde de verano que entra por la ventana del desván (pedido del 18-oct): un
## sol de fuera que solo entra por la ventana (con sombras: las paredes lo paran y el marco se dibuja en
## el suelo), un haz de luz en el aire (shaders/haz_luz.gdshader) y polvo flotando dentro del haz.
## Está apagada hasta que se pone la ventana (la pieza `ventana`) y entonces se enciende despacio.
## Cuelga del nivel (no del modelo) y monta lo suyo un fotograma después del Diorama: así no le cae la
## capa de madera cruda ni hace de superficie para la pieza en mano.

@export var ventana := Vector3(-0.44, 2.08, -1.6)      ## centro de la ventana (por fuera de la pared, en su plano)
@export var tam_ventana := Vector2(1.7, 1.7)            ## ancho y alto del hueco
@export var direccion := Vector3(0.3, -0.8, 1.0)         ## hacia dónde va la luz (hacia dentro y abajo)
@export var color := Color(1.0, 0.74, 0.46)               ## la tarde de verano
@export var energia := 7.0
@export var largo := 3.6                                 ## del cristal al suelo, a lo largo del haz
@export var fuerza_haz := 0.16                           ## luz que suma cada metro de haz (shaders/haz_luz)
@export var pieza := &"ventana"                          ## la que la enciende
@export_range(0.1, 10.0) var segundos_encender := 2.2

var sol: SpotLight3D
var haz: MeshInstance3D
var polvo: CPUParticles3D
var encendida := 0.0                                     ## 0 = apagada, 1 = del todo (tests)
var _mat: ShaderMaterial
var _t := 0.0


func _ready() -> void:
	_build.call_deferred()


func _build() -> void:
	var d := direccion.normalized()
	var look := Basis.looking_at(d, Vector3.UP)             # -Z mira hacia d
	sol = SpotLight3D.new()
	sol.name = "SolTarde"
	sol.position = ventana - d * 4.0
	sol.basis = look
	sol.light_color = color
	sol.light_energy = 0.0
	sol.spot_range = 4.0 + largo + 2.5
	sol.spot_angle = rad_to_deg(atan(tam_ventana.length() * 0.62 / 4.0))
	sol.spot_attenuation = 0.35
	sol.spot_angle_attenuation = 0.6
	sol.shadow_enabled = true
	sol.shadow_bias = 0.04
	sol.shadow_normal_bias = 1.2
	sol.shadow_blur = 1.6
	sol.light_specular = 0.6
	add_child(sol)
	# El haz: el prisma que dibuja el hueco de la ventana al avanzar la luz (un cubo deformado: X e Y
	# = la ventana, Z = a lo largo de la luz), de la ventana hacia el suelo.
	haz = MeshInstance3D.new()
	haz.name = "Haz"
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	haz.mesh = box
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/haz_luz.gdshader")
	_mat.set_shader_parameter("color", color)
	_mat.set_shader_parameter("fuerza", fuerza_haz)
	_mat.set_shader_parameter("aparicion", 0.0)
	_mat.set_shader_parameter("camara", Vector3(0, 0, -3))
	haz.material_override = _mat
	haz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var prisma := Basis(Vector3(tam_ventana.x, 0, 0), Vector3(0, tam_ventana.y, 0), d * largo)
	haz.transform = Transform3D(prisma, ventana + d * largo * 0.5)
	haz.custom_aabb = AABB(Vector3(-0.6, -0.6, -0.6), Vector3(1.2, 1.2, 1.2))
	add_child(haz)
	# El polvo: motas que solo se ven dentro del haz (nacen en él y se apagan al salir).
	polvo = CPUParticles3D.new()
	polvo.name = "PolvoEnLaLuz"
	polvo.amount = 90
	polvo.lifetime = 9.0
	polvo.preprocess = 9.0
	polvo.emitting = false
	polvo.local_coords = true
	polvo.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	polvo.emission_box_extents = Vector3(tam_ventana.x * 0.36, tam_ventana.y * 0.36, largo * 0.42)
	polvo.direction = Vector3.UP
	polvo.spread = 180.0
	polvo.initial_velocity_min = 0.005
	polvo.initial_velocity_max = 0.03
	polvo.gravity = Vector3(0.0, -0.004, 0.0)
	polvo.scale_amount_min = 0.006
	polvo.scale_amount_max = 0.016
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	polvo.color_ramp = ramp
	polvo.color = Color(1.0, 0.86, 0.62, 0.9)
	polvo.transform = Transform3D(Basis.looking_at(-d, Vector3.UP), ventana + d * largo * 0.45)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var dot := StandardMaterial3D.new()
	dot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dot.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dot.billboard_keep_scale = true                      # sin esto, cada mota mide 1 m (un borrón blanco)
	dot.disable_receive_shadows = true
	dot.vertex_color_use_as_albedo = true
	dot.albedo_texture = Efectos._draw("luz")
	quad.material = dot
	polvo.mesh = quad
	polvo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(polvo)
	# El cristal y los marcos de la ventana no hacen sombra: si no, el sol no entraría (las paredes sí).
	var d3 := get_parent()
	if d3 != null:
		for n in d3.find_children("P_%s*" % pieza, "", true, false):
			for m: GeometryInstance3D in n.find_children("*", "GeometryInstance3D", true, false):
				m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	if sol == null:
		return
	_t += delta
	var want := 1.0 if _window_placed() else 0.0
	encendida = move_toward(encendida, want, delta / segundos_encender)
	var e := smoothstep(0.0, 1.0, encendida)
	# Un temblor lentísimo, como si pasara una rama por delante del sol.
	var shimmer := 1.0 + 0.04 * sin(_t * 0.9) * sin(_t * 0.37 + 1.3)
	sol.light_energy = energia * e * shimmer
	sol.visible = e > 0.001
	_mat.set_shader_parameter("aparicion", e * shimmer)
	var cam := get_viewport().get_camera_3d()
	if cam != null and haz.is_inside_tree():
		_mat.set_shader_parameter("camara", haz.global_transform.affine_inverse() * cam.global_position)
		_mat.set_shader_parameter("prisma", haz.global_transform.basis)
	haz.visible = e > 0.001
	polvo.emitting = e > 0.3


func _window_placed() -> bool:
	var d := get_parent() as Diorama
	if d == null:
		return true
	for s in d.slots:
		if s.id == pieza:
			return s.filled
	return true
