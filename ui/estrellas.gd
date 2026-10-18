class_name EstrellasLogros
extends Control
## Las estrellas de los logros (petición del equipo): arriba a la izquierda, junto a la tarjeta de
## tarea, una fila con un hueco por logro (core/logros.gd) que se va llenando. Al conseguir uno:
##  1) cae desde arriba, en el centro, un AVISO DORADO bien llamativo (contrasta con el azul de la
##     interfaz): una estrella grande que gira, "¡LOGRO DESBLOQUEADO!", el nombre y qué era;
##  2) la estrella sale del aviso, cruza la pantalla en arco girando y encaja en su hueco de la fila,
##     que da un salto y se queda dorado; 3) el aviso se va hacia arriba.
## Le acompaña el cerdito (feedback): entra a saltitos hasta la esquina del aviso, lo celebra dando
## un par de saltos y, antes de que el aviso se retire, se va saltando por donde vino.
## Si llegan varios seguidos, esperan su turno. Durante un primer plano la fila está escondida (la
## interfaz se aparta): se asoma lo justo para recibir la estrella y se vuelve a ir.

const GOLD := Color(1.0, 0.8, 0.22)
const BANNER_Y := 70.0                       ## dónde se queda el aviso (desde arriba)
const BANNER_HIDDEN_Y := -220.0
const HOLD := 2.0                            ## lo que se lee el aviso antes de soltar la estrella (s)
const FLIGHT := 0.95                         ## lo que tarda la estrella en llegar a su hueco (s)
const PIG_SIZE := 104.0
const PIG_IN := 0.7                          ## lo que tarda en llegar a saltitos...
const PIG_OUT := 0.6                         ## ...y en irse

var bar: PanelContainer                      ## la fila de estrellas
var slots: Array[Estrella] = []              ## un hueco por logro, en el orden de Logros.LISTA
var banner: PanelContainer
var flying: Estrella                         ## la estrella que viaja ahora (null = ninguna)
var _queue: Array[String] = []
var _busy := false
var _bar_wanted := true                      ## la fila se ve (no estamos en un primer plano)
var _banner_star: Estrella
var _banner_name: Label
var _banner_text: Label
var pig: Node2D                              ## el cerdito que acompaña al aviso (en los pies; Node2D, trampa 46)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UiTheme._box(Color(1, 1, 1, 0.42), 18, Color(1, 1, 1, 0.75), 0, 2, 12, 6))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.tooltip_text = "Logros"
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	bar.add_child(row)
	for l: Dictionary in Logros.LISTA:
		var s := Estrella.new(24.0)
		row.add_child(s)
		slots.append(s)
	_build_banner()
	pig = Node2D.new()
	pig.hide()
	add_child(pig)
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://icon.png")
	sprite.scale = Vector2.ONE * PIG_SIZE / 256.0
	sprite.position = Vector2(0, -PIG_SIZE * 0.5)
	pig.add_child(sprite)


func _build_banner() -> void:
	banner = PanelContainer.new()
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var sb := UiTheme._box(GOLD, 30, Color.WHITE, 0, 5, 26, 14)
	sb.shadow_color = Color(UiTheme.BLUE_DEEP, 0.45)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 8)
	banner.add_theme_stylebox_override("panel", sb)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.hide()
	add_child(banner)
	_set_banner_y(BANNER_HIDDEN_Y)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	banner.add_child(row)
	_banner_star = Estrella.new(64.0)
	_banner_star.filled = true
	_banner_star.color = Color.WHITE
	row.add_child(_banner_star)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var kicker := Label.new()
	kicker.text = "¡LOGRO DESBLOQUEADO!"
	var spaced := FontVariation.new()
	spaced.base_font = UiTheme.FONT_BOLD
	spaced.spacing_glyph = 2
	kicker.add_theme_font_override("font", spaced)
	kicker.add_theme_font_size_override("font_size", 16)
	kicker.add_theme_color_override("font_color", UiTheme.CORAL)
	col.add_child(kicker)
	_banner_name = Label.new()
	_banner_name.add_theme_font_override("font", UiTheme.FONT_BOLD)
	_banner_name.add_theme_font_size_override("font_size", 32)
	_banner_name.add_theme_color_override("font_color", UiTheme.BLUE_DEEP)
	col.add_child(_banner_name)
	_banner_text = Label.new()
	_banner_text.add_theme_font_size_override("font_size", 16)
	_banner_text.add_theme_color_override("font_color", Color(UiTheme.BLUE_DEEP, 0.8))
	col.add_child(_banner_text)


