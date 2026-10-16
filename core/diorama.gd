class_name Diorama
extends Node3D
## Raíz de cada nivel. Lee la convención de nombres del modelo (NameRules) y monta el puzle:
## huecos blancos, inventario, cajones, piezas escondidas, sub-dioramas y la pintura que despierta.
## Un nivel = una escena con este script en la raíz y el .glb de las artistas dentro, o con la
## ruta del .glb en `modelo` (se carga al empezar: cambiar el arte = dejar el fichero en su sitio).

const PAINT_TIME := 0.9                     ## lo que tarda en extenderse la pintura de una pieza (s)
const FINAL_PAINT_TIME := 1.8               ## y la del diorama entero al completarlo

@export var level_title := "Diorama"
## Modelo del diorama: un .glb (o escena) con la convención de nombres. Si el fichero existe, se
## carga como hijo "Modelo" antes de leer los nombres. Si no existe, se usa `modelo_provisional`.
## Los dos vacíos = el nivel ya trae el modelo dentro de la escena.
@export_file("*.glb", "*.gltf", "*.tscn", "*.scn") var modelo := ""
@export_file("*.glb", "*.gltf", "*.tscn", "*.scn") var modelo_provisional := ""
## Multiplica la energía de todas las luces del modelo (las de Blender llegan con otras unidades:
## si salen muy fuertes o muy flojas, se ajusta aquí sin reexportar).
@export_range(0.0, 20.0) var escala_luces := 1.0
@export var intro_key := ""                 ## clave de narración al empezar ("" = nada)
@export var outro_key := ""                 ## clave de narración al completar
@export var color_radius := 1.4             ## radio (m) que se colorea alrededor de cada pieza
@export var snap_px := 70.0                 ## tolerancia de encaje, en píxeles a 720p
@export var camera_distance := 7.0
@export var camera_min_distance := 2.5
@export var camera_max_distance := 12.0
@export var camera_pitch_deg := 32.0
@export var camera_yaw_deg := 25.0
## Límites de giro (grados): el jugador no puede salirse de ellos. Elegirlos para que la cámara
## nunca quede detrás de una pared ni deje de ver el diorama.
@export var camera_yaw_min_deg := -35.0
@export var camera_yaw_max_deg := 85.0
@export var camera_pitch_min_deg := 12.0
@export var camera_pitch_max_deg := 65.0
@export var order_rules: Dictionary = {}    ## {"taza": ["mesa"]} = la taza va después de la mesa
@export var inventory_seed := 7
## Luz propia de este nivel (una escena de iluminacion/). Vacío = la de por defecto.
@export_file("*.tscn") var iluminacion := ""

var slots: Array[PieceSlot] = []
var interactables: Array[Interactable] = []
var inventory: Array[StringName] = []       ## una entrada por pieza disponible (repetidas = varias)
var focus: Interactable = null              ## sub-diorama Z_ con zoom activo (null = general)
var completed := false
var model_path := ""                        ## el modelo cargado ("" = venía dentro de la escena)

var _clay_meshes: Array[MeshInstance3D] = []  ## lo que lleva la capa de madera cruda
var _paint_mat: ShaderMaterial              ## esa capa (una para todo el diorama)
var _paint: Array[Vector4] = []             ## manchas de pintura: centro xyz + radio w
var _paint_dirty := false
var _all_painted := false
var _base_scale: Dictionary = {}            ## Node3D -> Vector3


func _ready() -> void:
	_load_model()
	_scale_lights()
	_scan(self, null)
	for s in slots:
		for p in order_rules.get(String(s.id), []):
			s.prereqs.append(StringName(String(p).to_lower()))
	_build_inventory()
	_apply_clay()
	_build_surfaces()
	Events.world_clicked.connect(_on_world_clicked)
	GameState.diorama = self
	Events.level_started.emit(self)
	if intro_key != "":
		Narrator.say(intro_key)


## Los prototipos no viven en el árbol: si no se liberan a mano, se fugan.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for s in slots:
			if is_instance_valid(s.prototype):
				s.prototype.free()


# --- Lectura del modelo ---------------------------------------------------------------

func _load_model() -> void:
	var path := modelo if modelo != "" and ResourceLoader.exists(modelo) else modelo_provisional
	if path == "":
		return
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Diorama '%s': no puedo cargar el modelo %s" % [name, path])
		return
	var inst := scene.instantiate()
	inst.name = "Modelo"
	add_child(inst)
	model_path = path
	if path == modelo_provisional and modelo != "":
		print("Diorama '%s': uso el modelo provisional (cuando exista %s, se usará ese)" % [name, modelo])


