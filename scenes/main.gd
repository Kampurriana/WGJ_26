extends Node3D
## Escena principal: monta cámara, arrastre, interfaz, menús, mando y la luz de cada nivel.
## Orden (cuarta nota): el puzle del título (el cerdito, con sus frases) → el menú, con el cerdito y
## sin frases (se abre cuando acaban) → los actos → el espejo → transición → la hucha → fundido →
## créditos (ui/creditos.gd) → el menú otra vez. Una vez resuelto el título, sale ya montado.
## Los niveles jugables vienen de data/levels.json; el progreso se guarda en GameState.
##
## Argumentos para Claude (después de "--" en la línea de comandos):
##   --level=N            empieza directamente en el nivel N (índice de data/levels.json)
##   --level=menu         empieza en el menú de inicio (igual que sin --level)
##   --menu-page=P        al abrirse el menú, en la página P (opciones, logros, creditos);
##                        "pausa" abre la pausa nada más cargar; "dibujos" (o "dialogos"), la pausa en esa página (a los 1,5 s,
##                        para que --f9 ya haya colgado los dibujos)
##   --solve=K            coloca K piezas solo (jugador automático), una cada 0,3 s; solo dice la frase de la última
##   --capture=ruta.png   guarda una captura (relativa al proyecto) y sale
##   --capture-after=S    segundos de espera antes de la captura (por defecto 3)
##   --capturas=N,S       (capturas) N capturas, una cada S segundos (ruta_00.png, ruta_01.png...): una animación
##   --rincon=ID          (capturas) monta solo hasta que se abre el rincón que da ID (hucha, mp3) y entra en él
##   --prototipo          se juega el desván prototipo (figuras provisionales) en vez del oficial
##   --capitulo           (capturas) al segundo de empezar, la estructura del desván ya puesta y se abre el
##                        capítulo I como en la partida: su rótulo y, cuando se va, sus cosas apareciendo
##   --hold=X,Y           (capturas) coge la pieza más grande del panel y la lleva a ese punto
##   --zoom=K,X,Y         (capturas) K pasos de zoom hacia ese punto de la pantalla
##   --f9                 (capturas) pulsa F9 al segundo de empezar: el diorama entero de golpe
##   --sin-interfaz       (capturas) la captura sale sin la interfaz del juego (portada y capturas de itch.io)
##   --presentacion       (capturas) con la presentación del principio (las capturas, si no, empiezan sin ella)
##   --creditos           (capturas) al segundo de empezar pasan los créditos del final
##   --inspeccion         (capturas) al segundo de empezar, el primer plano de un dibujo (como al encontrarlo)
##   --logro=ID           (capturas) al segundo de empezar, el aviso de ese logro y su estrella volando
##   --fondo=C,M          (capturas) el fondo con el color C y el motivo M (ui/fondos.gd)
##   --solo-fondo         (capturas) sin diorama ni partículas: el fondo solo, para medir la luz

const MENU_DELAY := 1.6                      ## tras resolver el título, lo que dura la onda de color
const FADE_TIME := 0.7                       ## fundido desde negro al cargar un diorama
const END_FADE_TIME := 2.5                   ## fundido a negro del final de la historia (Diorama.fundido_final)
const BLACKOUT_TIME := 0.6                   ## al darle a Jugar (sexta nota): la pantalla se va a negro...
const BLACKOUT_HOLD := 0.25                  ## ...un instante a oscuras (ahí se carga el diorama)...
const BLACKOUT_IN := 1.1                     ## ...y el diorama aparece desde el negro (s)
const DEFAULT_LIGHTING := "res://iluminacion/luz_por_defecto.tscn"
# Volumen de cada canción, medido (ffmpeg ebur128): Ankui está masterizada muy baja (-32 LUFS, pico
# -15 dB) y Loft a -27,6 LUFS. Con el bus Musica al 0,7 de las Opciones, el menú queda en ~-22 LUFS y
# la partida ~5 LU por debajo, de fondo ("volumen moderado"), sin que ninguna llegue a recortar.
const MUSIC_MENU_DB := 13.0                  ## Ankui (musica/menu): puzle del título y menú
const MUSIC_GAME_DB := 3.5                   ## Loft (musica/juego): en bucle durante la partida

