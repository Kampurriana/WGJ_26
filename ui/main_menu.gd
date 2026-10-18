class_name MainMenu
extends CanvasLayer
## Menú de inicio. Sale a la izquierda, encima del diorama del título, cuando su puzle está
## resuelto (o directamente si ya se resolvió en otra partida). El título del juego es el letrero
## que el jugador acaba de montar: el panel no lo repite. Páginas:
##   principal  Jugar/Continuar · Opciones · Logros · Créditos · Salir (no en Web). Sin selector de
##              nivel: el juego es un solo diorama (el desván)
##   opciones   OptionsPanel con "Borrar progreso"
##   creditos   el texto de data/creditos_es.txt
## Teclado: flechas + Intro. Esc vuelve a la página principal.

signal play_requested(index: int)

const WIDTH := 430.0
const PAGE_MAX_HEIGHT := 440.0
const CREDITS_PATH := "res://data/creditos_es.txt"

var buttons: Dictionary = {}                ## nombre -> Button (los tests pulsan por aquí)
var options: OptionsPanel
var page := ""
var pending_page := ""                      ## página con la que abrirse la próxima vez (capturas)

var _panel: PanelContainer
var _pages: Dictionary = {}                 ## nombre -> Control
var logo: Logo                               ## el logo montado con las piezas de las artistas (ui/logo.gd)
var _logros: LogrosLista


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_floating_theme()    # sin recuadro: el logo y las opciones flotan
	add_child(root)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)    # anclado arriba: lo de arriba no se mueve y
	_panel.offset_left = 48                               # lo nuevo se despliega hacia abajo
	_panel.offset_top = 110
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	root.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_panel.add_child(v)
	_build_main(v)
	_build_options(v)
	_build_achievements(v)
	_build_credits(v)
	hide()


func open(p := "principal") -> void:
	var tab := -1
	if pending_page != "":
		p = pending_page
		pending_page = ""
		if p.contains(":"):                      # (capturas) "opciones:2" = la pestaña Juego
			tab = p.get_slice(":", 1).to_int()
			p = p.get_slice(":", 0)
	buttons.jugar.text = "Continuar" if GameState.has_progress() else "Jugar"
	show()
	show_page(p)
	if tab >= 0:
		options.show_tab(tab)
	Juice.pop_in(_panel, 0.0, 0.88, 0.4)         # el panel llega con un saltito
	if p == "principal":
		logo.play_intro(0.15)                    # y las piezas del logo, una tras otra


func close() -> void:
	Settings.save_now()
	hide()


func is_open() -> bool:
	return visible


func show_page(p: String) -> void:
	if not _pages.has(p):
		push_warning("MainMenu: no existe la página '%s'" % p)
		p = "principal"
	if page == "opciones" and p != "opciones":
		Settings.save_now()
	page = p
	for k: String in _pages:
		(_pages[k] as Control).visible = k == p
	if p == "opciones":
		options.refresh()
	elif p == "logros":
		_logros.refresh()
	Juice.stagger(_pages[p])                     # y lo de la página, uno tras otro
	_focus_first(_pages[p])


# --- Páginas -----------------------------------------------------------------------------

func _build_main(parent: Control) -> void:
	var p := VBoxContainer.new()
	p.add_theme_constant_override("separation", 10)
	logo = Logo.new(430.0)                       # encima de las opciones; cada pieza se mueve a su aire
	logo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_child(logo)
	_add_button(p, "jugar", "Jugar", func() -> void: play_requested.emit(GameState.next_level_to_play()))
	_add_button(p, "opciones", "Opciones", func() -> void: show_page("opciones"))
	_add_button(p, "logros", "Logros", func() -> void: show_page("logros"))
	_add_button(p, "creditos", "Créditos", func() -> void: show_page("creditos"))
	var quit := _add_button(p, "salir", "Salir", func() -> void: Sfx.quit())
	quit.visible = not OS.has_feature("web")     # en el navegador no hay "salir"
	_add_page(parent, "principal", p)


func _build_options(parent: Control) -> void:
	var p := VBoxContainer.new()
	p.add_theme_constant_override("separation", 10)
	p.add_child(_heading("Opciones"))
	options = OptionsPanel.new(true)
	p.add_child(_scroll(options))
	_add_button(p, "opciones_volver", "Volver", func() -> void: show_page("principal"))
	_add_page(parent, "opciones", p)


func _build_achievements(parent: Control) -> void:
	var p := VBoxContainer.new()
	p.add_theme_constant_override("separation", 10)
	p.add_child(_heading("Logros"))
	_logros = LogrosLista.new()
	p.add_child(_scroll(_logros))
	_add_button(p, "logros_volver", "Volver", func() -> void: show_page("principal"))
	_add_page(parent, "logros", p)


func _build_credits(parent: Control) -> void:
	var p := VBoxContainer.new()
	p.add_theme_constant_override("separation", 10)
	p.add_child(_heading("Créditos"))
	var text := Label.new()
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(WIDTH - 70, 0)
	text.text = FileAccess.get_file_as_string(CREDITS_PATH).strip_edges()
	if text.text == "":
		push_warning("MainMenu: %s vacío o no existe" % CREDITS_PATH)
	p.add_child(_scroll(text))
	_add_button(p, "creditos_volver", "Volver", func() -> void: show_page("principal"))
	_add_page(parent, "creditos", p)


# --- Piezas de interfaz ------------------------------------------------------------------

func _add_page(parent: Control, p: String, node: Control) -> void:
	node.hide()
	_pages[p] = node
	parent.add_child(node)


func _add_button(parent: Control, key: String, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT          # opciones en texto, alineadas bajo el logo
	b.custom_minimum_size = Vector2(0, 46)
	b.pressed.connect(func() -> void:
		Sfx.play("click", 0.0)
		action.call())
	parent.add_child(b)
	buttons[key] = b
	return b


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	UiTheme.style_title(l, 40)
	return l


## Un ScrollContainer no pide altura por su contenido: se la damos a mano, hasta PAGE_MAX_HEIGHT
## (a partir de ahí, scroll). Así el panel crece con la página y nunca se sale de la pantalla.
func _scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	var fit := func() -> void: s.custom_minimum_size.y = minf(content.get_combined_minimum_size().y, PAGE_MAX_HEIGHT)
	content.minimum_size_changed.connect(fit)
	fit.call_deferred()
	return s


func _focus_first(node: Control) -> void:
	for c in node.find_children("*", "Button", true, false):
		var b := c as Button
		if b.is_visible_in_tree() and not b.disabled:
			b.grab_focus.call_deferred()
			return


func _unhandled_input(e: InputEvent) -> void:
	if visible and page != "principal" and e.is_action_pressed("back"):
		show_page("principal")
		get_viewport().set_input_as_handled()
