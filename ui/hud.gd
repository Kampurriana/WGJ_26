class_name Hud
extends CanvasLayer
## Interfaz construida en código: bandeja de piezas a la derecha, pista con recarga, botón Volver
## (sub-dioramas), botón Menú (pausa), subtítulos del narrador y aviso de diorama completado.
## Aspecto: UiTheme (o res://ui/theme.tres si existe).
##
## La bandeja flota a la derecha (dos columnas de fichas pequeñas, con scroll) y enseña TODAS las
## piezas que faltan, agrupadas por acto: las que aún no se pueden poner van grises, con candado, y
## al pasar el ratón o tocarlas dice por qué (Diorama.lock_reason). Al coger una pieza se aparta
## hacia la derecha (queda solo su borde, para soltar ahí y no poner nada) y deja colocar lo que
## tapaba; al soltar, vuelve. Al completar el diorama se recoge, como en Woodo.
##
## Lo que se encuentra guardado (H_) no aparece de golpe en la bandeja: su ficha sale de donde estaba
## el objeto y vuela en arco hasta su sitio (quinta nota: "que no se teletransporte").
##
## Disposición (pulido con la referencia de Ooblets): arriba a la izquierda, la TARJETA DE TAREA
## (dónde estás, qué toca ahora y una barra con lo que falta de la zona, como su panel de tareas);
## arriba a la derecha, el contador de dibujos (como su contador de la esquina) y debajo la bandeja;
## abajo en el centro, los subtítulos; abajo a la derecha, los consejos como avisos que entran desde
## el borde (como su "New ooblet spotted"); abajo a la izquierda, Menú y Pista con su tecla.
## Dibujos escondidos (C_): al encontrar uno, lo que se enseña es su primer plano (ui/inspeccion.gd).

signal next_requested
signal pause_requested

@export var hint_cooldown := 25.0            ## segundos de recarga de la pista
@export var assist_after := 45.0             ## sin progreso tanto tiempo => la pista se recarga sola

const COLUMNS := 2
const GAP := 6.0
const PANEL_WIDTH := COLUMNS * InventoryItem.SIZE.x + (COLUMNS - 1) * GAP + 2 * 10.0 + 14.0
const MARGIN := 10.0                         ## la bandeja flota: separada del borde de la pantalla
const LIP := 26.0                            ## lo que se ve de ella mientras se arrastra una pieza
const SLIDE_TIME := 0.22
const FLY_TIME := 0.8                        ## lo que tarda en volar a la bandeja lo que se recoge (s)
const COUNTER_H := 42.0                      ## alto del contador de dibujos (la bandeja empieza debajo)
const TASK_WIDTH := 300.0                    ## ancho de la tarjeta de tarea
const TIP_WIDTH := 300.0                     ## ancho de un aviso (consejo), abajo a la derecha
const TIP_SLIDE := 60.0                      ## lo que entra deslizándose desde la derecha

