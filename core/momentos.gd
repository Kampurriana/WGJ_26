class_name Momentos
extends Node
## Las secuencias de la historia ("momentos"), en los dioramas con `momentos = true` (el desván).
## Al colocar un objeto con frase (pieza_<id> en narracion_es.json): la cámara avanza despacio hacia
## él desde donde miraba el jugador (los objetos planos de pared, como el dibujo, se ven de frente),
## lo que se cruce por delante se desvanece, entran dos bandas negras de cine y un foco, el enfoque
## se va al objeto y suena su frase. El objeto se queda QUIETO (cuarta nota: sin gestos) y la cámara
## deja de respirar. La bandeja y los botones se apartan; un clic pasa a la siguiente frase. Al
## callarse, todo vuelve.
## Dos momentos especiales, por nombre en el modelo (core/name_rules.gd):
##   __reflejo  (el espejo): la cámara se pone delante, todo lo demás se va a negro y en la luna
##              aparece una silueta que se desvanece con la última frase ("¿Dónde estoy yo?").
##   __ofrecida (la moneda): el final. Si viene del espejo, primero una transición (el espejo vacío
##              en silencio y un fundido lento a negro); luego, corte a un primer plano ligeramente
##              cenital de lo que la sostiene (la hucha), SOLA y quieta, en una escena acogedora: luz
##              cálida de lámpara que parpadea un pelín, un contraluz, motas de polvo y, detrás, un
##              fondo cálido con luces desenfocadas (shaders/acogedor.gdshader). Sexta nota, en orden:
##              1) sus frases (un clic pasa a la siguiente); 2) en cuanto se callan, la moneda aparece a
##              su lado, quieta y con un destello, y una moneda FANTASMA (shaders/fantasma.gdshader)
##              enseña en bucle el gesto de meterla en la ranura; 3) el jugador la coge (el bucle se
##              para) y la ARRASTRA hasta la ranura (cerca, la ranura la atrae): entra con un golpe de
##              luz y chispas doradas. Después, fundido a negro y créditos (main.gd).

const MIN_TIME := 2.0                        ## un momento dura al menos esto (s)
const IRIS := 0.7                            ## lo oscuro alrededor del objeto en un momento normal
const IRIS_SOFT := 1.9                       ## sexta nota: el foco, muy degradado; llega a 1 + esto veces el radio...
const IRIS_INSIDE := 0.45                    ## ...y empieza a oscurecer ya dentro (fracción del radio): sin borde
const COZY_DARK := Color(0.16, 0.08, 0.04)   ## (ofrecida) el oscuro del foco: el tono del fondo cálido
const BARS := 54.0                           ## alto de las bandas de cine (px a 720)
const FADE := 0.9
const CUT_TIME := 0.45                       ## (ofrecida) fundido a negro antes del corte, y vuelta
const ZENITH := 38.0                         ## (ofrecida) inclinación del primer plano de la hucha
const ENDING_YAW := 22.0                     ## (ofrecida) giro sobre la vista del nivel: tres cuartos, se le ve la cara
const ENDING_MARGIN := 3.2                   ## (ofrecida) la hucha y su sitio (la moneda y su fantasma alrededor)
const ISOLATE_LAYER := 20                    ## capa de render de lo aislado (el resto no se ve)
const MIRROR_TIME := 2.6                     ## (espejo) el zoom hasta tenerlo de frente y el fundido a negro de lo demás (s)
const MIRROR_SMOOTH := 1.1                   ## (espejo) un zoom blando, sin tirón
const MIRROR_MARGIN := 1.3                   ## (espejo) el espejo entero, con su marco, llena así la pantalla
const MIRROR_GROW := 1.06                    ## (espejo) el hueco del negro, ceñido al espejo entero (lo de alrededor se va)
const MIRROR_REVEAL := 2.0                   ## (espejo) la luna vacía se funde en la de ella pintada (s)
const MIRROR_REVEAL_DELAY := 0.3             ## (espejo) un momento con la luna vacía antes de empezar
const COIN_GRAB_PX := 70.0                   ## lo cerca que hay que coger la moneda
const COIN_SNAP_PX := 80.0                   ## y lo cerca de la ranura que hay que soltarla
const HIDE_TIME := 0.35                      ## lo que tarda en desvanecerse lo que tapa el plano
const TRANSITION_HOLD := 1.4                 ## (espejo → final) el espejo vacío, en silencio...
const TRANSITION_FADE := 1.8                 ## ...y el fundido lento a negro (s)
const CUT_IN := 1.8                          ## (ofrecida) lo que tarda en verse la escena tras el corte
const GHOST_TIME := 1.5                      ## (ofrecida) la moneda fantasma va de la moneda a la ranura en esto...
const GHOST_REST := 0.7                      ## ...y espera esto antes de repetirlo (s)
const GHOST_ALPHA := 0.9                     ## lo que se ve la fantasma (es una pista, no la moneda)
const COIN_SCALE := 1.15                     ## la moneda que espera, un poco más grande (se lee mejor)
const COIN_MAGNET := 1.8                     ## la ranura atrae la moneda desde COIN_SNAP_PX × esto
const COZY_IRIS := 0.3                       ## (ofrecida) poco foco: el fondo cálido tiene que verse

var active := false
var kind := ""                               ## "" / "normal" / "reflejo" / "transicion" / "ofrecida"
var target: Node3D                           ## el objeto del momento
var coin: Node3D                             ## (ofrecida) la pieza flotando, lista para arrastrarla
var ghost: Node3D                            ## (ofrecida) su fantasma, que enseña en bucle cómo meterla (null = parado)
var reflection: Node3D                       ## (reflejo) vaho en la luna + la silueta de ella + su luz
var hidden_for_shot: Array = []              ## lo que tapaba el plano (GeometryInstance3D escondidos mientras dura)
var _figure: Sprite3D                        ## la silueta (aparece con la primera frase, se va con la última)
var _spot: SpotLight3D                       ## (ofrecida) la luz de arriba sobre la hucha sola
var _rim: OmniLight3D                        ## (ofrecida) contraluz cálido detrás de la hucha
var _motes: CPUParticles3D                   ## (ofrecida) motas de polvo en la luz
var _spot_energy := 0.0                      ## (ofrecida) la del foco (parpadea un pelín, como una lámpara vieja)
var _cozy: ColorRect                         ## (ofrecida) fondo acogedor detrás del 3D
var _cozy_mat: ShaderMaterial
var _cozy_tween: Tween
var _textures: Dictionary = {}               ## texturas de partículas (las de Efectos)
var _bloom: TextureRect                      ## (ofrecida) destello cálido en pantalla cuando entra la moneda

