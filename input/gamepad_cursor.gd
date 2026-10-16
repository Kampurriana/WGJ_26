class_name GamepadCursor
extends Node
## Mando: el stick izquierdo mueve el puntero del ratón y A hace de clic izquierdo.
## Así todo el juego (arrastrar, girar, pulsar cajones) funciona igual con ratón y con mando.
## (Stick derecho y gatillos los lee la cámara directamente.) PROBAR CON UN MANDO REAL.

@export var speed_px := 900.0

var _held := false


func _process(delta: float) -> void:
	var v := Input.get_vector("cursor_left", "cursor_right", "cursor_up", "cursor_down")
	if v == Vector2.ZERO:
		return
	var vp := get_viewport()
	var old := vp.get_mouse_position()
	var pos := (old + v * speed_px * delta).clamp(Vector2.ZERO, vp.get_visible_rect().size)
	vp.warp_mouse(pos)
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	m.relative = pos - old
	if _held:
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(m)


func _input(e: InputEvent) -> void:
	if not (e is InputEventJoypadButton) or not e.is_action("pad_click"):
		return
	_held = e.is_pressed()
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = _held
	b.position = get_viewport().get_mouse_position()
	b.global_position = b.position
	Input.parse_input_event(b)
