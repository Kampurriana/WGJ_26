class_name PauseMenu
extends CanvasLayer
## Pausa (Esc, botón "Menú" o B en el mando): para el juego y ofrece Reanudar, Dibujos (si el
## diorama los tiene), Opciones, Menú principal (no durante el puzle del título: ya estás en él) y
## Salir (no en Web).
## Dibujos: el álbum, como el libro de la referencia (Ooblets): dos páginas, a la izquierda todos los
## dibujos (los encontrados con su color; los que faltan, en silueta y con "?") y a la derecha el
## elegido en grande, con su nombre y su texto.

signal main_menu_requested

var buttons: Dictionary = {}                ## nombre -> Button (los tests pulsan por aquí)
var options: OptionsPanel
var page := ""

var _panel: PanelContainer
var _main_page: VBoxContainer
var _options_page: VBoxContainer
var _album_page: VBoxContainer
var _achievements_page: VBoxContainer
var logros: LogrosLista
var _album_grid: GridContainer
var _album_icon: DibujoIcono
var _album_name: Label
var _album_text: Label
var _album_count: Label
var album_slots: Array[Button] = []          ## una casilla por dibujo del diorama (los tests las pulsan)
var _album_items: Array = []                 ## sus Interactable, en el mismo orden


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(UiTheme.BLUE_DEEP, 0.5)
	root.add_child(dim)                     # tapa el juego: los clics no pasan al diorama
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)   # anclado arriba: el título y las pestañas no
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH   # se mueven al cambiar de página; crece hacia abajo
	panel.offset_top = 70
	panel.custom_minimum_size = Vector2(420, 0)
	root.add_child(panel)
	_panel = panel
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var title := Label.new()
	title.text = "Pausa"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_title(title, 44)
	v.add_child(title)
	_main_page = VBoxContainer.new()
	_main_page.add_theme_constant_override("separation", 10)
	v.add_child(_main_page)
	_add_button(_main_page, "reanudar", "Reanudar", resume)
	_add_button(_main_page, "dibujos", "Dibujos", func() -> void: show_page("dibujos"))
	_add_button(_main_page, "logros", "Logros", func() -> void: show_page("logros"))
	_add_button(_main_page, "opciones", "Opciones", func() -> void: show_page("opciones"))
	_add_button(_main_page, "menu", "Menú principal", func() -> void:
		close()
		main_menu_requested.emit())
	var quit := _add_button(_main_page, "salir", "Salir del juego", func() -> void: Sfx.quit())
	quit.visible = not OS.has_feature("web")
	_options_page = VBoxContainer.new()
	_options_page.add_theme_constant_override("separation", 10)
	v.add_child(_options_page)
	options = OptionsPanel.new(false)
	_options_page.add_child(options)
	_add_button(_options_page, "opciones_volver", "Volver", func() -> void: show_page("principal"))
	_build_album(v)
	_achievements_page = VBoxContainer.new()
	_achievements_page.add_theme_constant_override("separation", 10)
	v.add_child(_achievements_page)
	logros = LogrosLista.new()
	_achievements_page.add_child(logros)
	_add_button(_achievements_page, "logros_volver", "Volver", func() -> void: show_page("principal"))
	hide()


func _build_album(parent: Control) -> void:
	_album_page = VBoxContainer.new()
	_album_page.add_theme_constant_override("separation", 10)
	parent.add_child(_album_page)
	var book := HBoxContainer.new()
	book.add_theme_constant_override("separation", 6)
	_album_page.add_child(book)
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UiTheme._box(UiTheme.CARD, 10, Color(UiTheme.WOOD, 0.5), 0, 2, 16, 14))
	book.add_child(left)
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 10)
	left.add_child(left_col)
	_album_count = Label.new()
	_album_count.add_theme_font_size_override("font_size", 17)
	left_col.add_child(_album_count)
	_album_grid = GridContainer.new()
	_album_grid.columns = 4
	_album_grid.add_theme_constant_override("h_separation", 8)
	_album_grid.add_theme_constant_override("v_separation", 8)
	left_col.add_child(_album_grid)
	var spine := ColorRect.new()                 # el lomo del libro
	spine.color = Color(UiTheme.WOOD_DARK, 0.6)
	spine.custom_minimum_size = Vector2(4, 0)
	book.add_child(spine)
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(250, 0)
	right.add_theme_stylebox_override("panel", UiTheme._box(UiTheme.CARD, 10, Color(UiTheme.WOOD, 0.5), 0, 2, 16, 14))
	book.add_child(right)
	var right_col := VBoxContainer.new()
	right_col.alignment = BoxContainer.ALIGNMENT_CENTER
	right_col.add_theme_constant_override("separation", 8)
	right.add_child(right_col)
	_album_icon = DibujoIcono.new(Vector2(104, 130))
	_album_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right_col.add_child(_album_icon)
	_album_name = Label.new()
	_album_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_album_name.add_theme_font_size_override("font_size", 22)
	right_col.add_child(_album_name)
	_album_text = Label.new()
	_album_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_album_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_album_text.custom_minimum_size = Vector2(220, 0)
	_album_text.add_theme_font_size_override("font_size", 16)
	_album_text.add_theme_color_override("font_color", Color(UiTheme.INK, 0.8))
	right_col.add_child(_album_text)
	_add_button(_album_page, "dibujos_volver", "Volver", func() -> void: show_page("principal"))


