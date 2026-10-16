class_name Diorama
extends Node3D
## Raíz de cada nivel. Lee la convención de nombres del modelo (NameRules) y monta el puzle:
## huecos blancos, inventario, cajones, piezas escondidas, sub-dioramas y la pintura que despierta.
## Un nivel = una escena con este script en la raíz y el .glb de las artistas dentro, o con la
## ruta del .glb en `modelo` (se carga al empezar: cambiar el arte = dejar el fichero en su sitio).
##
## Secciones (S_<orden>_<nombre>): el diorama se monta por zonas. Solo la sección abierta enseña
## sus piezas; al completarla se pinta entera, se dice su frase si la tiene, y tras una pausa se
## abre la siguiente (se encienden sus luces, sale su rótulo, la cámara la encuadra).
## Desbloqueo: una pieza solo aparece (silueta y bandeja) cuando su sección está abierta, sus
## __after-x están puestas y, si es __clave, todas las demás de su sección también.
## Objetos escondidos (H_): solo aparecen cuando toca encontrarlos; entonces su mueble brilla y se
## mueve (Interactable.set_attention) y la primera vez sale un consejo.

const PAINT_TIME := 0.9                     ## lo que tarda en extenderse la pintura de una pieza (s)
const FINAL_PAINT_TIME := 1.8               ## y la del diorama entero al completarlo
const SECTION_PAINT_TIME := 1.4             ## y la de una sección completa
const SECTION_PAUSE := 1.6                  ## pausa entre completar una sección y abrir la siguiente (s)
const LIGHT_FADE := 1.6                     ## lo que tardan en encenderse las luces de una sección

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
## Al completarlo: fundido a negro y créditos, sin el aviso de "completado" (final de la historia).
@export var fundido_final := false

var slots: Array[PieceSlot] = []
var interactables: Array[Interactable] = []
var sections: Array[Section] = []           ## en orden de apertura
var inventory: Array[StringName] = []       ## una entrada por pieza disponible (repetidas = varias)
var focus: Interactable = null              ## sub-diorama Z_ con zoom activo (null = general)
var completed := false
var model_path := ""                        ## el modelo cargado ("" = venía dentro de la escena)

var _clay_meshes: Array[MeshInstance3D] = []  ## lo que lleva la capa de madera cruda
var _paint_mat: ShaderMaterial              ## esa capa (una para todo el diorama)
var _paint: Array[Dictionary] = []          ## manchas de pintura: {c: centro, r: radio}
var _paint_dirty := false
var _all_painted := false
var _base_scale: Dictionary = {}            ## Node3D -> Vector3
var _pending: Section                       ## sección que se va a abrir (esperando la pausa o sus frases)
var _tips_shown: Dictionary = {}            ## consejos ya dados en este diorama


func _ready() -> void:
	_load_model()
	_scale_lights()
	_scan(self, null, null)
	for s in slots:
		for p in order_rules.get(String(s.id), []):
			s.prereqs.append(StringName(String(p).to_lower()))
	_build_inventory()
	_apply_clay()
	_build_surfaces()
	_setup_sections()
	_link_containers()
	_refresh(false)
	Events.world_clicked.connect(_on_world_clicked)
	GameState.diorama = self
	Narrator.clear()
	Events.level_started.emit(self)
	if intro_key != "":
		Narrator.say(intro_key)


## Los prototipos no viven en el árbol: si no se liberan a mano, se fugan. Y sección y pieza se
## apuntan la una a la otra (un ciclo que nunca se liberaría solo): se corta aquí.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for s in slots:
			if is_instance_valid(s.prototype):
				s.prototype.free()
			s.section = null
		for sec in sections:
			sec.slots.clear()
			sec.interactables.clear()


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


