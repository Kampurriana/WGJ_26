class_name Interactable
extends StaticBody3D
## Todo lo que se pulsa en el diorama: cajones (OD_), puertas (OR_), piezas escondidas (H_),
## dibujos escondidos que se cuelgan en la cuerda (C_) y sub-dioramas con zoom (Z_). Se cuelga como hijo del nodo del modelo, con una caja de
## colisión calculada de sus mallas, para que el rayo del clic lo encuentre.
## "Atención" (set_attention): cuando un mueble guarda el siguiente objeto que hace falta, brilla
## (borde cálido que late) y cada poco se mueve un pelín (el cajón asoma, la puerta se entreabre)
## para que el jugador descubra que los muebles se abren. Lo decide el Diorama.

const OPEN_TIME := 0.45
const RATTLE_EVERY := 2.4                    ## cada cuánto se mueve un mueble que llama la atención (s)
const GLOW_SHADER := preload("res://shaders/brillo.gdshader")
const OUTLINE_SHADER := preload("res://shaders/borde.gdshader")
const OUTLINE := 0.02                        ## grosor del contorno dorado (m)

var kind: String
var id: StringName
var target: Node3D
var scope: Interactable          # sub-diorama que lo contiene (null = el general)
var section: Section             # sección S_ que lo contiene (null = ninguna)
var container: Interactable      # (H_) el cajón o la puerta donde está guardado (null = a la vista)
var diorama: Diorama
var is_open := false
var inside: Array[PieceSlot] = []         ## (OD_/OR_) piezas que van dentro del mueble (su cajón): sin ellas no se abre
var collected := false
var completed := false
var available := true            # (H_) se ve y se puede coger (si no, aún no toca encontrarlo)
var attention := false
var reward: StringName = &""
var prereqs: Array[StringName] = []          ## (C_) no está hasta que estas piezas estén puestas
var comes_with: StringName = &""             ## (C_) viene con esa pieza: al ponerla, se encuentra solo

var _closed: Transform3D
var _open: Transform3D
var _axis := Vector3.BACK                    ## (OD_) hacia dónde sale el cajón
var _hinge := Vector3.UP                     ## (OR_) eje de la bisagra: vertical (puerta) u horizontal (tapa)
var _side := 1.0
var _shape: CollisionShape3D
var _tween: Tween
var _glow: Array[MeshInstance3D] = []
var _glow_mat: ShaderMaterial
var _outline_mat: ShaderMaterial
var _rattle_t := 0.0
var _clickable := true


func setup(p_diorama: Diorama, p_target: Node3D, info: Dictionary, p_scope: Interactable) -> void:
	diorama = p_diorama
	target = p_target
	kind = info.kind
	id = info.id
	scope = p_scope
	name = "Interactable"
	var tokens: PackedStringArray = info.tokens
	var box := Visuals.local_aabb(target)
	target.add_child(self)
	_shape = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size.max(Vector3.ONE * 0.05)
	_shape.shape = shape
	_shape.position = box.get_center()
	add_child(_shape)
	_closed = target.transform
	match kind:
		NameRules.DRAWER:
			_axis = _axis_from_tokens(tokens, Vector3.BACK)
			var depth := absf(box.size.dot(_axis.abs()))
			_open = _closed.translated_local(_axis * depth * 0.75)
		NameRules.DOOR:
			# __x = bisagra horizontal (la tapa de un baúl: se levanta); si no, vertical (una puerta).
			_hinge = Vector3.RIGHT if NameRules.has_token(tokens, "x") else Vector3.UP
			_side = -1.0 if NameRules.has_token(tokens, "n") else 1.0
			if _hinge == Vector3.RIGHT:
				_side = -_side                   # la tapa sube hacia atrás
			_open = _closed * Transform3D(Basis(_hinge, deg_to_rad(95.0 * _side)), Vector3.ZERO)
		NameRules.ZOOM:
			var r := NameRules.values(tokens, "reward")
			reward = r[0] if not r.is_empty() else &""
		NameRules.COLLECTIBLE:
			prereqs = NameRules.values(tokens, "after")
			var with := NameRules.values(tokens, "con")
			comes_with = with[0] if not with.is_empty() else &""


static func _axis_from_tokens(tokens: PackedStringArray, fallback: Vector3) -> Vector3:
	var table := {"x": Vector3.RIGHT, "nx": Vector3.LEFT, "y": Vector3.UP, "ny": Vector3.DOWN,
		"z": Vector3.BACK, "nz": Vector3.FORWARD}
	for t in tokens:
		if table.has(t):
			return table[t]
	return fallback


func is_openable() -> bool:
	return kind == NameRules.DRAWER or kind == NameRules.DOOR


## Lo que se encuentra (una pieza H_ o un dibujo C_): puede estar guardado en un mueble.
func is_hidden_item() -> bool:
	return kind == NameRules.PICKUP or kind == NameRules.COLLECTIBLE