var start_in_menu := true                    ## los tests lo ponen a false para ir directos al nivel
var splash: Presentacion                     ## la presentación del principio, mientras está (ui/presentacion.gd)
var _force_splash := false
var _entrance_delay := 0.0                   ## (presentación) el inicio del cerdito espera a que se abra
var _skip_fade := false                      ## (presentación) el título aparece por su círculo, no desde negro
var menu: MainMenu
var pause: PauseMenu
var credits: Creditos
var effects: Efectos
var momentos: Momentos
var inspeccion: Inspeccion                   ## el primer plano de un dibujo encontrado (sexta nota)
var logros: Logros                           ## los logros (core/logros.gd)
var enfoque: Enfoque
var _level: Node
var _lighting: Node
var _fade: ColorRect
var _fade_tween: Tween
var blacking_out := false                    ## yendo a negro desde el menú (no se puede tocar nada)
var _flash: ColorRect
var _only_background := false
var _lighting_path := ""
var _menu_page := ""
var _hold := Vector2(-1, -1)
var _zoom_steps := 0
var _press_f9 := false
var _no_hud := false
var _roll_credits := false
var _inspect := false
var _celebrate := ""
var _zoom_at := Vector2.ZERO
var _capture_path := ""
var _capture_after := 3.0
var _shots := 1                              ## (--capturas) cuántas y cada cuánto
var _shot_every := 0.0
var _shot_n := 0
var _open_chapter := false
var _corner := ""
var _solve_left := 0
var _solve_timer := 0.0
var _elapsed := 0.0
## Si no está vacío, el juego tiene solo este nivel en vez de los de data/levels.json (el prototipo del
## desván se juega así: levels/prototipo/jugar_prototipo.tscn, o el argumento --prototipo).
@export_file("*.tscn") var solo_nivel := ""
const PROTOTIPO := "res://levels/prototipo/desvan_prototipo.tscn"


func _ready() -> void:
	# main sigue viva en pausa (capturas, menús, mando); lo que es "juego" se pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Juice.watch(get_tree())                      # todo botón que aparezca, con sus animaciones (ui/juice.gd)
	# El fondo pastel pasa por el tonemap del 3D: sin HDR en 2D, el lienzo se corta en 1,0 y no sale
	# de un gris apagado (medido: tope 208/255). Con HDR sale el color calibrado (iluminacion/fondo.gdshader).
	get_viewport().use_hdr_2d = true
	_parse_args()
	if solo_nivel != "":
		GameState.levels = PackedStringArray([solo_nivel])
	var cam := DioramaCamera.new()
	cam.name = "Camera"
	cam.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(cam)
	GameState.camera = cam
	var drag := DragController.new()
	drag.name = "Drag"
	drag.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(drag)
	GameState.drag = drag
	effects = Efectos.new()
	effects.name = "Efectos"
	effects.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(effects)
	var hud := Hud.new()
	hud.name = "Hud"
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hud)
	GameState.hud = hud
	enfoque = Enfoque.new()                     # antes que Momentos: el desenfoque va debajo de su foco
	enfoque.name = "Enfoque"
	enfoque.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(enfoque)
	GameState.enfoque = enfoque
	momentos = Momentos.new()
	momentos.name = "Momentos"
	momentos.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(momentos)
	inspeccion = Inspeccion.new()
	inspeccion.name = "Inspeccion"
	inspeccion.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(inspeccion)
	logros = Logros.new()
	logros.name = "Logros"
	add_child(logros)
	add_child(GamepadCursor.new())
	menu = MainMenu.new()
	menu.name = "MainMenu"
	add_child(menu)
	pause = PauseMenu.new()
	pause.name = "PauseMenu"
	add_child(pause)
	credits = Creditos.new()
	credits.name = "Creditos"
	add_child(credits)
	credits.finished.connect(_after_credits)
	_build_fade()
	hud.next_requested.connect(next_level)
	Events.flash_requested.connect(flash)
	Events.section_opened.connect(func(sec: RefCounted) -> void:
		if GameState.mode == GameState.Mode.PLAYING and not GameState.camera.in_moment:   # el epílogo es un momento
			GameState.camera.frame_box((sec as Section).box()))
	hud.pause_requested.connect(open_pause)
	menu.play_requested.connect(blackout_to_level)
	pause.main_menu_requested.connect(show_title)
	Events.level_completed.connect(_on_level_completed)
	Settings.changed.connect(func(key: String) -> void:
		if key.begins_with("fondo_"):
			_apply_background())
	if start_in_menu and (_capture_path == "" or _force_splash):
		_start_with_splash()
	elif start_in_menu:
		show_title()
	else:
		load_level(GameState.level_index)
	if _menu_page == "pausa":
		open_pause()
	elif _menu_page == "dibujos" or _menu_page == "dialogos":
		pass                                     # en _process, cuando ya han pasado F9 y compañía
	elif _menu_page != "":
		menu.pending_page = _menu_page