var _root: Control
var _panel: PanelContainer
var _list: VBoxContainer                     ## un grupo por acto: rótulo + rejilla de fichas
var _scroll: ScrollContainer
var _flights: Array[Control] = []            ## fichas volando hacia la bandeja (lo recogido)
var _groups: Dictionary = {}                 ## índice de sección (-1 = sin sección) -> {box, header, grid}
var _cards: Dictionary = {}                  ## id de pieza -> InventoryItem
var _empty: Label
var _tray_tween: Tween
var _slide := 0.0                            ## 0 = en su sitio, 1 = apartada (al arrastrar)
var _slide_tween: Tween
var _info: PanelContainer                    ## bocadillo junto a la bandeja: qué es la pieza y si no se puede poner, por qué
var _info_label: Label
var _info_left := 0.0
var _moment := false                         ## momento de la historia: bandeja y botones apartados
var _moment_tween: Tween
var _moment_hidden: Array[Control] = []
var _hint_button: Button
var _hint_bar: ProgressBar
var _back_button: Button
var _task: PanelContainer                    ## tarjeta de tarea (arriba a la izquierda)
var _title: Label                            ## dónde estás: "EL DESVÁN", "I · INFANCIA"
var _task_text: Label                        ## qué toca ahora
var _task_bar: ProgressBar                   ## lo puesto de la zona abierta
var _task_count: Label                       ## "5 / 12"
var _subtitle_box: PanelContainer
var _subtitle: Label
var _chapter: Control                        ## rótulo de capítulo a toda pantalla (al empezar un acto)
var _chapter_dim: ColorRect
var _chapter_kicker: Label                   ## "CAPÍTULO II"
var _chapter_title: Label                    ## "Adolescencia"
var _chapter_line: ColorRect
var _chapter_spacing: FontVariation          ## el título se abre letra a letra al aparecer
var _chapter_text := ""                      ## el rótulo entero ("II · Adolescencia"), para los tests
var _chapter_tween: Tween
var _tip_waiting: Array = []                 ## consejo que espera a que acabe el rótulo de capítulo
var _tip_box: PanelContainer                 ## consejo de juego (aviso abajo a la derecha)
var _tip_tween: Tween
var _tip: Label
var _tip_left := 0.0
var _drawings: PanelContainer                ## contador de dibujos encontrados (arriba a la derecha)
var _drawings_icon: DibujoIcono
var _drawings_label: Label
var _done: PanelContainer
var _done_button: Button
var _controls: VBoxContainer
var _game_ui := true
var _charge := 1.0
var _idle := 0.0
var _subtitle_left := 0.0
var _hinted: PieceSlot


