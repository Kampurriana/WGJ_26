class_name Efectos
extends Node3D
## Partículas del juego. Todas son CPUParticles3D (funcionan igual en el navegador). Escucha a
## Events y no lo llama nadie:
##   empieza un nivel  -> polvo en suspensión alrededor del diorama, que brilla en la luz
##   encaja una pieza  -> serrín que salta, chispas que suben y un anillo que se abre en el suelo
##   se recoge una H_  -> un soplo de polvo
##   pista             -> chispas alrededor del sitio
##   diorama completo  -> lluvia de chispas y hojas de colores
## Texturas: si existe assets/texturas/particulas/<polvo|chispa|hoja|viruta>.png se usa esa (así
## las artistas las cambian sin tocar código); si no, se dibujan aquí.

const TEXTURE_DIR := "res://assets/texturas/particulas/"
const DUST_COLOR := Color(1.0, 0.86, 0.62, 0.55)
const SAWDUST_COLOR := Color(0.86, 0.68, 0.46)
const SPARK_COLOR := Color(1.0, 0.85, 0.55)
const CONFETTI := [Color(0.98, 0.78, 0.35), Color(0.95, 0.5, 0.35), Color(0.55, 0.78, 0.4),
	Color(0.98, 0.93, 0.8), Color(0.85, 0.45, 0.55)]

var dust: CPUParticles3D                     ## (tests) el polvo del nivel actual
var bursts := 0                              ## (tests) ráfagas lanzadas en este nivel

var _textures: Dictionary = {}
var _ring_shader := preload("res://shaders/anillo.gdshader")


func _ready() -> void:
	Events.level_started.connect(_on_level_started)
	Events.piece_placed.connect(func(_id: StringName, n: Node3D) -> void: placed_at(Visuals.global_aabb(n)))
	Events.piece_collected.connect(func(_id: StringName, n: Node3D) -> void: _puff(Visuals.global_aabb(n)))
	Events.hint_shown.connect(func(n: Node3D) -> void: _hint(Visuals.global_aabb(n)))
	Events.level_completed.connect(func(d: Node) -> void: _celebrate(Visuals.global_aabb(d as Node3D)))


func _on_level_started(d: Node) -> void:
	for c in get_children():
		c.queue_free()
	bursts = 0
	var box := Visuals.global_aabb(d as Node3D)
	dust = _dust(box)


# --- Polvo en suspensión ------------------------------------------------------------------

func _dust(box: AABB) -> CPUParticles3D:
	var p := _particles("Polvo", 0, _texture("polvo"), true)
	var size := box.size.length()
	p.amount = clampi(int(size * 14.0), 30, 120)
	p.lifetime = 8.0
	p.preprocess = 8.0                       # ya hay polvo flotando al empezar
	p.randomness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(box.size.x * 0.55, box.size.y * 0.5, box.size.z * 0.55)
	p.position = box.get_center() + Vector3.UP * box.size.y * 0.15
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.01
	p.initial_velocity_max = 0.05
	p.gravity = Vector3(0.0, 0.012, 0.0)
	p.damping_min = 0.0
	p.damping_max = 0.01
	var dot := clampf(size * 0.006, 0.012, 0.035)
	p.scale_amount_min = dot * 0.6
	p.scale_amount_max = dot * 1.5
	p.color = DUST_COLOR
	p.color_ramp = _fade(0.25, 0.7)
	return p


# --- Encaje: serrín, chispas y anillo ----------------------------------------------------------