func _scan(n: Node, scope: Interactable, section: Section) -> void:
	for c in n.get_children():
		if c is Interactable:
			continue
		var next_scope := scope
		var next_section := section
		var info: Dictionary = NameRules.parse(c.name) if c is Node3D else {}
		if not info.is_empty():
			if info.kind == NameRules.SECTION:
				next_section = Section.new()
				next_section.setup(c as Node3D, info, sections.size())
				sections.append(next_section)
				_scan(c, scope, next_section)
				continue
			if info.kind == NameRules.PIECE:
				var s := PieceSlot.new()
				s.setup(info.id, c as Node3D, scope)
				s.prereqs = NameRules.values(info.tokens, "after")
				s.is_key = NameRules.has_token(info.tokens, "clave")
				s.flash = NameRules.has_token(info.tokens, "flash")
				s.section = section
				if section != null:
					section.slots.append(s)
				slots.append(s)
				continue                    # no se busca nada dentro de una pieza
			var it := Interactable.new()
			it.setup(self, c as Node3D, info, scope)
			it.section = section
			if section != null:
				section.interactables.append(it)
			interactables.append(it)
			if info.kind == NameRules.PICKUP:
				continue
			if info.kind == NameRules.ZOOM:
				next_scope = it
		_scan(c, next_scope, next_section)


## La primera sección empieza abierta (sin rótulo ni frases); las demás, cerradas y a oscuras.
func _setup_sections() -> void:
	sections.sort_custom(func(a: Section, b: Section) -> bool: return a.order < b.order)
	for i in sections.size():
		var sec := sections[i]
		sec.collect_lights()
		sec.opened = i == 0
		sec.set_lights(sec.opened)
		sec.set_decor(sec.opened)
		for it in sec.interactables:
			if it.kind != NameRules.PICKUP:
				it.set_clickable(sec.opened)


## Cada H_ sabe en qué mueble (OD_/OR_) está guardado:
##  - en un cajón (OD_), el H_ es HIJO del cajón (se mueve con él);
##  - en un armario o un baúl (OR_), el H_ es HERMANO de la puerta o la tapa, dentro del mismo grupo
##    del mueble (si fuera hijo, giraría con la puerta).
## Se busca hacia arriba; no se mira entre los hijos de una sección ni de la raíz (ahí todo es hermano).
func _link_containers() -> void:
	for it in interactables:
		if it.kind != NameRules.PICKUP:
			continue
		var n := it.target.get_parent()
		while n != null and n != self:
			var c := n.get_node_or_null("Interactable") as Interactable
			if c != null and c.is_openable():
				it.container = c
				break
			if n.name != "Modelo" and NameRules.parse(n.name).get("kind", "") != NameRules.SECTION:
				for sib in n.get_children():
					var sc := sib.get_node_or_null("Interactable") as Interactable
					if sc != null and sc.is_openable() and not sib.is_ancestor_of(it.target):
						it.container = sc
						break
				if it.container != null:
					break
			n = n.get_parent()


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


## Ids que se ven en el panel ahora: las del inventario con algún hueco libre y DESBLOQUEADO en el
## ámbito actual (lo que aún no toca no se enseña: así se monta por orden).
func visible_inventory() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in inventory:
		if out.has(id):
			continue
		for s in slots:
			if s.id == id and not s.filled and s.scope == focus and is_unlocked(s):
				out.append(id)
				break
	return out


func prereqs_met(slot: PieceSlot) -> bool:
	for p in slot.prereqs:
		for s in slots:
			if s.id == p and not s.filled:
				return false
	return true


## ¿Toca ya esta pieza? Sección abierta, sus anteriores puestas y, si es clave, todo lo demás de su
## sección también.
func is_unlocked(slot: PieceSlot) -> bool:
	if slot.section != null and not slot.section.opened:
		return false
	if not prereqs_met(slot):
		return false
	if slot.is_key and slot.section != null:
		for s in slot.section.slots:
			if s != slot and not s.filled:
				return false
	return true


## ¿Se está abriendo la sección siguiente? (entre una y otra la bandeja está vacía, pero no "acabada")
func is_opening() -> bool:
	return _pending != null


## ¿Hay algo escondido que ya toca encontrar (en el ámbito actual)?
func has_findable() -> bool:
	for it in interactables:
		if it.kind == NameRules.PICKUP and it.available and not it.collected and it.scope == focus:
			return true
	return false