func _ready() -> void:
	layer = 2                                    # encima del enfoque (0) y de los momentos (1): nunca se desenfoca
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	_build_panel()
	_build_controls()
	_build_chapter()                             # debajo de los subtítulos: el rótulo no los apaga
	_build_subtitle()
	_build_tip()
	_build_done()
	Events.level_started.connect(func(_d: Node) -> void: _on_level_started())
	Events.inventory_changed.connect(rebuild_inventory)
	Events.inventory_changed.connect(_update_task)
	Events.inventory_changed.connect(_update_counter)
	Events.level_completed.connect(func(_d: Node) -> void: _update_task())
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
	Events.collectible_found.connect(_on_collectible_found)
	Events.piece_collected.connect(_on_piece_collected)
	Events.piece_drag_started.connect(func(_id: StringName) -> void:
		_hide_info()
		_slide_to(1.0))
	Events.piece_drag_ended.connect(func(_id: StringName, _placed: bool) -> void: _slide_to(0.0))
	Narrator.skipped.connect(func() -> void: _subtitle_box.hide())


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.theme_type_variation = &"Bandeja"
	_root.add_child(_panel)
	_set_slide(0.0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	_scroll = scroll
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	column.add_child(_list)
	_empty = Label.new()
	_empty.text = "Aquí no queda nada.\nBusca piezas escondidas\no acércate a otro rincón."
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.custom_minimum_size = Vector2(PANEL_WIDTH - 40.0, 0)
	_empty.add_theme_color_override("font_color", UiTheme.CREAM)
	_empty.hide()
	column.add_child(_empty)
	column.move_child(_empty, 0)                 # arriba: se lee antes que las fichas con candado
	_info = PanelContainer.new()
	_info.theme_type_variation = &"Subtitulo"
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.hide()
	_root.add_child(_info)
	_info_label = Label.new()
	_info_label.theme_type_variation = &"SubtituloTexto"
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(230, 0)
	_info_label.add_theme_font_size_override("font_size", 17)
	_info.add_child(_info_label)


## Posición de la bandeja: 0 = en su sitio, 1 = apartada a la derecha (solo asoma su borde).
func _set_slide(v: float) -> void:
	_slide = v
	var shift := v * (PANEL_WIDTH - LIP + MARGIN)
	_panel.offset_left = -PANEL_WIDTH - MARGIN + shift
	_panel.offset_right = -MARGIN + shift
	_panel.offset_top = MARGIN + (COUNTER_H + GAP if _drawings != null and _drawings.visible else 0.0)
	_panel.offset_bottom = -MARGIN


func _slide_to(v: float) -> void:
	if _slide_tween != null:
		_slide_tween.kill()
	_slide_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_method(_set_slide, _slide, v, SLIDE_TIME * absf(v - _slide) + 0.01)


## (Tests) ¿Está la bandeja apartada (arrastrando una pieza)?
func tray_is_away() -> bool:
	return _slide > 0.5


## Todas las fichas de la bandeja, en orden. available_only = solo las que se pueden poner ya.
func cards(available_only := false) -> Array[InventoryItem]:
	var out: Array[InventoryItem] = []
	for g in _list.get_children():
		for c in g.find_children("*", "InventoryItem", true, false):
			if not (c as InventoryItem).is_queued_for_deletion() and (not available_only or not (c as InventoryItem).locked):
				out.append(c)
	return out


func _show_info(card: InventoryItem, text: String, seconds := 0.0) -> void:
	_info_label.text = text
	_info.show()
	_info.reset_size()
	var r := card.get_global_rect()
	var y := clampf(r.get_center().y - _info.size.y * 0.5, 8.0, _root.size.y - _info.size.y - 8.0)
	_info.position = Vector2(_panel.get_global_rect().position.x - _info.size.x - 8.0, y)
	_info_left = seconds


func _hide_info() -> void:
	_info.hide()
	_info_left = 0.0


## (Tests) Lo que dice ahora el bocadillo de la bandeja ("" = no se ve).
func info_text() -> String:
	return _info_label.text if _info.visible else ""


func _on_card_hovered(card: InventoryItem, on: bool) -> void:
	if not on:
		if _info_left <= 0.0:
			_hide_info()
		return
	var what := Narrator.piece_name(card.piece_id, true)
	_show_info(card, what + ("\n" + card.reason if card.locked else ""))


## Tocar una ficha con candado: tiembla, suena "no" y la bandeja dice por qué (y qué va antes).
func _on_locked_pressed(card: InventoryItem) -> void:
	Sfx.play("reject")
	_show_info(card, "Todavía no se puede poner.\n" + card.reason, 3.5)
	Events.piece_rejected.emit(card.piece_id, "bloqueada")


func _build_controls() -> void:
	_task = PanelContainer.new()
	_task.position = Vector2(MARGIN + 6, MARGIN + 4)
	_task.custom_minimum_size = Vector2(TASK_WIDTH, 0)
	_task.theme_type_variation = &"Subtitulo"
	_task.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_task)
	var task_col := VBoxContainer.new()
	task_col.add_theme_constant_override("separation", 4)
	_task.add_child(task_col)
	_title = Label.new()
	var spaced := FontVariation.new()
	spaced.base_font = UiTheme.FONT_BOLD
	spaced.spacing_glyph = 2
	_title.add_theme_font_override("font", spaced)
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_color", UiTheme.ORANGE)
	task_col.add_child(_title)
	_task_text = Label.new()
	_task_text.theme_type_variation = &"SubtituloTexto"
	_task_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_task_text.custom_minimum_size = Vector2(TASK_WIDTH - 36.0, 0)
	_task_text.add_theme_font_size_override("font_size", 18)
	task_col.add_child(_task_text)
	var task_row := HBoxContainer.new()
	task_row.add_theme_constant_override("separation", 10)
	task_col.add_child(task_row)
	_task_bar = ProgressBar.new()
	_task_bar.show_percentage = false
	_task_bar.max_value = 1.0
	_task_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_task_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_task_bar.custom_minimum_size = Vector2(0, 10)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(1, 1, 1, 0.14)
	bar_bg.set_corner_radius_all(5)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = UiTheme.ORANGE
	bar_fill.set_corner_radius_all(5)
	_task_bar.add_theme_stylebox_override("background", bar_bg)
	_task_bar.add_theme_stylebox_override("fill", bar_fill)
	task_row.add_child(_task_bar)
	_task_count = Label.new()
	_task_count.theme_type_variation = &"SubtituloTexto"
	_task_count.add_theme_font_size_override("font_size", 15)
	task_row.add_child(_task_count)
	_drawings = PanelContainer.new()
	_drawings.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_drawings.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_drawings.offset_right = -MARGIN
	_drawings.offset_top = MARGIN
	_drawings.custom_minimum_size = Vector2(PANEL_WIDTH, COUNTER_H)
	_drawings.theme_type_variation = &"Subtitulo"
	_drawings.add_theme_stylebox_override("panel", UiTheme._box(Color(0.14, 0.21, 0.52, 0.84), 21, Color(UiTheme.PALE, 0.25), 0, 2, 14, 5))
	_drawings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawings.hide()
	_root.add_child(_drawings)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_drawings.add_child(row)
	_drawings_icon = DibujoIcono.new(Vector2(18, 22))
	row.add_child(_drawings_icon)
	var drawings_word := Label.new()
	drawings_word.text = "Dibujos"
	drawings_word.theme_type_variation = &"SubtituloTexto"
	drawings_word.add_theme_font_size_override("font_size", 15)
	row.add_child(drawings_word)
	_drawings_label = Label.new()
	_drawings_label.theme_type_variation = &"SubtituloTexto"
	_drawings_label.add_theme_font_size_override("font_size", 17)
	_drawings_label.add_theme_color_override("font_color", UiTheme.ORANGE)
	row.add_child(_drawings_label)
	_back_button = Button.new()
	_back_button.text = "Volver"
	_back_button.position = Vector2(MARGIN + 6, 150)
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
	menu.text = "Menú  · Esc"
	menu.pressed.connect(func() -> void: pause_requested.emit())
	box.add_child(menu)
	_hint_button = Button.new()
	_hint_button.text = "Pista  · H"
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
	_subtitle_box.offset_right = 100.0           # centrados en lo que deja la bandeja; a su derecha, los avisos
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
	_chapter = Control.new()
	_chapter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chapter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chapter.modulate.a = 0.0
	_root.add_child(_chapter)
	_chapter_dim = ColorRect.new()
	_chapter_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chapter_dim.color = Color(UiTheme.BLUE_DEEP, 0.45)
	_chapter_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chapter.add_child(_chapter_dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chapter.add_child(box)
	_chapter_kicker = _chapter_label(22, UiTheme.CREAM)
	var kicker_font := FontVariation.new()
	kicker_font.base_font = UiTheme.FONT_BOLD
	kicker_font.spacing_glyph = 6
	_chapter_kicker.add_theme_font_override("font", kicker_font)
	box.add_child(_chapter_kicker)
	_chapter_title = _chapter_label(76, UiTheme.CREAM)
	UiTheme.style_title(_chapter_title, 76)          # como los títulos de la referencia
	_chapter_spacing = FontVariation.new()
	_chapter_spacing.base_font = UiTheme.FONT_BOLD
	_chapter_title.add_theme_font_override("font", _chapter_spacing)
	box.add_child(_chapter_title)
	var line_holder := CenterContainer.new()
	line_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line_holder)
	_chapter_line = ColorRect.new()
	_chapter_line.color = Color(UiTheme.PALE, 0.85)
	_chapter_line.custom_minimum_size = Vector2(0, 4)
	_chapter_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_holder.add_child(_chapter_line)


