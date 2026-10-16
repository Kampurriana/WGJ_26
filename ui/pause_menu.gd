class_name PauseMenu
extends CanvasLayer
## Pausa (Esc, botón "Menú" o B en el mando): para el juego y ofrece Reanudar, Opciones,
## Menú principal (no durante el puzle del título: ya estás en él) y Salir (no en Web).

signal main_menu_requested

var buttons: Dictionary = {}                ## nombre -> Button (los tests pulsan por aquí)
var options: OptionsPanel
var page := ""

var _main_page: VBoxContainer
var _options_page: VBoxContainer


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.12, 0.08, 0.05, 0.45)
	root.add_child(dim)                     # tapa el juego: los clics no pasan al diorama
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(420, 0)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var title := Label.new()
	title.text = "Pausa"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	v.add_child(title)
	_main_page = VBoxContainer.new()
	_main_page.add_theme_constant_override("separation", 10)
	v.add_child(_main_page)
	_add_button(_main_page, "reanudar", "Reanudar", resume)
	_add_button(_main_page, "opciones", "Opciones", func() -> void: show_page("opciones"))
	_add_button(_main_page, "menu", "Menú principal", func() -> void:
		close()
		main_menu_requested.emit())
	var quit := _add_button(_main_page, "salir", "Salir del juego", func() -> void: get_tree().quit())
	quit.visible = not OS.has_feature("web")
	_options_page = VBoxContainer.new()
	_options_page.add_theme_constant_override("separation", 10)
	v.add_child(_options_page)
	options = OptionsPanel.new(false)
	_options_page.add_child(options)
	_add_button(_options_page, "opciones_volver", "Volver", func() -> void: show_page("principal"))
	hide()


## can_go_menu = false durante el puzle del título (no hay "menú principal" al que volver).
func open(can_go_menu: bool) -> void:
	if visible:
		return
	if GameState.drag != null:
		GameState.drag.cancel()
	buttons.menu.visible = can_go_menu
	show()
	get_tree().paused = true
	show_page("principal")


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
	if p == "opciones":
		options.refresh()
	for c in (_main_page if p == "principal" else _options_page).find_children("*", "Button", true, false):
		if (c as Button).is_visible_in_tree():
			(c as Button).grab_focus.call_deferred()
			break


func _add_button(parent: Control, key: String, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50)
	b.pressed.connect(func() -> void:
		Sfx.play("click", 0.0)
		action.call())
	parent.add_child(b)
	buttons[key] = b
	return b


func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e.is_action_pressed("back"):
		if page == "opciones":
			show_page("principal")
		else:
			resume()
		get_viewport().set_input_as_handled()