## Al abrir el juego: la presentación (el cerdito de la pantalla de carga, vivo) y, cuando empieza a
## irse, el título debajo, que se ve por el círculo que se abre (sin fundido desde negro); el inicio
## del cerdito (bandeja, botones) espera a que se vea entero.
func _start_with_splash() -> void:
	splash = Presentacion.new()
	splash.name = "Presentacion"
	add_child(splash)
	splash.opening.connect(func() -> void:
		_skip_fade = true
		_entrance_delay = Presentacion.REVEAL_TIME
		show_title()
		_entrance_delay = 0.0)
	splash.finished.connect(func() -> void: splash = null)


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			var v := a.get_slice("=", 1)
			start_in_menu = v == "menu"
			if not start_in_menu:
				GameState.level_index = v.to_int()
		elif a.begins_with("--menu-page="):
			_menu_page = a.get_slice("=", 1)
		elif a.begins_with("--hold="):
			var v := a.get_slice("=", 1).split_floats(",")
			_hold = Vector2(v[0], v[1])
		elif a.begins_with("--zoom="):
			var v := a.get_slice("=", 1).split_floats(",")
			_zoom_steps = int(v[0])
			_zoom_at = Vector2(v[1], v[2])
		elif a.begins_with("--solve="):
			_solve_left = a.get_slice("=", 1).to_int()
		elif a.begins_with("--capture="):
			_capture_path = a.get_slice("=", 1)
		elif a.begins_with("--capture-after="):
			_capture_after = a.get_slice("=", 1).to_float()
		elif a.begins_with("--capturas="):
			var v := a.get_slice("=", 1).split_floats(",")
			_shots = maxi(1, int(v[0]))
			_shot_every = v[1] if v.size() > 1 else 0.25
		elif a == "--capitulo":
			_open_chapter = true
		elif a.begins_with("--rincon="):
			_corner = a.get_slice("=", 1)
		elif a == "--prototipo":
			solo_nivel = PROTOTIPO
		elif a == "--solo-fondo":
			_only_background = true
		elif a == "--f9":
			_press_f9 = true
		elif a == "--presentacion":
			_force_splash = true
		elif a == "--sin-interfaz":
			_no_hud = true
		elif a == "--creditos":
			_roll_credits = true
		elif a == "--inspeccion":
			_inspect = true
		elif a.begins_with("--logro="):
			_celebrate = a.get_slice("=", 1)
		elif a.begins_with("--fondo="):          # (capturas) color,motivo del fondo: --fondo=1,1
			var v := a.get_slice("=", 1).split(",")
			Settings.set_value("fondo_color", int(v[0]))
			Settings.set_value("fondo_motivo", int(v[1]) if v.size() > 1 else 0)


## (--capitulo) Pone la estructura del desván de golpe y abre el capítulo siguiente por el camino de la
## partida («Continuar», rótulo y, cuando se va, sus cosas apareciendo), sin el momento de la hucha.
func _open_first_chapter() -> void:
	var d := GameState.diorama
	var guard := 0
	while d.opening_section() == null and not d.completed and guard < 200:
		d.debug_solve_step()
		guard += 1
	Narrator.clear()
	if momentos.active:
		momentos.finish()
	d.continue_act()                         # como si pulsara «Continuar»