func _chapter_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(UiTheme.BLUE_DEEP, 0.85))
	return l


func _build_tip() -> void:
	_tip_box = PanelContainer.new()
	_tip_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_tip_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tip_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tip_box.offset_right = -(PANEL_WIDTH + MARGIN * 2.0)
	_tip_box.offset_bottom = -20
	_tip_box.custom_minimum_size = Vector2(TIP_WIDTH, 0)
	_tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_box.theme_type_variation = &"Subtitulo"
	_tip_box.hide()
	_root.add_child(_tip_box)
	var tip_col := VBoxContainer.new()
	tip_col.add_theme_constant_override("separation", 2)
	_tip_box.add_child(tip_col)
	var kicker := Label.new()
	kicker.text = "CONSEJO"
	kicker.add_theme_font_size_override("font_size", 13)
	kicker.add_theme_font_override("font", UiTheme.FONT_BOLD)
	kicker.add_theme_color_override("font_color", UiTheme.ORANGE)
	tip_col.add_child(kicker)
	_tip = Label.new()
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(TIP_WIDTH - 36.0, 0)
	_tip.theme_type_variation = &"SubtituloTexto"
	_tip.add_theme_font_size_override("font_size", 18)
	tip_col.add_child(_tip)


## Rótulo de "nuevo capítulo" al empezar un acto: la escena se oscurece un poco, sale "CAPÍTULO II"
## y el nombre del acto, que se abre letra a letra y sube un poco, con una línea que crece desde el
## centro; se queda un momento y se va despacio. "II · Adolescencia" -> CAPÍTULO II / Adolescencia;
## sin número ("Epílogo") solo el nombre.
func show_chapter(text: String) -> void:
	if text == "":
		return
	_chapter_text = text
	var parts := text.split(" · ", false, 1)
	_chapter_kicker.text = ("CAPÍTULO " + parts[0]) if parts.size() == 2 else ""
	_chapter_kicker.visible = parts.size() == 2
	_chapter_title.text = parts[parts.size() - 1]
	if _chapter_tween != null:
		_chapter_tween.kill()
	_chapter.modulate.a = 0.0
	_chapter_line.custom_minimum_size.x = 0.0
	Sfx.play("capitulo")
	_chapter_tween = create_tween()
	_chapter_tween.set_parallel()
	_chapter_tween.tween_property(_chapter, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	_chapter_tween.tween_method(func(v: float) -> void: _chapter_spacing.spacing_glyph = int(v), 22.0, 3.0, 1.6) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_chapter_tween.tween_property(_chapter_line, "custom_minimum_size:x", 340.0, 1.4).set_delay(0.4) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_chapter_tween.chain().tween_interval(2.0)
	_chapter_tween.chain().tween_property(_chapter, "modulate:a", 0.0, 1.1).set_trans(Tween.TRANS_SINE)


func show_tip(text: String, seconds := 7.0) -> void:
	if text == "":
		return
	if _chapter_showing() or _moment:            # no encima del rótulo de capítulo ni de un primer plano: espera
		_tip_waiting = [text, seconds]
		return
	_tip.text = text
	_tip_box.show()
	_tip_left = seconds
	if _tip_tween != null:                       # entra deslizándose desde el borde, como un aviso
		_tip_tween.kill()
	_tip_box.modulate.a = 0.0
	_tip_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tip_tween.tween_property(_tip_box, "modulate:a", 1.0, 0.3)
	_tip_tween.tween_method(func(x: float) -> void: _tip_box.offset_right = x,
		-(PANEL_WIDTH + MARGIN * 2.0) + TIP_SLIDE, -(PANEL_WIDTH + MARGIN * 2.0), 0.45)


func _chapter_showing() -> bool:
	return _chapter.modulate.a > 0.01 or (_chapter_tween != null and _chapter_tween.is_running())


## (Tests) Lo que dicen ahora el rótulo y el consejo ("" = no se ven).
func chapter_text() -> String:
	return _chapter_text if _chapter.modulate.a > 0.01 else ""


func tip_text() -> String:
	return _tip.text if _tip_box.visible else ""


## Algo guardado se ha recogido: su ficha vuela desde el objeto hasta su sitio en la bandeja.
func _on_piece_collected(id: StringName, node: Node3D) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not is_instance_valid(node) or not _panel.visible:
		return
	var center := Visuals.global_aabb(node).get_center()
	if cam.is_position_behind(center):
		return
	_fly_to_tray.call_deferred(id, cam.unproject_position(center))   # la bandeja ya sabe que la tiene


func _fly_to_tray(id: StringName, from: Vector2) -> void:
	var card := item_for(id)
	if card == null:
		return
	_scroll.ensure_control_visible(card)
	var icon := TextureRect.new()
	icon.name = "Vuelo"
	# Una foto de la vista de la ficha (no su textura viva: la ficha puede rehacerse mientras vuela).
	var can_read := card.texture() != null and DisplayServer.get_name() != "headless"   # sin pantalla no hay imagen que leer
	var img := card.texture().get_image() if can_read else null
	icon.texture = ImageTexture.create_from_image(img) if img != null and not img.is_empty() else null
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = InventoryItem.SIZE
	icon.pivot_offset = icon.size * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1.15, 1.1, 0.95)
	_root.add_child(icon)
	_flights.append(icon)
	var start := from
	var state := {"goal": card.get_global_rect().get_center()}   # dónde está la ficha (se pone al día al volar)
	var tw := icon.create_tween()
	tw.tween_method(func(t: float) -> void:
		var target := item_for(id)                   # la ficha puede moverse (o rehacerse) mientras vuela
		if target != null:
			state.goal = target.get_global_rect().get_center()
		var goal: Vector2 = state.goal
		var peak := start.lerp(goal, 0.5) + Vector2(0, -150)
		var p := start.lerp(peak, t).lerp(peak.lerp(goal, t), t)
		icon.position = p - icon.size * 0.5
		icon.scale = Vector2.ONE * (0.55 + 0.6 * sin(t * PI) * (1.0 - t) + 0.45 * t)
		icon.rotation = sin(t * PI) * 0.25, 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		_flights.erase(icon)
		icon.queue_free()
		var target := item_for(id)
		if target != null:
			target.celebrate_unlock()
		Sfx.play("bandeja"))


