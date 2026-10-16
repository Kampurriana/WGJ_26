extends Node
## Mapa de controles, declarado en código (más fácil de leer y editar que project.godot).
## Ratón y táctil no necesitan acciones: los leen la cámara y el arrastre directamente.

const K := 0      # tecla
const A := 1      # eje de mando: [tipo, eje, signo]
const B := 2      # botón de mando

const ACTIONS := {
	"cam_left": [[K, KEY_A], [K, KEY_LEFT], [A, JOY_AXIS_RIGHT_X, -1.0]],
	"cam_right": [[K, KEY_D], [K, KEY_RIGHT], [A, JOY_AXIS_RIGHT_X, 1.0]],
	"cam_up": [[K, KEY_W], [K, KEY_UP], [A, JOY_AXIS_RIGHT_Y, -1.0]],
	"cam_down": [[K, KEY_S], [K, KEY_DOWN], [A, JOY_AXIS_RIGHT_Y, 1.0]],
	"zoom_in": [[K, KEY_E], [A, JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	"zoom_out": [[K, KEY_Q], [A, JOY_AXIS_TRIGGER_LEFT, 1.0]],
	"cursor_left": [[A, JOY_AXIS_LEFT_X, -1.0]],
	"cursor_right": [[A, JOY_AXIS_LEFT_X, 1.0]],
	"cursor_up": [[A, JOY_AXIS_LEFT_Y, -1.0]],
	"cursor_down": [[A, JOY_AXIS_LEFT_Y, 1.0]],
	"pad_click": [[B, JOY_BUTTON_A]],
	"hint": [[K, KEY_H], [B, JOY_BUTTON_Y]],
	"back": [[K, KEY_ESCAPE], [K, KEY_BACKSPACE], [B, JOY_BUTTON_B]],
	"complete_all": [[K, KEY_F9]],                  # atajo de prueba (GameState.DEBUG_SHORTCUTS)
}


func _ready() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for spec: Array in ACTIONS[action]:
			InputMap.action_add_event(action, _event(spec))


func _event(spec: Array) -> InputEvent:
	match spec[0]:
		K:
			var k := InputEventKey.new()
			k.physical_keycode = spec[1]
			return k
		A:
			var m := InputEventJoypadMotion.new()
			m.axis = spec[1]
			m.axis_value = spec[2]
			return m
		_:
			var b := InputEventJoypadButton.new()
			b.button_index = spec[1]
			return b
