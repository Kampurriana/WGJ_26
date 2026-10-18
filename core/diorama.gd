class_name Diorama
extends Node3D
## Raíz de cada nivel. Lee la convención de nombres del modelo (NameRules) y monta el puzle:
## huecos blancos, inventario, cajones, piezas escondidas, sub-dioramas y la pintura que despierta.
## Un nivel = una escena con este script en la raíz y el .glb de las artistas dentro, o con la
## ruta del .glb en `modelo` (se carga al empezar: cambiar el arte = dejar el fichero en su sitio).
##
## Secciones (S_<orden>_<nombre>): el diorama se monta por zonas. Solo se ve la sección abierta (y
## las ya hechas): de las demás no se ve nada, ni siluetas ni muebles. Al completarla se pinta
## entera, se dice su frase si la tiene, y tras una pausa se abre la siguiente (aparecen sus
## muebles, se encienden sus luces, sale el rótulo de capítulo, la cámara la encuadra y sus
## siluetas se materializan).
## Desbloqueo: una pieza se puede poner (silueta clara, ficha activa en la bandeja) cuando su
## sección está abierta, sus __after-x están puestas y, si es __clave, todas las demás de su sección
## también. Mientras no, su silueta va tenue y su ficha, con candado y el porqué (lock_reason).
## Objetos escondidos (H_): solo aparecen cuando toca encontrarlos; entonces su mueble brilla y se
## mueve (Interactable.set_attention) y la primera vez sale un consejo.
## Dibujos escondidos (C_, cuarta nota): coleccionables que no hacen falta para acabar. Están por el
## desván (dentro de muebles, debajo de la cama...) desde que se abre su zona; al tocar uno se
## levanta, vuela hasta la cuerda (T_) y se cuelga en la siguiente pinza, y sale un aviso de logro
## ("3 de 7"). El que viene con una pieza (con-camara) se encuentra solo al acabar su momento.

const PAINT_TIME := 0.9                     ## lo que tarda en extenderse la pintura de una pieza (s)
const FINAL_PAINT_TIME := 1.8               ## y la del diorama entero al completarlo
const SECTION_PAINT_TIME := 1.4             ## y la de una sección completa
const SECTION_PAUSE := 1.6                  ## pausa entre completar una sección y abrir la siguiente (s)
const ACT_FADE := 0.5                        ## (cambio de acto) lo que tarda la voz en apagarse si el jugador sigue
const COMPLETE_SOUND := "completar_puzzle"   ## al completar el puzle (Drive FXS, «COMPLETAR PUZZLE»)
const STORE_SOUND := "guardar_inventario"    ## al coger lo que va a la bandeja (Drive FXS, «GUARDAR OBJETO EN EL INVENTARIO»)
## Al abrirse un capítulo (una sección con rótulo), primero el rótulo; sus cosas (muebles y siluetas)
## aparecen cuando se empieza a ir (Hud.show_chapter: a los 3,8 s), creciendo una tras otra con el
## sonido de Drive FXS «Cuando aparecen las cosas del capitulo» (aparecer_capitulo). Pedido del 18-oct.
const CHAPTER_REVEAL := 3.6
const LIGHT_FADE := 1.6                     ## lo que tardan en encenderse las luces de una sección
const POP_TIME := 0.35                      ## el saltito de una pieza al encajar (crece y vuelve)
const LIFT_TIME := 0.45                     ## un dibujo encontrado se levanta de donde estaba...
const HANG_TIME := 1.3                      ## ...vuela en arco hasta su pinza...
const SWING_TIME := 2.4                     ## ...y se balancea en la cuerda hasta quedarse quieto (s)
const GIVEN_DELAY := 0.7                    ## lo que espera el dibujo que viene con una pieza tras su momento (s)
const TWIN_STEP := 0.07                     ## una pieza repetida se pone en todos sus huecos, uno tras otro (s)
## Piezas que suenan como otra al encajar (Sfx: colocar_<id>): la cumbrera es una viga más del techo.
const SUENA_COMO := {&"cumbrera": "viga", &"pilar": "viga", &"poste": "viga", &"correa": "viga",
	&"borde_suelo": "tablon", &"rodapie": "pared", &"moldura": "pared"}