## La fila, junto a la tarjeta de tarea (arriba a la izquierda).
func place_bar(at: Vector2) -> void:
	bar.position = at


## Rellena la fila con los logros ya conseguidos (al empezar un nivel).
func refresh() -> void:
	for i in slots.size():
		slots[i].filled = Logros.is_unlocked(Logros.LISTA[i].id)
		slots[i].scale = Vector2.ONE


## La fila se ve en partida; en los primeros planos y en el menú, no (pero se asoma para recibir).
func set_bar_visible(on: bool) -> void:
	_bar_wanted = on
	if not _busy:
		bar.visible = on
		bar.modulate.a = 1.0


## Un logro conseguido: aviso, estrella que vuela a su hueco. En cola si ya hay otro.
func celebrate(id: String) -> void:
	_queue.append(id)
	if not _busy:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		if not _bar_wanted:
			var out := bar.create_tween()
			out.tween_property(bar, "modulate:a", 0.0, 0.4)
			out.tween_callback(func() -> void:
				if not _busy and not _bar_wanted:
					bar.hide())
		return
	_busy = true
	var id: String = _queue.pop_front()
	var info := Logros.info(id)
	_banner_name.text = String(info.get("nombre", id))
	_banner_text.text = String(info.get("texto", ""))
	_banner_star.visible = true
	_banner_star.rotation = 0.0
	banner.show()
	banner.scale = Vector2.ONE
	Sfx.play("logro")
	if not bar.visible:                          # en un primer plano: la fila se asoma para recibirla
		bar.show()
		bar.modulate.a = 0.0
		bar.create_tween().tween_property(bar, "modulate:a", 1.0, 0.4)
	var tw := create_tween()
	tw.tween_method(_set_banner_y, BANNER_HIDDEN_Y, BANNER_Y, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_banner_star, "rotation", TAU, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		Juice.bounce(banner, 1.06)
		_pig_in())
	tw.tween_interval(HOLD)
	tw.tween_callback(_fly.bind(Logros.LISTA.map(func(l: Dictionary) -> String: return l.id).find(id)))


## La estrella sale del aviso y viaja en arco, girando, hasta su hueco de la fila.
func _fly(index: int) -> void:
	var target: Estrella = slots[clampi(index, 0, slots.size() - 1)]
	var from := _banner_star.get_global_rect().get_center()
	_banner_star.visible = false
	flying = Estrella.new(64.0)
	flying.filled = true
	flying.color = GOLD
	add_child(flying)
	flying.position = from - flying.size * 0.5
	var to := target.get_global_rect().get_center()
	var peak := from.lerp(to, 0.5) + Vector2(0, 140)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(flying):
			return
		var a := from.lerp(peak, t)
		var b := peak.lerp(to, t)
		var p := a.lerp(b, t)
		var s := lerpf(1.0, 24.0 / 64.0, t)
		flying.pivot_offset = flying.size * 0.5
		flying.scale = Vector2.ONE * s
		flying.rotation = t * TAU * 2.0
		flying.position = p - flying.size * 0.5, 0.0, 1.0, FLIGHT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pig_out()                                   # el cerdito se va antes que el aviso
	tw.parallel().tween_method(_set_banner_y, BANNER_Y, BANNER_HIDDEN_Y, 0.5).set_delay(maxf(FLIGHT * 0.5, PIG_OUT)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if is_instance_valid(flying):
			flying.queue_free()
		flying = null
		target.filled = true
		Juice.bounce(target, 1.8)
		Juice.bounce(bar, 1.08)
		Sfx.play("pinza")
		banner.hide())
	tw.tween_interval(0.5)
	tw.tween_callback(_next)


