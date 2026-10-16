class_name Momentos
extends Node
## Las secuencias de la historia ("momentos"), en los dioramas con `momentos = true` (el desván).
## Al colocar un objeto con frase (pieza_<id> en narracion_es.json): la cámara se le acerca despacio,
## entran dos bandas negras de cine y un foco que oscurece alrededor del objeto, el objeto hace su
## gesto (la bailarina gira, la nutria se achucha, las llaves tintinean...) y suena su frase. La
## bandeja y los botones se apartan; un clic pasa a la siguiente frase. Al callarse, todo vuelve.
## Dos momentos especiales, por nombre en el modelo (core/name_rules.gd):
##   __reflejo  (el espejo): la cámara se pone delante, todo lo demás se va a negro y en la luna
##              aparece una silueta que se desvanece con la última frase ("¿Dónde estoy yo?").
##   __ofrecida (la moneda): su sección se abre con un primer plano de su hueco (la hucha); la
##              moneda aparece flotando mientras se dicen las frases y, cuando acaban, un clic en
##              ella la mete sola. Después, el final de siempre (fundido a negro).

const MIN_TIME := 2.0                        ## un momento dura al menos esto (s)
const IRIS := 0.62                           ## lo oscuro alrededor del objeto en un momento normal
const BARS := 54.0                           ## alto de las bandas de cine (px a 720)
const FADE := 0.9
const REFLECTION_LAYER := 20                 ## capa de render del espejo aislado (el resto, a negro)
const COIN_CLICK_PX := 70.0                  ## lo cerca que hay que tocar la moneda

## Gesto de cada objeto mientras habla (lo que le da personalidad). Sin entrada = flota un poco.
const GESTURES := {
	"hucha": "sacudir", "caja_musica": "bailarina", "dibujo": "aletear", "peluche": "achuchar",
	"mp3": "latir", "camara": "disparar", "solicitud": "aletear", "llaves": "sacudir",
	"caballete": "balancear", "espejo": "", "moneda": "girar",
}

var active := false
var kind := ""                               ## "" / "normal" / "reflejo" / "ofrecida"
var target: Node3D                           ## el objeto del momento
var coin: Node3D                             ## (ofrecida) la pieza flotando, lista para el clic
var reflection: Node3D                       ## (reflejo) vaho en la luna + la silueta de ella + su luz
var _figure: Sprite3D                        ## la silueta (aparece con la primera frase, se va con la última)

var _layer: CanvasLayer
var _iris: ColorRect
var _black: ColorRect                        ## (reflejo) fondo negro de verdad detrás del 3D
var _iris_mat: ShaderMaterial
var _bars: Array[ColorRect] = []
var _prompt: Label
var _elapsed := 0.0
var _iris_tween: Tween
var _bars_tween: Tween
var _base: Transform3D                       ## transformación del objeto antes del gesto
var _base_valid := false                     ## se toma al acabar el "pop" de encajar (si no, saldría más grande)
var _gesture := ""
var _t := 0.0
var _offered: PieceSlot
var _isolated: Dictionary = {}               ## VisualInstance3D -> capas de antes (reflejo)
var _lines_seen := 0
var _coin_flying := false
var _coin_y := 0.0


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 0                         # encima del 3D y por debajo de la interfaz (subtítulos)
	add_child(_layer)
	var back := CanvasLayer.new()
	back.layer = -5                          # parte del fondo (background_canvas_max_layer = -1), sobre el degradado
	add_child(back)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(_black)
	_iris = ColorRect.new()
	_iris.set_anchors_preset(Control.PRESET_FULL_RECT)
	_iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_iris_mat = ShaderMaterial.new()
	_iris_mat.shader = preload("res://shaders/foco.gdshader")
	_iris_mat.set_shader_parameter("fuerza", 0.0)
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
	Events.section_opened.connect(_on_section_opened)
	Events.level_completed.connect(func(_d: Node) -> void:
		if active and kind != "ofrecida":       # F9 o el último objeto: se acaba y la cámara se mece
			finish()
			GameState.camera.showcase())
	Narrator.subtitle.connect(_on_subtitle)


## Corta lo que hubiera (al cambiar de diorama) sin animación.
func reset() -> void:
	_restore_target()
	_unisolate()
	if is_instance_valid(coin):
		coin.queue_free()
	if is_instance_valid(reflection):
		reflection.queue_free()
	coin = null
	reflection = null
	_figure = null
	_offered = null
	_coin_flying = false
	active = false
	kind = ""
	target = null
	_set_frame(0.0, 0.0, 0.0)
	_black.color.a = 0.0
	if GameState.hud != null:
		GameState.hud.set_moment(false)


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