const WORKBENCH_WAIT := 0.8                  ## (Z_ __monta) lo que se ve montado antes de irse a la bandeja (s)

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
## Momentos de la historia (core/momentos.gd): al colocar un objeto con frase, la cámara se le acerca
## y la pantalla se enmarca mientras habla.
@export var momentos := false

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
var clothesline: Node3D                     ## la cuerda de los dibujos (T_); null = no hay
var _spots: Array[Node3D] = []              ## sus pinzas, en orden: el n-ésimo dibujo encontrado va a la n-ésima
var _given: Array[Interactable] = []        ## dibujos que vienen con una pieza, esperando a que acabe su momento
var _given_wait := 0.0
var _held: Dictionary = {}                  ## dibujos encontrados que se están mirando (ui/inspeccion.gd) -> su pinza
## (Momentos) Mientras sea true, la sección siguiente no se abre sola al acabar la pausa: espera
## (el final no se abre encima del espejo; lo abre la transición con open_pending_now).
var hold_sections := false
var _waiting_act: Section                    ## (cambio de acto) el acto siguiente, esperando a que el jugador siga


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
	Events.piece_drag_started.connect(_pulse_slots_for)
	Events.piece_drag_ended.connect(func(_id: StringName, _placed: bool) -> void: _pulse_slots_for(&""))
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
			if info.kind == NameRules.LINE:
				clothesline = c as Node3D
				_spots.clear()
				for k in c.get_children():
					if k is Node3D and String(k.name).begins_with("Pinza"):
						_spots.append(k)
				_spots.sort_custom(func(a: Node3D, b: Node3D) -> bool: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
				continue
			if info.kind == NameRules.PIECE:
				var s := PieceSlot.new()
				s.setup(info.id, c as Node3D, scope)
				s.prereqs = NameRules.values(info.tokens, "after")
				s.is_key = NameRules.has_token(info.tokens, "clave")
				s.flash = NameRules.has_token(info.tokens, "flash")
				s.reflejo = NameRules.has_token(info.tokens, "reflejo")
				s.offered = NameRules.has_token(info.tokens, "ofrecida")
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
			if it.is_hidden_item():
				continue
			if info.kind == NameRules.ZOOM:
				next_scope = it
		_scan(c, next_scope, next_section)


## La primera sección empieza abierta (sin rótulo ni frases); las demás, cerradas: ocultas y a oscuras.
func _setup_sections() -> void:
	sections.sort_custom(func(a: Section, b: Section) -> bool: return a.order < b.order)
	for i in sections.size():
		var sec := sections[i]
		sec.collect_lights()
		sec.opened = i == 0
		sec.set_lights(sec.opened)
		sec.set_decor(sec.opened)
		for it in sec.interactables:
			if not it.is_hidden_item():
				it.set_clickable(sec.opened)


## Cada H_ sabe en qué mueble (OD_/OR_) está guardado:
##  - en un cajón (OD_), el H_ es HIJO del cajón (se mueve con él);
##  - en un armario o un baúl (OR_), el H_ es HERMANO de la puerta o la tapa, dentro del mismo grupo
##    del mueble (si fuera hijo, giraría con la puerta).
## Se busca hacia arriba; no se mira entre los hijos de una sección ni de la raíz (ahí todo es hermano).
func _link_containers() -> void:
	for it in interactables:                  # un mueble que lleva piezas suyas dentro (su cajón): no se abre sin ellas
		if it.is_openable():
			for s in slots:
				if it.target.is_ancestor_of(s.node):
					it.inside.append(s)
			it.refresh_clickable()
	for it in interactables:
		if not it.is_hidden_item():
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
		if it.is_hidden_item():              # lo escondido se queda en color: es lo que se busca
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
		if it.is_hidden_item():
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


## Lo que enseña la bandeja: TODAS las piezas que faltan en el ámbito actual (una entrada por id),
## por orden de sección y, dentro de cada una, primero las que ya se pueden poner.
## {id, count, locked, reason, section}: locked = aún no se puede poner; reason = por qué.
func tray_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for s in slots:
		if s.filled or s.scope != focus or seen.has(s.id) or s.offered:
			continue                             # lo ofrecido no va a la bandeja: aparece en la escena
		seen[s.id] = true
		var reason := lock_reason(s.id)
		var missing := slots.filter(func(o: PieceSlot) -> bool: return o.id == s.id and not o.filled and o.scope == focus).size()
		out.append({"id": s.id, "count": count_of(s.id) if reason == "" else missing, "locked": reason != "",
			"reason": reason, "section": s.section, "_i": out.size()})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := sections.find(a.section)
		var sb := sections.find(b.section)
		if sa != sb:
			return sa < sb
		if a.locked != b.locked:
			return not a.locked
		return a._i < b._i)
	return out


