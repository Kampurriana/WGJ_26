class_name MarcaPista
extends Control
## La marca de la pista (ui/hud.gd): sobre el sitio donde va la pieza, una flecha que bota y un aro
## que late, en los colores de la interfaz. Se dibuja en pantalla (siempre se ve, aunque algo lo
## tape) y sigue al punto del diorama aunque la cámara gire o se acerque.

const ARROW := Vector2(26, 24)               ## ancho y alto de la flecha
const BOUNCE := 10.0
const RING := 16.0

var target: Node3D                           ## lo que se señala (el hueco, o el mueble que lo guarda)
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


func point(node: Node3D) -> void:
	target = node
	_t = 0.0
	visible = node != null


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or GameState.camera == null:
		hide()
		return
	var cam: Camera3D = GameState.camera.cam
	var box := Visuals.global_aabb(target)
	var top := box.get_center() + Vector3(0, box.size.y * 0.5, 0)
	if cam.is_position_behind(top):
		modulate.a = 0.0
		return
	modulate.a = minf(1.0, _t * 4.0)
	position = cam.unproject_position(top)
	_t += delta
	queue_redraw()


## Dónde está en pantalla la punta de la flecha (tests).
func tip() -> Vector2:
	return position


func _draw() -> void:
	for k in 2:                                  # dos aros que se abren y se apagan, desfasados
		var f := fmod(_t * 0.9 + k * 0.5, 1.0)
		draw_arc(Vector2.ZERO, RING + 22.0 * f, 0.0, TAU, 48, Color(UiTheme.ORANGE, 0.9 * (1.0 - f)), 4.0, true)
	draw_circle(Vector2.ZERO, 6.0, Color.WHITE)
	draw_circle(Vector2.ZERO, 4.0, UiTheme.ORANGE)
	var lift := -RING - 8.0 - absf(sin(_t * 4.0)) * BOUNCE
	var tip_pt := Vector2(0, lift)
	var head := PackedVector2Array([tip_pt, tip_pt + Vector2(-ARROW.x * 0.5, -ARROW.y * 0.6), tip_pt + Vector2(ARROW.x * 0.5, -ARROW.y * 0.6)])
	var stem := Rect2(tip_pt + Vector2(-ARROW.x * 0.18, -ARROW.y * 1.25), Vector2(ARROW.x * 0.36, ARROW.y * 0.7))
	var outline := PackedVector2Array([head[0] + Vector2(0, 4), head[1] + Vector2(-4, -2), head[2] + Vector2(4, -2)])
	draw_colored_polygon(outline, Color.WHITE)
	draw_rect(stem.grow(3.0), Color.WHITE)
	draw_colored_polygon(head, UiTheme.ORANGE)
	draw_rect(stem, UiTheme.ORANGE)