## Al abrirse una sección con una pieza ofrecida (el epílogo): primer plano de su hueco (la hucha)
## mientras se dicen sus frases, y la moneda flotando.
func _on_section_opened(sec: RefCounted) -> void:
	var d := _diorama()
	if d == null:
		return
	for s in (sec as Section).slots:
		if s.offered and not s.filled:
			_offered = s
			var around := _what_holds(d, s)
			start(around, "ofrecida", String(s.id))
			get_tree().create_timer(1.2, false).timeout.connect(_spawn_coin)
			return


func start(node: Node3D, p_kind: String, id: String) -> void:
	_restore_target()
	_clear_extras()                              # si venía de otro momento (el espejo), fuera lo suyo
	active = true
	kind = p_kind
	target = node
	_elapsed = 0.0
	_t = 0.0
	_lines_seen = 0
	_base_valid = false
	_gesture = String(GESTURES.get(id, "flotar"))
	var cam := GameState.camera
	var box := Visuals.global_aabb(node)
	if kind == "reflejo":
		cam.close_up(_glass_box(node), node.global_basis.z)
		_frame_to(1.0, 0.0, 1.2)
		_black.create_tween().tween_property(_black, "color:a", 1.0, 1.2)
		get_tree().create_timer(1.3, false).timeout.connect(_isolate.bind(node))
		get_tree().create_timer(Diorama.POP_TIME + 0.05, false).timeout.connect(_make_reflection.bind(node))
	elif kind == "ofrecida":
		cam.close_up(box.grow(0.08))
		_frame_to(0.82, BARS, FADE)
	else:
		cam.close_up(box)
		_frame_to(IRIS, BARS, FADE)
	GameState.hud.set_moment(true)
	Sfx.play("momento")


# --- Durante ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not active:
		return
	_elapsed += delta
	_t += delta
	_follow_iris()
	_gesture_step(delta)
	if is_instance_valid(coin) and not _coin_flying:
		_present_coin()
	var talking := Narrator.remaining() > 0.0
	_prompt.modulate.a = move_toward(_prompt.modulate.a, 1.0 if talking or _coin_ready() else 0.0, delta * 2.0)
	_prompt.text = "toca la moneda" if _coin_ready() and not talking else "clic para seguir  ›"
	if kind == "ofrecida":
		return                                   # el final no se acaba solo: lo cierra el fundido
	if not talking and _elapsed >= MIN_TIME:
		finish()


func _unhandled_input(e: InputEvent) -> void:
	if not active or not (e is InputEventMouseButton):
		return
	var mb := e as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	get_viewport().set_input_as_handled()
	if _coin_ready() and _near_coin(mb.position):
		_drop_coin()
	elif not Narrator.skip() and kind != "ofrecida":
		finish()


## El foco sigue al objeto en pantalla (la cámara se mueve) y lo rodea con holgura.
func _follow_iris() -> void:
	if not is_instance_valid(target):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var box := _glass_box(target) if kind == "reflejo" else Visuals.global_aabb(target)
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
	var grow := 1.3 if kind == "reflejo" else 1.35
	var r := ((hi - lo) * 0.5 * grow).max(Vector2(110, 110) if kind != "reflejo" else Vector2(40, 40))
	_iris_mat.set_shader_parameter("centro", (lo + hi) * 0.5)
	_iris_mat.set_shader_parameter("radio", r)
	_iris_mat.set_shader_parameter("suave", 0.12 if kind == "reflejo" else 0.45)
	_iris_mat.set_shader_parameter("tam", _iris.size)


## Las frases del espejo: con la primera aparece la silueta en la luna; con la última se va.
func _on_subtitle(_text: String, seconds: float) -> void:
	if not active or kind != "reflejo" or not is_instance_valid(_figure):
		return
	_lines_seen += 1
	if Narrator.remaining() <= seconds + Narrator.GAP + 0.05:       # la última frase: ya no está
		var tw := _figure.create_tween().set_trans(Tween.TRANS_SINE)
		tw.tween_property(_figure, "modulate:a", 0.0, seconds * 0.9)


# --- Gestos ----------------------------------------------------------------------------------