## Por qué no se puede poner todavía esa pieza ("" = sí se puede). Es lo que lee el jugador al
## tocar una ficha con candado: le orienta hacia lo que va antes.
func lock_reason(id: StringName) -> String:
	var first: PieceSlot = null
	for s in slots:
		if s.filled or s.id != id or s.scope != focus:
			continue
		if is_unlocked(s):
			return "" if inventory.has(id) else _hidden_reason(id)
		if first == null:
			first = s
	if first == null:
		return tr("Ya está puesta.")
	var sec := first.section
	if sec != null and not sec.opened:
		if sec == _pending:
			return tr("Ya casi: se está abriendo «%s».") % section_title(sec)
		var i := sections.find(sec)
		return tr("Es de «%s». Se abre al terminar «%s».") % [section_title(sec), section_title(sections[i - 1])] if i > 0 \
			else tr("Es de «%s».") % section_title(sec)
	var before: PackedStringArray = []
	for p in first.prereqs:
		for o in slots:
			if o.id == p and not o.filled:
				before.append(Narrator.piece_name(p))
				break
	if not before.is_empty():
		return tr("Antes tiene que estar %s.") % tr(" y ").join(before)
	if first.is_key and sec != null:
		var left := sec.slots.filter(func(o: PieceSlot) -> bool: return o != first and not o.filled).size()
		return tr("Va la última de «%s»: antes, %s.") % [section_title(sec), tr("la que falta") if left == 1 else tr("las %d que faltan") % left]
	return tr("Todavía no.")


## Una pieza que ya toca pero no está en la bandeja: está guardada (H_) o se gana en un rincón (Z_).
func _hidden_reason(id: StringName) -> String:
	for it in interactables:
		if it.kind == NameRules.PICKUP and it.id == id and not it.collected:
			if it.container != null and not it.container.is_open:
				return tr("Está guardada en un mueble: toca el que brilla.")
			return tr("Está a la vista: tócala para cogerla.")
		if it.kind == NameRules.ZOOM and it.reward == id and not it.completed:
			return tr("Se consigue al completar un rincón.")
	return tr("Todavía no.")


## Nombre de una sección para la interfaz ("I · Infancia"); si no tiene rótulo, su nombre.
func section_title(sec: Section) -> String:
	var t := Narrator.text("titulo_" + sec.name)
	return t if t != "" else sec.name.capitalize()


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


## Pone la pieza en ese hueco y, si es repetida, también en sus gemelos (twins_of): con soltar un
## tablón se completan todos los iguales (sexta nota). Cuentan como puestos al momento; se ven
## encajar uno tras otro, del más cercano al más lejano.
func place(slot: PieceSlot) -> void:
	var twins := twins_of(slot)
	slot.filled = true
	inventory.erase(slot.id)
	for t in twins:
		t.filled = true                          # ya puesta para el juego; su silueta espera su turno
		inventory.erase(t.id)
	_show_placed(slot)
	for it in interactables:                  # su mueble (el cajón ya puesto) se puede abrir
		if it.inside.has(slot) or twins.any(func(t: PieceSlot) -> bool: return it.inside.has(t)):
			it.refresh_clickable()
	var sound := place_sound(slot.id)
	for i in twins.size():                     # (los sonidos propios ya traen varios golpes: uno por gesto)
		create_tween().tween_callback(_show_placed.bind(twins[i], sound == "colocar")).set_delay((i + 1) * TWIN_STEP)
	Narrator.say_if_exists("pieza_" + String(slot.id))
	if slot.flash:
		Events.flash_requested.emit()
	_refresh(true)
	Events.inventory_changed.emit()
	_check_scope(slot.scope)
	_check_sections()
	_check_completed()


