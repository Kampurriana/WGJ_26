class_name DioramaCamera
extends Node3D
## Cámara de "plataforma giratoria": orbita alrededor del diorama, zoom con límites,
## desplazamiento corto y suavizado. Ratón, táctil (pellizco), trackpad, teclado y mando.
##   Arrastrar (izq. o dcho.) en vacío = girar · rueda/pellizco = zoom
##   Botón central o Mayús+arrastrar = desplazar · clic corto = tocar el objeto (Events.world_clicked)

@export var orbit_deg_per_px := 0.3
@export var pad_orbit_deg_per_s := 140.0
@export var zoom_step := 0.12
@export var pad_zoom_per_s := 1.6
@export var pitch_min := 6.0
@export var pitch_max := 82.0
@export var smoothing := 10.0
@export var drag_threshold_px := 6.0
@export var pan_radius := 1.5                ## cuánto se puede alejar el centro de la vista

const MENU_SWAY_DEG := 14.0                  ## en el menú de inicio, el diorama se mece así de un lado a otro
const MENU_SWAY_SPEED := 0.35
const MENU_SHIFT := 0.22                     ## y se corre a la derecha para dejar sitio al panel del menú

var cam: Camera3D
var yaw := 25.0
var pitch := 32.0
var distance := 7.0
var min_distance := 2.5
var max_distance := 12.0
var center := Vector3.ZERO

var _cur_yaw := 25.0
var _cur_pitch := 32.0
var _cur_distance := 7.0
var _cur_center := Vector3.ZERO
var _home := {}                              ## vista del ámbito actual (general o sub-diorama)
var _press_pos := Vector2.ZERO
var _press_button := 0
var _orbiting := false
var _panning := false
var _touches: Dictionary = {}
var _input_enabled := true
var _menu_view := false
var _sway_t := 0.0
var _cur_h_offset := 0.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	cam.make_current()
	Events.focus_changed.connect(_on_focus_changed)
	Events.piece_placed.connect(func(_id: StringName, _n: Node3D) -> void: center = _home.get("center", center))


func configure(d: Diorama) -> void:
	var box := Visuals.global_aabb(d)
	yaw = d.camera_yaw_deg
	pitch = d.camera_pitch_deg
	_set_home(box.get_center(), d.camera_distance, d.camera_min_distance, d.camera_max_distance, box.size.length() * 0.3)
	_home.yaw = yaw
	_home.pitch = pitch
	snap()


## Vista del menú de inicio: vuelve al encuadre inicial, se mece sola, se corre a la derecha
## y no hace caso al jugador (las flechas y el ratón son para el menú).
func set_menu_view(on: bool) -> void:
	_menu_view = on
	_input_enabled = not on
	_sway_t = 0.0
	if on:
		yaw = _home.get("yaw", yaw)
		pitch = _home.get("pitch", pitch)
		center = _home.get("center", center)
		distance = _home.get("distance", distance)


func _set_home(c: Vector3, dist: float, dmin: float, dmax: float, radius: float) -> void:
	_home = {"center": c, "distance": dist, "min": dmin, "max": dmax, "radius": radius}
	center = c
	distance = dist
	min_distance = dmin
	max_distance = dmax
	pan_radius = radius


## Salta al objetivo sin suavizado (tests, capturas, cambio de nivel).
func snap() -> void:
	_cur_yaw = yaw
	_cur_pitch = pitch
	_cur_distance = distance
	_cur_center = center
	_cur_h_offset = _h_offset_goal()
	_apply()


func _h_offset_goal() -> float:
	return -MENU_SHIFT * _cur_distance if _menu_view else 0.0


func _on_focus_changed(anchor: Node) -> void:
	var d := GameState.diorama
	if d == null:
		return
	if anchor == null:
		var box := Visuals.global_aabb(d)
		_set_home(box.get_center(), d.camera_distance, d.camera_min_distance, d.camera_max_distance, box.size.length() * 0.3)
		return
	var it := anchor as Interactable
	var sub := Visuals.global_aabb(it.target)
	var r := sub.size.length()
	_set_home(sub.get_center(), r * 1.5, r * 0.6, r * 3.0, r * 0.3)


## Mira hacia un punto (pistas): gira para verlo de frente y se acerca.
func look_at_point(p: Vector3) -> void:
	var home_center: Vector3 = _home.get("center", center)
	var from_center := p - home_center
	from_center.y = 0.0
	if from_center.length() > 0.05:
		yaw = rad_to_deg(atan2(from_center.x, from_center.z))
	center = home_center.lerp(p, 0.6)
	distance = clampf(distance * 0.75, min_distance, max_distance)