func _gesture_step(delta: float) -> void:
	if not is_instance_valid(target) or _t < Diorama.POP_TIME + 0.05:   # primero, el "pop" de encajar
		return
	if not _base_valid:
		_base = target.transform
		_base_valid = true
	var t := _t - Diorama.POP_TIME - 0.05
	var xf := _base
	match _gesture:
		"sacudir":
			var shake := sin(t * 30.0) * 0.12 * maxf(0.0, 1.0 - fmod(t, 1.6) * 1.6)
			xf.basis = _base.basis * Basis(Vector3.FORWARD, shake)
		"aletear":
			xf.basis = _base.basis * Basis(Vector3.RIGHT, sin(t * 7.0) * 0.08)
		"achuchar":
			var k := 1.0 + sin(t * 5.0) * 0.08 * exp(-fmod(t, 2.0) * 1.2)
			xf.basis = _base.basis * Basis.from_scale(Vector3(k, 2.0 - k, k))
		"latir":
			var beat := 1.0 + 0.07 * pow(maxf(0.0, sin(t * 7.5)), 8.0)
			xf.basis = _base.basis * Basis.from_scale(Vector3.ONE * beat)
		"disparar":
			xf.origin = _base.origin - _base.basis.z.normalized() * 0.03 * exp(-t * 6.0)
		"balancear":
			xf.basis = _base.basis * Basis(Vector3.FORWARD, sin(t * 1.6) * 0.05)
		"girar":
			xf.basis = _base.basis * Basis(Vector3.UP, t * 2.0)
		"bailarina":
			for n in target.find_children("*", "MeshInstance3D", true, false):
				if String(n.name).to_lower().contains("bailarina") or String(n.name).to_lower().contains("tutu") \
						or String(n.name).to_lower().contains("cabeza"):
					(n as Node3D).rotate_y(delta * 3.0)
		"flotar":
			xf.origin = _base.origin + Vector3.UP * sin(t * 2.4) * 0.015
	if _gesture != "" and _gesture != "bailarina":
		target.transform = xf


func _restore_target() -> void:
	if active and _base_valid and is_instance_valid(target) and _gesture != "" and _gesture != "bailarina":
		target.transform = _base
	_base_valid = false


# --- Reflejo ---------------------------------------------------------------------------------

## La luna del espejo (la malla que se llame Luna, Cristal o Espejo); si no hay, el objeto entero.
func _glass_box(node: Node3D) -> AABB:
	for m in Visuals.meshes_under(node):
		var n := String(m.name).to_lower()
		if n.contains("luna") or n.contains("cristal") or n.contains("espejo"):
			return Visuals.global_aabb(m)
	return Visuals.global_aabb(node)


## Todo a negro menos el espejo: la cámara solo ve su capa, y el fondo se va al negro del foco.
func _isolate(node: Node3D) -> void:
	if not active or kind != "reflejo" or not is_instance_valid(node):
		return
	for v in node.find_children("*", "VisualInstance3D", true, false):
		_isolated[v] = (v as VisualInstance3D).layers
		(v as VisualInstance3D).layers = 1 << (REFLECTION_LAYER - 1)
	if is_instance_valid(reflection):
		for v in reflection.find_children("*", "VisualInstance3D", true, false):
			(v as VisualInstance3D).layers = 1 << (REFLECTION_LAYER - 1)
	get_viewport().get_camera_3d().cull_mask = 1 << (REFLECTION_LAYER - 1)


func _unisolate() -> void:
	for v: VisualInstance3D in _isolated:
		if is_instance_valid(v):
			v.layers = _isolated[v]
	_isolated.clear()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		cam.cull_mask = 0xFFFFF


## (Tests) ¿Solo se ve el espejo?
func is_isolated() -> bool:
	return not _isolated.is_empty()