func activate() -> void:
	match kind:
		NameRules.DRAWER, NameRules.DOOR:
			set_open(not is_open)
		NameRules.PICKUP:
			diorama.collect(self)
		NameRules.COLLECTIBLE:
			diorama.find_collectible(self)
		NameRules.ZOOM:
			diorama.enter_focus(self)


func set_open(value: bool, animate := true) -> void:
	is_open = value
	Sfx.play("open" if is_open else "close")
	var goal := _open if is_open else _closed
	if _tween != null:
		_tween.kill()
	if not animate:
		target.transform = goal
	else:
		_tween = target.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(target, "transform", goal, OPEN_TIME)
	if diorama != null:
		diorama.on_container_changed(self)


## Encender o apagar el clic (un Z_ se apaga mientras estás dentro para poder tocar lo de dentro).
func set_clickable(value: bool) -> void:
	_clickable = value
	_shape.disabled = not (value and pieces_ready())


func is_clickable() -> bool:
	return _clickable and pieces_ready() and is_visible_in_tree()


## (OD_/OR_) Lo que hay que poner del propio mueble antes de poder abrirlo (el cajón del escritorio
## es una pieza: hasta que está puesto, ni se abre ni brilla). Al ponerlo, refresh_clickable.
func pieces_ready() -> bool:
	return inside.all(func(s: PieceSlot) -> bool: return s.filled)


func refresh_clickable() -> void:
	set_clickable(_clickable)


## (H_, C_) Si toca encontrarlo ya: se ve y se puede coger. Si no, ni se ve (no estropea la historia).
func set_available(on: bool) -> void:
	available = on
	if collected:
		return
	target.visible = on
	set_clickable(on)


# --- Atención: brillo + un pequeño movimiento cada poco -------------------------------------

func set_attention(on: bool) -> void:
	if on == attention:
		return
	attention = on
	_rattle_t = RATTLE_EVERY * 0.5
	if on:
		_make_glow()
	else:
		for g in _glow:
			if is_instance_valid(g):
				g.queue_free()
		_glow.clear()
	Events.attention_changed.emit(self, on)


## Dos copias por malla: una que suma luz cálida (el mueble se templa y su borde brilla) y otra un
## poco más grande, de la que solo asoma un contorno dorado (lo que de verdad se lee de lejos).
func _make_glow() -> void:
	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = GLOW_SHADER
	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = OUTLINE_SHADER
	for m in Visuals.meshes_under(target):
		if m.name == "Brillo" or _inside_other_pickup(m):
			continue
		var g := _glow_copy(m, _glow_mat)
		_glow.append(g)
		var o := _glow_copy(m, _outline_mat)
		# Más grande desde el centro de la malla, lo mismo por cada lado (no por un factor: así una
		# tabla fina y un cajón grande llevan el mismo borde).
		var box := m.mesh.get_aabb()
		var k := (box.size + Vector3.ONE * OUTLINE * 2.0) / box.size.max(Vector3.ONE * 0.001)
		var c := box.get_center()
		o.transform = Transform3D(Basis.from_scale(k), c - c * k)
		_glow.append(o)


func _glow_copy(m: MeshInstance3D, mat: Material) -> MeshInstance3D:
	var g := MeshInstance3D.new()
	g.name = "Brillo"
	g.mesh = m.mesh
	g.material_override = mat
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(g)
	return g


## Lo que va guardado DENTRO de un mueble no brilla con él (si no, se delataría antes de abrirlo).
func _inside_other_pickup(m: Node) -> bool:
	var n := m.get_parent()
	while n != null and n != target:
		var it := n.get_node_or_null("Interactable") as Interactable
		if it != null and it != self and it.kind == NameRules.PICKUP:
			return true
		n = n.get_parent()
	return false


func _process(delta: float) -> void:
	if not attention:
		return
	_rattle_t += delta
	if _rattle_t >= RATTLE_EVERY:
		_rattle_t = 0.0
		rattle()


## Un movimiento pequeño de "aquí dentro hay algo": el cajón asoma y vuelve, la puerta se
## entreabre, el objeto da un saltito.
func rattle() -> void:
	if _tween != null and _tween.is_running():
		return
	var base := target.transform
	var peek := base
	match kind:
		NameRules.DRAWER:
			if is_open:
				return
			peek = _closed.translated_local(_axis * 0.035)
			base = _closed
		NameRules.DOOR:
			if is_open:
				return
			peek = _closed * Transform3D(Basis(_hinge, deg_to_rad(7.0 * _side)), Vector3.ZERO)
			base = _closed
		_:
			peek = base.translated(Vector3.UP * 0.04)
	_tween = target.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(target, "transform", peek, 0.12)
	_tween.tween_property(target, "transform", base, 0.22).set_ease(Tween.EASE_IN_OUT)


## (Tests) Copias de brillo vivas ahora mismo.
func glow_count() -> int:
	return _glow.filter(func(g: MeshInstance3D) -> bool: return is_instance_valid(g)).size()


## (Tests) De esas, las del contorno dorado.
func outline_count() -> int:
	return _glow.filter(func(g: MeshInstance3D) -> bool:
		return is_instance_valid(g) and g.material_override == _outline_mat).size()