## (Tests) Fichas volando ahora hacia la bandeja.
func flights() -> Array[Control]:
	return _flights


## Un dibujo encontrado: el contador (su primer plano lo enseña ui/inspeccion.gd).
func _on_collectible_found(item: Node, found: int, total: int) -> void:
	var it := item as Interactable
	var color := drawing_color(it.target if it != null else null)
	_drawings_label.text = "%d / %d" % [found, total]
	_drawings_icon.color = color
	_drawings_icon.faded = false


## El contador, al día con lo encontrado (F9 los cuelga todos sin avisar uno a uno).
func _update_counter() -> void:
	var d := GameState.diorama
	if d == null or not is_instance_valid(d) or d.collectible_total() == 0:
		return
	var found := d.collectibles_found()
	_drawings_label.text = "%d / %d" % [found, d.collectible_total()]
	_drawings_icon.faded = found == 0


## El color de un dibujo (el de su papel, o el de su malla más grande), para pintar el icono igual.
static func drawing_color(n: Node) -> Color:
	var best := Color(0.35, 0.72, 0.32)
	var best_area := -1.0
	if n != null:
		for m in Visuals.meshes_under(n):
			var mat := m.get_active_material(0) as StandardMaterial3D
			if mat == null:
				continue
			var size := m.get_aabb().size
			var area := maxf(size.x * size.y, maxf(size.y * size.z, size.x * size.z)) + (1.0 if String(m.name) == "Papel" else 0.0)
			if area > best_area:
				best_area = area
				best = mat.albedo_color
	return best