## Los huecos libres iguales a ese (mismo id, mismo ámbito, ya desbloqueados) que se llenan con él,
## del más cercano al más lejano; tantos como piezas de ese id queden en el inventario.
func twins_of(slot: PieceSlot) -> Array[PieceSlot]:
	var out: Array[PieceSlot] = []
	for s in slots:
		if s != slot and s.id == slot.id and not s.filled and s.scope == slot.scope and is_unlocked(s):
			out.append(s)
	var c := slot.center()
	out.sort_custom(func(a: PieceSlot, b: PieceSlot) -> bool: return a.center().distance_to(c) < b.center().distance_to(c))
	out.resize(mini(out.size(), maxi(0, inventory.count(slot.id) - 1)))
	return out


## El sonido de una pieza al encajar: colocar_<id>, o el de la primera parte de su id (tablon_largo →
## colocar_tablon; pared_fondo → colocar_pared), o el de la pieza a la que suena (SUENA_COMO); si no hay,
## colocar. Los del desván son de Drive FXS (18-oct).
func place_sound(id: StringName) -> String:
	var base := String(SUENA_COMO.get(id, id))
	while not base.is_empty() and not Sfx.has("colocar_" + base):
		base = base.left(maxi(base.rfind("_"), 0))
	return "colocar_" + base if not base.is_empty() else "colocar"


## Lo que se ve al encajar una pieza: deja de ser silueta, salta, pinta alrededor y avisa (efectos,
## cámara, momentos). En las gemelas llega un poco después que en la que soltó el jugador; suenan
## también si su sonido es el corto de siempre (`sound`), no si es uno propio de varios golpes.
func _show_placed(slot: PieceSlot, sound := true) -> void:
	slot.fill()
	for m in slot.meshes():
		Visuals.add_surface(m)
	if not slot.offered:                        # la moneda entra en la hucha sin saltito: el final es quieto
		_pop(slot.node)
	_reveal_around(slot.center())
	_play_animation(String(slot.id) + "_placed")
	if sound:
		Sfx.play(place_sound(slot.id))
	Events.piece_placed.emit(slot.id, slot.node)


func collect(it: Interactable) -> void:
	if it.collected:
		return
	it.collected = true
	it.set_clickable(false)
	it.set_attention(false)
	inventory.append(it.id)
	Sfx.play(STORE_SOUND, 0.03)
	Events.piece_collected.emit(it.id, it.target)
	Narrator.say_if_exists("recogido_" + String(it.id))
	# El objeto se encoge donde estaba y su ficha vuela por la pantalla hasta la bandeja (Hud).
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(it.target, "scale", Vector3.ONE * 0.01, 0.25)
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
	Visuals.stop_growing(anchor.target)          # si aún estaba apareciendo, ya entero: la cámara lo encuadra por su tamaño
	for s in slots:
		if s.scope == anchor:
			Visuals.stop_growing(s.node)
	Sfx.play("zoom_in")
	_refresh(true)                               # (dentro de un rincón, el rincón ya no llama)
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
	_refresh(true)
	Events.focus_changed.emit(focus)
	Events.inventory_changed.emit()


## Mientras se arrastra una pieza, laten las siluetas donde puede ir ("aquí"). &"" = ninguna.
## Las piezas repetidas (un tablón vale en varios huecos, no en todos) no laten: encontrar dónde va
## su juego (largo, medio o corto) es el reto (quinta nota: "crea una cierta complejidad"); al
## soltarla bien se ponen todas las iguales (sexta nota, place).
func _pulse_slots_for(id: StringName) -> void:
	var guide := id != &"" and slots.filter(func(o: PieceSlot) -> bool: return o.id == id).size() == 1
	for s in slots:
		if not s.filled:
			s.set_pulse(guide and s.id == id and s.scope == focus and is_unlocked(s))


