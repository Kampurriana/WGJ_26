class_name Presentacion
extends CanvasLayer
## La presentación al abrir el juego. Sigue a la pantalla de carga de Godot sin que se note (el mismo
## fondo, application/boot_splash/bg_color, y el mismo cerdito, icon.png, a su tamaño y en el centro),
## pero vivo: respira, da dos saltitos con su sombra y, al acabar, se encoge con un «pop» mientras se
## abre un círculo desde él que descubre el puzle del cerdito (con la cámara entrando).
## Un clic o una tecla la adelantan. Señales: opening (main carga el título debajo, sin fundido) y
## finished (se ha ido del todo). Lo que se mueve va en Node2D (trampa 46).

signal opening
signal finished

const IMAGE := preload("res://icon.png")
const SIZE := 256.0                          ## como la pantalla de carga (la imagen a su tamaño)
const START_WAIT := 0.35                     ## quieta un momento, como la pantalla de carga
const HOPS := 2
const HOP_TIME := 0.6                        ## lo que dura cada saltito...
const HOP_GAP := 0.15                        ## ...y la pausa entre uno y otro
const HOP_HEIGHT := 46.0
const OPEN_AT := START_WAIT + HOPS * (HOP_TIME + HOP_GAP) + 0.1   ## cuándo empieza a irse
const POP_TIME := 0.4
const IRIS_DELAY := 0.08
const IRIS_TIME := 1.0
const REVEAL_TIME := IRIS_DELAY + IRIS_TIME  ## desde opening hasta que se ve todo el juego
const SOUND := "presentacion"                ## «Mortadela logo inicio» (Drive, 20-oct): tres golpes, el último el grande...
const SOUND_HIT := 1.35                      ## ...a este segundo del fichero: cae justo en el «pop»

var _t := 0.0
var _opened := false
var _sounded := false
var _wait_frames := -1                       ## tras opening, fotogramas hasta irse (la carga del título da un tirón)
var _curtain: ColorRect
var _iris: ShaderMaterial
var _pig: Node2D                             ## en los pies del cerdito: se aplasta y salta desde ahí
var _shadow: Polygon2D
var _feet := Vector2.ZERO


func _ready() -> void:
	layer = 60                                   # encima de todo, también del fundido (50)
	var bg: Color = ProjectSettings.get_setting("application/boot_splash/bg_color", Color(0.816, 0.886, 0.965))
	var view := get_viewport().get_visible_rect().size
	_curtain = ColorRect.new()
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	_iris = ShaderMaterial.new()
	_iris.shader = preload("res://shaders/iris.gdshader")
	_iris.set_shader_parameter("color", bg)
	_iris.set_shader_parameter("centro", Vector2(0.5, 0.5))
	_iris.set_shader_parameter("radio", -0.05)
	_iris.set_shader_parameter("aspecto", view.x / maxf(view.y, 1.0))
	_iris.set_shader_parameter("suave", 0.006)
	_iris.set_shader_parameter("borde", 0.012)
	_curtain.material = _iris
	_curtain.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_skip())
	add_child(_curtain)
	_feet = view * 0.5 + Vector2(0, SIZE * 0.5)
	_shadow = Polygon2D.new()
	var points := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		points.append(Vector2(cos(a) * SIZE * 0.3, sin(a) * SIZE * 0.06))
	_shadow.polygon = points
	_shadow.color = Color(bg.darkened(0.45), 0.3)
	_shadow.position = _feet - Vector2(0, SIZE * 0.04)
	add_child(_shadow)
	_pig = Node2D.new()
	_pig.position = _feet
	add_child(_pig)
	var sprite := Sprite2D.new()
	sprite.texture = IMAGE
	sprite.scale = Vector2.ONE * SIZE / maxf(IMAGE.get_width(), 1.0)
	sprite.position = Vector2(0, -SIZE * 0.5)
	_pig.add_child(sprite)


func _process(delta: float) -> void:
	_t += delta
	if not _sounded and _t >= OPEN_AT - SOUND_HIT:   # (si se adelanta con un clic, empieza en el «pop»)
		_sounded = true
		Sfx.play(SOUND, 0.0)
	if not _opened:
		var pose := _pose(_t)
		var h: float = pose[0]
		_pig.position = _feet - Vector2(0, h)
		_pig.scale = pose[1]
		_pig.rotation_degrees = pose[2]
		_shadow.scale = Vector2.ONE * (1.0 - 0.4 * h / HOP_HEIGHT)
		if _t >= OPEN_AT:
			_opened = true
			_wait_frames = 2
			_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
			opening.emit()
	elif _wait_frames > 0:
		_wait_frames -= 1
		if _wait_frames == 0:
			_leave()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		_skip()


## Un clic o una tecla: se salta los saltitos y se va ya.
func _skip() -> void:
	if not _opened:
		_t = maxf(_t, OPEN_AT)
		get_viewport().set_input_as_handled()


## Altura, escala y giro del cerdito en el instante t: respira; en cada saltito se agacha, salta
## estirado con un pequeño giro (a un lado y luego al otro) y cae aplastándose un poco.
func _pose(t: float) -> Array:
	var breath := sin(t * 2.6) * 0.012
	var h := 0.0
	var s := Vector2(1.0 - breath, 1.0 + breath)
	var rot := 0.0
	var local := t - START_WAIT
	if local >= 0.0:
		var i := int(local / (HOP_TIME + HOP_GAP))
		var p := (local - i * (HOP_TIME + HOP_GAP)) / HOP_TIME
		if i < HOPS and p <= 1.0:
			var side := -1.0 if i % 2 == 0 else 1.0
			if p < 0.18:
				var k := sin(p / 0.18 * PI * 0.5)
				s = Vector2(1.0 + 0.12 * k, 1.0 - 0.14 * k)
			elif p < 0.84:
				var q := (p - 0.18) / 0.66
				h = sin(q * PI) * HOP_HEIGHT
				var out := 1.0 - q
				s = Vector2(1.0 - 0.07 * out, 1.0 + 0.09 * out)
				rot = sin(q * PI) * 5.0 * side
			else:
				var k := sin((p - 0.84) / 0.16 * PI)
				s = Vector2(1.0 + 0.1 * k, 1.0 - 0.1 * k)
	return [h, s, rot]


## El «pop» del cerdito y el círculo que se abre desde él hasta dejar ver toda la pantalla.
func _leave() -> void:
	_pig.position = _feet
	_pig.rotation = 0.0
	var view := get_viewport().get_visible_rect().size
	var far := Vector2(0.5 * view.x / maxf(view.y, 1.0), 0.5).length() + 0.05
	var pop := create_tween()
	pop.tween_property(_pig, "scale", Vector2(1.15, 1.15), POP_TIME * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pop.tween_property(_pig, "scale", Vector2.ZERO, POP_TIME * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	create_tween().tween_property(_shadow, "modulate:a", 0.0, POP_TIME)
	var iris := create_tween()
	iris.tween_interval(IRIS_DELAY)
	iris.tween_method(func(r: float) -> void: _iris.set_shader_parameter("radio", r), -0.05, far, IRIS_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	iris.tween_callback(func() -> void:
		finished.emit()
		queue_free())


# --- (Tests) -----------------------------------------------------------------------------

func pig() -> Node2D:
	return _pig


func background() -> Color:
	return _iris.get_shader_parameter("color")


func iris_radius() -> float:
	return _iris.get_shader_parameter("radio")


func is_opening() -> bool:
	return _opened