## Dónde se pone el cerdito: a la izquierda del aviso, pegado a su borde (sin tapar la estrella).
func _pig_spot() -> Vector2:
	var r := banner.get_global_rect()
	return get_global_transform().affine_inverse() * Vector2(r.position.x - PIG_SIZE * 0.42, r.end.y + 10.0)


## Entra a saltitos desde fuera de la pantalla y, ya en su sitio, lo celebra con dos saltos.
func _pig_in() -> void:
	var to := _pig_spot()
	var from := Vector2(-PIG_SIZE, to.y)
	pig.show()
	pig.position = from
	pig.scale = Vector2.ONE
	var tw := pig.create_tween()
	tw.tween_method(func(t: float) -> void: _hop(from, to, t, 3, 26.0), 0.0, 1.0, PIG_IN)
	tw.tween_method(func(t: float) -> void: _hop(to, to, t, 2, 34.0), 0.0, 1.0, 0.8)


## Se va saltando por donde vino.
func _pig_out() -> void:
	if not pig.visible:
		return
	var from := pig.position
	var to := Vector2(-PIG_SIZE * 1.5, from.y)
	var tw := pig.create_tween()
	tw.tween_method(func(t: float) -> void: _hop(from, to, t, 3, 30.0), 0.0, 1.0, PIG_OUT)
	tw.tween_callback(pig.hide)


## Un tramo a saltitos: avanza de from a to dando `hops` botes; se estira en el aire y se aplasta
## un poco al tocar el suelo, con un pequeño balanceo.
func _hop(from: Vector2, to: Vector2, t: float, hops: int, height: float) -> void:
	if t >= 1.0:                                 # al final, en el suelo y derecho
		pig.position = to
		pig.scale = Vector2.ONE
		pig.rotation = 0.0
		return
	var phase := fmod(t * hops, 1.0)
	var lift := sin(phase * PI)
	pig.position = from.lerp(to, t) - Vector2(0, lift * height)
	var squash := 1.0 - lift
	pig.scale = Vector2(1.0 + 0.1 * squash * squash - 0.04 * lift, 1.0 - 0.1 * squash * squash + 0.06 * lift)
	pig.rotation = sin(t * hops * TAU) * 0.08


func _set_banner_y(y: float) -> void:
	banner.offset_top = y
	banner.offset_bottom = y


## (Tests) Lo que dice el aviso ahora ("" = no se ve) y cuántas estrellas tiene la fila.
func banner_text() -> String:
	return _banner_name.text if banner.visible else ""


func filled_count() -> int:
	return slots.filter(func(s: Estrella) -> bool: return s.filled).size()


func is_busy() -> bool:
	return _busy


## Una estrella de cinco puntas: dorada si está llena; si no, solo su contorno (un hueco).
class Estrella extends Control:
	var filled := false:
		set(v):
			filled = v
			queue_redraw()
	var color := Color(1.0, 0.8, 0.22):
		set(v):
			color = v
			queue_redraw()

	func _init(px := 24.0) -> void:
		custom_minimum_size = Vector2(px, px)
		size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(func() -> void: pivot_offset = size * 0.5)

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		var pts := PackedVector2Array()
		for k in 10:
			var rr := r if k % 2 == 0 else r * 0.45
			var a := -PI * 0.5 + k * PI / 5.0
			pts.append(size * 0.5 + Vector2(cos(a), sin(a)) * rr)
		if filled:
			var shadow := PackedVector2Array()
			for p in pts:
				shadow.append(p + Vector2(0, r * 0.08))
			draw_colored_polygon(shadow, Color(UiTheme.BLUE_DEEP, 0.3))
			draw_colored_polygon(pts, color)
			pts.append(pts[0])
			draw_polyline(pts, Color.WHITE, maxf(1.5, r * 0.09), true)
		else:
			pts.append(pts[0])
			draw_polyline(pts, Color(UiTheme.VIOLET, 0.55), maxf(1.5, r * 0.1), true)