## (--rincon) Monta solo hasta que el rincón que da `reward` está a la vista y entra en él (primer plano).
func _enter_corner(reward: StringName) -> void:
	var d := GameState.diorama
	var bench: Interactable = null
	for it in d.interactables:
		if it.kind == NameRules.ZOOM and it.reward == reward:
			bench = it
	if bench == null:
		return
	var guard := 0
	while bench.section != null and not bench.section.opened and guard < 400:
		if d.act_waiting():
			d.continue_act()
			d._open_pending(d.opening_section())
			d._reveal_pending(d.opening_section())
		else:
			d.debug_solve_step()
		Narrator.clear()
		if momentos.active:
			momentos.finish()
		guard += 1
	while d.focus != null:
		d.exit_focus()
	d.enter_focus(bench)
	var cam := GameState.camera
	print("RINCON %s: centro %s distancia %.2f inclinación %.1f giro %.1f momento %s" % [reward, cam.center, cam.distance, cam.pitch, cam.yaw, cam.in_moment])


## Cortina negra por encima de todo (menos de lo que no deja de verse): se abre al cargar.
func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_flash = ColorRect.new()
	_flash.color = Color(1, 0.98, 0.94, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)


## Destello blanco (el flash de la cámara de fotos): la pantalla en blanco un instante.
func flash() -> void:
	var tw := _flash.create_tween()
	tw.tween_property(_flash, "color:a", 0.92, 0.07)
	tw.tween_interval(0.12)
	tw.tween_property(_flash, "color:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _fade_in(seconds := FADE_TIME) -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	_fade.color.a = 1.0
	_fade_tween = _fade.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(_fade, "color:a", 0.0, seconds)


## La luz vive en escenas de iluminacion/ que se ajustan en el editor (docs/ILUMINACION.md), no aquí.
## Cada nivel usa la suya si la indica (Diorama.iluminacion) y si no, la de por defecto. Solo hay
## una a la vez: dos WorldEnvironment no se suman (manda uno) y dos soles sí (doble de luz).
func _apply_lighting(path: String) -> void:
	if path == _lighting_path:
		return
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Main: no puedo cargar la iluminación '%s'; uso la de por defecto" % path)
		if path == DEFAULT_LIGHTING:
			return
		return _apply_lighting(DEFAULT_LIGHTING)
	if _lighting != null:
		remove_child(_lighting)
		_lighting.queue_free()
	_lighting = scene.instantiate()
	_lighting.name = "Iluminacion"
	add_child(_lighting)
	_lighting_path = path
	_apply_background()


## El fondo que eligió el jugador en Opciones (ui/fondos.gd), en el de la escena de luz; y la viñeta,
## del oscuro de ese mismo tono.
func _apply_background() -> void:
	var rect := _lighting.get_node_or_null("Fondo/Degradado") as CanvasItem if _lighting != null else null
	if rect != null:
		Fondos.apply(rect.material as ShaderMaterial, true, Settings.get_value("fondo_color"), Settings.get_value("fondo_motivo"))
	var vignette := _lighting.get_node_or_null("Vineta/Sombra") as CanvasItem if _lighting != null else null
	if vignette != null and vignette.material is ShaderMaterial:
		(vignette.material as ShaderMaterial).set_shader_parameter("color", Fondos.dark(Settings.get_value("fondo_color")))


func load_level(index: int) -> void:
	if GameState.levels.is_empty():
		return
	GameState.level_index = clampi(index, 0, GameState.levels.size() - 1)
	GameState.mode = GameState.Mode.PLAYING
	Sfx.music("juego", MUSIC_GAME_DB)
	_load(GameState.levels[GameState.level_index])


## El diorama del título. Si ya se resolvió alguna vez, sale montado y con el menú abierto.
func show_title() -> void:
	get_tree().paused = false
	GameState.mode = GameState.Mode.MENU
	Sfx.music("menu", MUSIC_MENU_DB)
	var unlocked := GameState.menu_unlocked
	_load(GameState.MENU_LEVEL, unlocked)
	if unlocked:
		GameState.diorama.complete_silently()
		_open_menu()
	else:
		GameState.camera.set_menu_view(false)
		GameState.hud.set_game_ui_visible(true)
		GameState.hud.stage_entrance(_entrance_delay)   # el cerdito; luego la bandeja; luego los botones


## Desde el menú (Jugar, Continuar o un diorama elegido): la pantalla se va a negro con el menú
## encima, a oscuras se carga el diorama y aparece desde el negro (sexta nota: "transición blackout").
## Mientras dura, la cortina no deja tocar nada.
func blackout_to_level(index: int) -> void:
	if blacking_out:
		return
	blacking_out = true
	Sfx.music("juego", MUSIC_GAME_DB, BLACKOUT_TIME + BLACKOUT_HOLD + BLACKOUT_IN)   # cambia con el negro
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = _fade.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_property(_fade, "color:a", 1.0, BLACKOUT_TIME)
	_fade_tween.tween_interval(BLACKOUT_HOLD)
	_fade_tween.tween_callback(func() -> void:
		blacking_out = false
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		play_level(index)
		_fade_in(BLACKOUT_IN))


func play_level(index: int) -> void:
	menu.close()
	GameState.camera.set_menu_view(false)
	GameState.hud.set_game_ui_visible(true)
	load_level(index)


func next_level() -> void:
	if GameState.level_index + 1 < GameState.levels.size():
		load_level(GameState.level_index + 1)
	else:
		roll_credits()


## Fin del juego: pasan los créditos (con los dibujos encontrados) y luego, el menú.
func roll_credits() -> void:
	var d := GameState.diorama
	var found: Array = []
	var total := 0
	if d != null and is_instance_valid(d):
		total = d.collectible_total()
		for it in d.interactables:
			if it.kind == NameRules.COLLECTIBLE and it.collected:
				found.append({"color": Hud.drawing_color(it.target), "textura": Hud.drawing_texture(it.target)})
	Narrator.clear()
	momentos.reset()
	GameState.drag.cancel()
	GameState.hud.set_game_ui_visible(false)
	credits.play(found, total)
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = _fade.create_tween()           # los créditos aparecen desde el negro del final
	_fade_tween.tween_property(_fade, "color:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE)


func _after_credits() -> void:
	if _fade_tween != null:
		_fade_tween.kill()
	_fade.color.a = 1.0                          # el menú aparece desde negro (show_title funde)
	show_title()


func open_pause() -> void:
	if menu.is_open():
		return
	pause.open(GameState.mode == GameState.Mode.PLAYING)


func _open_menu() -> void:
	Narrator.clear()                             # el menú, sin frases
	GameState.hud.set_game_ui_visible(false)
	GameState.camera.set_menu_view(true)
	menu.open()


func _on_level_completed(d: Node) -> void:
	if GameState.mode == GameState.Mode.MENU:
		GameState.unlock_menu()
		# El menú sale cuando el cerdito ha acabado de hablar (y ha pasado la onda de color).
		get_tree().create_timer(maxf(MENU_DELAY, Narrator.remaining() + 0.4)).timeout.connect(func() -> void:
			if GameState.diorama == d and GameState.mode == GameState.Mode.MENU and not menu.is_open():
				_open_menu())
	else:
		GameState.mark_completed(GameState.levels[GameState.level_index])
		var ending := d as Diorama
		if ending != null and ending.fundido_final:
			# Final de la historia: deja que acabe la última frase y funde a negro hacia los créditos
			# (la segunda transición de la cuarta nota).
			var wait := maxf(Narrator.remaining() + 1.2, 3.0)
			get_tree().create_timer(wait).timeout.connect(func() -> void:
				if GameState.diorama != ending:
					return
				if _fade_tween != null:
					_fade_tween.kill()
				_fade_tween = _fade.create_tween()
				_fade_tween.tween_property(_fade, "color:a", 1.0, END_FADE_TIME).set_trans(Tween.TRANS_SINE)
				_fade_tween.tween_callback(func() -> void:
					if GameState.diorama == ending:
						roll_credits()))


## silent = sin la frase de entrada (el título ya montado no tiene que explicar nada).
func _load(path: String, silent := false) -> void:
	credits.cancel()
	if _level != null:
		GameState.drag.cancel()
		remove_child(_level)
		_level.queue_free()
	var scene: PackedScene = load(path)
	_level = scene.instantiate()
	_level.process_mode = Node.PROCESS_MODE_PAUSABLE
	if silent:
		_level.set("intro_key", "")
	add_child(_level)
	var own := String(_level.get("iluminacion")) if "iluminacion" in _level else ""
	_apply_lighting(own if own != "" else DEFAULT_LIGHTING)
	GameState.camera.configure(GameState.diorama)
	GameState.camera.intro()
	if _skip_fade:
		_skip_fade = false
	else:
		_fade_in()
	if _only_background:
		_level.hide()
		effects.hide()


func _process(delta: float) -> void:
	_elapsed += delta
	if _solve_left > 0:
		_solve_timer -= delta
		if _solve_timer <= 0.0:
			_solve_timer = 0.3
			_solve_left -= 1
			if inspeccion.is_open():
				inspeccion.close_now()           # el paso automático no se queda mirando un dibujo
			GameState.diorama.debug_solve_step()
			if _solve_left > 0:
				Narrator.clear()                 # en la captura se oye (y se ve) solo la última frase
	if _press_f9 and _elapsed > 1.0:
		_press_f9 = false
		var key := InputEventKey.new()
		key.physical_keycode = KEY_F9
		key.pressed = true
		Input.parse_input_event(key)         # por el mismo camino que la tecla de verdad
	if _roll_credits and _elapsed > 1.0:
		_roll_credits = false
		roll_credits()
	if _corner != "" and _elapsed > 1.0 and GameState.diorama != null:
		_enter_corner(StringName(_corner))
		_corner = ""
	if _open_chapter and _elapsed > 1.0 and GameState.diorama != null:
		_open_chapter = false
		_open_first_chapter()
	if (_menu_page == "dibujos" or _menu_page == "dialogos") and _elapsed > 1.5 and _solve_left == 0:
		var p := _menu_page
		_menu_page = ""
		open_pause()
		pause.show_page(p)
	if _celebrate != "" and _elapsed > 1.0:
		GameState.hud.stars.celebrate(_celebrate)
		_celebrate = ""
	if _inspect and _elapsed > 1.0:
		_inspect = false
		var d := GameState.diorama
		for it in d.interactables if d != null else []:
			if it.kind == NameRules.COLLECTIBLE:
				inspeccion.open(it, 3, d.collectible_total())    # solo para mirarla: no lo encuentra
				break
	if _zoom_steps > 0 and _elapsed > 0.5:
		_zoom_steps -= 1
		GameState.camera.zoom_at(1.0 - GameState.camera.zoom_step, _zoom_at)
	if _hold.x >= 0.0 and _elapsed > 1.0 and _solve_left == 0 and not GameState.is_dragging:
		var cards := GameState.hud.cards(true)
		if not cards.is_empty():
			var card: InventoryItem = cards[0]
			GameState.drag.begin(card.piece_id, card)
			GameState.drag.hold_at(_hold)
		_hold = Vector2(-1, -1)
	if _no_hud and GameState.hud != null:
		GameState.hud.visible = false
	if _capture_path != "" and _elapsed >= _capture_after and _solve_left == 0:
		var img := get_viewport().get_texture().get_image()
		var path := _capture_path if _shots == 1 else "%s_%02d.png" % [_capture_path.get_basename(), _shot_n]
		var out := ProjectSettings.globalize_path("res://" + path)
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var err := img.save_png(out)
		print("CAPTURA %s %dx%d err=%d" % [out, img.get_width(), img.get_height(), err])
		_shot_n += 1
		if _shot_n < _shots:
			_capture_after += _shot_every
			return
		_capture_path = ""
		Sfx.quit()