func _on_world_clicked(screen_pos: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var it := pick_interactable(screen_pos, cam)
	if it != null:
		it.activate()


## Rayo desde la cámara. Si el primer impacto es un cajón ABIERTO y detrás hay una pieza o un dibujo
## escondido que vive dentro de él, gana lo de dentro (si no, nunca se podría coger).
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
			if h.is_hidden_item() and (h.container == first or first.target.is_ancestor_of(h.target)):
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
				if not it.container.pieces_ready():
					continue                     # primero hay que poner el cajón (su hueco ya salió arriba)
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
	if scope.workbench:                         # lo montado se va a la bandeja: se pone en su sitio del desván
		scope.set_attention(false)
		get_tree().create_timer(WORKBENCH_WAIT, false).timeout.connect(_send_to_tray.bind(scope))
	Narrator.say_if_exists("sub_completo")
	Events.inventory_changed.emit()
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if focus == scope:
			exit_focus())


## (Z_ __monta) Lo montado en el banco se encoge donde estaba y su ficha vuela a la bandeja (como lo
## que se encuentra guardado): ahora hay que ponerlo en su sitio del desván.
func _send_to_tray(scope: Interactable) -> void:
	if not is_inside_tree() or not is_instance_valid(scope.target) or not scope.target.visible:
		return
	Events.piece_collected.emit(scope.reward, scope.target)
	Sfx.play("pickup")
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(scope.target, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(scope.target.hide)


# --- Dibujos escondidos (C_) -----------------------------------------------------------

## ¿Está ya este dibujo? Su zona abierta y sus after-x (y la pieza con la que viene) puestas.
func collectible_ready(it: Interactable) -> bool:
	if it.section != null and not it.section.opened:
		return false
	var need: Array[StringName] = it.prereqs.duplicate()
	if it.comes_with != &"":
		need.append(it.comes_with)
	for p in need:
		for s in slots:
			if s.id == p and not s.filled:
				return false
	return true


func collectible_total() -> int:
	return interactables.filter(func(it: Interactable) -> bool: return it.kind == NameRules.COLLECTIBLE).size()


func collectibles_found() -> int:
	return interactables.filter(func(it: Interactable) -> bool: return it.kind == NameRules.COLLECTIBLE and it.collected).size()


## Un dibujo encontrado: sale el logro y vuela a la siguiente pinza de la cuerda (si alguien lo está
## mirando de cerca, hold_collectible, espera a que lo suelte).
func find_collectible(it: Interactable) -> void:
	if it.kind != NameRules.COLLECTIBLE or it.collected or not it.available:
		return
	it.collected = true
	it.set_clickable(false)
	_given.erase(it)
	var found := collectibles_found()
	Sfx.jingle("logro")
	Events.collectible_found.emit(it, found, collectible_total())
	if not _held.has(it):
		_hang(it, found - 1, true)              # sin frase ni consejo: los encuentra el jugador (quinta nota)


## (Inspección, sexta nota) Ese dibujo recién encontrado se queda donde estaba mientras se mira de cerca.
func hold_collectible(it: Interactable) -> void:
	if it.collected and not _held.has(it):
		_held[it] = collectibles_found() - 1


## Y al dejar de mirarlo, vuela a su pinza.
func release_collectible(it: Interactable) -> void:
	if not _held.has(it):
		return
	var index: int = _held[it]
	_held.erase(it)
	_hang(it, index, true)


## (Tests) ¿Está ese dibujo esperando a que se deje de mirar?
func is_held(it: Interactable) -> bool:
	return _held.has(it)


## Lo cuelga en la pinza `index` (animate = en vuelo y balanceándose; si no, ya colgado). Sin cuerda
## o sin pinza libre, se va como lo escondido.
func _hang(it: Interactable, index: int, animate: bool) -> void:
	var t := it.target
	if clothesline == null or index < 0 or index >= _spots.size():
		push_warning("Diorama '%s': el dibujo %s no tiene pinza en la cuerda (T_ con hijos Pinza…)" % [name, t.name])
		t.hide()
		return
	var spot := _spots[index]
	Visuals.stop_growing(clothesline)            # (si la cuerda aún estaba apareciendo, ya a su tamaño)
	t.reparent(clothesline, true)
	t.show()
	var size := t.global_basis.get_scale()
	var goal := Transform3D(spot.global_basis.orthonormalized().scaled(size), spot.global_position)
	if not animate:
		t.global_transform = goal
		return
	var from := t.global_transform
	var lift := from.origin + Vector3.UP * 0.18
	var peak := lift.lerp(goal.origin, 0.5) + Vector3.UP * (0.25 + lift.distance_to(goal.origin) * 0.15)
	var q0 := from.basis.get_rotation_quaternion()
	var q1 := goal.basis.get_rotation_quaternion()
	var tw := t.create_tween()
	tw.tween_method(func(k: float) -> void:              # ¡aquí está!: se levanta y crece un poco
		t.global_transform = Transform3D(Basis(q0.slerp(q1, k * 0.25)).scaled(size * (1.0 + 0.25 * k)),
			from.origin.lerp(lift, k)), 0.0, 1.0, LIFT_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.15)
	tw.tween_method(func(k: float) -> void:              # vuela en arco hasta su pinza
		var a := lift.lerp(peak, k)
		var b := peak.lerp(goal.origin, k)
		t.global_transform = Transform3D(Basis(q0.slerp(q1, 0.25 + 0.75 * k)).scaled(size * (1.25 - 0.25 * k)),
			a.lerp(b, k)), 0.0, 1.0, HANG_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		Sfx.play("pinza")
		Events.collectible_hung.emit(it))
	tw.tween_method(func(k: float) -> void:              # se engancha y se balancea hasta quedarse quieto
		var e := k * SWING_TIME
		t.global_transform = Transform3D(goal.basis * Basis(Vector3.RIGHT, 0.5 * exp(-e * 2.2) * sin(e * 8.0)), goal.origin), \
		0.0, 1.0, SWING_TIME)


## (Tests) La pinza donde va el n-ésimo dibujo (desde 0); null si no hay.
func spot(index: int) -> Node3D:
	return _spots[index] if index >= 0 and index < _spots.size() else null


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
			if hold_sections:                   # el espejo: el final lo abre su transición
				var wait := maxf(SECTION_PAUSE, Narrator.remaining() + 0.3)
				get_tree().create_timer(wait, false).timeout.connect(_open_when_free.bind(_pending))
			else:                               # el capítulo siguiente sale cuando el jugador decide seguir
				_waiting_act = _pending
			Events.inventory_changed.emit()       # la bandeja espera a la sección nueva (no está "vacía")


## (Cambio de acto) ¿Espera el acto siguiente a que el jugador siga? (botón «Continuar», o un clic
## en el primer plano del objeto que lo cerró).
func act_waiting() -> bool:
	return _waiting_act != null


## El jugador sigue: si aún se oye el diálogo, la voz se apaga en un momento (ACT_FADE) y, después,
## sale el rótulo del capítulo siguiente y se abre (feedback: "una pequeña transición de audio").
func continue_act() -> void:
	if _waiting_act == null:
		return
	var sec := _waiting_act
	_waiting_act = null
	var talking := Narrator.remaining() > 0.05
	if talking:
		Narrator.fade_out(ACT_FADE)
	Events.act_continued.emit()
	get_tree().create_timer(ACT_FADE if talking else 0.05, false).timeout.connect(_open_when_free.bind(sec))


func _open_when_free(sec: Section) -> void:
	if not is_inside_tree():                     # (el nivel ya se fue: otra partida, el menú)
		return
	if hold_sections and sec == _pending:
		get_tree().create_timer(0.2, false).timeout.connect(_open_when_free.bind(sec))
		return
	_open_pending(sec)


## (Momentos) Abre ya la sección que esperaba (al acabar la transición del espejo al final).
func open_pending_now() -> void:
	if _pending != null:
		_open_pending(_pending)


## La sección que se está abriendo (o esperando para abrirse); null si ninguna.
func opening_section() -> Section:
	return _pending


## Abre la sección que esperaba: luces de la zona, rótulo, cámara y sus frases (si las tiene).
## Sus cosas aparecen cuando acaban esas frases (el epílogo habla antes de enseñar la moneda) y, si es
## un capítulo, cuando se empieza a ir su rótulo (CHAPTER_REVEAL).
func _open_pending(sec: Section) -> void:
	if sec == null or sec != _pending or sec.opened or sec.opening or not is_inside_tree():
		return
	sec.opening = true
	sec.set_lights(true, LIGHT_FADE)
	Events.section_opened.emit(sec)
	Narrator.say_if_exists("seccion_" + sec.name)
	_reveal_when_quiet(sec, CHAPTER_REVEAL if is_chapter(sec) else 0.0)


## Sus cosas salen cuando se callan esas frases (antes si el jugador las pasa con clics: el final no
## hace esperar a la moneda, sexta nota) y no antes de `wait` s (lo que se ve el rótulo del capítulo).
func _reveal_when_quiet(sec: Section, wait := 0.0) -> void:
	if not is_inside_tree():                     # (el nivel ya se fue: otra partida, el menú)
		return
	if Narrator.remaining() > 0.05 or wait > 0.0:
		get_tree().create_timer(0.1, false).timeout.connect(_reveal_when_quiet.bind(sec, maxf(wait - 0.1, 0.0)))
	else:
		_reveal_pending(sec)


## Aparecen sus muebles y sus siluetas, creciendo una tras otra de izquierda a derecha (Visuals.grow_in),
## y sus piezas pasan a la bandeja.
func _reveal_pending(sec: Section) -> void:
	if sec == null or sec != _pending or not is_inside_tree():
		return
	_pending = null
	sec.opened = true
	sec.set_decor(true, true)
	for it in sec.interactables:
		if not it.is_hidden_item():
			it.set_clickable(true)
	if is_chapter(sec):
		Sfx.play("aparecer_capitulo", 0.0)
	_refresh(true)
	Events.inventory_changed.emit()
	Events.section_revealed.emit(sec)


## Una sección con rótulo de capítulo (la infancia...; el epílogo no).
func is_chapter(sec: Section) -> bool:
	return Narrator.text("titulo_" + sec.name) != ""


## Pone al día lo que se ve: las siluetas de las secciones abiertas (se materializan si animate),
## cuáles ya se pueden poner (claras) y cuáles aún no (grises), los objetos escondidos que ya toca
## encontrar y qué mueble u objeto llama la atención.
func _refresh(animate: bool) -> void:
	for s in slots:
		if not s.filled:
			s.set_shown(s.section == null or s.section.opened, animate)
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
		if wanted and hidden_inside and it.container.pieces_ready():
			_tip_once("consejo_muebles")
		elif wanted and it.container != null and not hidden_inside:   # (abierto: lo de dentro ya se puede coger)
			_tip_once("consejo_dentro")
	for c: Interactable in calling:
		c.set_attention(calling[c] and c.pieces_ready())   # el cajón sin poner aún no llama
	# Un rincón (Z_) con piezas por montar llama la atención mientras no se está dentro.
	for it in interactables:
		if it.kind == NameRules.ZOOM and not it.completed:
			it.set_attention(focus == null and (it.section == null or it.section.opened) and is_instance_valid(it.target) and it.target.visible)
	# Los dibujos escondidos: están en cuanto se abre su zona (y su after-x está puesta); dentro de un
	# mueble cerrado no se pueden coger. El que viene con una pieza espera a que acabe su momento.
	for it in interactables:
		if it.kind != NameRules.COLLECTIBLE or it.collected:
			continue
		var ready := collectible_ready(it)
		it.set_available(ready)
		it.set_clickable(ready and it.comes_with == &"" and (it.container == null or it.container.is_open))
		if ready and it.comes_with != &"" and not _given.has(it):
			_given.append(it)
			_given_wait = GIVEN_DELAY


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
	if not fundido_final:                       # el cerdito del título; el desván acaba con la moneda
		Sfx.jingle(COMPLETE_SOUND)
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
	for old in _paint:                           # si otra mancha ya cubre esto, no hace falta otra (con todas las
		if float(old.t) >= radius and (old.c as Vector3).distance_to(origin) <= float(old.t) - radius * 0.6:
			return                                   # piezas del kit sueltas, se acababan las del shader)
	if _paint.size() >= Visuals.MAX_PAINT:
		push_warning("Diorama '%s': más de %d manchas de pintura; pinto de golpe" % [name, Visuals.MAX_PAINT])
		for m in _clay_meshes:
			if Visuals.global_aabb(m).get_center().distance_to(origin) <= radius:
				m.material_overlay = null
		return
	var spot := {"c": origin, "r": 0.0, "t": radius}
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


func _process(delta: float) -> void:
	if not _given.is_empty():                    # el dibujo que viene con una pieza, cuando acaba su momento
		if GameState.camera != null and is_instance_valid(GameState.camera) and GameState.camera.in_moment:
			_given_wait = GIVEN_DELAY
		else:
			_given_wait -= delta
			if _given_wait <= 0.0:
				_given_wait = GIVEN_DELAY
				find_collectible(_given.pop_front())
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
	tw.tween_property(n, "scale", base, POP_TIME)


func _play_animation(anim: String) -> void:
	for p in find_children("*", "AnimationPlayer", true, false):
		var player := p as AnimationPlayer
		if player.has_animation(anim):
			player.play(anim)


# --- Para tests y capturas: un paso de "jugador automático" ------------------------------

## (Atajo F9) Lo monta entero de golpe: todas las zonas abiertas, cada pieza en su sitio (lo
## escondido ya no hace falta buscarlo; los dibujos, ya en su cuerda), sin frases. Luego el final de siempre (onda de color,
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
			sec.set_decor(true)                  # de golpe: sin la ola de aparecer
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
	_given.clear()
	for it in interactables:                    # los dibujos, ya colgados en su cuerda
		if it.kind == NameRules.ZOOM and it.workbench:   # lo montado en un banco ya está en su sitio
			it.completed = true
			it.set_attention(false)
			it.target.hide()
		if it.kind == NameRules.COLLECTIBLE and not it.collected:
			it.collected = true
			it.set_clickable(false)
			_hang(it, collectibles_found() - 1, false)
	Events.inventory_changed.emit()
	_check_completed()


## (Atajo C, de capítulo) Acaba de golpe el capítulo en curso, para probar cada uno suelto: sus piezas en su sitio
## (con su pintura), lo que guardaba ya puesto y sus dibujos en la cuerda, sin frases ni primeros planos.
## Luego sigue como si se hubiera acabado jugando (su logro, el «Continuar» del siguiente). Si el
## siguiente ya esperaba al «Continuar», lo abre sin rótulo de espera. Devuelve la sección que ha
## acabado o abierto (null si no había nada que hacer).
func debug_complete_chapter() -> Section:
	if completed:
		return null
	Narrator.clear()
	Events.act_continued.emit()                  # (si estaba en un primer plano, se acaba)
	if _pending != null:
		_waiting_act = null
		var next := _pending
		_open_pending(next)
		_reveal_pending(next)
		return next
	var sec: Section = null
	for s in sections:
		if s.opened and not s.completed:
			sec = s
			break
	if sec == null:
		return null
	while focus != null:
		exit_focus()
	for d in sec.decor:                          # si aún crecía, ya a su tamaño
		Visuals.stop_growing(d)
	for s in sec.slots:
		if not s.filled:
			s.filled = true
			inventory.erase(s.id)
			s.fill()
			for m in s.meshes():
				Visuals.add_surface(m)
			_reveal_around(s.center())
	for it in sec.interactables:
		if it.kind == NameRules.PICKUP and not it.collected:
			it.collected = true                  # lo guardado ya está puesto: no hace falta buscarlo
			it.set_clickable(false)
			it.set_attention(false)
			it.target.hide()
		elif it.kind == NameRules.COLLECTIBLE and not it.collected:
			it.collected = true
			it.set_clickable(false)
			_given.erase(it)
			_hang(it, collectibles_found() - 1, false)
	_refresh(false)
	Events.inventory_changed.emit()
	_check_sections()
	_check_completed()
	return sec


func debug_solve_step() -> bool:
	if completed:
		return false
	if _pending != null:                        # sin esperar pausas, frases ni a que el jugador siga
		_waiting_act = null
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
