class_name Hud
extends CanvasLayer
## Interfaz construida en código: bandeja de piezas a la derecha (dos columnas de fichas pequeñas,
## con scroll; al completar el diorama se recoge, como en Woodo), pista con recarga, botón Volver
## (sub-dioramas), botón Menú (pausa), subtítulos del narrador y aviso de diorama completado.
## Aspecto: UiTheme (o res://ui/theme.tres si existe).

signal next_requested
signal pause_requested

@export var hint_cooldown := 25.0            ## segundos de recarga de la pista
@export var assist_after := 45.0             ## sin progreso tanto tiempo => la pista se recarga sola

const COLUMNS := 2
const GAP := 8.0
const PANEL_WIDTH := COLUMNS * InventoryItem.SIZE.x + (COLUMNS - 1) * GAP + 2 * 12.0 + 14.0

var _root: Control
var _panel: PanelContainer
var _list: GridContainer
var _empty: Label
var _tray_tween: Tween
var _hint_button: Button
var _hint_bar: ProgressBar
var _back_button: Button
var _title: Label
var _subtitle_box: PanelContainer
var _subtitle: Label
var _chapter: Label                          ## rótulo de sección ("I · Infancia")
var _tip_box: PanelContainer                 ## consejo de juego (arriba)
var _tip: Label
var _tip_left := 0.0
var _done: PanelContainer
var _done_button: Button
var _controls: VBoxContainer
var _game_ui := true
var _charge := 1.0
var _idle := 0.0
var _subtitle_left := 0.0
var _hinted: PieceSlot


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	_build_panel()
	_build_controls()
	_build_subtitle()
	_build_chapter()
	_build_done()
	Events.level_started.connect(func(_d: Node) -> void: _on_level_started())
	Events.inventory_changed.connect(rebuild_inventory)
	Events.focus_changed.connect(func(a: Node) -> void: _back_button.visible = a != null)
	Events.piece_placed.connect(func(_id: StringName, _n: Node3D) -> void: _on_progress())
	Events.level_completed.connect(func(_d: Node) -> void:
		rebuild_inventory()                  # el último encaje avisó antes de marcarse completado
		_put_tray_away()
		if GameState.mode == GameState.Mode.PLAYING and not (GameState.diorama != null and GameState.diorama.fundido_final):
			get_tree().create_timer(1.6).timeout.connect(_show_done))
	Narrator.subtitle.connect(_show_subtitle)
	Events.section_opened.connect(func(sec: RefCounted) -> void: show_chapter(Narrator.text("titulo_" + (sec as Section).name)))
	Events.tip_requested.connect(func(key: String) -> void: show_tip(Narrator.text(key)))


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -PANEL_WIDTH
	_panel.theme_type_variation = &"Bandeja"
	_root.add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	_list = GridContainer.new()
	_list.columns = COLUMNS
	_list.add_theme_constant_override("h_separation", int(GAP))
	_list.add_theme_constant_override("v_separation", int(GAP))
	column.add_child(_list)
	_empty = Label.new()
	_empty.text = "Aquí no queda nada.\nBusca piezas escondidas\no acércate a otro rincón."
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.custom_minimum_size = Vector2(PANEL_WIDTH - 40.0, 0)
	_empty.add_theme_color_override("font_color", UiTheme.CREAM)
	_empty.hide()
	column.add_child(_empty)


func _build_controls() -> void:
	_title = Label.new()
	_title.position = Vector2(20, 14)
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_constant_override("outline_size", 8)
	_title.add_theme_color_override("font_color", UiTheme.CREAM)
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
	_controls = box
	var menu := Button.new()
	menu.text = "Menú"
	menu.pressed.connect(func() -> void: pause_requested.emit())
	box.add_child(menu)
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
	_subtitle_box.grow_vertical = Control.GROW_DIRECTION_BEGIN    # una frase larga crece hacia arriba
	_subtitle_box.offset_top = -16
	_subtitle_box.offset_bottom = -16
	_subtitle_box.offset_left = -360
	_subtitle_box.offset_right = 360 - PANEL_WIDTH * 0.75
	_subtitle_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_box.theme_type_variation = &"Subtitulo"
	_subtitle_box.hide()
	_root.add_child(_subtitle_box)
	_subtitle = Label.new()
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.theme_type_variation = &"SubtituloTexto"
	_subtitle.add_theme_font_size_override("font_size", 22)
	_subtitle_box.add_child(_subtitle)


## Rótulo grande al abrirse una sección, y un consejo pequeño debajo cuando hace falta.
func _build_chapter() -> void:
	_chapter = Label.new()
	_chapter.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_chapter.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_chapter.offset_top = 70
	_chapter.offset_left = -400
	_chapter.offset_right = 400 - PANEL_WIDTH
	_chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chapter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chapter.add_theme_font_size_override("font_size", 44)
	_chapter.add_theme_constant_override("outline_size", 12)
	_chapter.add_theme_color_override("font_color", UiTheme.CREAM)
	_chapter.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.05, 0.9))
	_chapter.modulate.a = 0.0
	_root.add_child(_chapter)
	_tip_box = PanelContainer.new()
	_tip_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_tip_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tip_box.offset_top = 140
	_tip_box.offset_left = -300
	_tip_box.offset_right = 300 - PANEL_WIDTH
	_tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_box.theme_type_variation = &"Subtitulo"
	_tip_box.hide()
	_root.add_child(_tip_box)
	_tip = Label.new()
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.theme_type_variation = &"SubtituloTexto"
	_tip.add_theme_font_size_override("font_size", 20)
	_tip_box.add_child(_tip)