## Ráfaga de encaje para una pieza cuya caja es `box` (público: lo usan también las capturas).
func placed_at(box: AABB) -> void:
	bursts += 1
	var s := clampf(box.size.length(), 0.15, 1.6)
	var base := Vector3(box.get_center().x, box.position.y + 0.02, box.get_center().z)
	var saw := _particles("Serrin", 18, _texture("viruta"), false)
	saw.position = base
	saw.one_shot = true
	saw.explosiveness = 0.95
	saw.lifetime = 0.9
	saw.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	saw.emission_ring_axis = Vector3.UP
	saw.emission_ring_radius = s * 0.35
	saw.emission_ring_inner_radius = s * 0.2
	saw.emission_ring_height = 0.0
	saw.direction = Vector3.UP
	saw.spread = 60.0
	saw.initial_velocity_min = 0.9 * s
	saw.initial_velocity_max = 1.7 * s
	saw.gravity = Vector3(0.0, -5.0 * s, 0.0)
	saw.angle_min = 0.0
	saw.angle_max = 360.0
	saw.angular_velocity_min = -360.0
	saw.angular_velocity_max = 360.0
	saw.scale_amount_min = 0.025 * s
	saw.scale_amount_max = 0.055 * s
	saw.color = SAWDUST_COLOR
	saw.color_ramp = _fade(0.0, 0.6)
	saw.emitting = true
	_free_later(saw)
	var sparks := _particles("Chispas", 12, _texture("chispa"), true)
	sparks.position = base + Vector3.UP * box.size.y * 0.4
	sparks.one_shot = true
	sparks.explosiveness = 0.8
	sparks.lifetime = 1.3
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = s * 0.4
	sparks.direction = Vector3.UP
	sparks.spread = 35.0
	sparks.initial_velocity_min = 0.2 * s
	sparks.initial_velocity_max = 0.6 * s
	sparks.gravity = Vector3(0.0, 0.25 * s, 0.0)
	sparks.damping_min = 0.3
	sparks.damping_max = 0.6
	sparks.scale_amount_min = 0.05 * s
	sparks.scale_amount_max = 0.11 * s
	sparks.color = SPARK_COLOR
	sparks.color_ramp = _fade(0.05, 0.5)
	sparks.emitting = true
	_free_later(sparks)
	_ring(base, s)


func _ring(at: Vector3, s: float) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "Anillo"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	ring.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = _ring_shader
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = at
	ring.scale = Vector3.ONE * s * 0.3
	add_child(ring)
	var tw := ring.create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "scale", Vector3.ONE * s * 1.15, 0.55)
	tw.tween_method(func(f: float) -> void: mat.set_shader_parameter("fuerza", f), 1.0, 0.0, 0.55)
	tw.chain().tween_callback(ring.queue_free)


# --- Recoger, pista y final --------------------------------------------------------------------

func _puff(box: AABB) -> void:
	bursts += 1
	var s := clampf(box.size.length(), 0.15, 1.2)
	var p := _particles("Soplo", 16, _texture("polvo"), false)
	p.position = box.get_center()
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = s * 0.3
	p.spread = 180.0
	p.initial_velocity_min = 0.3 * s
	p.initial_velocity_max = 0.8 * s
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.12 * s
	p.scale_amount_max = 0.25 * s
	p.color = Color(1.0, 0.95, 0.85, 0.7)
	p.color_ramp = _fade(0.05, 0.4)
	p.emitting = true
	_free_later(p)


func _hint(box: AABB) -> void:
	bursts += 1
	var s := clampf(box.size.length(), 0.2, 1.5)
	var p := _particles("ChispasPista", 24, _texture("chispa"), true)
	p.position = box.get_center()
	p.lifetime = 1.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = s * 0.6
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.3
	p.scale_amount_min = 0.05 * s
	p.scale_amount_max = 0.09 * s
	p.color = Color(1.0, 0.95, 0.75)
	p.color_ramp = _fade(0.2, 0.6)
	p.emitting = true
	get_tree().create_timer(2.5, false).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.emitting = false)
	_free_later(p, 4.0)


