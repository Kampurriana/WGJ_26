class_name DioramaCamera
extends Node3D
## Cámara de "plataforma giratoria", fija: el diorama no se desplaza. Solo se gira dentro de los
## límites de cada nivel (Diorama.camera_yaw_min_deg... para no acabar detrás de una pared) y se
## hace un zoom limitado HACIA LO QUE SEÑALA EL CURSOR, para colocar cómodamente las piezas
## pequeñas; al alejar el zoom vuelve sola al encuadre inicial. Ratón, táctil, teclado y mando.
##   Arrastrar (izq. o dcho.) en vacío = girar · rueda/pellizco/Q-E = zoom
##   clic corto = tocar el objeto (Events.world_clicked)

@export var orbit_deg_per_px := 0.3
@export var pad_orbit_deg_per_s := 140.0
@export var zoom_step := 0.12
@export var pad_zoom_per_s := 1.6
@export var smoothing := 10.0
@export var drag_threshold_px := 6.0

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
var yaw_min := -180.0
var yaw_max := 180.0
var pitch_min := 10.0
var pitch_max := 70.0

var _cur_yaw := 25.0
var _cur_pitch := 32.0
var _cur_distance := 7.0
var _cur_center := Vector3.ZERO
var _home := {}                              ## encuadre del ámbito actual (general o rincón Z_)
var _press_pos := Vector2.ZERO
var _press_button := 0
var _orbiting := false
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


func configure(d: Diorama) -> void:
	var box := Visuals.global_aabb(d)
	yaw_min = d.camera_yaw_min_deg
	yaw_max = d.camera_yaw_max_deg
	pitch_min = d.camera_pitch_min_deg
	pitch_max = d.camera_pitch_max_deg
	yaw = clampf(d.camera_yaw_deg, yaw_min, yaw_max)
	pitch = clampf(d.camera_pitch_deg, pitch_min, pitch_max)
	_set_home(box.get_center(), d.camera_distance, d.camera_min_distance, d.camera_max_distance, box.size.length() * 0.35)
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


func home_center() -> Vector3:
	return _home.get("center", center)


func _set_home(c: Vector3, dist: float, dmin: float, dmax: float, radius: float) -> void:
	var keep := {"yaw": _home.get("yaw", yaw), "pitch": _home.get("pitch", pitch)}
	_home = {"center": c, "distance": dist, "min": dmin, "max": dmax, "radius": radius}
	_home.merge(keep)
	center = c
	distance = dist
	min_distance = dmin
	max_distance = dmax


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
		_set_home(box.get_center(), d.camera_distance, d.camera_min_distance, d.camera_max_distance, box.size.length() * 0.35)
		return
	var it := anchor as Interactable
	var sub := Visuals.global_aabb(it.target)
	var r := sub.size.length()
	_set_home(sub.get_center(), r * 1.5, r * 0.6, r * 3.0, r * 0.35)


## Pista: vuelve al encuadre completo y gira (dentro de los límites) para ver el punto de frente.
func look_at_point(p: Vector3) -> void:
	var c := home_center()
	center = c
	distance = float(_home.get("distance", distance))
	var flat := p - c
	flat.y = 0.0
	if flat.length() > 0.05:
		yaw = clampf(rad_to_deg(atan2(flat.x, flat.z)), yaw_min, yaw_max)


func _process(delta: float) -> void:
	if _input_enabled:
		var v := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
		if v != Vector2.ZERO:
			_orbit(-v.x * pad_orbit_deg_per_s * delta, -v.y * pad_orbit_deg_per_s * delta)
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


## Giro con las opciones del jugador (sensibilidad, eje invertido) y SIEMPRE dentro de los límites.
func _orbit(d_yaw: float, d_pitch: float) -> void:
	var s := float(Settings.get_value("sensibilidad_camara"))
	var inv := -1.0 if Settings.get_value("invertir_y") else 1.0
	yaw = clampf(yaw + d_yaw * s, yaw_min, yaw_max)
	pitch = clampf(pitch + d_pitch * s * inv, pitch_min, pitch_max)


## Para capturas y tests: zoom como el de la rueda en ese punto de la pantalla.
func zoom_at(factor: float, screen_pos: Vector2) -> void:
	_zoom(factor, screen_pos)


## Zoom limitado. Al acercar hacia un punto de la pantalla, ese punto se queda bajo el cursor; al
## alejar, el centro vuelve al del encuadre inicial. Nunca hay desplazamiento libre.
func _zoom(factor: float, screen_pos := Vector2(-1, -1)) -> void:
	var old := distance
	distance = clampf(distance * factor, min_distance, max_distance)
	if factor < 1.0 and screen_pos.x >= 0.0 and distance < old:
		var p := _point_under(screen_pos)
		center += (p - center) * (1.0 - distance / old)
	_clamp_center()


## Cuánto puede alejarse el centro del inicial: nada en el encuadre inicial (o más lejos) y como
## mucho `radius` con el zoom al máximo.
func _clamp_center() -> void:
	var c := home_center()
	var span := maxf(float(_home.get("distance", distance)) - min_distance, 0.001)
	var t := clampf((distance - min_distance) / span, 0.0, 1.0)
	center = c + (center - c).limit_length(float(_home.get("radius", 1.0)) * (1.0 - t))


## Punto del diorama bajo el cursor (las superficies); si no hay, el plano que pasa por el centro.
func _point_under(screen_pos: Vector2) -> Vector3:
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0, Visuals.SURFACE_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		return hit.position
	var plane := Plane(-cam.global_basis.z, center)
	var p: Variant = plane.intersects_ray(from, dir)
	return p if p != null else center


func _unhandled_input(e: InputEvent) -> void:
	if GameState.is_dragging or not _input_enabled:
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_zoom(1.0 - zoom_step, mb.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_zoom(1.0 + zoom_step)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				if mb.pressed:
					_press_pos = mb.position
					_press_button = mb.button_index
					_orbiting = false
				elif mb.button_index == _press_button:
					if mb.button_index == MOUSE_BUTTON_LEFT and not _orbiting:
						Events.world_clicked.emit(mb.position)
					_press_button = 0
					_orbiting = false
	elif e is InputEventMouseMotion and _press_button != 0:
		var mm := e as InputEventMouseMotion
		if _orbiting or mm.position.distance_to(_press_pos) > drag_threshold_px:
			_orbiting = true
			_orbit(-mm.relative.x * orbit_deg_per_px, mm.relative.y * orbit_deg_per_px)
	elif e is InputEventMagnifyGesture:
		_zoom(1.0 / (e as InputEventMagnifyGesture).factor, get_viewport().get_mouse_position())
	elif e is InputEventPanGesture:
		var pg := e as InputEventPanGesture
		_orbit(-pg.delta.x * 4.0, pg.delta.y * 4.0)
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
				_zoom(before / after, (sd.position + other) * 0.5)
		_touches[sd.index] = sd.position