func _process(delta: float) -> void:
	if _input_enabled:
		var v := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
		if v != Vector2.ZERO:
			yaw -= v.x * pad_orbit_deg_per_s * _sensitivity() * delta
			pitch = clampf(pitch - v.y * pad_orbit_deg_per_s * _sensitivity() * _invert() * delta, pitch_min, pitch_max)
		var z := Input.get_axis("zoom_out", "zoom_in")
		if z != 0.0:
			_zoom(1.0 - z * pad_zoom_per_s * delta)
	if _menu_view:
		_sway_t += delta
		yaw = float(_home.get("yaw", 0.0)) + sin(_sway_t * MENU_SWAY_SPEED) * MENU_SWAY_DEG
	var k := 1.0 - exp(-smoothing * delta)
	_cur_yaw = lerpf(_cur_yaw, yaw, k)
	_cur_pitch = lerpf(_cur_pitch, pitch, k)
	_cur_distance = lerpf(_cur_distance, distance, k)
	_cur_center = _cur_center.lerp(center, k)
	_cur_h_offset = lerpf(_cur_h_offset, _h_offset_goal(), k)
	_apply()


func _apply() -> void:
	global_position = _cur_center
	rotation = Vector3(deg_to_rad(-_cur_pitch), deg_to_rad(_cur_yaw), 0.0)
	cam.position = Vector3(0.0, 0.0, _cur_distance)
	cam.h_offset = _cur_h_offset


## Opciones del jugador: multiplicador de giro y eje vertical invertido.
func _sensitivity() -> float:
	return float(Settings.get_value("sensibilidad_camara"))


func _invert() -> float:
	return -1.0 if Settings.get_value("invertir_y") else 1.0


func _zoom(factor: float) -> void:
	distance = clampf(distance * factor, min_distance, max_distance)


func _unhandled_input(e: InputEvent) -> void:
	if GameState.is_dragging or not _input_enabled:
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom(1.0 - zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom(1.0 + zoom_step)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				if mb.pressed:
					_press_pos = mb.position
					_press_button = mb.button_index
					_orbiting = false
					_panning = mb.button_index == MOUSE_BUTTON_MIDDLE or mb.shift_pressed
				elif mb.button_index == _press_button:
					if mb.button_index == MOUSE_BUTTON_LEFT and not _orbiting and not _panning:
						Events.world_clicked.emit(mb.position)
					_press_button = 0
					_orbiting = false
					_panning = false
	elif e is InputEventMouseMotion and _press_button != 0:
		var mm := e as InputEventMouseMotion
		if _panning:
			var right := cam.global_basis.x
			var up := cam.global_basis.y
			var pan_k := distance * 0.0016
			var home_center: Vector3 = _home.get("center", center)
			var moved := center + (-right * mm.relative.x + up * mm.relative.y) * pan_k
			var offset := moved - home_center
			center = home_center + offset.limit_length(pan_radius)
		elif _orbiting or mm.position.distance_to(_press_pos) > drag_threshold_px:
			_orbiting = true
			yaw -= mm.relative.x * orbit_deg_per_px * _sensitivity()
			pitch = clampf(pitch + mm.relative.y * orbit_deg_per_px * _sensitivity() * _invert(), pitch_min, pitch_max)
	elif e is InputEventMagnifyGesture:
		_zoom(1.0 / (e as InputEventMagnifyGesture).factor)
	elif e is InputEventPanGesture:
		var pg := e as InputEventPanGesture
		yaw -= pg.delta.x * 4.0 * _sensitivity()
		pitch = clampf(pitch + pg.delta.y * 4.0 * _sensitivity() * _invert(), pitch_min, pitch_max)
	elif e is InputEventScreenTouch:
		var st := e as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
	elif e is InputEventScreenDrag:
		var sd := e as InputEventScreenDrag
		if _touches.size() == 2 and _touches.has(sd.index):
			var other: Vector2 = _touches[_touches.keys()[1] if _touches.keys()[0] == sd.index else _touches.keys()[0]]
			var before := (_touches[sd.index] as Vector2).distance_to(other)
			var after := sd.position.distance_to(other)
			if before > 1.0 and after > 1.0:
				_zoom(before / after)
		_touches[sd.index] = sd.position