var _layer: CanvasLayer
var _iris: ColorRect
var _black: ColorRect                        ## (reflejo) fondo negro de verdad detrás del 3D
var _curtain: ColorRect                      ## (ofrecida) fundido a negro del corte
var _iris_mat: ShaderMaterial
var _bars: Array[ColorRect] = []
var _prompt: Label
var _elapsed := 0.0
var _iris_tween: Tween
var _t := 0.0
var _offered: PieceSlot
var _isolated: Dictionary = {}               ## VisualInstance3D -> capas de antes
var _lines_seen := 0
var _coin_rest := Vector3.ZERO               ## dónde flota la moneda cuando no se arrastra
var _coin_state := ""                        ## "" flotando · "arrastrando" · "volviendo" · "entrando"
var _shot_ready := false                     ## (ofrecida) ya se ha hecho el corte a la hucha
var _ghost_mat: ShaderMaterial
var _ghost_tween: Tween


func _ready() -> void:
	Events.act_continued.connect(func() -> void:
		if active and kind == "normal":
			finish())
	_layer = CanvasLayer.new()
	_layer.layer = 1                         # encima del enfoque (0) y por debajo de la interfaz (2)
	add_child(_layer)
	var back := CanvasLayer.new()
	back.layer = -5                          # parte del fondo (background_canvas_max_layer = -1), sobre el degradado
	add_child(back)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(_black)
	var cozy_layer := CanvasLayer.new()
	cozy_layer.layer = -4                    # también fondo, encima del negro
	add_child(cozy_layer)
	_cozy = ColorRect.new()
	_cozy.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cozy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cozy_mat = ShaderMaterial.new()
	_cozy_mat.shader = preload("res://shaders/acogedor.gdshader")
	_cozy_mat.set_shader_parameter("alpha", 0.0)
	_cozy_mat.set_shader_parameter("brillo", 1.0)
	_cozy.material = _cozy_mat
	_cozy.hide()
	cozy_layer.add_child(_cozy)
	_iris = ColorRect.new()
	_iris.set_anchors_preset(Control.PRESET_FULL_RECT)
	_iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_iris_mat = ShaderMaterial.new()
	_iris_mat.shader = preload("res://shaders/foco.gdshader")
	_iris_mat.set_shader_parameter("fuerza", 0.0)
	_iris_mat.set_shader_parameter("suave", IRIS_SOFT)
	_iris_mat.set_shader_parameter("dentro", IRIS_INSIDE)
	_iris_mat.set_shader_parameter("color", Color.BLACK)
	_iris.material = _iris_mat
	_layer.add_child(_iris)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.offset_top = 0.0
		bar.offset_bottom = 0.0
		_layer.add_child(bar)
		_bars.append(bar)
	_curtain = ColorRect.new()
	_curtain.color = Color(0, 0, 0, 0)
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_curtain)
	_bloom = TextureRect.new()
	_bloom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloom.size = Vector2(560, 560)
	_bloom.pivot_offset = _bloom.size * 0.5
	var glow_grad := Gradient.new()
	glow_grad.set_color(0, Color(1.0, 0.82, 0.5, 1.0))
	glow_grad.set_color(1, Color(1.0, 0.6, 0.25, 0.0))
	var glow_tex := GradientTexture2D.new()
	glow_tex.gradient = glow_grad
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(0.5, 0.0)
	_bloom.texture = glow_tex
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_bloom.material = add
	_bloom.modulate.a = 0.0
	_bloom.hide()
	_layer.add_child(_bloom)
	_prompt = Label.new()
	_prompt.text = "clic para seguir  ›"
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.offset_right = -24
	_prompt.offset_bottom = -14
	_prompt.add_theme_font_size_override("font_size", 16)
	_prompt.add_theme_color_override("font_color", Color(UiTheme.CREAM, 0.75))
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.modulate.a = 0.0
	_layer.add_child(_prompt)
	Events.level_started.connect(func(_d: Node) -> void: reset())
	Events.piece_placed.connect(_on_piece_placed)
	Events.whole_placed.connect(_on_whole_placed)
	Events.section_opened.connect(_on_section_opened)
	Events.level_completed.connect(func(_d: Node) -> void:
		if active and kind != "ofrecida":       # F9 o el último objeto: se acaba y la cámara se mece
			finish()
			GameState.camera.showcase())
	Narrator.subtitle.connect(_on_subtitle)


## Corta lo que hubiera (al cambiar de diorama) sin animación.
func reset() -> void:
	_stop_ghost()
	_unisolate()
	_show_hidden(false)
	_shot_ready = false
	if is_instance_valid(coin):
		coin.queue_free()
	if is_instance_valid(reflection):
		reflection.queue_free()
	_free_ending_lights()
	coin = null
	reflection = null
	_figure = null
	_offered = null
	_coin_state = ""
	active = false
	kind = ""
	target = null
	_set_frame(0.0, 0.0, 0.0)
	_black.color.a = 0.0
	_curtain.color.a = 0.0
	_bloom.hide()
	_set_cozy(0.0, 0.0)
	_hold_sections(false)
	if GameState.enfoque != null:
		GameState.enfoque.reset()
	if GameState.hud != null:
		GameState.hud.set_moment(false)


## Mientras dura el espejo, la sección siguiente (el final) no se abre sola: la abre la transición.
func _hold_sections(on: bool) -> void:
	var d := GameState.diorama
	if d != null and is_instance_valid(d):
		d.hold_sections = on


func _diorama() -> Diorama:
	var d := GameState.diorama
	return d if is_instance_valid(d) and d.momentos and GameState.mode == GameState.Mode.PLAYING else null


# --- Empezar ---------------------------------------------------------------------------------

func _on_piece_placed(id: StringName, node: Node3D) -> void:
	var d := _diorama()
	if d == null:
		return
	if kind == "ofrecida":
		if _offered != null and id == _offered.id and is_instance_valid(coin):
			coin.queue_free()                 # ya está en su hueco: la copia flotante sobra
			coin = null
		return                                   # el final: la hucha sigue en primer plano
	if not Narrator.has_line("pieza_" + String(id)):
		return
	var slot := _slot_of(d, node)
	start(node, "reflejo" if slot != null and slot.reflejo else "normal", String(id))


## Lo montado de trozos (token de-<id>, el MP3 en el escritorio): con el último, su momento, entero.
func _on_whole_placed(id: StringName, node: Node3D) -> void:
	if _diorama() != null and kind != "ofrecida" and node != null and Narrator.has_line("pieza_" + String(id)):
		start(node, "normal", String(id))


## Al abrirse una sección con una pieza ofrecida (el epílogo): corte a un primer plano de lo que la
## sostiene (la hucha), sola, mientras se dicen sus frases; y la moneda flotando a su lado.
func _on_section_opened(sec: RefCounted) -> void:
	var d := _diorama()
	if d == null:
		return
	for s in (sec as Section).slots:
		if s.offered and not s.filled:
			_offered = s
			start(_what_holds(d, s), "ofrecida", String(s.id))
			return


