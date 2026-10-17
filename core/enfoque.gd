class_name Enfoque
extends CanvasLayer
## Enfoque de cine (postproceso, shaders/desenfoque.gdshader): todo un poco desdibujado y, fuera de
## la zona de foco, más; como la maqueta de Woodo, que parece fotografiada con poca profundidad de
## campo. El foco no está quieto: va a lo importante con un "cambio de foco" suave (nada salta):
##  - jugando: el centro de la pantalla (los bordes, desenfocados; al hacer zoom, la cámara lleva la
##    zona hacia el centro: quinta nota); al arrastrar una pieza, donde está la mano;
##  - en un momento de la historia: el objeto (lo pide Momentos con focus_on), y fuera más borroso.
## Va en la capa 0, por encima del 3D y por debajo de la interfaz (que nunca se desenfoca).

const RACK_TIME := 0.45                      ## lo que tarda en cambiar de foco (s, muelle exponencial)
const PLAY_RADIUS := Vector2(0.38, 0.34)     ## zona nítida al jugar (fracción de la pantalla)
const PLAY_BLUR := 2.2                       ## desenfoque fuera del foco al jugar (px)
const MOMENT_BLUR := 4.5                     ## y en un momento de la historia
const SOFT_BLUR := 0.45                      ## desenfoque leve en todo

var enabled := true
var _rect: ColorRect
var _mat: ShaderMaterial
var _center := Vector2(640, 380)
var _radius := Vector2(480, 245)
var _blur := PLAY_BLUR
var _goal_center := Vector2(640, 380)
var _goal_radius := Vector2(480, 245)
var _goal_blur := PLAY_BLUR
var _moment_left := 0.0                      ## mientras > 0, manda el foco que pidió el momento


func _ready() -> void:
	layer = 0
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/desenfoque.gdshader")
	_mat.set_shader_parameter("dentro", SOFT_BLUR)
	_rect.material = _mat
	add_child(_rect)


## Un momento de la historia pide el foco en esa zona de la pantalla (se pide cada fotograma).
func focus_on(center: Vector2, radius: Vector2, strength := 1.0) -> void:
	_goal_center = center
	_goal_radius = radius
	_goal_blur = lerpf(PLAY_BLUR, MOMENT_BLUR, strength)
	_moment_left = 0.2


## Vuelve al foco de jugar.
func reset() -> void:
	_moment_left = 0.0


func _process(delta: float) -> void:
	_rect.visible = enabled
	if not enabled:
		return
	var size := _rect.size
	if _moment_left > 0.0:
		_moment_left -= delta
	else:
		_goal_blur = PLAY_BLUR
		_goal_radius = size * PLAY_RADIUS
		_goal_center = _play_center(size)
	var k := 1.0 - exp(-delta / maxf(RACK_TIME * 0.4, 0.001))
	_center = _center.lerp(_goal_center, k)
	_radius = _radius.lerp(_goal_radius, k)
	_blur = lerpf(_blur, _goal_blur, k)
	_mat.set_shader_parameter("centro", _center)
	_mat.set_shader_parameter("radio", _radius)
	_mat.set_shader_parameter("fuera", _blur)
	_mat.set_shader_parameter("tam", size)


## Al jugar, el foco está en el centro de la pantalla; al arrastrar una pieza, en la mano.
func _play_center(size: Vector2) -> Vector2:
	if GameState.is_dragging:
		return _rect.get_local_mouse_position()
	return size * 0.5


## (Tests) El foco de ahora: centro, radio y desenfoque fuera.
func state() -> Dictionary:
	return {"centro": _center, "radio": _radius, "fuera": _blur}