func _scale_lights() -> void:
	if is_equal_approx(escala_luces, 1.0):
		return
	for l in find_children("*", "Light3D", true, false):
		(l as Light3D).light_energy *= escala_luces


func _scan(n: Node, scope: Interactable) -> void:
	for c in n.get_children():
		if c is Interactable:
			continue
		var next_scope := scope
		var info: Dictionary = NameRules.parse(c.name) if c is Node3D else {}
		if not info.is_empty():
			if info.kind == NameRules.PIECE:
				var s := PieceSlot.new()
				s.setup(info.id, c as Node3D, scope)
				s.prereqs = NameRules.values(info.tokens, "after")
				slots.append(s)
				continue                    # no se busca nada dentro de una pieza
			var it := Interactable.new()
			it.setup(self, c as Node3D, info, scope)
			interactables.append(it)
			if info.kind == NameRules.PICKUP:
				continue
			if info.kind == NameRules.ZOOM:
				next_scope = it
		_scan(c, next_scope)


func _build_inventory() -> void:
	var counts: Dictionary = {}
	for s in slots:
		counts[s.id] = counts.get(s.id, 0) + 1
	for it in interactables:
		var given := it.id if it.kind == NameRules.PICKUP else it.reward
		if given == &"":
			continue
		if not counts.has(given):
			push_warning("Diorama '%s': %s da la pieza '%s' pero no hay ningún hueco P_%s" % [name, it.target.name, given, given])
			continue
		counts[given] -= 1
	for id: StringName in counts:
		for i in maxi(0, counts[id]):
			inventory.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = inventory_seed
	for i in range(inventory.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := inventory[i]
		inventory[i] = inventory[j]
		inventory[j] = tmp


func _apply_clay() -> void:
	var skip: Dictionary = {}
	for s in slots:
		for m in s.meshes():
			skip[m] = true
	for it in interactables:
		if it.kind == NameRules.PICKUP:      # lo escondido se queda en color: es lo que se busca
			for m in Visuals.meshes_under(it.target):
				skip[m] = true
	_paint_mat = Visuals.make_clay_overlay()
	for m in Visuals.meshes_under(self):
		if skip.has(m):
			continue
		m.material_overlay = _paint_mat
		_clay_meshes.append(m)


## Todo lo que se ve y no es un hueco pendiente ni algo escondido es "superficie": la pieza en
## mano no lo atraviesa. Las piezas pasan a serlo al colocarse (place / complete_silently).
func _build_surfaces() -> void:
	var skip: Dictionary = {}
	for s in slots:
		for m in s.meshes():
			skip[m] = true
	for it in interactables:
		if it.kind == NameRules.PICKUP:
			for m in Visuals.meshes_under(it.target):
				skip[m] = true
	for m in Visuals.meshes_under(self):
		if not skip.has(m):
			Visuals.add_surface(m)


# --- Consultas -------------------------------------------------------------------------

func prototype_for(id: StringName) -> Node3D:
	for s in slots:
		if s.id == id:
			return s.prototype
	return null


func reference_node_for(id: StringName) -> Node3D:
	for s in slots:
		if s.id == id and not s.filled:
			return s.node
	for s in slots:
		if s.id == id:
			return s.node
	return null


func count_of(id: StringName) -> int:
	return inventory.count(id)


## Ids que se ven en el panel ahora: las del inventario con algún hueco libre en el ámbito actual.
func visible_inventory() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in inventory:
		if out.has(id):
			continue
		for s in slots:
			if s.id == id and not s.filled and s.scope == focus:
				out.append(id)
				break
	return out


func prereqs_met(slot: PieceSlot) -> bool:
	for p in slot.prereqs:
		for s in slots:
			if s.id == p and not s.filled:
				return false
	return true


func _snap_scale() -> float:
	return get_viewport().get_visible_rect().size.y / 720.0


func snap_distance_px() -> float:
	return snap_px * _snap_scale()


## Hueco libre de esa pieza más cercano al cursor, en el ámbito actual. {} si no hay.
func candidate_for(piece_id: StringName, screen_pos: Vector2, cam: Camera3D) -> Dictionary:
	var best := {}
	for s in slots:
		if s.filled or s.id != piece_id or s.scope != focus:
			continue
		var c := s.center()
		if cam.is_position_behind(c):
			continue
		var d := cam.unproject_position(c).distance_to(screen_pos)
		if best.is_empty() or d < best.dist:
			best = {"slot": s, "dist": d}
	return best


# --- Acciones del jugador ---------------------------------------------------------------

func try_place(piece_id: StringName, screen_pos: Vector2, cam: Camera3D) -> bool:
	if not inventory.has(piece_id):
		return false
	var c := candidate_for(piece_id, screen_pos, cam)
	if c.is_empty() or c.dist > snap_distance_px():
		Events.piece_rejected.emit(piece_id, "lejos")
		return false
	var slot: PieceSlot = c.slot
	if not prereqs_met(slot):
		Events.piece_rejected.emit(piece_id, "orden")
		Narrator.say("orden")
		return false
	place(slot)
	return true


func place(slot: PieceSlot) -> void:
	slot.fill()
	for m in slot.meshes():
		Visuals.add_surface(m)
	inventory.erase(slot.id)
	_pop(slot.node)
	_reveal_around(slot.center())
	_play_animation(String(slot.id) + "_placed")
	Sfx.play("snap")
	Narrator.say_if_exists("pieza_" + String(slot.id))
	Events.piece_placed.emit(slot.id, slot.node)
	Events.inventory_changed.emit()
	_check_scope(slot.scope)
	_check_completed()


func collect(it: Interactable) -> void:
	if it.collected:
		return
	it.collected = true
	it.set_clickable(false)
	inventory.append(it.id)
	Sfx.play("pickup")
	Events.piece_collected.emit(it.id, it.target)
	Narrator.say_if_exists("recogido_" + String(it.id))
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(it.target, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(it.target.hide)
	Events.inventory_changed.emit()


func enter_focus(anchor: Interactable) -> void:
	if anchor.completed or focus == anchor:
		return
	if focus != null:
		focus.set_clickable(true)
	focus = anchor
	anchor.set_clickable(false)
	Sfx.play("zoom_in")
	Events.focus_changed.emit(anchor)
	Events.inventory_changed.emit()


func exit_focus() -> void:
	if focus == null:
		return
	var leaving := focus
	focus = leaving.scope
	if not leaving.completed:
		leaving.set_clickable(true)
	if focus != null:
		focus.set_clickable(false)
	Sfx.play("zoom_out")
	Events.focus_changed.emit(focus)
	Events.inventory_changed.emit()


func _on_world_clicked(screen_pos: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var it := pick_interactable(screen_pos, cam)
	if it != null:
		it.activate()


## Rayo desde la cámara. Si el primer impacto es un cajón ABIERTO y detrás hay una pieza
## escondida que vive dentro de él, gana la pieza (si no, nunca se podría coger).
func pick_interactable(screen_pos: Vector2, cam: Camera3D) -> Interactable:
	var space := get_world_3d().direct_space_state
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 200.0
	var hits: Array[Interactable] = []
	var exclude: Array[RID] = []
	for i in 4:
		var q := PhysicsRayQueryParameters3D.create(from, to, Visuals.CLICK_LAYER)
		q.exclude = exclude
		var r := space.intersect_ray(q)
		if r.is_empty():
			break
		exclude.append(r.rid)
		if r.collider is Interactable:
			hits.append(r.collider)
	if hits.is_empty():
		return null
	var first := hits[0]
	if first.is_openable() and first.is_open:
		for h in hits.slice(1):
			if h.kind == NameRules.PICKUP and first.target.is_ancestor_of(h.target):
				return h
	return first


# --- Pistas -----------------------------------------------------------------------------

## Qué enseñar al pedir pista: {node, slot?, piece?}. Prioridad: la pieza que el jugador
## tiene señalada; si no, cualquiera que ya encaje; si no, algo escondido; si no, un sub-diorama.
func hint_target(preferred: StringName = &"") -> Dictionary:
	for pass_preferred in [true, false]:
		if pass_preferred and preferred == &"":
			continue
		for s in slots:
			if s.filled or s.scope != focus or not inventory.has(s.id) or not prereqs_met(s):
				continue
			if pass_preferred and s.id != preferred:
				continue
			return {"node": s.node, "slot": s, "piece": s.id}
	for it in interactables:
		if it.kind == NameRules.PICKUP and not it.collected and it.scope == focus:
			return {"node": it.target}
	for it in interactables:
		if it.kind == NameRules.ZOOM and not it.completed and it.scope == focus:
			return {"node": it.target}
	return {}


# --- Progreso ---------------------------------------------------------------------------

func _check_scope(scope: Interactable) -> void:
	if scope == null or scope.completed:
		return
	for s in slots:
		if s.scope == scope and not s.filled:
			return
	scope.completed = true
	if scope.reward != &"":
		inventory.append(scope.reward)
	Narrator.say_if_exists("sub_completo")
	Events.inventory_changed.emit()
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if focus == scope:
			exit_focus())


func _check_completed() -> void:
	if completed:
		return
	for s in slots:
		if not s.filled:
			return
	completed = true
	var box := Visuals.global_aabb(self)
	_add_paint(box.get_center(), box.size.length() * 0.75, FINAL_PAINT_TIME)
	get_tree().create_timer(FINAL_PAINT_TIME + 0.1, false).timeout.connect(_finish_paint)
	_play_animation("celebrar")
	Sfx.play("complete")
	if outro_key != "":
		Narrator.say(outro_key)
	Events.level_completed.emit(self)


## Lo deja terminado al instante, sin sonidos, frases ni señales de completado (el menú del
## título cuando ya se resolvió en otra partida).
func complete_silently() -> void:
	for s in slots:
		if not s.filled:
			s.fill(false)
			for m in s.meshes():
				Visuals.add_surface(m)
	inventory.clear()
	_finish_paint()
	completed = true
	Events.inventory_changed.emit()


# --- Pintura: la madera cruda se pinta en manchas que crecen desde cada pieza ------------

func _reveal_around(origin: Vector3) -> void:
	_add_paint(origin, color_radius, PAINT_TIME)


## Una mancha de pintura que crece desde `origin` hasta `radius` en `seconds`. Si ya no caben más
## en el shader, lo de alrededor se pinta de golpe (sin onda): se nota menos que quedarse sin color.
func _add_paint(origin: Vector3, radius: float, seconds: float) -> void:
	if _clay_meshes.is_empty():
		return
	if _paint.size() >= Visuals.MAX_PAINT:
		push_warning("Diorama '%s': más de %d manchas de pintura; pinto de golpe" % [name, Visuals.MAX_PAINT])
		for m in _clay_meshes:
			if Visuals.global_aabb(m).get_center().distance_to(origin) <= radius:
				m.material_overlay = null
		return
	_paint.append(Vector4(origin.x, origin.y, origin.z, 0.0))
	var i := _paint.size() - 1
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(r: float) -> void:
		_paint[i].w = r
		_paint_dirty = true, 0.0, radius, seconds)


## Todo pintado: se quita la capa de madera (dibujarla ya no aporta nada y cuesta).
func _finish_paint() -> void:
	_all_painted = true
	for m in _clay_meshes:
		if is_instance_valid(m):
			m.material_overlay = null
	if _paint_mat != null:
		_paint_mat.set_shader_parameter("todo_pintado", 1.0)


func _process(_delta: float) -> void:
	if _paint_dirty:
		_paint_dirty = false
		_paint_mat.set_shader_parameter("pintura", PackedVector4Array(_paint))
		_paint_mat.set_shader_parameter("n_pintura", _paint.size())


## ¿Está ya pintado ese punto? (lo mismo que calcula el shader, sin el borde irregular)
func is_painted_at(p: Vector3) -> bool:
	if _clay_meshes.is_empty() or _all_painted:
		return true
	for e in _paint:
		if p.distance_to(Vector3(e.x, e.y, e.z)) < e.w * 0.8:
			return true
	return false


func has_unpainted_layer() -> bool:
	for m in _clay_meshes:
		if is_instance_valid(m) and m.material_overlay != null:
			return true
	return false


## Parte montada del diorama, de 0 a 1 (la luz despierta con ella).
func progress() -> float:
	if slots.is_empty():
		return 1.0 if completed else 0.0
	var n := 0
	for s in slots:
		n += 1 if s.filled else 0
	return float(n) / slots.size()


func _pop(n: Node3D) -> void:
	if not _base_scale.has(n):
		_base_scale[n] = n.scale
	var base: Vector3 = _base_scale[n]
	n.scale = base * 1.2
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "scale", base, 0.35)


func _play_animation(anim: String) -> void:
	for p in find_children("*", "AnimationPlayer", true, false):
		var player := p as AnimationPlayer
		if player.has_animation(anim):
			player.play(anim)


# --- Para tests y capturas: un paso de "jugador automático" ------------------------------

func debug_solve_step() -> bool:
	if completed:
		return false
	var h := hint_target()
	if h.has("slot"):
		place(h.slot)
		return true
	for it in interactables:
		if it.kind == NameRules.PICKUP and not it.collected and it.scope == focus:
			collect(it)
			return true
	for it in interactables:
		if it.kind == NameRules.ZOOM and not it.completed and it.scope == focus:
			enter_focus(it)
			return true
	if focus != null:
		exit_focus()
		return true
	return false