## Rellena el álbum con los dibujos del diorama de ahora y enseña el primero encontrado.
func _fill_album() -> void:
	for b in album_slots:
		b.queue_free()
	album_slots.clear()
	_album_items.clear()
	var d := GameState.diorama
	if d == null or not is_instance_valid(d):
		return
	var first := -1
	for it in d.interactables:
		if it.kind != NameRules.COLLECTIBLE:
			continue
		var i := _album_items.size()
		_album_items.append(it)
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(58, 70)
		b.add_theme_stylebox_override("normal", UiTheme._box(Color(UiTheme.PAPER, 0.6), 8, Color(0, 0, 0, 0), 0, 0, 6, 6))
		b.add_theme_stylebox_override("hover", UiTheme._box(UiTheme.PAPER, 8, Color(UiTheme.WOOD, 0.6), 0, 2, 6, 6))
		b.add_theme_stylebox_override("pressed", UiTheme._box(UiTheme.PAPER, 8, UiTheme.WOOD_DARK, 0, 3, 6, 6))
		b.add_theme_stylebox_override("hover_pressed", UiTheme._box(UiTheme.PAPER, 8, UiTheme.WOOD_DARK, 0, 3, 6, 6))
		var icon := DibujoIcono.new(Vector2(36, 46))
		icon.position = Vector2(11, 12)          # centrado en la casilla de 58×70
		icon.faded = not it.collected
		icon.color = Hud.drawing_color(it.target)
		icon.texture = Hud.drawing_texture(it.target)
		b.add_child(icon)
		if not it.collected:
			b.text = "?"
			for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(state, Color(UiTheme.INK, 0.45))
		b.pressed.connect(_show_drawing.bind(i))
		_album_grid.add_child(b)
		album_slots.append(b)
		if first < 0 and it.collected:
			first = i
	var found := _album_items.filter(func(it: Interactable) -> bool: return it.collected).size()
	_album_count.text = tr("Dibujos de cuando era pequeña · %d de %d") % [found, _album_items.size()]
	_show_drawing(maxi(first, 0))


## La página de la derecha: el dibujo elegido, en grande (o su silueta si aún no está).
func _show_drawing(i: int) -> void:
	if i < 0 or i >= _album_items.size():
		return
	var it: Interactable = _album_items[i]
	for k in album_slots.size():
		album_slots[k].set_pressed_no_signal(k == i)
	_album_icon.faded = not it.collected
	_album_icon.color = Hud.drawing_color(it.target)
	_album_icon.texture = Hud.drawing_texture(it.target)
	_album_name.text = Narrator.piece_name(it.id, true) if it.collected else "???"
	_album_text.text = Narrator.text("logro_dibujo") if it.collected else "Todavía no lo has encontrado. Está escondido por el desván."


## (Tests) Lo que enseña la página de la derecha: "nombre | texto".
func album_detail() -> String:
	return "%s | %s" % [_album_name.text, _album_text.text]


## can_go_menu = false durante el puzle del título (no hay "menú principal" al que volver).
func open(can_go_menu: bool) -> void:
	if visible:
		return
	if GameState.drag != null:
		GameState.drag.cancel()
	buttons.menu.visible = can_go_menu
	var d := GameState.diorama
	buttons.dibujos.visible = d != null and is_instance_valid(d) and d.collectible_total() > 0
	show()
	get_tree().paused = true
	show_page("principal")
	Juice.pop_in(_panel, 0.0, 0.88, 0.4)


func resume() -> void:
	close()


func close() -> void:
	Settings.save_now()
	hide()
	get_tree().paused = false


func is_open() -> bool:
	return visible


func show_page(p: String) -> void:
	page = p
	_main_page.visible = p == "principal"
	_options_page.visible = p == "opciones"
	_album_page.visible = p == "dibujos"
	_achievements_page.visible = p == "logros"
	if p == "logros":
		logros.refresh()
	if p == "opciones":
		options.refresh()
	if p == "dibujos":
		_fill_album()
	var shown: Control = {"principal": _main_page, "opciones": _options_page, "dibujos": _album_page,
		"logros": _achievements_page}.get(p, _main_page)
	Juice.stagger(shown)
	for c in shown.find_children("*", "Button", true, false):
		if (c as Button).is_visible_in_tree():
			(c as Button).grab_focus.call_deferred()
			break


func _add_button(parent: Control, key: String, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.pressed.connect(action)                    # (su sonido, el de todo botón: ui/juice.gd)
	parent.add_child(b)
	buttons[key] = b
	return b


func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e.is_action_pressed("back"):
		if page != "principal":
			show_page("principal")
		else:
			resume()
		get_viewport().set_input_as_handled()