func show_chapter(text: String) -> void:
	if text == "":
		return
	_chapter.text = text
	var tw := _chapter.create_tween()
	tw.tween_property(_chapter, "modulate:a", 1.0, 0.8).from(0.0)
	tw.tween_interval(2.4)
	tw.tween_property(_chapter, "modulate:a", 0.0, 1.0)


func show_tip(text: String, seconds := 7.0) -> void:
	if text == "":
		return
	_tip.text = text
	_tip_box.show()
	_tip_left = seconds


## (Tests) Lo que dicen ahora el rótulo y el consejo ("" = no se ven).
func chapter_text() -> String:
	return _chapter.text if _chapter.modulate.a > 0.01 else ""


func tip_text() -> String:
	return _tip.text if _tip_box.visible else ""


## Arriba y centrado: el diorama recién completado se tiene que ver entero (la cámara lo enseña).
func _build_done() -> void:
	_done = PanelContainer.new()
	_done.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_done.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_done.offset_top = 64
	_done.hide()
	_root.add_child(_done)
	var v := VBoxContainer.new()
	_done.add_child(v)
	var l := Label.new()
	l.text = "¡Diorama completado!"
	l.add_theme_font_size_override("font_size", 30)
	v.add_child(l)
	_done_button = Button.new()
	_done_button.pressed.connect(func() -> void:
		_done.hide()
		next_requested.emit())
	v.add_child(_done_button)


func _show_done() -> void:
	var last := GameState.level_index + 1 >= GameState.levels.size()
	_done_button.text = "Volver al menú" if last else "Siguiente"
	_done.show()
	_done_button.grab_focus()


## Panel de piezas, título, pista, Menú y Volver. En el menú de inicio se esconden
## (los subtítulos no: el narrador puede hablar encima del menú).
func set_game_ui_visible(on: bool) -> void:
	_game_ui = on
	_panel.visible = on
	_title.visible = on
	_controls.visible = on
	_back_button.visible = on and GameState.diorama != null and GameState.diorama.focus != null
	if not on:
		_done.hide()


## Bandeja vacía = diorama hecho: se recoge con un fundido.
func _put_tray_away() -> void:
	_tray_tween = _panel.create_tween()
	_tray_tween.tween_property(_panel, "modulate:a", 0.0, 0.45)
	_tray_tween.tween_callback(_panel.hide)


func _on_level_started() -> void:
	if _tray_tween != null:
		_tray_tween.kill()
	_panel.modulate.a = 1.0
	_panel.visible = _game_ui
	_title.text = GameState.diorama.level_title
	_chapter.modulate.a = 0.0
	_tip_box.hide()
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
	_empty.visible = _list.get_child_count() == 0 and not d.completed and not d.is_opening()
	_empty.text = "Algo está guardado.\nToca el mueble que brilla." if d.has_findable() \
		else "Aquí no queda nada.\nBusca piezas escondidas\no acércate a otro rincón."


func item_for(id: StringName) -> InventoryItem:
	for c in _list.get_children():
		if c is InventoryItem and (c as InventoryItem).piece_id == id:
			return c
	return null


func is_over_panel(pos: Vector2) -> bool:
	return _panel.visible and _panel.get_global_rect().has_point(pos)


## (Tests) ¿Dice la bandeja que no quedan piezas aquí?
func says_nothing_left() -> bool:
	return _empty.visible


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
	if not Settings.get_value("subtitulos"):
		return
	_subtitle.text = text
	_subtitle_box.show()
	_subtitle_left = seconds


func _process(delta: float) -> void:
	_idle += delta
	_charge = minf(1.0, _charge + delta / hint_cooldown)
	var assist: bool = Settings.get_value("ayuda_automatica") and _idle >= assist_after
	if assist:
		_charge = 1.0
	_hint_bar.value = _charge
	_hint_button.disabled = _charge < 1.0
	_hint_button.modulate = Color(1.2, 1.15, 0.7) if assist else Color.WHITE
	if _subtitle_left > 0.0:
		_subtitle_left -= delta
		if _subtitle_left <= 0.0:
			_subtitle_box.hide()
	if _tip_left > 0.0:
		_tip_left -= delta
		if _tip_left <= 0.0:
			_tip_box.hide()


func _unhandled_input(e: InputEvent) -> void:
	if not _game_ui:
		return
	if e.is_action_pressed("hint"):
		request_hint()
	elif e.is_action_pressed("back"):
		if GameState.diorama != null and GameState.diorama.focus != null:
			_on_back()
		else:
			pause_requested.emit()
		get_viewport().set_input_as_handled()