func start(node: Node3D, p_kind: String, _id: String) -> void:
	_clear_extras()                              # si venía de otro momento (el espejo), fuera lo suyo
	_show_hidden(true)
	active = true
	kind = p_kind
	target = node
	_elapsed = 0.0
	_t = 0.0
	_lines_seen = 0
	_shot_ready = false
	_hold_sections(kind == "reflejo")           # tras el espejo, el final espera a su transición
	var cam := GameState.camera
	var box := Visuals.global_aabb(node)
	match kind:
		"reflejo":
			# 18-oct: «un zoom in con un fade out a negro del resto del environment y la cámara centrada
			# frontalmente al espejo»: se acerca despacio hasta tenerlo de frente y centrado (mirando hacia
			# donde mira su luna) mientras todo lo demás se va a negro a la vez; al acabar, solo queda él.
			cam.close_up(box, _mirror_front(node), 0.0, MIRROR_MARGIN, MIRROR_TIME, MIRROR_SMOOTH)
			_frame_to(1.0, 0.0, MIRROR_TIME)
			_black.create_tween().tween_property(_black, "color:a", 1.0, MIRROR_TIME)
			var mirror_id := node.get_instance_id()      # (por id: si el nivel se va antes, el espejo ya no está; trampa 40)
			get_tree().create_timer(MIRROR_TIME + 0.1, false).timeout.connect(func() -> void:
				var mirror := instance_from_id(mirror_id) as Node3D
				if active and kind == "reflejo" and mirror != null:
					_isolate([mirror, reflection]))
			get_tree().create_timer(Diorama.POP_TIME + 0.05, false).timeout.connect(func() -> void:
				var mirror := instance_from_id(mirror_id) as Node3D
				if mirror != null:
					_make_reflection(mirror))
		"ofrecida":
			_cut_to_offered(node)
		_:
			var front := _flat_front(node)
			cam.close_up(box, front, 8.0)
			_hide_occluders(node)
			_frame_to(IRIS, BARS, FADE)
	GameState.hud.set_moment(true)
	Sfx.play("momento")


## Hacia dónde mira el espejo: hacia donde mira su luna (la del kit tiene la cara en su -Z, no en la +Z
## de la pieza); sin luna, la +Z de la pieza.
func _mirror_front(node: Node3D) -> Vector3:
	var painted := _painted_mark(node)
	if painted != null:
		return painted.global_basis.z.normalized()
	var glass := _glass_mesh(node)
	return (glass.global_basis.z if glass != null else node.global_basis.z).normalized()


## Un objeto plano y de pie (un dibujo en la pared, un tablero de llaves) se ve mejor de frente:
## su cara mira hacia su +Z local. ZERO = no es plano (se ve desde donde miraba el jugador).
func _flat_front(node: Node3D) -> Vector3:
	var lb := Visuals.local_aabb(node)
	if lb.size.z < 0.2 * maxf(lb.size.x, lb.size.y) and lb.size.y > lb.size.z * 3.0:
		return node.global_basis.z.normalized()
	return Vector3.ZERO


## Lo que se cruza entre la cámara (donde va a acabar) y el objeto se desvanece mientras dura el
## plano: rayos desde la cámara a varios puntos del objeto contra las superficies (lo que se ve).
## Lo que está PEGADO al objeto (su caja toca la suya: el cuadro en el caballete, la cama bajo la
## nutria) no se esconde: es parte de lo que se enseña (quinta nota).
func _hide_occluders(node: Node3D) -> void:
	var d := GameState.diorama
	var from := GameState.camera.goal_position()
	var box := Visuals.global_aabb(node)
	var targets: Array[Vector3] = [box.get_center()]
	for i in 8:
		targets.append(box.get_center().lerp(box.get_endpoint(i), 0.7))
	var space := d.get_world_3d().direct_space_state
	var mine: Dictionary = {}
	for m in Visuals.meshes_under(node):
		mine[m] = true
	var near := box.grow(0.02)                   # lo que toca esta caja va con el objeto
	var found: Dictionary = {}
	for p in targets:
		var exclude: Array[RID] = []
		for k in 6:
			var q := PhysicsRayQueryParameters3D.create(from, from.lerp(p, 0.97), Visuals.SURFACE_LAYER)
			q.exclude = exclude
			var r := space.intersect_ray(q)
			if r.is_empty():
				break
			exclude.append(r.rid)
			var mesh := (r.collider as Node).get_parent() as GeometryInstance3D
			if mesh != null and not mine.has(mesh) and mesh.is_visible_in_tree() and not _touches(mesh, near):
				found[mesh] = true
	for s in d.slots:                            # siluetas que se cruzan (no tienen superficie)
		if s.filled or not s.shown or s.node == node:
			continue
		for m in s.meshes():
			var mb: AABB = m.global_transform * m.get_aabb()
			if mb.intersects(near):
				continue
			for p in targets:
				if mb.intersects_segment(from, from.lerp(p, 0.97)):
					found[m] = true
					break
	for g in found.keys():
		var geo := g as GeometryInstance3D
		hidden_for_shot.append(geo)
		var tw := geo.create_tween()
		tw.tween_property(geo, "transparency", 1.0, HIDE_TIME)
		tw.tween_callback(geo.hide)


static func _touches(m: GeometryInstance3D, near: AABB) -> bool:
	return (m.global_transform * m.get_aabb()).intersects(near)


## Vuelve lo que se escondió para el plano. fade = poco a poco.
func _show_hidden(fade := true) -> void:
	for g in hidden_for_shot.duplicate():
		if not is_instance_valid(g):
			continue
		var geo := g as GeometryInstance3D
		geo.show()
		if fade:
			geo.create_tween().tween_property(geo, "transparency", 0.0, HIDE_TIME)
		else:
			geo.transparency = 0.0
	hidden_for_shot.clear()


# --- Durante ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not active:
		return
	_elapsed += delta
	_t += delta
	_follow_iris()
	if kind == "transicion":
		return
	if is_instance_valid(coin) and _coin_state == "":
		_present_coin()
	var talking := Narrator.remaining() > 0.0
	if kind == "ofrecida" and not talking and _shot_ready and not is_instance_valid(coin) and _offered != null \
			and _offered.available and not _offered.filled:
		_spawn_coin()                            # se callan las frases: ya, la moneda (y su fantasma)
	var coin_turn := _coin_ready() and not talking
	_prompt.modulate.a = move_toward(_prompt.modulate.a, 1.0 if talking or coin_turn else 0.0, delta * 2.0)
	_prompt.text = "arrastra la moneda hasta la hucha" if coin_turn else "clic para seguir  ›"
	if _offered != null and not _offered.filled:
		_offered.set_pulse(coin_turn)
	if kind == "ofrecida":
		_cozy_step()
		return                                   # el final no se acaba solo: lo cierra el fundido
	if not talking and _elapsed >= MIN_TIME:
		_end_moment()