## La tarjeta de tarea (como el panel de tareas de la referencia): dónde estás (la zona abierta),
## qué toca ahora y cuánto llevas de esa zona.
func _update_task() -> void:
	var d := GameState.diorama
	if d == null or not is_instance_valid(d):
		return
	var sec: Section = null
	for s_ in d.sections:
		if s_.opened and not s_.completed:
			sec = s_
	if sec == null and d.is_opening():
		sec = d.opening_section()
	_title.text = (d.section_title(sec) if sec != null else d.level_title).to_upper()
	_title.visible = _title.text != ""
	var pool: Array = sec.slots if sec != null else d.slots
	var done := pool.filter(func(o: PieceSlot) -> bool: return o.filled).size()
	_task_bar.value = float(done) / maxf(1.0, pool.size())
	_task_count.text = "%d / %d" % [done, pool.size()]
	var left := pool.filter(func(o: PieceSlot) -> bool: return not o.filled)
	if d.completed:
		_task_text.text = "¡Completado!"
	elif d.is_opening():
		_task_text.text = "Se abre un capítulo nuevo…"
	elif d.has_findable() and d.visible_inventory().is_empty():   # primero, lo que ya se puede poner
		_task_text.text = "Busca lo guardado: toca lo que brilla."
	elif left.size() == 1 and (left[0] as PieceSlot).is_key:
		_task_text.text = "Falta la última: %s." % Narrator.piece_name((left[0] as PieceSlot).id)
	elif left.size() == 1 and (left[0] as PieceSlot).offered:
		_task_text.text = "Mete la moneda en la hucha."
	else:
		_task_text.text = "Lleva cada pieza de la bandeja a su silueta."


## (Tests) Lo que dice la tarjeta de tarea: "ZONA | qué toca | 5 / 12".
func task_text() -> String:
	return "%s | %s | %s" % [_title.text, _task_text.text, _task_count.text] if _task.visible else ""


