class_name Juice
extends RefCounted
## Animaciones de la interfaz (petición del equipo: "animaciones en toda la UI para que la interacción
## sea satisfactoria y de mucho feedback"). Todo son muelles cortos con rebote:
##  - Botones: cualquier BaseButton se engancha solo al entrar en el árbol (main.gd llama a watch).
##    Al pasar el ratón crece un poco y se inclina; al pulsar se aplasta; al soltar rebota; con el
##    mando, crece al tener el foco.
##  - pop_in: aparece desde pequeño con un saltito (paneles, páginas, avisos, fichas nuevas).
##  - stagger: los hijos de una lista aparecen uno tras otro.
##  - bounce: un golpe de escala (un número que cambia, algo que se consigue).
##  - wiggle: un meneo corto (algo nuevo que pide atención).

const HOVER := 1.06                          ## escala con el ratón encima
const PRESS := 0.9                           ## escala al pulsar
const TILT := 1.5                            ## grados que se inclina con el ratón encima
const FOCUS := 1.04                          ## escala con el foco (mando, teclado)


## Engancha las animaciones a todo botón que entre en el árbol a partir de ahora.
static func watch(tree: SceneTree) -> void:
	tree.node_added.connect(func(n: Node) -> void:
		if n is BaseButton:
			attach_button(n as BaseButton))


static func attach_button(b: BaseButton) -> void:
	if b.has_meta(&"juice"):
		return
	b.set_meta(&"juice", true)
	_keep_centered(b)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			_to(b, HOVER, TILT, 0.22))
	b.mouse_exited.connect(func() -> void:
		_to(b, FOCUS if b.has_focus() else 1.0, 0.0, 0.25))
	b.focus_entered.connect(func() -> void:
		if not b.is_hovered():
			_to(b, FOCUS, 0.0, 0.22))
	b.focus_exited.connect(func() -> void:
		if not b.is_hovered():
			_to(b, 1.0, 0.0, 0.22))
	b.button_down.connect(func() -> void:
		_to(b, PRESS, 0.0, 0.07, Tween.TRANS_QUAD))
	b.button_up.connect(func() -> void:
		var over := b.is_hovered()
		_to(b, HOVER if over else 1.0, TILT if over else 0.0, 0.45))


## Aparece desde pequeño y transparente con un saltito, tras `delay` segundos.
static func pop_in(c: Control, delay := 0.0, from := 0.85, seconds := 0.35) -> void:
	_keep_centered(c)
	c.scale = Vector2.ONE * from
	c.modulate.a = 0.0
	# El fundido va aparte: si el ratón o el foco cambian la escala a medias, no se queda transparente.
	c.create_tween().tween_property(c, "modulate:a", 1.0, seconds * 0.6).set_delay(delay)
	_tween(c).tween_property(c, "scale", Vector2.ONE, seconds).set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Los hijos visibles de una lista aparecen uno tras otro.
static func stagger(parent: Node, step := 0.045, from := 0.9) -> void:
	var i := 0
	for child in parent.get_children():
		if child is Control and (child as Control).visible:
			pop_in(child as Control, i * step, from, 0.3)
			i += 1


## Se despliega hacia abajo desde su borde de arriba (las tarjetas de una pestaña de opciones).
static func unfold(c: Control, delay := 0.0, seconds := 0.32) -> void:
	c.pivot_offset = Vector2(c.size.x * 0.5, 0.0)
	c.scale = Vector2(1.0, 0.15)
	c.modulate.a = 0.0
	c.create_tween().tween_property(c, "modulate:a", 1.0, seconds * 0.6).set_delay(delay)
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, seconds).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: c.pivot_offset = c.size * 0.5)


## Un golpe de escala: crece de golpe y vuelve rebotando.
static func bounce(c: Control, amount := 1.15) -> void:
	_keep_centered(c)
	var tw := _tween(c)
	tw.tween_property(c, "scale", Vector2.ONE * amount, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Un meneo corto, de lado a lado.
static func wiggle(c: Control, degrees := 8.0) -> void:
	_keep_centered(c)
	var tw := c.create_tween()
	for k in [1.0, -0.8, 0.5, -0.25, 0.0]:
		tw.tween_property(c, "rotation_degrees", degrees * k, 0.07)


static func _to(c: Control, s: float, deg: float, seconds: float, trans := Tween.TRANS_BACK) -> void:
	var tw := _tween(c).set_parallel().set_trans(trans).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE * s, seconds)
	tw.tween_property(c, "rotation_degrees", deg, seconds)


## Una sola animación de escala a la vez por control: la nueva corta la anterior.
static func _tween(c: Control) -> Tween:
	if c.has_meta(&"juice_tween"):                # (get_meta con null por defecto da error si no está)
		var old: Variant = c.get_meta(&"juice_tween")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var tw := c.create_tween()
	c.set_meta(&"juice_tween", tw)
	return tw


## Crece y gira desde su centro, también cuando cambia de tamaño.
static func _keep_centered(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	if not c.has_meta(&"juice_pivot"):
		c.set_meta(&"juice_pivot", true)
		c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)