func _unhandled_input(e: InputEvent) -> void:
	if not active:
		return
	if e is InputEventMouseMotion and _coin_state == "arrastrando":
		_drag_coin((e as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()
		return
	if not (e is InputEventMouseButton) or (e as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var mb := e as InputEventMouseButton
	get_viewport().set_input_as_handled()
	if not mb.pressed:
		if _coin_state == "arrastrando":
			_release_coin(mb.position)
		return
	if _coin_ready() and _near_coin(mb.position):
		_coin_state = "arrastrando"               # se coge: ahora hay que llevarla hasta la ranura
		_stop_ghost()                            # y la fantasma ya no hace falta
		Sfx.play("pickup")
	elif kind == "transicion":
		pass                                     # la transición no se salta: dura lo que dura
	elif kind == "normal" and _diorama() != null and _diorama().act_waiting():
		_diorama().continue_act()                # cierra un acto: al siguiente (la voz se apaga y sale su capítulo)
	elif not Narrator.skip() and kind != "ofrecida":
		_end_moment()


## Al callarse (o con un clic sin frases): se acaba; si después viene el final (el espejo), transición.
func _end_moment() -> void:
	if kind == "reflejo" and _ending_follows():
		_transition_to_ending()
	else:
		finish()


## ¿Lo siguiente es el final? (la sección que se está abriendo trae una pieza ofrecida: la moneda)
func _ending_follows() -> bool:
	var d := _diorama()
	var sec := d.opening_section() if d != null else null
	if sec == null:
		return false
	for sl in sec.slots:
		if sl.offered and not sl.filled:
			return true
	return false


## Del espejo al final: el espejo vacío se queda un momento en silencio, fundido lento a negro y,
## ya a oscuras, se abre la sección del final (su corte empieza desde el negro).
func _transition_to_ending() -> void:
	kind = "transicion"
	_prompt.create_tween().tween_property(_prompt, "modulate:a", 0.0, 0.4)
	var tw := create_tween()
	tw.tween_interval(TRANSITION_HOLD)
	tw.tween_property(_curtain, "color:a", 1.0, TRANSITION_FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		if not active or kind != "transicion":
			return
		_clear_extras()
		_show_hidden(false)
		_hold_sections(false)
		var d := _diorama()
		if d != null:
			d.open_pending_now())


## El foco sigue al objeto en pantalla (la cámara se mueve) y lo rodea con holgura; el enfoque, igual.
func _follow_iris() -> void:
	if not is_instance_valid(target):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var box := Visuals.global_aabb(target)       # (el espejo, entero: con su marco)
	if is_instance_valid(coin):
		box = box.merge(Visuals.global_aabb(coin))   # el foco también alumbra la moneda
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in 8:
		var p := box.get_endpoint(i)
		if cam.is_position_behind(p):
			continue
		var s := cam.unproject_position(p)
		lo = lo.min(s)
		hi = hi.max(s)
	if lo.x == INF:
		return
	var grow := MIRROR_GROW if kind == "reflejo" else 1.35
	var r := ((hi - lo) * 0.5 * grow).max(Vector2(110, 110) if kind != "reflejo" else Vector2(40, 40))
	_iris_mat.set_shader_parameter("centro", (lo + hi) * 0.5)
	_iris_mat.set_shader_parameter("radio", r)
	var black := kind == "reflejo" or kind == "transicion"     # el espejo: todo a negro, con borde
	_iris_mat.set_shader_parameter("suave", 0.12 if black else IRIS_SOFT)
	_iris_mat.set_shader_parameter("dentro", 1.0 if black else IRIS_INSIDE)
	_iris_mat.set_shader_parameter("color", Color.BLACK if black else COZY_DARK if kind == "ofrecida"
		else Fondos.dark(Settings.get_value("fondo_color")))
	_iris_mat.set_shader_parameter("tam", _iris.size)
	if GameState.enfoque != null:
		GameState.enfoque.focus_on((lo + hi) * 0.5, r * 1.1, 1.0)


## Las frases del espejo: con la última, la silueta se va.
func _on_subtitle(_text: String, seconds: float) -> void:
	if not active or kind != "reflejo" or not is_instance_valid(_figure):
		return
	_lines_seen += 1
	if Narrator.remaining() <= seconds + Narrator.GAP + 0.05:       # la última frase: ya no está
		var tw := _figure.create_tween().set_trans(Tween.TRANS_SINE)
		tw.tween_property(_figure, "modulate:a", 0.0, seconds * 0.9)


# --- Aislar: solo se ve lo que importa ---------------------------------------------------------

## Solo se ve lo que cuelga de `nodes`: la cámara pasa a ver únicamente su capa.
func _isolate(nodes: Array) -> void:
	for n in nodes:
		if not is_instance_valid(n):
			continue
		var all: Array = (n as Node).find_children("*", "VisualInstance3D", true, false)
		if n is VisualInstance3D:
			all.append(n)
		for v in all:
			if not _isolated.has(v):
				_isolated[v] = (v as VisualInstance3D).layers
			(v as VisualInstance3D).layers = 1 << (ISOLATE_LAYER - 1)
	get_viewport().get_camera_3d().cull_mask = 1 << (ISOLATE_LAYER - 1)


func _unisolate() -> void:
	for v in _isolated.keys():
		if is_instance_valid(v):
			(v as VisualInstance3D).layers = _isolated[v]
	_isolated.clear()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		cam.cull_mask = 0xFFFFF


## (Tests) ¿Solo se ve lo aislado?
func is_isolated() -> bool:
	return not _isolated.is_empty()


## (Tests) ¿Está este nodo entre lo que se ve en el aislamiento?
func is_in_isolation(n: Node) -> bool:
	return _isolated.has(n)


# --- Reflejo ---------------------------------------------------------------------------------

## La luna del espejo (la malla que se llame Luna, Cristal o Espejo); si no hay, el objeto entero.
func _glass_box(node: Node3D) -> AABB:
	var glass := _glass_mesh(node)
	return Visuals.global_aabb(glass) if glass != null else Visuals.global_aabb(node)


## En la luna del espejo: un vaho claro (la luna se ve aunque refleje negro), la silueta de ella
## (cabeza y hombros, borrosa; aparece y se va con sus frases) y una luz cálida solo para el espejo.
## Con la luna pintada (marca invisible), solo la luz.
func _make_reflection(node: Node3D) -> void:
	if not active or kind != "reflejo" or not is_instance_valid(node) or is_instance_valid(reflection):
		return
	var glass := _glass_mesh(node)
	var painted := _painted_mark(node)
	var xf := node.global_transform.affine_inverse() * (glass.global_transform if glass != null else node.global_transform)
	var lb: AABB = xf * glass.get_aabb() if glass != null else Visuals.local_aabb(node)
	var front := _mirror_front(node)
	reflection = Node3D.new()
	reflection.name = "Reflejo"
	node.get_parent().add_child(reflection)
	reflection.global_basis = (glass.global_basis if glass != null else node.global_basis).orthonormalized()
	reflection.global_position = node.global_transform * lb.get_center() + front * 0.012
	if painted != null:
		reflection.global_transform = painted.global_transform.orthonormalized()
		var after := painted.get_meta("material_pintado", null) as Material
		if after != null:
			_reveal_painted(node, after)
	# Si el espejo trae el reflejo pintado (el del kit, Pack08: ella de mayor), ni vaho ni silueta encima:
	# solo su luz.
	if painted == null:
		var mist := _sprite(_mist_texture(), lb.size, Color(0.72, 0.77, 0.84, 0.0))
		reflection.add_child(mist)
		mist.create_tween().tween_property(mist, "modulate:a", 0.42, 1.4)
		_figure = _sprite(_silhouette_texture(), Vector3(lb.size.x * 0.82, lb.size.y * 0.78, 1.0), Color(0.07, 0.06, 0.09, 0.0))
		_figure.position = Vector3(0, -lb.size.y * 0.07, 0.004)
		_figure.render_priority = 6              # encima del vaho
		reflection.add_child(_figure)
		_figure.create_tween().tween_property(_figure, "modulate:a", 0.85, 2.0).set_delay(0.6)
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.86, 0.68)
	spot.light_energy = 1.2                      # quinta nota: las luces de los efectos quemaban
	spot.spot_range = 3.5
	spot.spot_angle = 26.0
	reflection.add_child(spot)
	spot.global_position = reflection.global_position + front * 1.3 + Vector3.UP * 0.9
	spot.look_at(reflection.global_position, Vector3.UP)
	if not _isolated.is_empty():
		_isolate([reflection])


## La luna vacía del espejo se funde en la de ella pintada (18-oct: «durante el gameplay T_Pack08_BC_02,
## en el closeup que transicione a T_Pack08_BC»). El espejo pasa ya al material pintado y encima una copia
## con el de antes, transparente, se desvanece (dentro del reflejo: si el momento se corta, se va con él y
## el espejo se queda pintado). En Compatibility la copia, a la misma profundidad, se pinta encima.
func _reveal_painted(node: Node3D, after: Material) -> void:
	var fades: Array[StandardMaterial3D] = []
	for m in Visuals.meshes_under(node):
		var veil := MeshInstance3D.new()
		veil.name = "LunaVacia"
		veil.mesh = m.mesh
		veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in m.mesh.get_surface_count():
			var before := m.get_surface_override_material(s) as StandardMaterial3D   # (el suyo, no el que lleve encima)
			if before == null:
				before = m.mesh.surface_get_material(s) as StandardMaterial3D
			if before == null:
				continue
			var fade := before.duplicate() as StandardMaterial3D
			fade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fades.append(fade)
			veil.set_surface_override_material(s, fade)
			m.set_surface_override_material(s, after)
		reflection.add_child(veil)
		veil.global_transform = m.global_transform
	var tw := reflection.create_tween().set_parallel()
	for fade in fades:
		tw.tween_property(fade, "albedo_color:a", 0.0, MIRROR_REVEAL).set_delay(MIRROR_REVEAL_DELAY) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(func() -> void:
		for c in reflection.get_children():
			if c.name.begins_with("LunaVacia"):
				c.queue_free())


func _sprite(tex: Texture2D, size: Vector3, color: Color) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.shaded = false
	s.transparent = true
	s.double_sided = false
	s.render_priority = 5
	s.modulate = color
	s.pixel_size = size.y / 128.0
	s.scale = Vector3(size.x / maxf(size.y, 0.001), 1.0, 1.0)
	return s


## La marca de un espejo con el reflejo ya pintado (un nodo sin malla, "ReflejoPintado", en el centro
## de la luna y con su +Z hacia donde mira); null si no hay.
func _painted_mark(node: Node3D) -> Node3D:
	return node.find_child("ReflejoPintado", true, false) as Node3D


## La malla de la luna (Luna, Cristal o Espejo); null si no hay.
func _glass_mesh(node: Node3D) -> MeshInstance3D:
	for m in Visuals.meshes_under(node):
		var n := String(m.name).to_lower()
		if n.contains("luna") or n.contains("cristal") or n.contains("espejo"):
			return m
	return null


static func _silhouette_texture() -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var p := Vector2(x, y)
			var head := 1.0 - smoothstep(21.0, 28.0, p.distance_to(Vector2(64, 50)))
			var q := (p - Vector2(64, 124)) / Vector2(60, 46)
			var shoulders := 1.0 - smoothstep(0.82, 1.0, q.length())
			var neck := (1.0 - smoothstep(9.0, 14.0, absf(p.x - 64.0))) if p.y > 64 and p.y < 92 else 0.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(maxf(maxf(head, shoulders), neck), 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## Vaho: una elipse clara que se apaga hacia el borde.
static func _mist_texture() -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var r := Vector2(x - 63.5, y - 63.5).length() / 63.5
			img.set_pixel(x, y, Color(1, 1, 1, (1.0 - smoothstep(0.7, 1.0, r)) * (0.85 + 0.15 * (1.0 - float(y) / 127.0))))
	return ImageTexture.create_from_image(img)


# --- Ofrecida (la moneda en la hucha): el final ------------------------------------------------

## Corte al primer plano (la hucha sola, vista un poco desde arriba, sin moverse alrededor) en su
## escena acogedora. Si la pantalla ya está a negro (viene de la transición del espejo), el corte
## se hace ahí mismo; si no, primero un fundido a negro corto. La moneda aparece poco después.
func _cut_to_offered(node: Node3D) -> void:
	var tw := _curtain.create_tween()
	if _curtain.color.a < 0.99:
		tw.tween_property(_curtain, "color:a", 1.0, CUT_TIME)
	var pig_id := node.get_instance_id()          # (por id: si el nivel se va antes del corte, ya no está; trampa 40)
	tw.tween_callback(func() -> void:
		var pig := instance_from_id(pig_id) as Node3D
		if not active or kind != "ofrecida" or pig == null:
			return
		var cam := GameState.camera
		# Desde donde la ve el jugador en el desván, un poco girada para verle la cara (venimos del
		# espejo: su vista no sirve).
		var yaw := deg_to_rad(GameState.diorama.camera_yaw_deg + ENDING_YAW)
		cam.close_up(Visuals.global_aabb(pig).grow(0.06), Vector3(sin(yaw), 0.0, cos(yaw)), ZENITH, ENDING_MARGIN)
		cam.snap()                               # un corte, no un viaje: la cámara no da vueltas
		_light_ending(pig)
		var shown: Array = [pig, _offered.node, _spot, _rim, _motes]
		shown.append_array(_support_under(pig))
		_isolate(shown)
		_frame_to(COZY_IRIS, BARS, 0.01)
		_shot_ready = true)
	tw.tween_interval(0.5)
	tw.tween_property(_curtain, "color:a", 0.0, CUT_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## La escena acogedora: un foco cálido desde arriba (como una lámpara), un contraluz naranja detrás
## que le dibuja el borde, motas de polvo flotando en la luz y el fondo cálido con luces desenfocadas.
func _light_ending(node: Node3D) -> void:
	_free_ending_lights()
	var cam := GameState.camera.cam
	var box := Visuals.global_aabb(node)
	var top := box.get_center()
	var toward := cam.global_position - top
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.01 else Vector3.BACK
	var side := toward.cross(Vector3.UP)
	_spot = SpotLight3D.new()
	_spot.name = "LuzFinal"
	_spot.light_color = Color(1.0, 0.8, 0.58)
	_spot.light_energy = 1.2
	_spot.spot_range = 3.2
	_spot.spot_angle = 30.0
	_spot.spot_angle_attenuation = 0.8
	_spot.shadow_enabled = true
	node.get_parent().add_child(_spot)
	_spot.global_position = top + Vector3.UP * 1.3 + toward * 0.55 + side * 0.3
	_spot.look_at(top, Vector3.UP)
	_spot_energy = _spot.light_energy
	_rim = OmniLight3D.new()
	_rim.name = "Contraluz"
	_rim.light_color = Color(1.0, 0.55, 0.25)
	_rim.light_energy = 1.3
	_rim.omni_range = 0.85
	node.get_parent().add_child(_rim)
	_rim.global_position = top - toward * 0.38 + Vector3.UP * 0.22
	_motes = _particles("Motas", 24, "polvo", true)
	node.get_parent().add_child(_motes)
	_motes.global_position = top + Vector3.UP * 0.15
	_motes.lifetime = 7.0
	_motes.preprocess = 7.0                      # ya flotan al verse la escena
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_motes.emission_box_extents = Vector3(0.5, 0.35, 0.5)
	_motes.direction = Vector3.UP
	_motes.spread = 180.0
	_motes.initial_velocity_min = 0.005
	_motes.initial_velocity_max = 0.025
	_motes.gravity = Vector3(0.0, 0.006, 0.0)
	_motes.scale_amount_min = 0.006
	_motes.scale_amount_max = 0.016
	_motes.color = Color(1.0, 0.84, 0.6, 0.8)
	_motes.color_ramp = _fade_ramp(0.25, 0.7)
	_motes.emitting = true
	_set_cozy(1.0, 0.0)


## Lo que está justo debajo de la hucha (el baúl donde descansa): también se ve, para que no flote.
func _support_under(node: Node3D) -> Array:
	var box := Visuals.global_aabb(node)
	var out: Array = []
	for m in Visuals.meshes_under(GameState.diorama):
		if node.is_ancestor_of(m) or not m.is_visible_in_tree():
			continue
		var mb := Visuals.global_aabb(m)
		var overlaps := mb.position.x < box.end.x and mb.end.x > box.position.x \
			and mb.position.z < box.end.z and mb.end.z > box.position.z
		if overlaps and absf(mb.end.y - box.position.y) < 0.04:
			out.append(m)
	return out


## Cada fotograma del final: el foco parpadea un pelín (lámpara vieja) y el fondo sabe su tamaño.
func _cozy_step() -> void:
	if is_instance_valid(_spot):
		_spot.light_energy = _spot_energy * (1.0 + 0.035 * sin(_t * 7.3) * sin(_t * 2.9 + 1.0) + 0.02 * sin(_t * 13.1))
	_cozy_mat.set_shader_parameter("tam", _cozy.size)


## El fondo acogedor: alpha 0 = no se ve. seconds = 0, de golpe.
func _set_cozy(alpha: float, seconds: float) -> void:
	if _cozy_tween != null:
		_cozy_tween.kill()
	if alpha > 0.0:
		_cozy.show()
	if seconds <= 0.0:
		_cozy_mat.set_shader_parameter("alpha", alpha)
		_cozy_mat.set_shader_parameter("brillo", 1.0)
		_cozy.visible = alpha > 0.0
		return
	_cozy_tween = create_tween()
	_cozy_tween.tween_method(func(v: float) -> void: _cozy_mat.set_shader_parameter("alpha", v),
		float(_cozy_mat.get_shader_parameter("alpha")), alpha, seconds)
	if alpha <= 0.0:
		_cozy_tween.tween_callback(_cozy.hide)


## (Tests) ¿Se ve el fondo acogedor del final?
func cozy_shown() -> bool:
	return _cozy.visible and float(_cozy_mat.get_shader_parameter("alpha")) > 0.5


func _free_ending_lights() -> void:
	for n in [_spot, _rim, _motes]:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_spot = null
	_rim = null
	_motes = null


## La moneda espera quieta junto a la hucha, de cara a la cámara (un poco girada, para que se lea
## que es una moneda). Lo que se mueve es su brillo, no ella.
func _present_coin() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var to := cam.global_position - _coin_rest
	if to.length() < 0.01:
		return
	var face := Basis.looking_at(to, Vector3.UP, true) * Basis(Vector3.UP, 0.35) * _face_to_z(coin)
	coin.global_transform = Transform3D(face.scaled(Vector3.ONE * coin.scale.x), _coin_rest)


## Giro que lleva la cara de la moneda (su eje más fino) a +Z.
static func _face_to_z(n: Node3D) -> Basis:
	var size := Visuals.local_aabb(n).size
	if size.x <= size.y and size.x <= size.z:
		return Basis(Vector3.UP, -PI * 0.5)
	if size.y <= size.z:
		return Basis(Vector3.RIGHT, PI * 0.5)
	return Basis.IDENTITY


## Lo que sostiene a la pieza ofrecida (la hucha donde va la moneda): la pieza puesta más cercana.
func _what_holds(d: Diorama, s: PieceSlot) -> Node3D:
	var best: Node3D = s.node
	var best_d := INF
	for o in d.slots:
		if o != s and o.filled:
			var dist := o.center().distance_to(s.center())
			if dist < best_d and dist < 0.6:
				best = o.node
				best_d = dist
	return best


func _spawn_coin() -> void:
	if not active or kind != "ofrecida" or _offered == null or _offered.filled or is_instance_valid(coin):
		return
	coin = _offered.prototype.duplicate() as Node3D
	coin.name = "Ofrecida"
	GameState.diorama.add_child(coin)
	var cam := get_viewport().get_camera_3d()
	var side := cam.global_basis.x.normalized() if cam != null else Vector3.RIGHT
	coin.global_transform = _offered.node.global_transform
	_coin_rest = _offered.center() + side * 0.2 + Vector3.UP * 0.06
	coin.global_position = _coin_rest
	coin.scale = Vector3.ONE * 0.01
	var glow := ShaderMaterial.new()             # brilla y late: es lo que hay que coger
	glow.shader = Interactable.GLOW_SHADER
	glow.set_shader_parameter("fuerza", 1.4)
	for m in Visuals.meshes_under(coin):
		m.material_overlay = glow
	var glint := OmniLight3D.new()
	glint.light_color = Color(1.0, 0.82, 0.45)
	glint.light_energy = 0.5
	glint.omni_range = 0.45
	coin.add_child(glint)
	var sparkle := _particles("Destello", 1, "chispa", true)   # un destello que se enciende y se apaga
	sparkle.lifetime = 1.8
	sparkle.local_coords = true
	sparkle.gravity = Vector3.ZERO
	sparkle.initial_velocity_min = 0.0
	sparkle.initial_velocity_max = 0.0
	sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	sparkle.emission_sphere_radius = 0.035
	sparkle.scale_amount_min = 0.05
	sparkle.scale_amount_max = 0.05
	sparkle.scale_amount_curve = _pop_curve()
	sparkle.color = Color(1.0, 0.95, 0.8)
	sparkle.emitting = true
	coin.add_child(sparkle)
	_isolate([coin])
	var tw := coin.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(coin, "scale", Vector3.ONE * COIN_SCALE, 0.45)
	tw.tween_callback(_start_ghost)
	Sfx.play("moneda_aparece", 0.0)


## La moneda fantasma: una copia translúcida que sale de la moneda, se endereza sobre la ranura y entra
## en la hucha (desaparece dentro), una y otra vez, hasta que el jugador coge la moneda.
func _start_ghost() -> void:
	_stop_ghost()
	if not active or kind != "ofrecida" or not is_instance_valid(coin) or _coin_state != "" or _offered == null:
		return
	ghost = _offered.prototype.duplicate() as Node3D
	ghost.name = "Fantasma"
	_ghost_mat = ShaderMaterial.new()
	_ghost_mat.shader = preload("res://shaders/fantasma.gdshader")
	_ghost_mat.set_shader_parameter("alpha", 0.0)
	_ghost_mat.set_shader_parameter("color", Color(1.0, 0.97, 0.9))
	for m in Visuals.meshes_under(ghost):
		m.material_override = _ghost_mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	GameState.diorama.add_child(ghost)
	_ghost_at(0.0)
	_isolate([ghost])
	_ghost_tween = ghost.create_tween().set_loops()
	_ghost_tween.tween_method(_ghost_at, 0.0, 1.0, GHOST_TIME)
	_ghost_tween.tween_interval(GHOST_REST)


func _stop_ghost() -> void:
	if _ghost_tween != null:
		_ghost_tween.kill()
	_ghost_tween = null
	if is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null


## La fantasma en el instante t (0..1) del gesto: sale de la moneda, sube un poco en arco mientras se
## endereza como la ranura, y baja dentro de la hucha. Aparece al principio y se apaga al entrar.
func _ghost_at(t: float) -> void:
	if not is_instance_valid(ghost) or not is_instance_valid(coin) or _offered == null:
		return
	var from := coin.global_transform
	var goal := _offered.node.global_transform
	var above := goal.origin + Vector3.UP * 0.07
	var a := smoothstep(0.0, 0.68, t)
	var b := clampf((t - 0.68) / 0.27, 0.0, 1.0)
	var pos := from.origin.lerp(above, a) + Vector3.UP * sin(a * PI) * 0.06
	if b > 0.0:
		pos = above.lerp(goal.origin - Vector3.UP * 0.03, b * b)
	var q := from.basis.get_rotation_quaternion().slerp(goal.basis.get_rotation_quaternion(), a)
	ghost.global_transform = Transform3D(Basis(q).scaled(Vector3.ONE * lerpf(from.basis.get_scale().x, 1.0, a)), pos)
	_ghost_mat.set_shader_parameter("alpha", GHOST_ALPHA * smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.8, 0.97, t)))


func _coin_ready() -> bool:
	return kind == "ofrecida" and is_instance_valid(coin) and _coin_state != "entrando" and _offered != null \
		and _offered.available and GameState.diorama.inventory.has(_offered.id) and Narrator.remaining() <= 0.0


func _near_coin(pos: Vector2) -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam != null and cam.unproject_position(coin.global_position).distance_to(pos) <= COIN_GRAB_PX


## La moneda en la mano sigue al cursor, en un plano que pasa por la ranura y mira a la cámara. Cerca
## de la ranura, la ranura la atrae (se nota que ahí va).
func _drag_coin(pos: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not is_instance_valid(coin):
		return
	var plane := Plane(cam.global_basis.z, _offered.center())
	var hit: Variant = plane.intersects_ray(cam.project_ray_origin(pos), cam.project_ray_normal(pos))
	if hit == null:
		return
	var p: Vector3 = hit
	var reach := COIN_SNAP_PX * COIN_MAGNET * GameState.diorama._snap_scale()
	var d := pos.distance_to(cam.unproject_position(_offered.center()))
	if d < reach:
		p = p.lerp(_offered.center() + Vector3.UP * 0.05, (1.0 - d / reach) * 0.65)
	coin.global_position = p


## Soltarla con la moneda cerca de la ranura: se endereza, se pone encima y entra (y se coloca de
## verdad, con su golpe de luz). Lejos: vuelve a su sitio.
func _release_coin(_pos: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	var slot_px := cam.unproject_position(_offered.center()) if cam != null else Vector2(INF, INF)
	var coin_px := cam.unproject_position(coin.global_position) if cam != null else Vector2(-INF, -INF)
	if slot_px.distance_to(coin_px) <= COIN_SNAP_PX * GameState.diorama._snap_scale():
		_coin_state = "entrando"
		var from := coin.global_transform
		var goal := _offered.node.global_transform
		var above := goal.origin + Vector3.UP * 0.07
		var q0 := from.basis.get_rotation_quaternion()
		var q1 := goal.basis.get_rotation_quaternion()
		var s0 := from.basis.get_scale().x
		var tw := coin.create_tween()
		tw.tween_method(func(t: float) -> void:
			coin.global_transform = Transform3D(Basis(q0.slerp(q1, t)).scaled(Vector3.ONE * lerpf(s0, 1.0, t)), from.origin.lerp(above, t)),
			0.0, 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(t: float) -> void:
			coin.global_transform = Transform3D(goal.basis, above.lerp(goal.origin, t)), 0.0, 1.0, 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			_coin_in_fx(goal.origin)
			var d := GameState.diorama
			if is_instance_valid(d) and _offered != null and not _offered.filled:
				d.place(_offered))
	else:
		_coin_state = "volviendo"
		Sfx.play("reject")
		var tw := coin.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(coin, "global_position", _coin_rest, 0.35)
		tw.tween_callback(func() -> void:
			_coin_state = ""
			_start_ghost())                      # vuelve a enseñar el gesto


## La moneda entra: un golpe de luz cálida desde la ranura, chispas doradas que saltan, luces que
## suben despacio, y el fondo se aviva un momento.
func _coin_in_fx(at: Vector3) -> void:
	Sfx.play("moneda_hucha", 0.0)
	var d := GameState.diorama
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.78, 0.4)
	flash.omni_range = 1.4
	flash.light_energy = 0.0
	d.add_child(flash)
	flash.global_position = at + Vector3.UP * 0.08
	var tw := flash.create_tween()
	tw.tween_property(flash, "light_energy", 1.5, 0.08)
	tw.tween_property(flash, "light_energy", 0.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(flash.queue_free)
	var sparks := _particles("ChispasMoneda", 36, "chispa", true)
	d.add_child(sparks)
	sparks.global_position = at + Vector3.UP * 0.03
	sparks.one_shot = true
	sparks.explosiveness = 0.9
	sparks.lifetime = 1.4
	sparks.direction = Vector3.UP
	sparks.spread = 50.0
	sparks.initial_velocity_min = 0.35
	sparks.initial_velocity_max = 0.8
	sparks.gravity = Vector3(0.0, -0.9, 0.0)
	sparks.damping_min = 0.4
	sparks.damping_max = 0.9
	sparks.scale_amount_min = 0.03
	sparks.scale_amount_max = 0.055
	sparks.color = Color(1.0, 0.86, 0.5)
	sparks.color_ramp = _fade_ramp(0.0, 0.55)
	sparks.emitting = true
	var lights := _particles("LucesMoneda", 16, "luz", true)
	d.add_child(lights)
	lights.global_position = at + Vector3.UP * 0.05
	lights.one_shot = true
	lights.explosiveness = 0.5
	lights.lifetime = 3.5
	lights.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	lights.emission_sphere_radius = 0.12
	lights.direction = Vector3.UP
	lights.spread = 25.0
	lights.initial_velocity_min = 0.06
	lights.initial_velocity_max = 0.16
	lights.gravity = Vector3(0.0, 0.02, 0.0)
	lights.scale_amount_min = 0.03
	lights.scale_amount_max = 0.06
	lights.color = Color(1.0, 0.72, 0.38, 0.9)
	lights.color_ramp = _fade_ramp(0.15, 0.6)
	lights.emitting = true
	_isolate([flash, sparks, lights])
	var cam := get_viewport().get_camera_3d()
	if cam != null:                              # y en pantalla, un destello cálido que se abre desde la ranura
		_bloom.position = cam.unproject_position(at) - _bloom.size * 0.5
		_bloom.scale = Vector2.ONE * 0.25
		_bloom.modulate.a = 0.0
		_bloom.show()
		var bt := _bloom.create_tween().set_parallel()
		bt.tween_property(_bloom, "scale", Vector2.ONE * 1.6, 1.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		bt.tween_property(_bloom, "modulate:a", 0.4, 0.12)
		bt.chain().tween_property(_bloom, "modulate:a", 0.0, 1.1).set_trans(Tween.TRANS_SINE)
		bt.chain().tween_callback(_bloom.hide)
	for p in [sparks, lights]:
		get_tree().create_timer((p as CPUParticles3D).lifetime + 0.5, false).timeout.connect((p as Node).queue_free)
	var glow := create_tween()
	glow.tween_method(func(v: float) -> void: _cozy_mat.set_shader_parameter("brillo", v), 1.0, 1.8, 0.25)
	glow.tween_method(func(v: float) -> void: _cozy_mat.set_shader_parameter("brillo", v), 1.8, 1.3, 2.2) \
		.set_trans(Tween.TRANS_SINE)
	_spot_energy *= 1.15                         # y la luz se queda un poco más cálida


# --- Partículas del final (texturas de Efectos) ----------------------------------------------

func _particles(n: String, amount: int, tex: String, glow: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = n
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
	mat.disable_fog = true                   # la niebla teñía el cuadrado entero de cada mota
	if not _textures.has(tex):
		_textures[tex] = Efectos._draw(tex)
	mat.albedo_texture = _textures[tex]
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func _fade_ramp(fade_in: float, fade_out: float) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(maxf(fade_in, 0.001), Color(1, 1, 1, 1))
	g.add_point(clampf(fade_out, fade_in + 0.01, 0.999), Color(1, 1, 1, 1))
	return g


## Crece de la nada, brilla y se apaga (un destello).
static func _pop_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(0.6, 0.0))
	c.add_point(Vector2(1.0, 0.0))
	return c


## (Tests) Dónde está la moneda en pantalla (para cogerla) y dónde su ranura (para soltarla).
func coin_screen_position() -> Vector2:
	var cam := get_viewport().get_camera_3d()
	return cam.unproject_position(coin.global_position) if is_instance_valid(coin) and cam != null else Vector2(-1, -1)


func slot_screen_position() -> Vector2:
	var cam := get_viewport().get_camera_3d()
	return cam.unproject_position(_offered.center()) if _offered != null and cam != null else Vector2(-1, -1)


# --- Acabar ----------------------------------------------------------------------------------

func finish() -> void:
	if not active:
		return
	_clear_extras()
	_show_hidden(true)
	_hold_sections(false)
	active = false
	kind = ""
	target = null
	GameState.camera.end_close_up()
	_frame_to(0.0, 0.0, FADE)
	if GameState.enfoque != null:
		GameState.enfoque.reset()
	GameState.hud.set_moment(false)


## Lo que pone un momento especial (lo aislado, el reflejo, la luz de arriba, el fondo negro) se quita.
func _clear_extras() -> void:
	_stop_ghost()
	_unisolate()
	if is_instance_valid(reflection):
		reflection.queue_free()
	reflection = null
	_figure = null
	_free_ending_lights()
	if _cozy.visible:
		_set_cozy(0.0, FADE)
	if _black.color.a > 0.0:
		_black.create_tween().tween_property(_black, "color:a", 0.0, FADE)


func _frame_to(iris: float, bars: float, seconds: float) -> void:
	if _iris_tween != null:
		_iris_tween.kill()
	_iris_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_iris_tween.tween_method(func(v: float) -> void: _iris_mat.set_shader_parameter("fuerza", v),
		float(_iris_mat.get_shader_parameter("fuerza")), iris, seconds)
	_iris_tween.tween_property(_bars[0], "offset_bottom", bars, seconds)
	_iris_tween.tween_property(_bars[1], "offset_top", -bars, seconds)


func _set_frame(iris: float, bars: float, prompt: float) -> void:
	if _iris_tween != null:
		_iris_tween.kill()
	_iris_mat.set_shader_parameter("fuerza", iris)
	_bars[0].offset_bottom = bars
	_bars[1].offset_top = -bars
	_prompt.modulate.a = prompt


## (Tests) Cuánto oscurece el foco ahora (0..1).
func iris_strength() -> float:
	return float(_iris_mat.get_shader_parameter("fuerza"))


func _slot_of(d: Diorama, node: Node3D) -> PieceSlot:
	for s in d.slots:
		if s.node == node:
			return s
	return null