## (Tests) Lo que dice el contador de dibujos ("" = no se ve).
func drawings_text() -> String:
	return _drawings_label.text if _drawings.visible else ""


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
	_task.visible = on
	_drawings.visible = on and GameState.diorama != null and is_instance_valid(GameState.diorama) \
		and GameState.diorama.collectible_total() > 0
	_set_slide(_slide)                           # la bandeja empieza debajo del contador, si lo hay
	_controls.visible = on
	_back_button.visible = on and GameState.diorama != null and GameState.diorama.focus != null
	if not on:
		_done.hide()


## Durante un momento de la historia (core/momentos.gd) la bandeja, los botones y el título se
## apartan con un fundido; al acabar vuelven (la bandeja no, si el diorama ya está completo).
func set_moment(on: bool) -> void:
	if on == _moment:
		return
	_moment = on
	_hide_info()
	if on:
		_tip_box.hide()                          # el consejo no tapa el primer plano
	if _moment_tween != null:
		_moment_tween.kill()
	_moment_tween = create_tween().set_parallel()
	if on:
		_moment_hidden.clear()
		for c: Control in [_panel, _controls, _task, _drawings]:
			if c.visible:
				_moment_hidden.append(c)
				_moment_tween.tween_property(c, "modulate:a", 0.0, 0.45)
		_moment_tween.chain().tween_callback(func() -> void:
			for c in _moment_hidden:
				c.hide())
		return
	var done := GameState.diorama != null and is_instance_valid(GameState.diorama) and GameState.diorama.completed
	for c in _moment_hidden:
		if c == _panel and done:
			continue
		c.show()
		c.modulate.a = 0.0
		_moment_tween.tween_property(c, "modulate:a", 1.0, 0.6)
	_moment_hidden.clear()


## (Tests) ¿Está la interfaz apartada por un momento de la historia?
func in_moment() -> bool:
	return _moment


## Diorama hecho: la bandeja se recoge con un fundido.
func _put_tray_away() -> void:
	_hide_info()
	_tray_tween = _panel.create_tween()
	_tray_tween.tween_property(_panel, "modulate:a", 0.0, 0.45)
	_tray_tween.tween_callback(_panel.hide)


func _on_level_started() -> void:
	if _tray_tween != null:
		_tray_tween.kill()
	_panel.modulate.a = 1.0
	_panel.visible = _game_ui
	_set_slide(0.0)
	_hide_info()
	if _moment_tween != null:
		_moment_tween.kill()
	_moment = false
	for c in _moment_hidden:
		c.visible = _game_ui
	_moment_hidden.clear()
	for c: Control in [_panel, _controls, _task, _drawings]:
		c.modulate.a = 1.0
	var total := GameState.diorama.collectible_total()
	_drawings.visible = _game_ui and total > 0      # desde el principio: "0 / 7" invita a buscar
	_drawings_label.text = "%d / %d" % [0, total]
	_drawings_icon.faded = true
	_set_slide(0.0)
	for f in _flights:
		if is_instance_valid(f):
			f.queue_free()
	_flights.clear()
	for g in _list.get_children():               # las fichas son del diorama anterior
		_list.remove_child(g)
		g.queue_free()
	_groups.clear()
	_cards.clear()
	_title.text = GameState.diorama.level_title.to_upper()
	_chapter.modulate.a = 0.0
	_tip_waiting = []
	_tip_box.hide()
	_done.hide()
	_back_button.hide()
	_charge = 1.0
	_idle = 0.0
	rebuild_inventory()
	_update_task()