func _snap_scale() -> float:
	return get_viewport().get_visible_rect().size.y / 720.0


func snap_distance_px() -> float:
	return snap_px * _snap_scale()


## Hueco libre de esa pieza más cercano al cursor, en el ámbito actual. {} si no hay.
func candidate_for(piece_id: StringName, screen_pos: Vector2, cam: Camera3D) -> Dictionary:
	var best := {}
	for s in slots:
		if s.filled or s.id != piece_id or s.scope != focus or not is_unlocked(s):
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
	if slot.flash:
		Events.flash_requested.emit()
	Events.piece_placed.emit(slot.id, slot.node)
	_refresh(true)
	Events.inventory_changed.emit()
	_check_scope(slot.scope)
	_check_sections()
	_check_completed()


func collect(it: Interactable) -> void:
	if it.collected:
		return
	it.collected = true
	it.set_clickable(false)
	it.set_attention(false)
	inventory.append(it.id)
	Sfx.play("pickup")
	Events.piece_collected.emit(it.id, it.target)
	Narrator.say_if_exists("recogido_" + String(it.id))
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(it.target, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(it.target.hide)
	_refresh(true)
	Events.inventory_changed.emit()


## Un cajón o una puerta se ha abierto o cerrado: la atención pasa del mueble a lo de dentro.
func on_container_changed(_it: Interactable) -> void:
	_refresh(true)


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
			if s.filled or s.scope != focus or not inventory.has(s.id) or not is_unlocked(s):
				continue
			if pass_preferred and s.id != preferred:
				continue
			return {"node": s.node, "slot": s, "piece": s.id}
	# Algo escondido que ya toca encontrar: si su mueble está cerrado, se señala el mueble.
	for it in interactables:
		if it.kind == NameRules.PICKUP and it.available and not it.collected and it.scope == focus:
			if it.container != null and not it.container.is_open:
				return {"node": it.container.target, "container": it.container, "pickup": it}
			return {"node": it.target, "pickup": it}
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


# --- Secciones -------------------------------------------------------------------------

## ¿Se ha llenado la sección abierta? Se pinta entera y, tras una pausa (o cuando acabe de hablar
## el objeto que la cerró), se abre la siguiente.
func _check_sections() -> void:
	for i in sections.size():
		var sec := sections[i]
		if not sec.opened or sec.completed or not sec.is_full():
			continue
		sec.completed = true
		for d in sec.decor:                    # sus muebles despiertan (lo de alrededor ya lo pintaron sus piezas)
			var b := Visuals.global_aabb(d)
			_add_paint(b.get_center(), b.size.length() * 0.6 + 0.15, SECTION_PAINT_TIME)
		Events.section_completed.emit(sec)
		if i + 1 < sections.size() and _pending == null:
			_pending = sections[i + 1]
			var wait := maxf(SECTION_PAUSE, Narrator.remaining() + 0.3)
			get_tree().create_timer(wait, false).timeout.connect(_open_pending.bind(_pending))
			Events.inventory_changed.emit()       # la bandeja espera a la sección nueva (no está "vacía")


## Abre la sección que esperaba: luces de la zona, rótulo, cámara y sus frases (si las tiene).
## Sus piezas aparecen cuando acaban esas frases (el epílogo habla antes de enseñar la moneda).
func _open_pending(sec: Section) -> void:
	if sec == null or sec != _pending or sec.opened or sec.opening or not is_inside_tree():
		return
	sec.opening = true
	sec.set_lights(true, LIGHT_FADE)
	sec.set_decor(true, true)
	for it in sec.interactables:
		if it.kind != NameRules.PICKUP:
			it.set_clickable(true)
	Events.section_opened.emit(sec)
	Narrator.say_if_exists("seccion_" + sec.name)
	var talk := Narrator.remaining()
	if talk > 0.05:
		get_tree().create_timer(talk, false).timeout.connect(_reveal_pending.bind(sec))
	else:
		_reveal_pending(sec)


func _reveal_pending(sec: Section) -> void:
	if sec == null or sec != _pending or not is_inside_tree():
		return
	_pending = null
	sec.opened = true
	_refresh(true)
	Events.inventory_changed.emit()


## Pone al día lo que se ve: siluetas de las piezas que ya tocan (con fundido si animate), los
## objetos escondidos que ya toca encontrar y qué mueble u objeto llama la atención.
func _refresh(animate: bool) -> void:
	for s in slots:
		if not s.filled:
			s.set_available(is_unlocked(s), animate)
	var calling: Dictionary = {}                # mueble -> guarda algo que ya toca encontrar
	for it in interactables:
		if it.kind != NameRules.PICKUP:
			continue
		if it.collected:
			it.set_attention(false)
			continue
		var wanted := false
		for s in slots:
			if s.id == it.id and not s.filled and is_unlocked(s):
				wanted = true
				break
		it.set_available(wanted)
		var hidden_inside := it.container != null and not it.container.is_open
		it.set_attention(wanted and not hidden_inside)
		if it.container != null:
			calling[it.container] = calling.get(it.container, false) or (wanted and hidden_inside)
		if wanted and hidden_inside:
			_tip_once("consejo_muebles")
		elif wanted and it.container != null:
			_tip_once("consejo_dentro")
	for c: Interactable in calling:
		c.set_attention(calling[c])


func _tip_once(key: String) -> void:
	if _tips_shown.has(key):
		return
	_tips_shown[key] = true
	Events.tip_requested.emit(key)


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
	for sec in sections:
		sec.opened = true
		sec.completed = true
		sec.set_lights(true)
		sec.set_decor(true)
	_pending = null
	inventory.clear()
	_finish_paint()
	completed = true
	_refresh(false)
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
	var spot := {"c": origin, "r": 0.0}
	_paint.append(spot)
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(r: float) -> void:
		spot.r = r
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
		var packed := PackedVector4Array()
		for e in _paint:
			packed.append(Vector4(e.c.x, e.c.y, e.c.z, e.r))
		_paint_mat.set_shader_parameter("pintura", packed)
		_paint_mat.set_shader_parameter("n_pintura", _paint.size())


## ¿Está ya pintado ese punto? (lo mismo que calcula el shader, sin el borde irregular)
func is_painted_at(p: Vector3) -> bool:
	if _clay_meshes.is_empty() or _all_painted:
		return true
	for e in _paint:
		if p.distance_to(e.c) < float(e.r) * 0.8:
			return true
	return false


## (Tests) Cuántas manchas de pintura hay ahora en el shader.
func paint_spots() -> int:
	return _paint.size()


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

## (Atajo F9) Lo monta entero de golpe: todas las zonas abiertas, cada pieza en su sitio (lo
## escondido ya no hace falta buscarlo), sin frases. Luego el final de siempre (onda de color,
## luces, cámara que se mece) pero sin fundido a negro: se queda a la vista con el panel de fin.
func debug_complete() -> void:
	if completed:
		return
	Narrator.clear()
	fundido_final = false
	while focus != null:
		exit_focus()
	for sec in sections:
		if not sec.opened:
			sec.set_lights(true, LIGHT_FADE)
			sec.set_decor(true, true)
		sec.opening = false
		sec.opened = true
		sec.completed = true
	_pending = null
	for s in slots:
		if not s.filled:
			s.fill()
			for m in s.meshes():
				Visuals.add_surface(m)
	inventory.clear()
	_refresh(false)
	Events.inventory_changed.emit()
	_check_completed()


func debug_solve_step() -> bool:
	if completed:
		return false
	if _pending != null:                        # sin esperar pausas ni frases
		var sec := _pending
		_open_pending(sec)
		_reveal_pending(sec)
		return true
	var h := hint_target()
	if h.has("slot"):
		place(h.slot)
		return true
	for it in interactables:
		if it.kind == NameRules.PICKUP and it.available and not it.collected and it.scope == focus:
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