func _celebrate(box: AABB) -> void:
	bursts += 1
	var top := Vector3(box.get_center().x, box.end.y + box.size.y * 0.2, box.get_center().z)
	var spread := Vector3(box.size.x * 0.45, 0.05, box.size.z * 0.45)
	var leaves := _particles("Hojas", 70, _texture("hoja"), false)
	leaves.position = top
	leaves.one_shot = true
	leaves.explosiveness = 0.25
	leaves.lifetime = 4.0
	leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	leaves.emission_box_extents = spread
	leaves.direction = Vector3.UP
	leaves.spread = 50.0
	leaves.initial_velocity_min = 0.6
	leaves.initial_velocity_max = 1.4
	leaves.gravity = Vector3(0.0, -0.7, 0.0)
	leaves.damping_min = 0.4
	leaves.damping_max = 0.8
	leaves.angle_min = 0.0
	leaves.angle_max = 360.0
	leaves.angular_velocity_min = -180.0
	leaves.angular_velocity_max = 180.0
	var leaf := clampf(box.size.length() * 0.02, 0.04, 0.09)
	leaves.scale_amount_min = leaf * 0.7
	leaves.scale_amount_max = leaf * 1.3
	leaves.color_initial_ramp = _palette(CONFETTI)
	leaves.color_ramp = _fade(0.05, 0.75)
	leaves.emitting = true
	_free_later(leaves)
	var sparks := _particles("ChispasFinal", 60, _texture("chispa"), true)
	sparks.position = box.get_center()
	sparks.one_shot = true
	sparks.explosiveness = 0.4
	sparks.lifetime = 2.5
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparks.emission_box_extents = box.size * 0.5
	sparks.direction = Vector3.UP
	sparks.spread = 30.0
	sparks.initial_velocity_min = 0.2
	sparks.initial_velocity_max = 0.7
	sparks.gravity = Vector3(0.0, 0.15, 0.0)
	sparks.scale_amount_min = leaf * 0.8
	sparks.scale_amount_max = leaf * 1.8
	sparks.color = SPARK_COLOR
	sparks.color_ramp = _fade(0.1, 0.5)
	sparks.emitting = true
	_free_later(sparks)


# --- Piezas ----------------------------------------------------------------------------------

## Un emisor con su cuadrado mirando a cámara. glow = se suma a lo de detrás (brilla en lo oscuro).
func _particles(n: String, amount: int, tex: Texture2D, glow: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = n
	if amount > 0:
		p.amount = amount
	p.local_coords = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if glow else BaseMaterial3D.BLEND_MODE_MIX
	mat.albedo_texture = tex
	mat.disable_receive_shadows = true
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _free_later(p: Node, extra := 0.5) -> void:
	var life := (p as CPUParticles3D).lifetime if p is CPUParticles3D else 1.0
	get_tree().create_timer(life + extra, false).timeout.connect(p.queue_free)


## Opacidad a lo largo de la vida: aparece en `fade_in`, empieza a irse en `fade_out` (0-1).
static func _fade(fade_in: float, fade_out: float) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(maxf(fade_in, 0.001), Color(1, 1, 1, 1))
	g.add_point(clampf(fade_out, fade_in + 0.01, 0.999), Color(1, 1, 1, 1))
	return g


## Un color al azar de la lista para cada partícula (escalones, sin mezclas).
static func _palette(colors: Array) -> Gradient:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.set_offset(0, 0.0)
	g.set_color(0, colors[0])
	g.set_offset(1, 1.0)
	g.set_color(1, colors[-1])
	for i in range(1, colors.size()):
		g.add_point(float(i) / colors.size(), colors[i])
	return g


func _texture(n: String) -> Texture2D:
	if _textures.has(n):
		return _textures[n]
	var path := TEXTURE_DIR + n + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else _draw(n)
	_textures[n] = tex
	return tex


## Texturas de recambio dibujadas en código (blancas: el color lo pone cada emisor).
static func _draw(n: String) -> Texture2D:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5) / size * 2.0 - Vector2.ONE   # -1..1
			var a := 0.0
			match n:
				"chispa":                    # estrella de cuatro puntas con centro suave
					var core := clampf(1.0 - p.length() * 2.2, 0.0, 1.0)
					var rays := maxf(clampf(1.0 - absf(p.x) * 12.0, 0.0, 1.0) * (1.0 - absf(p.y)),
						clampf(1.0 - absf(p.y) * 12.0, 0.0, 1.0) * (1.0 - absf(p.x)))
					a = clampf(core * core + rays, 0.0, 1.0)
				"hoja":                      # lente puntiaguda con nervio
					var w := (1.0 - p.x * p.x) * 0.5
					a = clampf((w - absf(p.y)) * 20.0, 0.0, 1.0) * (0.75 if absf(p.y) < 0.04 else 1.0)
				"viruta":                    # astilla: rectángulo de bordes suaves
					a = clampf((0.8 - absf(p.x)) * 8.0, 0.0, 1.0) * clampf((0.45 - absf(p.y)) * 8.0, 0.0, 1.0)
				_:                           # polvo: punto suave
					a = pow(clampf(1.0 - p.length(), 0.0, 1.0), 1.6)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