## En la luna del espejo: un vaho claro (la luna se ve aunque refleje negro), la silueta de ella
## (cabeza y hombros, borrosa; aparece y se va con sus frases) y una luz cálida solo para el espejo.
func _make_reflection(node: Node3D) -> void:
	if not active or kind != "reflejo" or not is_instance_valid(node) or is_instance_valid(reflection):
		return
	var glass := _glass_mesh(node)
	var xf := node.global_transform.affine_inverse() * (glass.global_transform if glass != null else node.global_transform)
	var lb: AABB = xf * glass.get_aabb() if glass != null else Visuals.local_aabb(node)
	var front := node.global_basis.z.normalized()
	reflection = Node3D.new()
	reflection.name = "Reflejo"
	node.get_parent().add_child(reflection)
	reflection.global_basis = node.global_basis.orthonormalized()
	reflection.global_position = node.global_transform * lb.get_center() + front * 0.012
	var mist := _sprite(_mist_texture(), lb.size, Color(0.72, 0.77, 0.84, 0.0))
	reflection.add_child(mist)
	mist.create_tween().tween_property(mist, "modulate:a", 0.42, 1.4)
	_figure = _sprite(_silhouette_texture(), Vector3(lb.size.x * 0.82, lb.size.y * 0.78, 1.0), Color(0.07, 0.06, 0.09, 0.0))
	_figure.position = Vector3(0, -lb.size.y * 0.07, 0.004)
	_figure.render_priority = 6                  # encima del vaho (los dos sin profundidad)
	reflection.add_child(_figure)
	_figure.create_tween().tween_property(_figure, "modulate:a", 0.85, 2.0).set_delay(0.6)
	if _isolated.size() > 0:
		for v in reflection.find_children("*", "VisualInstance3D", true, false):
			(v as VisualInstance3D).layers = 1 << (REFLECTION_LAYER - 1)
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.86, 0.68)
	spot.light_energy = 1.6
	spot.spot_range = 3.5
	spot.spot_angle = 26.0
	reflection.add_child(spot)
	spot.global_position = reflection.global_position + front * 1.3 + Vector3.UP * 0.9
	spot.look_at(reflection.global_position, Vector3.UP)


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


# --- Ofrecida (la moneda) ---------------------------------------------------------------------

## La moneda flotando se enseña de cara a la cámara, meciéndose un poco (girando entera se veía de canto).
func _present_coin() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var to := cam.global_position - coin.global_position
	if to.length() < 0.01:
		return
	var face := Basis.looking_at(to, Vector3.UP, true)
	coin.global_basis = (face * Basis(Vector3.UP, sin(_t * 1.8) * 0.45)).scaled(Vector3.ONE * coin.scale.x)
	coin.global_position.y = _coin_y + sin(_t * 2.2) * 0.012


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
	coin.global_position = _offered.center() + side * 0.26 + Vector3.UP * 0.1
	_coin_y = coin.global_position.y
	coin.scale = Vector3.ONE * 0.01
	var glow := ShaderMaterial.new()             # brilla y late: es lo que hay que tocar
	glow.shader = Interactable.GLOW_SHADER
	glow.set_shader_parameter("fuerza", 1.4)
	for m in Visuals.meshes_under(coin):
		m.material_overlay = glow
	var glint := OmniLight3D.new()
	glint.light_color = Color(1.0, 0.82, 0.45)
	glint.light_energy = 0.8
	glint.omni_range = 0.45
	coin.add_child(glint)
	var tw := coin.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(coin, "scale", Vector3.ONE * 1.6, 0.7)
	Sfx.play("brillo")


func _coin_ready() -> bool:
	return kind == "ofrecida" and is_instance_valid(coin) and not _coin_flying and _offered != null \
		and _offered.available and GameState.diorama.inventory.has(_offered.id) and Narrator.remaining() <= 0.0


func _near_coin(pos: Vector2) -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam != null and cam.unproject_position(coin.global_position).distance_to(pos) <= COIN_CLICK_PX


## Un clic en la moneda: vuela en arco hasta la ranura y entra (y se coloca de verdad).
func _drop_coin() -> void:
	_coin_flying = true
	var from := coin.global_position
	var to := _offered.center()
	var tw := coin.create_tween()
	tw.tween_method(func(t: float) -> void:
		coin.global_position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * 0.18
		coin.scale = Vector3.ONE * lerpf(1.6, 1.0, t), 0.0, 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		var d := GameState.diorama
		if is_instance_valid(d) and _offered != null and not _offered.filled:
			d.place(_offered))


## (Tests) Dónde está la moneda en pantalla (para tocarla).
func coin_screen_position() -> Vector2:
	var cam := get_viewport().get_camera_3d()
	return cam.unproject_position(coin.global_position) if is_instance_valid(coin) and cam != null else Vector2(-1, -1)


# --- Acabar ----------------------------------------------------------------------------------

func finish() -> void:
	if not active:
		return
	_restore_target()
	_clear_extras()
	active = false
	kind = ""
	target = null
	GameState.camera.end_close_up()
	_frame_to(0.0, 0.0, FADE)
	GameState.hud.set_moment(false)


## Lo que pone un momento especial (espejo aislado, su reflejo, el fondo negro) se quita.
func _clear_extras() -> void:
	_unisolate()
	if is_instance_valid(reflection):
		reflection.queue_free()
	reflection = null
	_figure = null
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