## Pone al día la bandeja sin rehacerla: las fichas que siguen se quedan (su vista 3D no se vuelve a
## crear), las de piezas ya puestas se van, y cada una sabe si está bloqueada y por qué.
func rebuild_inventory() -> void:
	var d := GameState.diorama
	var entries: Array[Dictionary] = d.tray_entries() if d != null and is_instance_valid(d) else []
	var keep: Dictionary = {}
	for e in entries:
		keep[e.id] = e
	for id: StringName in _cards.keys():
		var card: InventoryItem = _cards[id]
		if not keep.has(id) or card.get_meta("grupo") != _group_key(d, keep[id]):
			card.get_parent().remove_child(card)
			card.queue_free()
			_cards.erase(id)
	var order: Array[int] = []
	for e in entries:
		var k := _group_key(d, e)
		if not order.has(k):
			order.append(k)
	for k: int in _groups.keys():
		if not order.has(k):
			_list.remove_child(_groups[k].box)
			_groups[k].box.queue_free()
			_groups.erase(k)
	for i in order.size():
		var g := _group(d, order[i])
		_list.move_child(g.box, i)
	var placed_in: Dictionary = {}               # grupo -> fichas ya colocadas en su orden
	for e in entries:
		var k := _group_key(d, e)
		var g: Dictionary = _groups[k]
		var card: InventoryItem = _cards.get(e.id)
		if card == null:
			card = InventoryItem.new()
			card.setup(e.id, d.prototype_for(e.id), d.reference_node_for(e.id), e.count)
			card.set_meta("grupo", k)
			card.hovered.connect(_on_card_hovered)
			card.locked_pressed.connect(_on_locked_pressed)
			g.grid.add_child(card)
			_cards[e.id] = card
		card.set_count(e.count)
		var at: int = placed_in.get(k, 0)
		g.grid.move_child(card, at)
		placed_in[k] = at + 1
		card.set_locked(e.locked, e.reason)
	for k: int in _groups:
		var sec: Section = d.sections[k] if k >= 0 and d != null and k < d.sections.size() else null
		var header: Label = _groups[k].header
		header.modulate = Color.WHITE if sec == null or sec.opened else Color(1, 1, 1, 0.55)
	var any_ready := entries.any(func(e: Dictionary) -> bool: return not e.locked)
	_empty.visible = d != null and not any_ready and not d.completed and not d.is_opening()
	_empty.text = "Algo está guardado.\nToca el mueble que brilla." if d != null and d.has_findable() \
		else "Aquí no queda nada.\nBusca piezas escondidas\no acércate a otro rincón."


func _group_key(d: Diorama, e: Dictionary) -> int:
	return d.sections.find(e.section) if d != null and e.section != null else -1


## El grupo de un acto en la bandeja: su rótulo (del color del acto) y su rejilla de fichas.
func _group(d: Diorama, k: int) -> Dictionary:
	if _groups.has(k):
		return _groups[k]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_list.add_child(box)
	var header := Label.new()
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_constant_override("outline_size", 4)
	header.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.05))
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sec: Section = d.sections[k] if k >= 0 else null
	header.text = d.section_title(sec) if sec != null else ""
	header.visible = sec != null
	header.add_theme_color_override("font_color", UiTheme.CREAM)
	box.add_child(header)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", int(GAP))
	grid.add_theme_constant_override("v_separation", int(GAP))
	box.add_child(grid)
	_groups[k] = {"box": box, "header": header, "grid": grid}
	return _groups[k]


func item_for(id: StringName) -> InventoryItem:
	var c: InventoryItem = _cards.get(id)
	return c if c != null and is_instance_valid(c) and not c.is_queued_for_deletion() else null


## Soltar aquí = no poner nada. Mientras se arrastra solo cuenta el borde que asoma.
func is_over_panel(pos: Vector2) -> bool:
	return _panel.visible and _panel.get_global_rect().has_point(pos)


## (Tests) ¿Dice la bandeja que no quedan piezas aquí?
func says_nothing_left() -> bool:
	return _empty.visible


func request_hint() -> void:
	var d := GameState.diorama
	if d == null or _charge < 1.0 or _moment:
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
	if not _tip_waiting.is_empty() and not _chapter_showing() and not _moment:
		var tip: Array = _tip_waiting
		_tip_waiting = []
		show_tip(tip[0], tip[1])
	if _info_left > 0.0:
		_info_left -= delta
		if _info_left <= 0.0:
			_hide_info()


func _unhandled_input(e: InputEvent) -> void:
	if not _game_ui:
		return
	if e.is_action_pressed("hint"):
		request_hint()
	elif e.is_action_pressed("complete_all") and GameState.DEBUG_SHORTCUTS and GameState.diorama != null:
		GameState.drag.cancel()
		GameState.diorama.debug_complete()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("back"):
		if GameState.diorama != null and GameState.diorama.focus != null:
			_on_back()
		else:
			pause_requested.emit()
		get_viewport().set_input_as_handled()
