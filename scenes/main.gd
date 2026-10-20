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
##   --rincon=ID          (capturas) monta solo hasta que se abre el rincón (Z_ __monta) que da ID y entra en él
##   --espejo             (capturas) monta solo hasta que solo falta el espejo y lo pone (su plano)
##   --prototipo          se juega el desván prototipo (figuras provisionales) en vez del oficial
##   --capitulo           (capturas) al segundo de empezar, la estructura del desván ya puesta y se abre el
##                        capítulo I como en la partida: su rótulo y, cuando se va, sus cosas apareciendo
##   --hold=X,Y           (capturas) coge la pieza más grande del panel y la lleva a ese punto
##   --zoom=K,X,Y         (capturas) K pasos de zoom hacia ese punto de la pantalla
##   --f9                 (capturas) pulsa F9 al segundo de empezar: el diorama entero de golpe
##   --sin-interfaz       (capturas) la captura sale sin la interfaz del juego (portada y capturas de itch.io)
##   --tiro=G,P[,Z]       (capturas) la cámara como la vista del diorama de la preview: giro G y caída P en
##                        grados, a 1,05 veces la diagonal del diorama (por Z); p. ej. --tiro=40,30
##   --presentacion       (capturas) con la presentación del principio (las capturas, si no, empiezan sin ella)
##   --creditos           (capturas) al segundo de empezar pasan los créditos del final
##   --inspeccion         (capturas) al segundo de empezar, el primer plano de un dibujo (como al encontrarlo)
##   --logro=ID           (capturas) al segundo de empezar, el aviso de ese logro y su estrella volando
##   --medir=S            (rendimiento) desde --capture-after, mide S segundos de fotogramas y sale: ms por
##                        fotograma (media y p95), llamadas de dibujo, objetos y tiempo de proceso
##   --sin=a,b            (rendimiento) quita partes para medir cuánto cuestan: post (enfoque y acabado de
##                        cine), madera (la capa de madera cruda), haz (la luz de la ventana en el aire), sombras,
##                        sombra_sol, sombra_ventana, ventana, bandeja (la interfaz), vistas (las fichas 3D),
##                        particulas, fondo, res75 (el 3D al 75 %), tope (sin el techo de resolución del 3D),
##                        proc:<script> (sin el _process de ese script, p. ej. proc:hud)
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
const MAX_3D_PIXELS := 1600.0 * 900.0       ## techo de píxeles del 3D (_cap_3d_resolution)
const MUSIC_MENU_DB := 13.0                  ## Ankui (musica/menu): puzle del título y menú
const MUSIC_GAME_DB := 3.5                   ## Loft (musica/juego): en bucle durante la partida
const MUSIC_CREDITS_DB := 0.0                ## «Little me» (musica/creditos, Drive 20-oct; el fichero, subido al nivel de la de antes: -23,6 LUFS): los créditos del final y su página del menú

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
var _tiro := Vector3.ZERO                    ## (capturas, --tiro) giro, caída y zoom de la cámara; z = 0: sin tiro
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
var _mirror := false                         ## (--espejo)
var _solve_left := 0
var _solve_timer := 0.0
var _elapsed := 0.0
var _measure := 0.0                          ## (--medir) segundos a medir; 0 = no se mide
var _measure_off: PackedStringArray = []     ## (--sin) lo que se quita para medirlo
var _frames: PackedFloat64Array = []
var _last_tick := 0
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
	get_viewport().size_changed.connect(_cap_3d_resolution)
	_cap_3d_resolution()
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
	# La cámara se queda quieta mientras está el rótulo del capítulo y, cuando aparecen sus cosas, se
	# desliza despacio hasta encuadrar la zona entera (18-oct: «arreglar el movimiento de la cámara al
	# anunciar el capítulo»: daba un salto a un encuadre cortado, con la zona aún vacía).
	Events.section_revealed.connect(func(sec: RefCounted) -> void:
		if GameState.mode == GameState.Mode.PLAYING and not GameState.camera.in_moment:   # el epílogo es un momento
			GameState.camera.frame_box((sec as Section).box()))
	hud.pause_requested.connect(open_pause)
	menu.play_requested.connect(blackout_to_level)
	menu.page_shown.connect(func(p: String) -> void:   # la página de créditos, con su canción
		if p == "creditos":
			Sfx.music("creditos", MUSIC_CREDITS_DB)
		elif Sfx.track == "creditos":
			Sfx.music("menu", MUSIC_MENU_DB))
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
	splash.wait_for_input = OS.has_feature("web")   # en la Web, el primer clic desbloquea el audio
	add_child(splash)
	splash.opening.connect(func() -> void:
		_skip_fade = true
		_entrance_delay = Presentacion.REVEAL_TIME
		show_title(true)                         # al abrir el juego, siempre se monta el cerdito
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
		elif a.begins_with("--medir="):
			_measure = a.get_slice("=", 1).to_float()
		elif a.begins_with("--sin="):
			_measure_off = a.get_slice("=", 1).split(",")
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
		elif a == "--espejo":
			_mirror = true
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
		elif a.begins_with("--tiro="):
			var t := a.get_slice("=", 1).split(",")
			_tiro = Vector3(t[0].to_float(), t[1].to_float() if t.size() > 1 else 30.0, t[2].to_float() if t.size() > 2 else 1.0)
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


## (--espejo) Acaba de golpe los capítulos de antes (como la tecla C), monta la adultez hasta que solo falta el
## espejo y lo pone: su plano, como en la partida.
func _place_mirror() -> void:
	var d := GameState.diorama
	var mirror: PieceSlot = null
	for s in d.slots:
		if s.reflejo:
			mirror = s
	if mirror == null:
		return
	var guard := 0
	while not (mirror.section.opened and d.is_unlocked(mirror)) and guard < 400:
		if mirror.section.opened:
			d.debug_solve_step()
		else:
			d.debug_complete_chapter()
		Narrator.clear()
		if momentos.active:
			momentos.finish()
		guard += 1
	d.place(mirror)


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


## (--tiro) La cámara como en la vista del diorama de la preview (preview_assets.gd, mostrar): mismo giro
## y caída, mirando al centro del diorama un poco por debajo, a 1,05 veces su diagonal. Sin límites ni
## vaivén, para que el tiro sea exactamente ese.
func _apply_tiro() -> void:
	var cam := GameState.camera
	var box := Visuals.global_aabb(GameState.diorama)
	cam.showcasing = false
	cam.yaw_min = -180.0
	cam.yaw_max = 180.0
	cam.pitch_min = 0.0
	cam.pitch_max = 89.0
	cam.yaw = _tiro.x
	cam.pitch = _tiro.y
	cam.center = box.get_center() + Vector3(0.0, -box.size.y * 0.12, 0.0)
	cam.distance = box.size.length() * 1.05 * _tiro.z
	cam.min_distance = minf(cam.min_distance, cam.distance)
	cam.max_distance = maxf(cam.max_distance, cam.distance)
	cam.snap()


func load_level(index: int) -> void:
	if GameState.levels.is_empty():
		return
	GameState.level_index = clampi(index, 0, GameState.levels.size() - 1)
	GameState.mode = GameState.Mode.PLAYING
	Sfx.music("juego", MUSIC_GAME_DB)
	_load(GameState.levels[GameState.level_index])


## El diorama del título. Si ya se resolvió alguna vez, sale montado y con el menú abierto (al volver de
## la partida o de los créditos); al abrir el juego (`again`), se vuelve a montar aunque el progreso
## guardado diga que ya se hizo (20-oct: «la de Windows se abre directamente en el menú»).
func show_title(again := false) -> void:
	get_tree().paused = false
	GameState.mode = GameState.Mode.MENU
	Sfx.music("menu", MUSIC_MENU_DB)
	var unlocked := GameState.menu_unlocked and not again
	_load(GameState.MENU_LEVEL, unlocked)
	if unlocked:
		GameState.diorama.complete_silently()
		_open_menu()
	else:
		if menu.is_open():
			menu.close()
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
	Sfx.jingle("transicion_desvan")                # la sintonía de pasar del menú al desván (Drive FXS)
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
	Sfx.music("creditos", MUSIC_CREDITS_DB, 1.2)  # su canción entra con los créditos (sale el menú)
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


## El 3D se dibuja como mucho a MAX_3D_PIXELS (19-oct: la build iba a tirones). En pantalla completa o en
## pantallas de mucha densidad (la Web multiplica por la del navegador) eran 2-4 veces más píxeles, cada uno
## con su sombra, su brillo y su desenfoque; la interfaz sigue a su tamaño, nítida. El enfoque de cine ya
## difumina: a 1600×900 no se nota.
func _cap_3d_resolution() -> void:
	var px := get_viewport().get_visible_rect().size
	var sz := Vector2(get_window().size) if get_window() != null else px
	var pixels := maxf(sz.x * sz.y, 1.0)
	get_viewport().scaling_3d_scale = clampf(sqrt(MAX_3D_PIXELS / pixels), 0.5, 1.0)


## (--medir) Un fotograma más de la medida; al acabar, el resumen y fuera. Lo de --sin se quita al empezar.
func _measure_frame() -> void:
	var now := Time.get_ticks_usec()
	if _last_tick == 0:
		_strip_for_measure()
	elif _last_tick > 0:
		_frames.append((now - _last_tick) / 1000.0)
	_last_tick = now
	if _frames.size() < 2 or _frames[_frames.size() - 1] <= 0.0 or (_elapsed - _capture_after) < _measure:
		return
	var sorted := _frames.duplicate()
	sorted.sort()
	var total := 0.0
	for f in _frames:
		total += f
	var avg := total / _frames.size()
	print("MEDIDA sin=%s fotogramas=%d media=%.1f ms (%.0f fps) p95=%.1f ms dibujos=%d objetos=%d primitivas=%d proceso=%.1f ms" % [
		",".join(_measure_off), _frames.size(), avg, 1000.0 / avg, sorted[int(sorted.size() * 0.95)],
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	_measure = 0.0
	Sfx.quit()


func _strip_for_measure() -> void:
	var d := GameState.diorama
	if _measure_off.has("post"):
		enfoque.visible = false
	if _measure_off.has("bandeja") and GameState.hud != null:
		GameState.hud.visible = false
	if _measure_off.has("res75"):
		get_viewport().scaling_3d_scale = 0.75
	if _measure_off.has("tope"):                 # (sin el techo de resolución del 3D)
		get_viewport().scaling_3d_scale = 1.0
	if _measure_off.has("particulas"):
		effects.visible = false
		effects.process_mode = Node.PROCESS_MODE_DISABLED
	for n in get_tree().root.find_children("*", "", true, false):
		if _measure_off.has("madera") and n is GeometryInstance3D:
			(n as GeometryInstance3D).material_overlay = null
		if _measure_off.has("sombras") and n is Light3D:
			(n as Light3D).shadow_enabled = false
		if _measure_off.has("sombra_sol") and n is DirectionalLight3D:
			(n as Light3D).shadow_enabled = false
		if _measure_off.has("sombra_ventana") and n is SpotLight3D:
			(n as Light3D).shadow_enabled = false
		if _measure_off.has("ventana") and n is SpotLight3D and n.name == &"SolTarde":
			(n as Light3D).visible = false
		if _measure_off.has("haz") and n.name == &"Haz" and n is Node3D:
			(n as Node3D).visible = false
		if _measure_off.has("fondo") and n.name == &"Fondo" and n is CanvasItem:
			(n as CanvasItem).visible = false
		var script := n.get_script() as Script
		if script != null and _measure_off.has("proc:" + script.resource_path.get_file().get_basename()):
			n.set_process(false)                 # (--sin=proc:diorama: sin el _process de ese script)
			n.set_physics_process(false)
	if _measure_off.has("vistas"):              # (las vistas 3D de las fichas, quietas)
		for v in get_tree().root.find_children("*", "SubViewport", true, false):
			(v as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	if d == null:
		print("MEDIDA sin nivel")


func _process(delta: float) -> void:
	_elapsed += delta
	if _measure > 0.0 and _elapsed >= _capture_after:
		_measure_frame()
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
	if _mirror and _elapsed > 1.0 and GameState.diorama != null:
		_mirror = false
		_place_mirror()
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
	if _tiro.z > 0.0 and _capture_path != "" and _elapsed >= _capture_after - 0.8 and GameState.diorama != null:
		_apply_tiro()
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
