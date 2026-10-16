class_name Hud
extends CanvasLayer
## Interfaz construida en código: panel de piezas a la derecha (con scroll), pista con recarga,
## botón Volver (sub-dioramas), subtítulos del narrador y panel de diorama completado.
## Para el aspecto: un Theme en res://ui/theme.tres se aplica solo si existe.

signal next_requested

@export var hint_cooldown := 25.0            ## segundos de recarga de la pista
@export var assist_after := 45.0             ## sin progreso tanto tiempo => la pista se recarga sola

var _root: Control
var _panel: PanelContainer
var _list: VBoxContainer
var _hint_button: Button
var _hint_bar: ProgressBar
var _back_button: Button
var _title: Label
var _subtitle_box: PanelContainer
var _subtitle: Label
var _done: PanelContainer
var _charge := 1.0
var _idle := 0.0
var _subtitle_left := 0.0
var _hinted: PieceSlot


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://ui/theme.tres"):
		_root.theme = load("res://ui/theme.tres")
	add_child(_root)
	_build_panel()
	_build_controls()
	_build_subtitle()
	_build_done()
	Events.level_started.connect(func(_d: Node) -> void: _on_level_started())
	Events.inventory_changed.connect(rebuild_inventory)
	Events.focus_changed.connect(func(a: Node) -> void: _back_button.visible = a != null)
	Events.piece_placed.connect(func(_id: StringName, _n: Node3D) -> void: _on_progress())
	Events.level_completed.connect(func(_d: Node) -> void: get_tree().create_timer(1.6).timeout.connect(_done.show))
	Narrator.subtitle.connect(_show_subtitle)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -InventoryItem.SIZE.x - 34
	_root.add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)


func _build_controls() -> void:
	_title = Label.new()
	_title.position = Vector2(20, 14)
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_constant_override("outline_size", 8)
	_title.add_theme_color_override("font_outline_color", Color(0.25, 0.18, 0.12))
	_root.add_child(_title)
	_back_button = Button.new()
	_back_button.text = "Volver"
	_back_button.position = Vector2(20, 60)
	_back_button.hide()
	_back_button.pressed.connect(_on_back)
	_root.add_child(_back_button)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_left = 20
	box.offset_bottom = -20
	box.custom_minimum_size = Vector2(150, 0)
	_root.add_child(box)
	_hint_button = Button.new()
	_hint_button.text = "Pista"
	_hint_button.pressed.connect(request_hint)
	box.add_child(_hint_button)
	_hint_bar = ProgressBar.new()
	_hint_bar.max_value = 1.0
	_hint_bar.show_percentage = false
	_hint_bar.custom_minimum_size = Vector2(150, 8)
	box.add_child(_hint_bar)


func _build_subtitle() -> void:
	_subtitle_box = PanelContainer.new()
	_subtitle_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subtitle_box.offset_top = -110
	_subtitle_box.offset_left = -360
	_subtitle_box.offset_right = 360 - InventoryItem.SIZE.x
	_subtitle_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_box.hide()
	_root.add_child(_subtitle_box)
	_subtitle = Label.new()
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 22)
	_subtitle_box.add_child(_subtitle)


func _build_done() -> void:
	_done = PanelContainer.new()
	_done.set_anchors_preset(Control.PRESET_CENTER)
	_done.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_done.grow_vertical = Control.GROW_DIRECTION_BOTH
	_done.hide()
	_root.add_child(_done)
	var v := VBoxContainer.new()
	_done.add_child(v)
	var l := Label.new()
	l.text = "¡Diorama completado!"
	l.add_theme_font_size_override("font_size", 30)
	v.add_child(l)
	var b := Button.new()
	b.text = "Siguiente"
	b.pressed.connect(func() -> void:
		_done.hide()
		next_requested.emit())
	v.add_child(b)


func _on_level_started() -> void:
	_title.text = GameState.diorama.level_title
	_done.hide()
	_back_button.hide()
	_charge = 1.0
	_idle = 0.0
	rebuild_inventory()


func rebuild_inventory() -> void:
	var d := GameState.diorama
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if d == null:
		return
	for id in d.visible_inventory():
		var item := InventoryItem.new()
		item.setup(id, d.prototype_for(id), d.reference_node_for(id), d.count_of(id))
		_list.add_child(item)
	if _list.get_child_count() == 0 and not d.completed:
		var empty := Label.new()
		empty.text = "Aquí no queda nada.\nBusca piezas escondidas\no acércate a otro rincón."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(InventoryItem.SIZE.x, 0)
		_list.add_child(empty)


func item_for(id: StringName) -> InventoryItem:
	for c in _list.get_children():
		if c is InventoryItem and (c as InventoryItem).piece_id == id:
			return c
	return null


func is_over_panel(pos: Vector2) -> bool:
	return _panel.get_global_rect().has_point(pos)


func request_hint() -> void:
	var d := GameState.diorama
	if d == null or _charge < 1.0:
		return
	var h := d.hint_target(GameState.hovered_piece)
	if h.is_empty():
		return
	_charge = 0.0
	Sfx.play("hint")
	Narrator.say_if_exists("pista")
	GameState.camera.look_at_point(Visuals.global_aabb(h.node).get_center())
	_clear_hint()
	if h.has("slot"):
		_hinted = h.slot
		_hinted.set_pulse(true)
		var item := item_for(h.piece)
		if item != null:
			item.highlight(true)
	Events.hint_shown.emit(h.node)


func _clear_hint() -> void:
	if _hinted != null:
		_hinted.set_pulse(false)
		var item := item_for(_hinted.id)
		if item != null:
			item.highlight(false)
	_hinted = null


func _on_progress() -> void:
	_idle = 0.0
	_clear_hint()


func _on_back() -> void:
	if GameState.diorama != null:
		GameState.diorama.exit_focus()


func _show_subtitle(text: String, seconds: float) -> void:
	_subtitle.text = text
	_subtitle_box.show()
	_subtitle_left = seconds


func _process(delta: float) -> void:
	_idle += delta
	_charge = minf(1.0, _charge + delta / hint_cooldown)
	if _idle >= assist_after:
		_charge = 1.0
	_hint_bar.value = _charge
	_hint_button.disabled = _charge < 1.0
	_hint_button.modulate = Color(1.2, 1.15, 0.7) if _idle >= assist_after else Color.WHITE
	if _subtitle_left > 0.0:
		_subtitle_left -= delta
		if _subtitle_left <= 0.0:
			_subtitle_box.hide()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("hint"):
		request_hint()
	elif e.is_action_pressed("back"):
		_on_back()
