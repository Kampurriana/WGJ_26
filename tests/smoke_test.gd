extends Node
## Test de humo: arranca el juego entero como un jugador: resuelve el puzle del título, usa el
## menú, juega el nivel 0 de principio a fin (con pausa) y vuelve al menú ya montado.
## Ejecutar (o mejor: tools/check.sh, que además lee el log):
##   godot --headless --path . res://tests/smoke_test.tscn
## Imprime "OK ..." / "FALLO ..." y termina con "SMOKE OK" o "SMOKE FALLO n".
## Un test que no imprime "SMOKE OK" NO ha pasado, diga lo que diga el código de salida.

const SAMPLE_LEVEL := "res://levels/level_00_muestra.tscn"
const TEST_SETTINGS := "user://test_ajustes.cfg"     ## nunca los ficheros de verdad del jugador
const TEST_PROGRESS := "user://test_progreso.cfg"
const LAMP := &"lampara"                             ## la pieza del desván que lleva luz (la lámpara del escritorio)

var _fails := 0
var _completed := false
var _farol_energy := 0.0                             ## la luz de la lámpara del desván, tal como viene del modelo


func _ready() -> void:
	Events.level_completed.connect(func(_d: Node) -> void: _completed = true)
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		print("OK    ", what)
	else:
		_fails += 1
		print("FALLO ", what)


func _run() -> void:
	Settings.load_from("")                       # solo en memoria: nunca los ajustes del jugador
	Settings.set_system_language("es")           # y en español, aunque la máquina esté en inglés
	_test_name_rules()
	_test_narrator()
	await _test_voices()
	await _test_english()
	_test_kit()
	await _test_logo()
	if GameState.RESET_ON_START:
		check(GameState.progress_path == "" and not GameState.menu_unlocked and not GameState.has_progress(),
			"modo prototipo: al darle a Play no se carga progreso (título y niveles desde cero)")
	for f in [TEST_SETTINGS, TEST_PROGRESS]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	_test_settings()
	Settings.load_from(TEST_SETTINGS)
	GameState.load_progress(TEST_PROGRESS)
	# Siempre el nivel de muestra, esté o no en data/levels.json: es el que usa toda la convención.
	GameState.levels = PackedStringArray([SAMPLE_LEVEL])
	GameState.level_index = 0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	for i in 3:
		await get_tree().process_frame
	if not await _test_title_menu(main):
		return _end()
	var d := GameState.diorama
	check(d != null and d.scene_file_path == SAMPLE_LEVEL, "Jugar carga el nivel 0 y registra su Diorama")
	if d == null:
		return _end()
	await get_tree().process_frame               # la luz anterior se libera al final del fotograma
	_check_lighting(main, main.DEFAULT_LIGHTING, "un nivel sin luz propia")
	var rig := main.get_node_or_null("Iluminacion") as RigLuz
	var sun := rig.get_node_or_null(rig.luz_principal) as Light3D if rig != null else null
	check(sun != null and is_equal_approx(sun.light_energy, rig.energia_inicio),
		"al empezar, la luz principal está en su energía de inicio (diorama sin montar)")
	var fx: Efectos = main.effects
	check(fx.dust != null and fx.dust.emitting and fx.dust.amount >= 30, "hay polvo flotando en la luz alrededor del diorama")
	await _test_pause(main, d)
	await _test_camera(d)
	for i in 2:
		await get_tree().process_frame
	var cam_yaw := GameState.camera.cam.global_rotation.y
	check(rig != null and absf(cam_yaw) > 0.1 and absf(wrapf(rig.rotation.y - cam_yaw * rig.seguir_camara, -PI, PI)) < 0.02,
		"la luz gira con la cámara (luz %.2f, cámara %.2f rad)" % [rig.rotation.y if rig else 0.0, cam_yaw])
	var reach := GameState.camera.cam.global_position.distance_to(rig._center) + rig._radius * rig.margen_sombra if rig else -1.0
	var shadow_dist := (sun as DirectionalLight3D).directional_shadow_max_distance if sun is DirectionalLight3D else -1.0
	check(rig != null and absf(shadow_dist - clampf(reach, 4.0, 40.0)) < 0.3 and shadow_dist < 25.0,
		"las sombras cubren solo lo que se ve, para que no salgan pixeladas (%.1f m)" % shadow_dist)
	await _test_hint(d)
	var cam := GameState.camera.cam
	GameState.camera.snap()
	check(d.slots.size() >= 5, "hay huecos P_ (%d)" % d.slots.size())
	check(not d.inventory.is_empty(), "el inventario empieza con piezas (%d)" % d.inventory.size())
	check(not d.inventory.has(&"cuchara"), "lo escondido (H_) no empieza en el inventario")
	check(not d.inventory.has(&"cuadro"), "la recompensa de un Z_ no empieza en el inventario")
	check(d.slots[0].is_ghost(), "los huecos empiezan como silueta blanca")
	check(GameState.hud.cards(true).size() > 0, "el panel muestra piezas")

	# Encaje por posición en pantalla: lejos falla, encima acierta.
	var id := d.inventory[0]
	check(not d.try_place(id, Vector2(-999, -999), cam), "soltar lejos NO encaja")

	# Orden: la taza no encaja sin la mesa.
	var taza := _slot(d, &"taza")
	if taza != null and d.inventory.has(&"taza"):
		var pos := cam.unproject_position(taza.center())
		check(not d.try_place(&"taza", pos, cam), "la taza NO encaja antes que la mesa (after-mesa)")

	var mesa := _slot(d, &"mesa")
	var bursts_before := fx.bursts
	var cam_before := cam.global_position
	check(mesa != null and d.try_place(&"mesa", cam.unproject_position(mesa.center()), cam), "la mesa encaja soltándola encima de su hueco")
	var painted_at_once := mesa != null and d.is_painted_at(mesa.center())
	await get_tree().process_frame
	var first_step := cam.global_position.distance_to(cam_before)
	check(mesa != null and mesa.filled and not mesa.is_ghost(), "la mesa colocada deja de ser silueta")
	check(mesa != null and not mesa.node.find_children("Superficie", "StaticBody3D", true, false).is_empty(),
		"la mesa colocada pasa a ser superficie (lo de encima se apoya en ella, no la atraviesa)")
	check(fx.bursts > bursts_before and fx.get_children().any(func(c: Node) -> bool: return c.name.begins_with("Serrin")),
		"al encajar una pieza salen serrín y chispas")
	if mesa != null:
		var far := mesa.center() + Vector3(d.color_radius * 1.6, 0.0, 0.0)
		check(not painted_at_once, "(control) justo al encajar la pintura aún no ha llegado: crece poco a poco")
		await get_tree().create_timer(Diorama.PAINT_TIME + 0.15).timeout
		check(d.is_painted_at(mesa.center()) and not d.is_painted_at(far) and d.has_unpainted_layer(),
			"al encajar, la pintura se extiende desde la pieza hasta su radio, y no más allá")
		var later := cam.global_position.distance_to(cam_before)
		check(first_step < 0.01 and later > 0.03,
			"al colocar, la cámara se acerca a la pieza suave: sin tirón al empezar (%.3f m) y se nota después (%.3f m)" % [first_step, later])

	# Arrastrar de verdad: pulsar en la ficha del panel, mover y soltar encima del hueco,
	# con eventos de ratón que recorren el mismo camino que los del jugador.
	var silla := _slot(d, &"silla")
	var item := GameState.hud.item_for(&"silla")
	check(item != null, "la silla tiene ficha en el panel")
	if silla != null and item != null:
		for i in 2:                                # el panel se maqueta un fotograma después
			await get_tree().process_frame
		item = GameState.hud.item_for(&"silla")
		var start := item.get_global_rect().get_center()
		var goal := cam.unproject_position(silla.center())
		_mouse_button(start, true)
		await get_tree().process_frame
		check(GameState.is_dragging and GameState.drag.piece_id == &"silla", "pulsar la ficha de la silla empieza a arrastrar la silla")
		_check_sweep("muestra")
		_mouse_move(goal)
		await get_tree().process_frame
		_mouse_button(goal, false)
		await get_tree().process_frame
		check(silla.filled, "soltar la silla sobre su hueco la coloca")
		check(not GameState.is_dragging, "al soltar se acaba el arrastre")

	# Cajón: se abre al pulsarlo y deja coger lo de dentro.
	var cajon := _interactable(d, NameRules.DRAWER)
	if cajon != null:
		var before := cajon.target.transform
		cajon.activate()
		await get_tree().create_timer(Interactable.OPEN_TIME + 0.2).timeout
		check(not cajon.target.transform.is_equal_approx(before), "el cajón se mueve al abrirlo")
		var cuchara := _interactable(d, NameRules.PICKUP)
		GameState.camera.snap()
		var hit := d.pick_interactable(cam.unproject_position(Visuals.global_aabb(cuchara.target).get_center()), cam)
		check(hit == cuchara, "con el cajón abierto, el clic sobre la cuchara la coge a ella (no al cajón)")

	# El resto, con el jugador automático.
	var steps := 0
	while not d.completed and steps < 200:
		d.debug_solve_step()
		steps += 1
		await get_tree().process_frame
	check(d.completed and _completed, "el nivel se completa (%d pasos) y emite level_completed" % steps)
	check(d.inventory.is_empty(), "inventario vacío al final")
	var all_filled := true
	for s in d.slots:
		all_filled = all_filled and s.filled
	check(all_filled, "todos los huecos llenos")
	check(GameState.camera.showcasing, "al completar, la cámara se mece enseñando el diorama")
	check(fx.get_children().any(func(c: Node) -> bool: return c.name == "Luces") and not fx.get_children().any(func(c: Node) -> bool: return c.name == "Hojas"),
		"al completar suben luces cálidas (sin hojas)")
	await get_tree().create_timer(Diorama.FINAL_PAINT_TIME + 0.3).timeout
	check(not d.has_unpainted_layer(), "al completar no queda madera sin pintar (y la capa se quita)")
	check(sun != null and is_equal_approx(sun.light_energy, rig.energia_final) and sun.light_color.is_equal_approx(rig.color_final),
		"la luz despierta con el diorama: completo, la luz principal es la final (%.2f)" % (sun.light_energy if sun else -1.0))
	check(not GameState.hud._panel.visible, "al completar, la bandeja vacía se recoge")
	await _test_back_to_menu(main)
	await _test_story(main)
	await _test_complete_shortcut(main)
	await _test_real_levels(main)
	await _test_light_scale()
	_test_artist(main)
	_test_dialogue_log(main)
	_end()


## Los diálogos ya dichos se pueden releer en la pausa (Diálogos), en orden y sin los avisos de juego;
## se guardan con el progreso.
func _test_dialogue_log(main: Node) -> void:
	main.open_pause()
	main.pause.show_page("dialogos")
	var lines: PackedStringArray = main.pause.dialogue_entries()
	var hucha := Array(lines).find(Narrator.text("pieza_hucha"))
	var espejo := Array(lines).find(Narrator.text("pieza_espejo"))
	var saved: Array = _saved(TEST_PROGRESS, "dialogos", [])
	check(main.pause.buttons.dialogos.visible and lines.size() >= 8 and hucha >= 0 and espejo > hucha
		and not lines.has(Narrator.text("pista")) and saved.has("pieza_hucha"),
		"en la pausa, «Diálogos» deja releer lo ya dicho, en orden (%d), sin los avisos de juego, y se guarda con el progreso" % lines.size())
	main.pause.close()


## «Alma de artista» (secreto): un minuto jugando con un fondo y otro con un fondo distinto.
func _test_artist(main: Node) -> void:
	var logros: Logros = main.logros
	var was_mode := GameState.mode
	var was_color: int = Settings.get_value("fondo_color")
	GameState.mode = GameState.Mode.PLAYING
	logros.backgrounds.clear()
	logros._process(Logros.ARTIST_SECONDS + 1.0)
	var after_one := Logros.is_unlocked("alma_artista")
	Settings.set_value("fondo_color", (was_color + 1) % Fondos.COLORES.size())
	logros._process(Logros.ARTIST_SECONDS * 0.5)
	var after_half := Logros.is_unlocked("alma_artista")
	logros._process(Logros.ARTIST_SECONDS * 0.5 + 1.0)
	check(not after_one and not after_half and Logros.is_unlocked("alma_artista") and Logros.is_secret("alma_artista"),
		"«Alma de artista» (secreto) llega al jugar más de un minuto con dos fondos distintos, no antes")
	Settings.set_value("fondo_color", was_color)
	GameState.mode = was_mode


## El narrador no pisa frases: una segunda frase espera a que acabe la primera.
func _test_narrator() -> void:
	Narrator.clear()
	var got: Array[String] = []
	var listen := func(text: String, _seconds: float) -> void: got.append(text)
	Narrator.subtitle.connect(listen)
	Narrator.say("pista")
	Narrator.say("orden")
	check(got.size() == 1 and got[0] == Narrator.text("pista") and Narrator.remaining() > 2.5,
		"el narrador no pisa frases: la segunda espera a que acabe la primera (%d de 2 dichas)" % got.size())
	Narrator.subtitle.disconnect(listen)
	Narrator.clear()


## Guion v2: cada objeto suena con su grabación (assets/audio/voz/<clave>.ogg) y su subtítulo, partido
## en las pausas de la grabación; la música baja mientras habla; pasar de frase se lleva el trozo entero.
func _test_voices() -> void:
	Narrator.clear()
	var got: Array = []
	var listen := func(text: String, seconds: float) -> void: got.append([text, seconds])
	Narrator.subtitle.connect(listen)
	var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/narracion_es.json"))
	var voiced := 0
	var marks_ok := true
	for key: String in ["pieza_caja_musica", "pieza_dibujo", "pieza_peluche", "pieza_solicitud", "pieza_camara",
			"pieza_llaves", "pieza_caballete", "pieza_espejo"]:
		var path := "res://assets/audio/voz/%s.ogg" % key
		if not ResourceLoader.exists(path) or not lines.has(key):
			continue
		voiced += 1
		var v: Variant = lines[key]
		if v is Dictionary:
			var marks: Array = (v as Dictionary).get("marcas", [])
			var length := (load(path) as AudioStream).get_length()
			var prev := 0.0
			marks_ok = marks_ok and marks.size() == ((v as Dictionary).frases as Array).size() - 1
			for m: Variant in marks:
				marks_ok = marks_ok and float(m) > prev and float(m) < length
				prev = float(m)
	check(voiced == 8 and marks_ok, "las 8 voces del guion v2 están, y sus frases partidas cambian dentro de la grabación (%d)" % voiced)
	Narrator.say("pieza_peluche")
	var voice_len := (load("res://assets/audio/voz/pieza_peluche.ogg") as AudioStream).get_length()
	var left := Narrator.remaining()
	check(got.size() == 1 and got[0][0] == "¡Gatito! Ahora sé que eres una nutria…" and is_equal_approx(float(got[0][1]), 3.85)
		and Narrator.voice_playing() and absf(left - (voice_len + Narrator.VOICE_TAIL + Narrator.GAP)) < 0.05,
		"una frase grabada suena entera con su voz y su subtítulo sale por trozos: el primero, hasta su pausa (%.2f s)" % left)
	check(is_equal_approx(Narrator.typing, 3.85 - Narrator.TYPE_LEAD),
		"el texto se escribe al ritmo de la voz: el primer trozo tarda lo que tarda en decirlo (%.2f s)" % Narrator.typing)
	for i in 2:                                      # (process_frame llega antes del _process del Narrador)
		await get_tree().process_frame
	check(Sfx.ducked, "mientras habla una voz, la música baja (ducking)")
	Narrator.skip()
	for i in 3:
		await get_tree().process_frame
	check(got.size() == 1 and Narrator.remaining() <= 0.0 and not Narrator.voice_playing(),
		"pasar de frase se lleva el trozo grabado entero: no sale el resto del subtítulo sin su voz")
	check(not Sfx.ducked, "al callarse, la música vuelve")
	var nuevas := 0                                  # las del 18-oct: entrar al desván, hucha, cerdito, dibujos, final
	var new_marks_ok := true
	for key: String in ["intro_desvan", "pieza_hucha", "fin_menu", "dibujo_encontrado_1", "dibujo_encontrado_2",
			"dibujo_encontrado_3", "dibujo_encontrado_4", "seccion_epilogo", "pieza_moneda"]:
		var path := "res://assets/audio/voz/%s.ogg" % key
		if not ResourceLoader.exists(path) or not lines.has(key) or Narrator.text(key) == "":
			continue
		nuevas += 1
		if lines[key] is Dictionary:                 # sus frases cambian en las pausas, dentro de la grabación
			var marks: Array = (lines[key] as Dictionary).get("marcas", [])
			var length := (load(path) as AudioStream).get_length()
			var prev := 0.0
			new_marks_ok = new_marks_ok and marks.size() == ((lines[key] as Dictionary).frases as Array).size() - 1
			for m: Variant in marks:
				new_marks_ok = new_marks_ok and float(m) > prev and float(m) < length
				prev = float(m)
	check(nuevas == 9 and new_marks_ok and not lines.has("intro_cerdito") and not lines.has("intro_menu"),
		"las voces del 18-oct (desván, hucha, «¡Ha quedado como nueva!», una por dibujo, el final y la moneda) con su texto y sus pausas; el cerdito empieza sin frase (%d de 9)" % nuevas)
	got.clear()
	Narrator._lines["_prueba_solo_voz"] = {"frases": [], "voz": "dibujo_encontrado_2"}
	Narrator.say("_prueba_solo_voz")
	Narrator._lines.erase("_prueba_solo_voz")
	var only_len := (load("res://assets/audio/voz/dibujo_encontrado_2.ogg") as AudioStream).get_length()
	check(got.is_empty() and Narrator.voice_playing()
		and absf(Narrator.remaining() - (only_len + Narrator.VOICE_TAIL + Narrator.GAP)) < 0.05,
		"una grabación sin texto todavía suena entera, sin subtítulo")
	Narrator.subtitle.disconnect(listen)
	Narrator.clear()


## El juego en inglés: sin voz, con subtítulos siempre (aunque estén apagados en Opciones), la
## interfaz traducida (data/ui_en.json), sus frases, nombres y créditos; y al volver al español,
## nada en inglés (el idioma de reserva es el español, no el inglés de Godot).
func _test_english() -> void:
	Narrator.clear()
	var es: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/narracion_es.json"))
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/narracion_en.json"))
	var names_es: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/piezas_es.json"))
	var names_en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/piezas_en.json"))
	var ui: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_en.json"))
	var same_keys := es.keys().all(func(k: String) -> bool: return en.has(k) and Narrator._segments(en[k]).size() == Narrator._segments(es[k]).size()) \
		and en.size() == es.size() and names_es.keys().all(func(k: String) -> bool: return names_en.has(k)) and names_en.size() == names_es.size()
	check(same_keys, "las frases y los nombres en inglés son los mismos que en español (%d frases, %d nombres)" % [en.size(), names_en.size()])
	var formats_ok := true
	for k: String in ui:
		if not k.begins_with("_"):
			formats_ok = formats_ok and String(ui[k]) != "" and k.count("%s") == String(ui[k]).count("%s") and k.count("%d") == String(ui[k]).count("%d")
	check(formats_ok and ui.size() > 90, "cada texto de la interfaz tiene su traducción, con sus huecos %%s/%%d (%d)" % (ui.size() - 1))
	Settings.set_value("subtitulos", false)
	Settings.set_value("idioma", "en")
	check(Narrator.language == "en" and not Narrator.voiced() and TranslationServer.translate("Jugar") == "Play"
		and TranslationServer.translate("CAPÍTULO %s") % "II" == "CHAPTER II" and Narrator.piece_name(&"hucha") == "the piggy bank",
		"en inglés: el narrador y la interfaz cambian de idioma (Jugar → %s)" % TranslationServer.translate("Jugar"))
	var hud := Hud.new()
	add_child(hud)
	await get_tree().process_frame
	Narrator.say("pieza_peluche")
	check(hud._subtitle_box.visible and hud._subtitle.text == "Kitty! Now I know you're an otter…" and not Narrator.voice_playing()
		and Narrator.remaining() > 5.0,
		"en inglés no suena ninguna voz y el subtítulo sale aunque estén apagados (%.1f s de lectura)" % Narrator.remaining())
	var options := OptionsPanel.new(false)
	add_child(options)
	var subs := options.controls["subtitulos"] as CheckButton
	check(subs.disabled and subs.button_pressed and options.languages[1].button_pressed and not (options.controls["volumen_voz"] as Range).editable,
		"en inglés, Opciones marca English y los subtítulos van fijos (sin voz que ajustar)")
	check(Settings.localized(Creditos.CREDITS_PATH).ends_with("creditos_en.txt") and FileAccess.get_file_as_string(Settings.localized(Creditos.CREDITS_PATH)).contains("Thanks for playing"),
		"los créditos en inglés")
	Narrator.clear()
	Settings.set_value("idioma", "es")
	check(Narrator.language == "es" and Narrator.voiced() and TranslationServer.translate("Jugar") == "Jugar"
		and TranslationServer.translate("Volver") == "Volver" and not subs.disabled and not subs.button_pressed,
		"al volver al español, todo en español (nada se cuela del inglés) y los subtítulos vuelven a su ajuste")
	Narrator.say("pieza_peluche")
	check(Narrator.voice_playing() and not hud._subtitle_box.visible, "en español, con su voz y, con los subtítulos apagados, sin subtítulo")
	Narrator.clear()
	options.queue_free()
	hud.queue_free()
	Settings.load_from("")
	await get_tree().process_frame


## La presentación al abrir el juego (ui/presentacion.gd): sigue a la pantalla de carga sin que se
## note (su fondo, el cerdito de icon.png a su tamaño en el centro), el cerdito se mueve, el título se
## carga debajo cuando empieza a irse y se ve por un círculo que se abre; luego se va del todo.
func _test_splash(main: Node) -> void:
	var sp: Presentacion = main.splash
	check(sp != null and GameState.diorama == null, "al abrir el juego sale la presentación, y todavía no hay diorama detrás")
	if sp == null:
		return
	var view := get_viewport().get_visible_rect().size
	var sprite := sp.pig().get_child(0) as Sprite2D
	var shown := sprite.texture.get_size() * sprite.scale
	check(sp.background() == ProjectSettings.get_setting("application/boot_splash/bg_color") and sprite.texture == load("res://icon.png")
		and is_equal_approx(shown.x, 256.0) and sp.pig().position.distance_to(view * 0.5 + Vector2(0, 128)) < 1.0,
		"la presentación sigue a la pantalla de carga: su fondo y el mismo cerdito, a su tamaño y en el centro")
	var poses: Array[Vector3] = []
	for i in 8:
		await get_tree().create_timer(0.2).timeout
		if is_instance_valid(sp) and not sp.is_opening():
			poses.append(Vector3(sp.pig().position.y, sp.pig().scale.y, sp.pig().rotation))
	var moved := poses.size() > 3 and poses.any(func(p: Vector3) -> bool: return not p.is_equal_approx(poses[0]))
	var hopped := poses.any(func(p: Vector3) -> bool: return p.x < view.y * 0.5 + 128.0 - 10.0)
	check(moved and hopped, "el cerdito de la presentación no es una imagen quieta: respira y da saltitos (%d poses)" % poses.size())
	var waited := 0.0
	while is_instance_valid(sp) and not sp.is_opening() and waited < 6.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await get_tree().process_frame
	check(is_instance_valid(sp) and GameState.diorama != null and GameState.diorama.scene_file_path == GameState.MENU_LEVEL
		and sp.iris_radius() < 0.2 and main._fade.color.a < 0.05,
		"al irse, el puzle del cerdito ya está cargado debajo y se descubre por el círculo (sin fundido desde negro)")
	var radii: Array[float] = []
	while is_instance_valid(sp) and waited < 9.0:
		radii.append(sp.iris_radius())
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	check(not is_instance_valid(sp) and main.splash == null and radii.size() > 4 and radii[-1] > radii[0] + 0.5,
		"el círculo se abre hasta dejar ver todo el juego y la presentación se va (%d pasos)" % radii.size())
	await get_tree().process_frame


## El logo (ui/logo.gd), montado con las piezas de las artistas: cada una en su caja de la referencia
## de maquetación, moviéndose cada una a su aire y sin taparse nunca entre ellas. Aquí, con piezas de
## las piezas de verdad (assets/ui/logo/) o, si faltan, unas de prueba de las mismas proporciones.
func _test_logo() -> void:
	var tex := Logo.load_pieces()
	if tex.is_empty():
		for key: String in Logo.REF_RECTS:
			var box: Rect2 = Logo.REF_RECTS[key]
			var img := Image.create(int(box.size.x / 4.0), int(box.size.y / 4.0), false, Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
			tex[key] = ImageTexture.create_from_image(img)
	var logo := Logo.new(800.0, tex)
	add_child(logo)
	logo.position = Vector2(20, 20)
	for i in 2:
		await get_tree().process_frame
	var coin := logo.drawing_box("moneda")
	var what := logo.drawing_box("what")
	var said := logo.drawing_box("said")
	var pig := logo.drawing_box("cerdito")
	check(logo.has_pieces() and coin.end.x < what.position.x and absf(coin.get_center().y - what.get_center().y) < coin.size.y
		and said.position.y > what.end.y and pig.position.x > said.end.x and pig.position.y > what.end.y,
		"el logo, como la referencia: la moneda a la izquierda de «what I never», «SAID» debajo y el cerdito a su derecha")
	var joined := [["moneda", "what"], ["what", "said"], ["said", "cerdito"], ["what", "cerdito"]].all(func(p: Array) -> bool:
		return logo.piece_box(p[0]).intersects(logo.piece_box(p[1])))
	check(joined and logo.backing.size() == 8,
		"el logo es una sola pegatina: los bordes blancos de las piezas se funden y detrás hay una silueta blanca común y una sombra")
	var keys := ["moneda", "what", "said", "cerdito"]
	var first := {}
	var moved := {}
	var touching := PackedStringArray()
	var said_img: Node2D = logo.motions["said"]
	var float_y := logo._stage.position.y
	var float_step := 0.0
	var said_rot := said_img.rotation_degrees
	var said_jump := 0.0
	var said_scaled := 0
	var squashed := false
	for step in 45:
		for a in keys.size():
			var ka: String = keys[a]
			var xf: Transform2D = (logo.pieces[ka] as Control).get_global_transform()
			if step == 0:
				first[ka] = xf
			elif not xf.is_equal_approx(first[ka]):
				moved[ka] = true
			for b in range(a + 1, keys.size()):
				if logo.drawing_box(ka).intersects(logo.drawing_box(keys[b])) and not touching.has(ka + "-" + keys[b]):
					touching.append(ka + "-" + keys[b])
		said_jump = maxf(said_jump, absf(said_img.rotation_degrees - said_rot))
		said_rot = said_img.rotation_degrees
		if absf(said_img.scale.y - 1.0) > 0.001:
			said_scaled += 1
		squashed = squashed or absf(logo.squash) > 0.004
		float_step = maxf(float_step, absf(logo._stage.position.y - float_y))
		float_y = logo._stage.position.y
		await get_tree().create_timer(0.1).timeout
	check(moved.size() == 4 and touching.is_empty(),
		"cada pieza del logo se mueve a su aire (%d de 4) y ningún dibujo tapa a otro (se tocan: %s)" % [moved.size(), ", ".join(touching)])
	check(said_jump < 0.1 and squashed and said_scaled <= 8,
		"«SAID» no tiembla: se mece lentísimo (%.3f° por décima) y solo se aplasta un pelín cuando cae el cerdito (%d de 45 muestras)"
		% [said_jump, said_scaled])
	check(logo._stage is Node2D and logo.motions.values().all(func(m: Node) -> bool: return m is Node2D)
		and get_viewport().gui_snap_controls_to_pixels and float_step > 0.0 and float_step < 0.4,
		"el logo flota fluido: lo que se mueve va en Node2D (los Control se ajustan al píxel y daban saltos de 1 px; aquí %.2f px por décima)"
		% float_step)
	logo.queue_free()
	var plain := Logo.new(430.0)
	check(plain.has_pieces() and plain.pieces.size() == 4,
		"el logo de las artistas está en el juego: sus cuatro piezas (moneda, «what I never», «SAID», cerdito)")
	plain.free()


## La historia del desván (docs/GUION.md): se monta por secciones en orden; en cada una los objetos
## de la historia aparecen de uno en uno y la clave al final; lo que está guardado en un mueble se
## descubre porque el mueble brilla, y en la adolescencia primero la solicitud y al final la cámara (guion v2).
func _test_story(main: Node) -> void:
	var attic := "res://levels/level_01_desvan.tscn"
	GameState.levels = PackedStringArray([attic])
	main.play_level(0)
	await get_tree().process_frame
	GameState.camera.snap()
	var d := GameState.diorama
	check(d != null and d.scene_file_path == attic and d.sections.size() == 5 and d.sections[0].opened and not d.sections[1].opened,
		"el desván empieza con su primera sección abierta y las otras cuatro cerradas")
	if d == null or d.sections.size() != 5:
		return
	var s1 := d.sections[0]
	var s2 := d.sections[1]
	var s3 := d.sections[2]
	var s4 := d.sections[3]
	var s5 := d.sections[4]
	var shown := d.visible_inventory()
	check(not shown.is_empty() and shown.all(func(id: StringName) -> bool: return _slot(d, id).section == s1)
		and not shown.has(&"tejado") and not shown.has(&"hucha"),
		"al empezar, la bandeja trae el suelo y las paredes: ni el tejado (va después) ni la hucha (la clave) ni nada de otra zona")
	var otter_slot := _slot(d, &"peluche")
	check(not otter_slot.shown and not otter_slot.ghost_visible() and not s2.decor[0].visible and not (s2.lights()[0] as Light3D).visible
		and d.find_children("*", "Label3D", true, false).is_empty(),
		"los actos cerrados no se ven: ni sus siluetas, ni sus muebles, ni su luz, ni su nombre en la escena")
	var wall := _slot(d, &"pared_fondo")
	var roof := _slot(d, &"tejado")
	check(wall.ghost_visible() and not wall.looks_locked() and roof.ghost_visible() and roof.looks_locked()
		and not wall._ghost.shader.code.contains("ALPHA"),
		"en el acto abierto se ven todas sus siluetas (opacas, como en Woodo): blancas las que ya van, grises las que esperan")
	var fx_focus: Dictionary = GameState.enfoque.state()
	check(GameState.enfoque._rect.visible and absf(float(fx_focus.fuera) - Enfoque.PLAY_BLUR) < 0.3,
		"todo se ve un poco desdibujado, más lejos del foco (enfoque de cine: %.1f px)" % float(fx_focus.fuera))
	var hud_now: Hud = GameState.hud
	check(hud_now.task_text().begins_with("EL DESVÁN | ") and hud_now.task_text().ends_with("| 0 / %d" % s1.slots.size())
		and hud_now._task.get_global_rect().position.x < 60.0 and hud_now._task.get_global_rect().position.y < 60.0,
		"arriba a la izquierda, la tarjeta de tarea: la zona, qué toca y cuánto falta (%s)" % hud_now.task_text())
	check(hud_now._panel.get_global_rect().position.y < 30.0 and hud_now._task.size.x < 260.0,
		"sin contador de dibujos: la bandeja empieza arriba; y la tarjeta de tarea es pequeña, que no llame la atención")
	var screen_w := get_viewport().get_visible_rect().size.x
	Narrator.clear()                               # que la frase de entrar al desván no salga encima de la de prueba
	Narrator.typing = -1.0                         # sin voz (la de entrar al desván ya había marcado su ritmo)
	hud_now._show_subtitle("Una frase de prueba, bastante larga, para ver cómo se escribe letra a letra.", 4.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var typing := hud_now._subtitle.visible_ratio
	check(typing < 0.5 and absf(hud_now._subtitle_box.get_global_rect().get_center().x - screen_w * 0.5) < 4.0 and hud_now._tail.visible,
		"el diálogo es una burbuja centrada en la pantalla, con su piquito, que se escribe letra a letra (%.2f)" % typing)
	await get_tree().create_timer(2.5).timeout
	check(is_equal_approx(hud_now._subtitle.visible_ratio, 1.0), "y acaba de escribirse")
	Narrator.typing = 3.0                          # con voz: al ritmo de la grabación, no al suyo
	hud_now._show_subtitle("Una frase de prueba, bastante larga, para ver cómo se escribe letra a letra.", 4.0)
	await get_tree().create_timer(0.5).timeout
	var early_h := hud_now._subtitle_box.size.y
	await get_tree().create_timer(1.5).timeout
	var voiced := hud_now._subtitle.visible_ratio
	Narrator.typing = -1.0
	check(voiced > 0.45 and voiced < 0.85, "con voz, la burbuja se escribe mientras lo dice (a los 2 s de 3, %.2f)" % voiced)
	await get_tree().create_timer(1.2).timeout
	check(is_equal_approx(hud_now._subtitle_box.size.y, early_h), "la burbuja tiene ya su tamaño final mientras se escribe (no crece)")
	hud_now._subtitle_box.hide()
	var stars: EstrellasLogros = hud_now.stars
	check(stars.bar.visible and stars.filled_count() == 0 and stars.slots.size() == Logros.LISTA.size(),
		"arriba, junto a la tarjeta, la fila de estrellas de los logros (vacía al empezar)")
	var heard_star: Dictionary = Sfx.played.duplicate()
	stars.celebrate("speedrunner")
	check(_heard(heard_star, "logro") == 1 and Sfx.jingle_playing() == "logro", "un logro suena con su sintonía (logro, de Drive FXS)")
	await get_tree().create_timer(0.8).timeout
	var pig_a := stars.pig.position
	await get_tree().create_timer(0.3).timeout
	var banner_rect := stars.banner.get_global_rect()
	check(stars.pig.visible and stars.pig.position != pig_a,
		"al aviso del logro le acompaña el cerdito, que llega a saltitos junto a él")
	await get_tree().create_timer(1.5).timeout
	var pig_at := stars.pig.get_global_transform() * Vector2.ZERO
	check(stars.pig.visible and stars.pig.scale.is_equal_approx(Vector2.ONE) and banner_rect.grow(140.0).has_point(pig_at),
		"el cerdito se queda en la esquina del aviso, derecho, después de celebrarlo (%s, %s, %s)" % [stars.pig.scale, pig_at, banner_rect])
	check(stars.banner_text() == "Speedrunner" and absf(banner_rect.get_center().x - screen_w * 0.5) < 4.0 and banner_rect.position.y < 140.0,
		"un logro sale en un aviso dorado arriba en el centro (%s)" % stars.banner_text())
	await get_tree().create_timer(EstrellasLogros.HOLD + EstrellasLogros.FLIGHT * 0.5 - 1.8).timeout
	check(is_instance_valid(stars.flying), "y su estrella sale volando del aviso...")
	await get_tree().create_timer(EstrellasLogros.FLIGHT * 0.5 + 0.8).timeout
	var speed_index := Logros.LISTA.map(func(l: Dictionary) -> String: return l.id).find("speedrunner")
	check(stars.filled_count() == 1 and stars.slots[speed_index].filled and not stars.is_busy() and stars.banner_text() == "",
		"...hasta su hueco en la fila, que se queda con su estrella")
	check(not stars.pig.visible, "y el cerdito se ha ido antes que el aviso")
	stars.refresh()
	await _test_tray(d, shown)
	# El suelo, a tablones de tres largos parecidos: cada uno vale en varios huecos, pero no en todos.
	var planks := {}
	for sl in s1.slots:
		if String(sl.id).begins_with("tablon_"):
			planks[sl.id] = planks.get(sl.id, 0) + 1
	check(planks.size() == 3 and planks.values().all(func(n: int) -> bool: return n == 4),
		"el suelo son los 12 tablones del kit, de tres largos (%s)" % planks)
	var cam3 := GameState.camera.cam
	var mid_plank: PieceSlot = s1.slots.filter(func(sl: PieceSlot) -> bool: return sl.id == &"tablon_medio")[0]
	var long_plank: PieceSlot = s1.slots.filter(func(sl: PieceSlot) -> bool: return sl.id == &"tablon_largo")[0]
	var heard_planks: Dictionary = Sfx.played.duplicate()
	var took := d.try_place(&"tablon_largo", cam3.unproject_position(mid_plank.center()), cam3)
	check(not mid_plank.filled, "un tablón largo no entra en el hueco de uno mediano")
	if not took:                                   # (si al lado había uno largo, ya ha ido ahí)
		took = d.try_place(&"tablon_largo", cam3.unproject_position(long_plank.center()), cam3)
	check(took and long_plank.filled, "y cerca de uno largo, sí (cualquiera de los largos)")
	await get_tree().create_timer(0.06).timeout
	check(GameState.hud._task_count.scale.x > 1.05, "al poner una pieza, la cifra de la tarjeta de tarea da un salto")
	var longs := s1.slots.filter(func(sl: PieceSlot) -> bool: return sl.id == &"tablon_largo")
	check(longs.all(func(sl: PieceSlot) -> bool: return sl.filled) and d.count_of(&"tablon_largo") == 0
		and not d.tray_entries().any(func(e: Dictionary) -> bool: return e.id == &"tablon_largo"),
		"al soltar un tablón se ponen todos los iguales: los %d largos de una vez, y su ficha se va de la bandeja" % longs.size())
	check(longs.any(func(sl: PieceSlot) -> bool: return sl.is_ghost()) and longs.any(func(sl: PieceSlot) -> bool: return not sl.is_ghost()),
		"se ven encajar uno tras otro: primero el que soltó el jugador")
	await get_tree().create_timer(Diorama.TWIN_STEP * longs.size() + 0.15).timeout
	check(longs.all(func(sl: PieceSlot) -> bool: return not sl.is_ghost()), "y enseguida están todos puestos")
	check(_heard(heard_planks, "colocar_tablon") == 1 and not _more(heard_planks, "colocar"),
		"el tablón suena con su sonido (Colocar madera del suelo), una vez por los 6: ya trae varios golpes (%d)" % _heard(heard_planks, "colocar_tablon"))
	GameState.drag.begin(&"tablon_corto", GameState.hud.item_for(&"tablon_corto"))
	check(GameState.is_dragging and not d.slots.any(func(sl: PieceSlot) -> bool:
		return float(sl._ghost.get_shader_parameter("pulse")) > 0.0 if sl._ghost != null else false),
		"al coger un tablón no late ninguna silueta: encontrar dónde va es el reto")
	GameState.drag.cancel()
	var solid := 0
	for dec in s2.decor:
		for body in dec.find_children("Superficie", "StaticBody3D", true, false):
			solid += 1 if (body as StaticBody3D).collision_layer != 0 else 0
	check(solid == 0, "los muebles ocultos de una zona cerrada no chocan con la pieza en mano (%d chocan)" % solid)
	# Arte oficial: cada pieza del kit, la suya (las iguales comparten nombre y se ponen juntas).
	check(_slots_with(d, &"borde_suelo") == 12 and _slots_with(d, &"pilar") == 3 and _slots_with(d, &"bombilla") == 12
		and _slots_with(d, &"guirnalda") == 4 and _slots_with(d, &"cajon_comoda") == 3 and _slots_with(d, &"polaroid") == 4
		and _slots_with(d, &"lapiz") == 3 and _slots_with(d, &"pared_fondo") == 1,
		"cada pieza del kit va suelta: 12 bordes del suelo, 3 pilares, 12 bombillas en 4 cuerdas, 3 cajones de la cómoda, 4 polaroids, 3 lápices")
	# La hucha del kit viene en 12 trozos: se monta en su rincón (Z_ __monta), con primer plano.
	var bench: Interactable = null
	for it in d.interactables:
		if it.kind == NameRules.ZOOM and it.reward == &"hucha":
			bench = it
	var bench_parts := d.slots.filter(func(sl: PieceSlot) -> bool: return sl.scope == bench) if bench != null else []
	check(bench != null and bench.workbench and bench_parts.size() == 12 and bench.attention and bench.is_clickable()
		and not d.visible_inventory().has(&"cuerpo_hucha"),
		"la hucha se monta en su rincón: 12 trozos que no salen en la bandeja hasta entrar, y el rincón llama la atención (%s)"
		% [[bench.workbench, bench_parts.size(), bench.attention, bench.is_clickable(), d.visible_inventory().has(&"cuerpo_hucha"), d.lock_reason(&"hucha")] if bench != null else []])
	if bench != null:
		d.enter_focus(bench)
		await get_tree().process_frame
		check(d.visible_inventory().has(&"cuerpo_hucha") and not d.visible_inventory().has(&"tejado") and not bench.attention,
			"al entrar en el rincón, la bandeja enseña solo sus trozos (y deja de llamar) (%s)" % [[d.visible_inventory().slice(0, 6), bench.attention]])
		d.exit_focus()
	var placed: Array[StringName] = []
	var record := func(id: StringName, _n: Node3D) -> void: placed.append(id)
	Events.piece_placed.connect(record)
	var flashes := [0]
	var count_flash := func() -> void: flashes[0] += 1
	Events.flash_requested.connect(count_flash)
	var found_events: Array = []
	var record_found := func(item: Node, n: int, total: int) -> void: found_events.append([item, n, total])
	Events.collectible_found.connect(record_found)
	var hung := [0]
	var count_hung := func(_item: Node) -> void: hung[0] += 1
	Events.collectible_hung.connect(count_hung)
	Narrator.clear()
	var heard_s1: Dictionary = Sfx.played.duplicate()
	var start_xf := {}                             # (cómo vienen las piezas del modelo: ninguna se queda pequeña)
	for sl in d.slots:
		start_xf[sl] = sl.node.transform
	var steps := 0
	while not s1.completed and steps < 80:
		d.debug_solve_step()
		steps += 1
	check(_heard(heard_s1, "colocar_pared") == 5 and _heard(heard_s1, "colocar_tejado") >= 1 and _heard(heard_s1, "colocar_viga") >= 5
		and _heard(heard_s1, "colocar_tablon") == 3 and _more(heard_s1, "colocar") and d.place_sound(&"cumbrera") == "colocar_viga",
		"cada pieza del desván suena según su tipo: paredes (y rodapiés y molduras), techo, vigas (cumbrera, pilares, postes, correas) y el resto del suelo (con su borde); la hucha, con el de siempre (%s)"
		% [[_heard(heard_s1, "colocar_pared"), _heard(heard_s1, "colocar_tejado"), _heard(heard_s1, "colocar_viga"), _heard(heard_s1, "colocar_tablon")]])
	check(s1.completed and not placed.is_empty() and placed.back() == &"hucha",
		"la estructura se monta entera y la hucha (clave) va la última (%s)" % [placed.back() if not placed.is_empty() else &""])
	check(bench != null and bench.completed and placed.find(&"cuerpo_hucha") >= 0 and placed.find(&"cuerpo_hucha") < placed.find(&"hucha"),
		"primero se monta la hucha en su rincón y luego, entera, se pone encima de su caja")
	var cam_ctl := GameState.camera
	var m: Momentos = main.momentos
	check(m.active and m.target == _slot(d, &"hucha").node and cam_ctl.in_moment and GameState.hud.in_moment()
		and cam_ctl.distance <= d.camera_distance * DioramaCamera.CLOSE_UP_MAX + 0.01,
		"al poner la hucha (tiene frase), momento: la cámara se le acerca, la pantalla se enmarca y la bandeja se aparta")
	var pig_size := Visuals.global_aabb(_slot(d, &"hucha").node).size.length()
	var pig_share := pig_size / (cam_ctl.distance * tan(deg_to_rad(cam_ctl.cam.fov * 0.5)) * 2.0)
	check(pig_share < 0.36 and cam_ctl.distance >= DioramaCamera.CLOSE_UP_MIN - 0.01,
		"el primer plano no se pega al objeto: ocupa un %d %% del alto (antes, un 45 %%)" % roundi(pig_share * 100.0))

	# Algo que se cruce entre la cámara y la hucha se esconde mientras dura el plano.
	var pig_node := _slot(d, &"hucha").node
	var blocker := MeshInstance3D.new()
	var blocker_mesh := BoxMesh.new()
	blocker_mesh.size = Vector3(0.25, 0.25, 0.25)
	blocker.mesh = blocker_mesh
	d.add_child(blocker)
	blocker.global_position = cam_ctl.goal_position().lerp(Visuals.global_aabb(pig_node).get_center(), 0.5)
	Visuals.add_surface(blocker)
	await get_tree().physics_frame               # que la física ya lo tenga en cuenta
	m.start(pig_node, "normal", "hucha")
	check(m.hidden_for_shot.has(blocker) and not m.hidden_for_shot.any(func(g: Node) -> bool: return pig_node.is_ancestor_of(g)),
		"lo que se cruza delante del objeto del primer plano se esconde (y el objeto no)")
	await get_tree().create_timer(0.8).timeout
	var pig_px := GameState.camera.cam.unproject_position(Visuals.global_aabb(pig_node).get_center())
	fx_focus = GameState.enfoque.state()
	check(float(fx_focus.fuera) > Enfoque.PLAY_BLUR + 0.5 and (fx_focus.centro as Vector2).distance_to(pig_px) < 120.0,
		"en un momento, el enfoque se va al objeto y lo demás se desenfoca más")
	var iris_color: Color = m._iris_mat.get_shader_parameter("color")
	var bg_dark := Fondos.dark(Settings.get_value("fondo_color"))
	check(iris_color.is_equal_approx(bg_dark) and iris_color.v > 0.1 and absf(iris_color.h - Fondos.color(Settings.get_value("fondo_color")).borde.h) < 0.03
		and float(m._iris_mat.get_shader_parameter("dentro")) < 0.6 and float(m._iris_mat.get_shader_parameter("suave")) > 1.5,
		"el foco del momento no es negro: oscuro del tono del fondo, y muy degradado (sin borde)")
	var still := pig_node.global_transform
	await get_tree().create_timer(0.5).timeout
	check(pig_node.global_transform.is_equal_approx(still) and cam_ctl.breath_amount() < 0.01,
		"en el primer plano el objeto se queda quieto (sin gesto) y la cámara deja de respirar")
	GameState.hud.show_tip("(prueba)")
	check(GameState.hud.tip_text() == "", "un consejo no sale encima de un primer plano: espera a que acabe")
	GameState.hud._tip_waiting = []
	await get_tree().process_frame
	check(d.is_opening() and not GameState.hud.says_nothing_left(),
		"entre una sección y la siguiente, la bandeja espera: no dice que aquí no queda nada")
	var waited := 0.0
	var heard_chapter: Dictionary = Sfx.played.duplicate()
	var arriving: Array[Node3D] = []               # lo que aparece al abrirse la infancia: sus muebles y sus siluetas
	arriving.append_array(s2.decor)
	for sl in s2.slots:
		arriving.append(sl.node)
	var arriving_xf := {}
	var arriving_floor := {}
	for n in arriving:
		arriving_xf[n] = n.transform
		arriving_floor[n] = Visuals.global_aabb(n)
	while (Narrator.remaining() > 0.0 or m.active) and waited < 25.0:   # la voz de la hucha dura 14 s
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	await get_tree().create_timer(Diorama.SECTION_PAUSE + 0.2).timeout
	check(not s2.opened and not s2.opening and d.act_waiting() and GameState.hud.continue_button.visible
		and GameState.hud.task_text().contains("Continuar"),
		"al acabar un acto, el siguiente no se abre solo: espera a que la jugadora pulse «Continuar»")
	_click(GameState.hud.continue_button.get_global_rect().get_center())
	waited = 0.0
	while not s2.opening and waited < 3.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	var title_wait := 0.0
	var quiet_title := true                        # mientras se ve el rótulo, aún no hay nada del capítulo
	while s2.opening and not s2.opened and title_wait < 8.0:
		quiet_title = quiet_title and not s2.decor.any(func(n: Node3D) -> bool: return n.visible and not n is Light3D) \
			and not _more(heard_chapter, "aparecer_capitulo")
		await get_tree().create_timer(0.1).timeout
		title_wait += 0.1
	check(s2.opened and not d.act_waiting() and not GameState.hud.continue_button.visible and GameState.hud.chapter_text().contains("Infancia"),
		"al pulsar «Continuar» sale el rótulo del capítulo y se abre la infancia")
	check(bench != null and not bench.target.visible, "lo montado en el rincón se fue a la bandeja (no se queda repetido en el rincón)")
	check(quiet_title and title_wait >= Diorama.CHAPTER_REVEAL - 0.15,
		"al abrirse un capítulo, primero su rótulo: sus muebles y sus siluetas esperan a que se empiece a ir (%.1f s)" % title_wait)
	check(_more(heard_chapter, "aparecer_capitulo") and Sfx.length("aparecer_capitulo") > 0.0,
		"y al aparecer sus cosas suena el de Drive FXS «Cuando aparecen las cosas del capitulo»")
	var growing := arriving.filter(func(n: Node3D) -> bool: return Visuals.is_growing(n))
	var delays := growing.map(func(n: Node3D) -> float: return Visuals.grow_delay(n))
	check(growing.size() >= 5 and s2.decor.any(func(n: Node3D) -> bool: return Visuals.is_growing(n))
		and delays.max() - delays.min() > Visuals.GROW_SWEEP * 0.4,
		"las cosas del capítulo no salen de golpe: muebles y siluetas crecen una tras otra, de izquierda a derecha (%d, de %.2f a %.2f s)"
		% [growing.size(), delays.min() if not delays.is_empty() else 0.0, delays.max() if not delays.is_empty() else 0.0])
	var late: Array = growing.filter(func(n: Node3D) -> bool: return Visuals.grow_delay(n) > 0.4)   # (aparecieron hace menos de 0,1 s)
	var from_floor := not late.is_empty() and late.all(func(n: Node3D) -> bool:
		var now := Visuals.global_aabb(n)
		var full: AABB = arriving_floor[n]
		return absf(now.position.y - full.position.y) < 0.02 and now.size.length() < full.size.length() * 0.2)
	check(from_floor, "y crecen desde el suelo, no desde su centro (las que aún esperan su turno: %d, diminutas y en el suelo)" % late.size())
	check(GameState.hud.chapter_text() != "" and GameState.hud.tip_text() == "",
		"mientras se va el rótulo, el consejo del mueble que brilla aún espera (no sale encima)")
	check(not m.active and not cam_ctl.in_moment and not GameState.hud.in_moment(),
		"al callarse, el momento acaba: la cámara vuelve al jugador y la bandeja vuelve")
	await get_tree().create_timer(Momentos.HIDE_TIME + 0.1).timeout
	check(blocker.visible and is_zero_approx(blocker.transparency), "y lo que se había escondido vuelve")
	blocker.queue_free()
	await get_tree().create_timer(0.3).timeout
	check(GameState.hud.chapter_text() == Narrator.text("titulo_infancia") and s2.decor[0].visible and (s2.lights()[0] as Light3D).visible,
		"al abrirse la infancia: su rótulo, sus muebles y su luz")
	check(GameState.hud._chapter_kicker.text == "CAPÍTULO I" and GameState.hud._chapter_title.text == "Infancia"
		and otter_slot.shown and otter_slot.ghost_visible(),
		"el rótulo es de nuevo capítulo (CAPÍTULO I / Infancia) y las siluetas del acto aparecen")
	await get_tree().create_timer(Visuals.GROW_SWEEP + Visuals.GROW_TIME).timeout
	check(not arriving.any(func(n: Node3D) -> bool: return Visuals.is_growing(n))
		and arriving.all(func(n: Node3D) -> bool: return n.transform.is_equal_approx(arriving_xf[n])),
		"al acabar de aparecer, cada mueble y cada silueta queda exactamente como venía")
	var probe := MeshInstance3D.new()
	probe.mesh = BoxMesh.new()
	d.add_child(probe)
	probe.position = Vector3(0.0, 0.5, 0.0)
	var probe_xf := probe.transform
	Visuals.grow_in(probe, 0.3)
	var probe_small := probe.transform.basis.get_scale().x < 0.1
	Visuals.stop_growing(probe)
	check(probe_small and probe.transform.is_equal_approx(probe_xf) and not Visuals.is_growing(probe),
		"si se corta mientras crece (se coloca la pieza o se oculta), queda a su tamaño al momento")
	probe.queue_free()
	shown = d.visible_inventory()
	check(shown.has(&"comoda_infantil") and not shown.has(&"caja_musica") and not shown.has(&"dibujo") and not shown.has(&"peluche"),
		"infancia: la caja de música espera a su cómoda, el dibujo a la caja y la nutria (clave) a todo lo demás")
	var friends := _collectible(d, &"dibujo_amigas")
	check(friends != null and not friends.available and not friends.target.visible and d.clothesline != null and d.clothesline.is_visible_in_tree(),
		"al abrirse la infancia aparece la cuerda de los dibujos; el de debajo de la cama aún no está (after-cama_infantil)")
	var blocks := _pickup(d, &"cubos")
	var chest: Interactable = blocks.container if blocks != null else null
	check(chest != null and chest.kind == NameRules.DOOR and not chest.target.is_ancestor_of(blocks.target),
		"los cubos están guardados en el baúl, sin ser hijos de la tapa (si no, girarían con ella)")
	# Su caja y su tapa son piezas del kit: hasta ponerlas, el baúl ni se abre ni brilla.
	check(chest != null and not chest.inside.is_empty() and not chest.pieces_ready() and not chest.is_clickable() and not chest.attention,
		"la caja de juguetes es una pieza y su tapa otra: sin ponerlas no se abre ni llama")
	for kind in [&"caja", &"tapa_caja"]:
		var first: PieceSlot = s2.slots.filter(func(sl: PieceSlot) -> bool: return sl.id == kind and not sl.filled)[0]
		d.place(first)
	await get_tree().create_timer(Diorama.TWIN_STEP * 8.0 + Diorama.POP_TIME).timeout
	check(chest != null and chest.attention and chest.glow_count() > 0 and main.effects.is_calling(chest),
		"el baúl que guarda lo que toca encontrar brilla, se mueve y echa motas")
	check(chest != null and chest.outline_count() > 0, "y lleva un contorno dorado (lo que se ve de lejos)")
	var tip_wait := 0.0
	while GameState.hud.tip_text() == "" and tip_wait < 6.0:      # sale cuando se va el rótulo de capítulo
		await get_tree().create_timer(0.25).timeout
		tip_wait += 0.25
	check(GameState.hud.tip_text() == Narrator.text("consejo_muebles") and GameState.hud.chapter_text() == "",
		"la primera vez sale el consejo de tocar el mueble que brilla, ya sin el rótulo de capítulo (%.1f s)" % tip_wait)
	check(GameState.hud.task_text().begins_with("I · INFANCIA | Lleva cada pieza") and d.has_findable(),
		"mientras haya piezas que poner, la tarjeta pide ponerlas (aunque ya haya algo guardado que buscar)")
	await get_tree().create_timer(0.5).timeout     # entra deslizándose
	var tip_rect: Rect2 = GameState.hud._tip_box.get_global_rect()
	var screen := get_viewport().get_visible_rect().size
	check(tip_rect.get_center().x > screen.x * 0.5 and tip_rect.end.y > screen.y * 0.8
		and tip_rect.end.x <= GameState.hud._panel.get_global_rect().position.x,
		"los consejos salen como avisos abajo a la derecha, junto a la bandeja")
	steps = 0
	while steps < 30:                              # todo lo que se pueda colocar sin buscar
		var h := d.hint_target()
		if not h.has("slot"):
			break
		d.place(h.slot)
		steps += 1
	check(d.hint_target().get("container") == chest, "cuando solo falta buscar, la pista señala el mueble (no lo escondido)")
	check(GameState.hud.task_text().begins_with("I · INFANCIA | Busca lo guardado"),
		"y la tarjeta de tarea dice que toca buscar (%s)" % GameState.hud.task_text())
	check(not _slot(d, &"peluche").available, "(control) la nutria no aparece mientras falten los cubos")
	var green := _collectible(d, &"dibujo_casa")
	check(d.collectible_total() == 4 and green != null and green.available and green.container == chest and not green.is_clickable(),
		"hay 4 dibujos escondidos; uno está en el baúl y, con el baúl cerrado, no se puede coger")
	var con_imagen := d.interactables.filter(func(it: Interactable) -> bool:
		var tex := Hud.drawing_texture(it.target) if it.kind == NameRules.COLLECTIBLE else null
		return tex != null and tex.resource_path.begins_with("res://assets/kit/dibujos/") and it.target.has_meta("color"))
	check(con_imagen.size() == d.collectible_total(),
		"los dibujos coleccionables son los de las artistas: cada uno lleva su imagen de assets/kit/dibujos y su color (%d)" % con_imagen.size())
	check(friends.available and friends.target.visible and friends.is_clickable()
		and Hud.drawing_texture(friends.target).resource_path == "res://assets/kit/dibujos/t_draw_04.jpg",
		"con la cama puesta, asoma el de debajo (Ana y Lurdes, t_draw_04) y se puede coger")
	Narrator.clear()                           # sin primer plano encima: consejos y avisos esperan a que acabe
	m.finish()
	if chest != null:
		chest.set_open(true)
		await get_tree().process_frame
		check(not chest.attention and blocks.attention and GameState.hud.tip_text() == Narrator.text("consejo_dentro"),
			"al abrir el baúl, lo que brilla es lo de dentro (y sale el consejo de cogerlo) (%s · %s · %s)" % [chest.attention, blocks.attention, GameState.hud.tip_text()])
		await get_tree().create_timer(0.5).timeout
		var tip_at: Vector2 = GameState.hud._tip_box.get_global_rect().get_center()
		_mouse_button(tip_at, true)
		var swipe := InputEventMouseMotion.new()
		swipe.position = tip_at + Vector2(140, 0)
		swipe.global_position = swipe.position
		swipe.relative = Vector2(140, 0)
		swipe.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(swipe, true)
		_mouse_button(tip_at + Vector2(140, 0), false)
		await get_tree().create_timer(0.4).timeout
		check(GameState.hud.tip_text() == "", "el consejo es una notificación: deslizándolo fuera de la pantalla, se va")
		var heard_store: Dictionary = Sfx.played.duplicate()
		d.collect(blocks)
		check(d.visible_inventory().has(&"cubos"), "los cubos encontrados pasan a la bandeja")
		check(_heard(heard_store, "guardar_inventario") == 1, "al coger lo que va a la bandeja suena «GUARDAR OBJETO EN EL INVENTARIO» (Drive FXS)")
		await get_tree().process_frame
		await get_tree().process_frame
		var flying := GameState.hud.flights()
		var cubes_card := GameState.hud.item_for(&"cubos")
		var fly_from: Vector2 = flying[0].get_global_rect().get_center() if not flying.is_empty() else Vector2.ZERO
		check(flying.size() == 1 and cubes_card != null and fly_from.distance_to(cubes_card.get_global_rect().get_center()) > 150.0,
			"al coger lo guardado, su ficha sale de donde estaba y vuela por la pantalla (no aparece de golpe en la bandeja)")
		await get_tree().create_timer(Hud.FLY_TIME + 0.15).timeout
		check(GameState.hud.flights().is_empty(), "y llega a su sitio en la bandeja")
		check(green.is_clickable(), "con el baúl abierto, el dibujo de dentro se puede coger")
		green.activate()
		await get_tree().process_frame
		await get_tree().process_frame
		var look: Inspeccion = main.inspeccion
		check(green.collected and found_events.size() == 1 and found_events[0][1] == 1 and found_events[0][2] == 4
			and look.is_open() and look.item == green and d.is_held(green) and green.target.get_parent() != d.clothesline,
			"tocar el dibujo lo encuentra (1 de 3) y sale su primer plano para mirarlo (aún no vuela a la cuerda)")
		check(Sfx.jingle_playing() == "logro", "al encontrar un dibujo suena la sintonía del logro")
		var heard_jingle: Dictionary = Sfx.played.duplicate()
		Sfx.jingle("logro")                        # (el último dibujo: se encuentra y gana su logro a la vez)
		for i in Sfx.POOL_SIZE + 1:
			Sfx.play("boton_seleccion")
		check(not _more(heard_jingle, "logro") and Sfx.jingle_playing() == "logro",
			"la sintonía no se monta sobre sí misma (el último dibujo y su logro suenan una vez) y los clics no la cortan")
		check(look.title_text() == Inspeccion.TITLE and look.name_text() == Narrator.piece_name(&"dibujo_casa").to_upper()
			and look.count_text() == "1 DE 4" and is_instance_valid(look.copy)
			and (look._pill_label.get_parent() as Control).get_global_rect().position.y >= look._title.get_global_rect().end.y - 2.0,
			"como en la referencia: título grande, su nombre en una cápsula, el dibujo en 3D, «1 DE 4» y el contador (%s · %s)"
			% [look.title_text(), look.name_text()])
		var voices: Array = Narrator._queue.map(func(e: Dictionary) -> String: return String(e.get("voice", "")))
		if Narrator.voice_playing():
			voices.append(Narrator._player.stream.resource_path)
		check(voices.any(func(v: String) -> bool: return v.ends_with("/dibujo_encontrado_1.ogg")),
			"al encontrar el primer dibujo suena su voz (la del primero; los demás, la suya)")
		for i in 2:                                # el visor se maqueta un fotograma después
			await get_tree().process_frame
		_click(look.button_center())               # el botón llega el último: un clic con prisa no lo cierra
		await get_tree().process_frame
		check(look.is_open(), "el botón aún no está: un clic con prisa no lo cierra")
		var turn_before := look.view_rotation().y
		_mouse_button(look.view_center(), true)
		var spin := InputEventMouseMotion.new()
		spin.position = look.view_center() + Vector2(90, 0)
		spin.global_position = spin.position
		spin.relative = Vector2(90, 0)
		spin.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(spin, true)
		await get_tree().process_frame
		_mouse_button(look.view_center() + Vector2(90, 0), false)
		check(look.view_rotation().y - turn_before > 0.6, "arrastrando sobre el dibujo se gira para mirarlo (%.2f rad)" % (look.view_rotation().y - turn_before))
		await get_tree().create_timer(Inspeccion.BUTTON_DELAY).timeout
		_click(look.button_center())
		await get_tree().process_frame
		check(not look.is_open() and not d.is_held(green) and green.target.get_parent() == d.clothesline,
			"«%s» lo cierra y el dibujo se va volando hacia la cuerda" % Inspeccion.BUTTON)
		await get_tree().create_timer(Diorama.LIFT_TIME + 0.15 + Diorama.HANG_TIME + 0.25).timeout
		check(green.target.global_position.distance_to(d.spot(0).global_position) < 0.02 and hung[0] == 1,
			"el dibujo vuela hasta la primera pinza de la cuerda y se cuelga")
		main.open_pause()
		main.pause.show_page("dibujos")
		var album: PauseMenu = main.pause
		check(album.buttons.dibujos.visible and album.album_slots.size() == 4
			and album.album_detail().begins_with(Narrator.piece_name(&"dibujo_casa", true))
			and (album.album_slots[0].get_child(0) as DibujoIcono).texture == Hud.drawing_texture(green.target),
			"en la pausa, el álbum de dibujos: las 4 casillas (con la imagen del dibujo) y, a la derecha, el encontrado en grande (%s)" % album.album_detail())
		var missing := album.album_slots.filter(func(b: Button) -> bool: return b.text == "?")
		if not missing.is_empty():
			(missing[0] as Button).pressed.emit()
		check(missing.size() == 3 and album.album_detail().begins_with("???"),
			"los que faltan salen en silueta con «?» y sin nombre")
		main.pause.close()
		check(not GameState.hud.tip_text().contains("dibujo") and not Narrator.has_line("consejo_dibujos"),
			"no hay frases ni consejos sobre los dibujos escondidos: los encuentra el jugador")
		await get_tree().create_timer(Efectos.GLINT_EVERY + 0.3).timeout
		check(main.effects.glints > 0, "los dibujos que esperan echan un destello de vez en cuando (%d)" % main.effects.glints)
		d.place(_slot(d, &"cubos"))
	check(_slot(d, &"peluche").available and d.visible_inventory().has(&"peluche"), "con todo lo demás puesto aparece la nutria (clave)")
	d.place(_slot(d, &"peluche"))
	check(s2.completed and placed.find(&"caja_musica") < placed.find(&"dibujo") and placed.find(&"dibujo") < placed.find(&"peluche"),
		"infancia completa en el orden del guion: caja de música, dibujo, nutria")
	# Un clic en el primer plano mientras aún habla: la voz se apaga en un momento y sale el acto siguiente.
	for i in 3:
		await get_tree().process_frame
	var talk_left := Narrator.remaining()
	check(d.act_waiting() and m.active and talk_left > 1.0 and not s3.opening,
		"al cerrar la infancia, su diálogo suena y la adolescencia espera (%.1f s de voz)" % talk_left)
	_click(Vector2(640, 300))
	await get_tree().create_timer(Diorama.ACT_FADE * 0.5).timeout
	var faded_mid := Narrator._player.volume_db
	await get_tree().create_timer(Diorama.ACT_FADE * 0.5 + 0.3).timeout
	check(faded_mid < -3.0 and not Narrator.voice_playing() and not m.active and (s3.opening or s3.opened)
		and GameState.hud.chapter_text().contains("Adolescencia"),
		"un clic mientras habla apaga la voz con un fundido (%.0f dB a mitad) y pasa al capítulo siguiente" % faded_mid)
	# El dibujo es plano y está en la pared: su primer plano es de frente.
	var drawing := _slot(d, &"dibujo").node
	var pared := Hud.drawing_texture(drawing)
	check(pared != null and pared.resource_path == "res://assets/kit/dibujos/t_draw_03.png",
		"el dibujo de la pared de la infancia («las niñas no pintan monstruos») es el de la niña bailarina y su abuela, y al colocarlo se sigue viendo")
	var face := drawing.global_basis.z
	m.start(drawing, "normal", "dibujo")
	check(absf(wrapf(cam_ctl.yaw - rad_to_deg(atan2(face.x, face.z)), -180.0, 180.0)) < 1.0 and absf(cam_ctl.pitch - 8.0) < 0.5
		and m._flat_front(_slot(d, &"hucha").node) == Vector3.ZERO,
		"los objetos planos de pared (el dibujo) se ven de frente en su primer plano")
	m.finish()
	if not s3.opened:
		d.debug_solve_step()                       # sus piezas, sin esperar a que se callen sus frases
	var camera_pick := _pickup(d, &"camara")
	var application := _pickup(d, &"solicitud")
	check(s3.opened and camera_pick != null and application != null and not camera_pick.available and not application.available,
		"al abrirse la adolescencia, ni la cámara ni la inscripción se ven todavía")
	var lamp := _slot(d, LAMP)
	var lamp_lights: Array = lamp.lights() if lamp != null else []
	check(not lamp_lights.is_empty() and not lamp.filled and not (lamp_lights[0][0] as Light3D).visible,
		"la luz de una pieza (la lámpara del escritorio) está apagada mientras es silueta")
	_farol_energy = float(lamp_lights[0][1]) if not lamp_lights.is_empty() else 0.0
	# Los cajones del escritorio también se ponen: dos iguales (estrella) y el del pomo, después del
	# escritorio; el de arriba (el de la solicitud) no se abre ni brilla hasta que está puesto.
	var drawer_slots := s3.slots.filter(func(sl: PieceSlot) -> bool: return String(sl.id).begins_with("cajon"))
	var top_drawer: Interactable = application.container
	check(drawer_slots.size() == 3 and _slots_with(d, &"cajon") == 2 and _slots_with(d, &"cajon_pomo") == 1
		and drawer_slots.all(func(sl: PieceSlot) -> bool: return sl.prereqs.has(&"escritorio") and not sl.filled)
		and top_drawer != null and top_drawer.inside.size() == 1 and not top_drawer.is_clickable() and not top_drawer.attention,
		"los cajones del escritorio son piezas que hay que poner (después del escritorio) y el de arriba no se abre sin ponerlo")
	steps = 0
	while not _slot(d, &"mp3").filled and steps < 40:
		d.debug_solve_step()
		steps += 1
	check(application.available and not camera_pick.available and application.container != null
		and application.container.kind == NameRules.DRAWER and application.container.attention
		and application.container.pieces_ready() and application.container.is_clickable(),
		"con el MP3 puesto toca encontrar la solicitud de Bellas Artes: el cajón brilla (la cámara aún no aparece)")
	# El escritorio y sus cajones son los de las artistas (kit), con su material, y el cajón de la
	# solicitud está en la columna del escritorio y sale hacia el jugador (+Z).
	var desk_meshes := Visuals.meshes_under(_slot(d, &"escritorio").node)
	var drawer_it := application.container
	var desk_box := Visuals.global_aabb(_slot(d, &"escritorio").node)
	var drawer_box := Visuals.global_aabb(drawer_it.target) if drawer_it != null else AABB()
	var kit_mat := func(m: MeshInstance3D) -> bool:
		var mat := m.get_surface_override_material(0)
		return mat != null and mat.resource_path == "res://assets/kit/materiales/M_Desk.tres"
	check(desk_meshes.any(func(m: MeshInstance3D) -> bool:
			return _kit_mesh(m, "SM_DeskA") and kit_mat.call(m))
		and drawer_it != null
		and Visuals.meshes_under(drawer_it.target).any(func(m: MeshInstance3D) -> bool:
			return _kit_mesh(m, "SM_DeskC") and kit_mat.call(m))
		and desk_box.grow(0.05).encloses(drawer_box) and (drawer_it._open.origin - drawer_it._closed.origin).z > 0.2,
		"el escritorio es el del kit (SM_DeskA, M_Desk) y el cajón de la solicitud, uno de sus cajones (SM_DeskC), en su columna y saliendo hacia el jugador")
	steps = 0
	while not camera_pick.available and steps < 80:
		d.debug_solve_step()
		steps += 1
	var rest := s3.slots.filter(func(sl: PieceSlot) -> bool: return not sl.filled and sl.id != &"camara")
	check(camera_pick.available and rest.is_empty() and camera_pick.container != null and camera_pick.container.attention,
		"con todo lo demás puesto, toca encontrar la cámara (clave): el armario brilla")
	var flashes_before: int = flashes[0]
	steps = 0
	while not _slot(d, &"camara").filled and steps < 40:
		d.debug_solve_step()
		steps += 1
	check(flashes[0] > flashes_before, "al colocar la cámara, destello blanco (el flash)")
	check(placed.find(&"mp3") < placed.find(&"solicitud") and placed.find(&"solicitud") < placed.find(&"camara"),
		"adolescencia en el orden del guion v2: MP3, solicitud y la cámara (clave) la última")
	var pink := _collectible(d, &"dibujo_monstruo")
	if not lamp.filled:
		d.place(lamp)
	await get_tree().create_timer(maxf(Diorama.GIVEN_DELAY + 0.3, PieceSlot.LIGHT_FADE + 0.1)).timeout
	if not lamp_lights.is_empty():
		var bulb: Light3D = lamp_lights[0][0]
		check(bulb.visible and is_equal_approx(bulb.light_energy, float(lamp_lights[0][1])),
			"al colocar la lámpara, su luz se enciende con un fundido (%.2f de %.2f)" % [bulb.light_energy, float(lamp_lights[0][1])])
	check(pink != null and pink.comes_with == &"" and not pink.collected and m.active,
		"al poner la cámara no sale ningún dibujo: el del monstruo está en otro sitio (debajo del puf)")
	Narrator.clear()
	m.finish()
	await get_tree().create_timer(Diorama.GIVEN_DELAY + 0.3).timeout
	check(not pink.collected and found_events.size() == 1, "al acabar el momento de la cámara, el dibujo del monstruo sigue sin encontrar")
	if not _slot(d, &"puf").filled:
		d.place(_slot(d, &"puf"))
	await get_tree().create_timer(Diorama.POP_TIME + 0.1).timeout
	check(pink.available and pink.target.visible and pink.is_clickable(),
		"con el puf puesto, el dibujo del monstruo asoma debajo y se puede coger (after-puf)")
	pink.activate()
	await get_tree().process_frame
	await get_tree().process_frame
	var look2: Inspeccion = main.inspeccion
	check(pink.collected and found_events.size() == 2 and found_events[1][1] == 2 and look2.is_open() and look2.count_text() == "2 DE 4",
		"al cogerlo de debajo del puf sale su primer plano (2 de 4)")
	await get_tree().create_timer(Inspeccion.BUTTON_DELAY + 0.05).timeout
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	check(not look2.is_open() and not main.pause.is_open() and pink.target.get_parent() == d.clothesline,
		"Esc también lo cierra (sin abrir la pausa) y el dibujo va a la cuerda")
	# El gato (after-cajas_tienda) no asoma hasta que están puestas las cajas de la tienda.
	var cat := _collectible(d, &"dibujo_gato")
	steps = 0
	while not s4.opened and steps < 60:
		d.debug_solve_step()
		steps += 1
	check(cat != null and s4.opened and not _slot(d, &"cajas_tienda").filled and not cat.available and not cat.target.visible,
		"al abrirse la profesión, el dibujo del gato aún no está: espera a las cajas de la tienda (after-cajas_tienda)")
	if s4.opened:
		d.place(_slot(d, &"cajas_tienda"))
	check(cat != null and cat.available and cat.target.visible and cat.is_clickable(), "con las cajas puestas, asoma el gato encima y se puede coger")
	steps = 0
	while not _slot(d, &"lienzo").filled and steps < 120:
		d.debug_solve_step()
		steps += 1
	var easel := _slot(d, &"caballete").node
	var canvas := _slot(d, &"lienzo").node
	m.start(easel, "normal", "caballete")
	check(_slot(d, &"lienzo").filled and not m.hidden_for_shot.any(func(g: Node) -> bool: return canvas.is_ancestor_of(g)),
		"en el primer plano del caballete no se quita el cuadro que lleva encima")
	Narrator.clear()
	m.finish()
	while not s4.completed and steps < 120:
		d.debug_solve_step()
		steps += 1
	check(Logros.is_unlocked("infancia") and Logros.is_unlocked("adolescencia") and Logros.is_unlocked("adultez")
		and not Logros.is_unlocked("dibujos"),
		"logros: al completar cada acto se desbloquean sus recuerdos (infancia, adolescencia, adultez)")
	check(s4.completed and placed.find(&"llaves") < placed.find(&"caballete") and placed.find(&"caballete") < placed.find(&"espejo"),
		"adultez en el orden del guion: llaves, caballete y el espejo (clave) el último")
	var mirror := _slot(d, &"espejo")
	var front := mirror.node.global_basis.z
	var want_yaw := rad_to_deg(atan2(front.x, front.z))
	await get_tree().create_timer(1.6).timeout
	var shrunk := d.slots.filter(func(sl: PieceSlot) -> bool:      # (el saltito de colocar parte de su tamaño de verdad)
		return sl.filled and sl.section != s1 and (not sl.node.transform.is_equal_approx(start_xf[sl])
			or not (d._base_scale.get(sl.node, sl.node.scale) as Vector3).is_equal_approx(sl.node.scale)))
	check(shrunk.is_empty(), "ninguna pieza se queda pequeña ni salta desde pequeña por colocarla mientras aún crecía (%s)"
		% [shrunk.map(func(sl: PieceSlot) -> StringName: return sl.id)])
	check(m.kind == "reflejo" and absf(cam_ctl.yaw - want_yaw) < 1.0 and cam_ctl.pitch < 8.0,
		"al poner el espejo, la cámara se pone delante de él (giro %.0f, quiere %.0f)" % [cam_ctl.yaw, want_yaw])
	check(m.is_isolated() and cam_ctl.cam.cull_mask != 0xFFFFF and m.iris_strength() > 0.95 and is_instance_valid(m.reflection),
		"espejo: todo lo demás a negro y en la luna aparece su reflejo")
	d._open_when_free(s5)                        # lo que hace la pausa entre secciones al acabar
	check(d.hold_sections and d.opening_section() == s5 and not s5.opening,
		"mientras dura el espejo, el final espera: no se abre encima")
	Narrator.clear()
	await get_tree().create_timer(Momentos.MIN_TIME * 0.5).timeout     # un momento dura al menos MIN_TIME
	check(m.active and m.kind == "transicion" and m.is_isolated() and cam_ctl.in_moment and not s5.opening,
		"al callarse el espejo no se vuelve al desván: transición (el espejo vacío, en silencio)")
	var cut_wait := 0.0
	while m.kind == "transicion" and cut_wait < 6.0:
		await get_tree().process_frame
		cut_wait += get_process_delta_time()
	check(cut_wait > Momentos.TRANSITION_HOLD and s5.opening and m.kind == "ofrecida" and m._curtain.color.a > 0.95 and not is_instance_valid(m.reflection)
		and GameState.hud.chapter_text() == "",
		"después, fundido lento a negro y, ya a oscuras, empieza el final (sin rótulo de capítulo)")
	check(not s5.opened and Narrator.remaining() > 3.0 and not _slot(d, &"moneda").available,
		"el final habla antes de enseñar la moneda")
	await get_tree().create_timer(0.3).timeout
	var pig := _slot(d, &"hucha").node
	check(m.kind == "ofrecida" and cam_ctl.in_moment and cam_ctl.center.distance_to(_slot(d, &"hucha").center()) < 0.2
		and not d.tray_entries().any(func(e: Dictionary) -> bool: return e.id == &"moneda"),
		"el final es un primer plano de la hucha mientras habla, y la moneda no va a la bandeja")
	var trunk := d.find_child("BaulViejo", true, false)
	check(m.is_isolated() and m.is_in_isolation(Visuals.meshes_under(pig)[0])
		and Visuals.meshes_under(trunk).any(func(t: MeshInstance3D) -> bool: return m.is_in_isolation(t))
		and not m.is_in_isolation(Visuals.meshes_under(_slot(d, &"escritorio").node)[0])
		and absf(cam_ctl.pitch - Momentos.ZENITH) < 0.5 and absf(cam_ctl._cur_pitch - cam_ctl.pitch) < 0.5,
		"corte a la hucha sola (sobre su baúl), vista un poco desde arriba, quieta y sin vueltas")
	check(m.cozy_shown() and is_instance_valid(m._rim) and is_instance_valid(m._motes) and m.is_in_isolation(m._motes),
		"la escena del final es acogedora: fondo cálido con luces desenfocadas, contraluz y motas en la luz")
	await get_tree().create_timer(1.0).timeout
	check(not is_instance_valid(m.coin) and Narrator.remaining() > 0.0, "primero el diálogo: mientras habla, aún no hay moneda")
	Narrator.clear()                               # el jugador pasa las frases con clics: no hay que esperar
	await get_tree().create_timer(0.3).timeout
	check(s5.opened and _slot(d, &"moneda").available and is_instance_valid(m.coin) and m._coin_ready(),
		"en cuanto se callan las frases, la moneda aparece junto a la hucha y ya se puede coger")
	await get_tree().create_timer(0.6).timeout
	var ghost_mesh: MeshInstance3D = Visuals.meshes_under(m.ghost)[0] if is_instance_valid(m.ghost) else null
	check(ghost_mesh != null and m.is_in_isolation(ghost_mesh) and (ghost_mesh.material_override as ShaderMaterial).shader.resource_path.ends_with("fantasma.gdshader"),
		"y una moneda fantasma (translúcida) enseña el gesto")
	var slot_at := _slot(d, &"moneda").center()
	var ghost_from := m.ghost.global_position.distance_to(slot_at) if is_instance_valid(m.ghost) else 0.0
	var coin_xf: Transform3D = m.coin.global_transform if is_instance_valid(m.coin) else Transform3D()
	var pig_xf := pig.global_transform
	await get_tree().create_timer(0.6).timeout
	check(is_instance_valid(m.ghost) and m.ghost.global_position.distance_to(slot_at) < ghost_from - 0.05,
		"la fantasma va de la moneda hacia la ranura de la hucha")
	check(is_instance_valid(m.coin) and m.coin.global_transform.is_equal_approx(coin_xf) and pig.global_transform.is_equal_approx(pig_xf),
		"la moneda y la hucha se quedan quietas (lo que se mueve es la fantasma y la luz)")
	var ghost_node := m.ghost
	var ghost_mid := m.ghost.global_position if is_instance_valid(m.ghost) else Vector3.ZERO
	await get_tree().create_timer(Momentos.GHOST_TIME + Momentos.GHOST_REST).timeout
	check(is_instance_valid(m.ghost) and m.ghost == ghost_node and m.ghost.global_position.distance_to(ghost_mid) < 0.03
		and float(m._ghost_mat.get_shader_parameter("alpha")) > 0.05,
		"el gesto de la fantasma se repite en bucle mientras no se coja la moneda")
	_mouse_button(m.coin_screen_position(), true)  # coger la moneda para el bucle...
	await get_tree().process_frame
	check(m._coin_state == "arrastrando" and not is_instance_valid(m.ghost), "al coger la moneda, la fantasma se va")
	_mouse_button(m.coin_screen_position(), false) # ...y soltarla lejos de la ranura no la mete: vuelve
	await get_tree().create_timer(0.6).timeout
	check(not _slot(d, &"moneda").filled and is_instance_valid(m.coin) and m._coin_state == "" and is_instance_valid(m.ghost),
		"soltar la moneda lejos de la ranura no la mete: vuelve a su sitio y la fantasma vuelve a enseñar el gesto")
	main.logros._start_ms = maxi(0, Time.get_ticks_msec() - 90000)   # como si llevara (como mucho) 1,5 minutos
	_mouse_button(m.coin_screen_position(), true)
	await get_tree().process_frame
	_mouse_move(m.slot_screen_position())
	await get_tree().process_frame
	_mouse_button(m.slot_screen_position(), false)
	await get_tree().create_timer(0.8).timeout
	check(d.completed and _slot(d, &"moneda").filled, "arrastrar la moneda hasta la ranura la mete en la hucha y completa el desván")
	var lista := LogrosLista.new()
	add_child(lista)
	lista.refresh()
	var got := lista.rows.filter(func(r: Control) -> bool: return bool(r.get_meta(&"conseguido")))
	var artist_card: Control = lista.rows[Logros.LISTA.size() - 1]
	check(Logros.is_unlocked("speedrunner") and lista.rows.size() == Logros.LISTA.size() and got.size() == 4
		and not Logros.is_unlocked("alma_artista") and String(artist_card.get_meta(&"texto")).begins_with("Logro secreto")
		and lista._count.text == "Conseguidos: 4 de %d" % Logros.LISTA.size(),
		"acabar el desván en menos de 2 minutos da «Speedrunner»; la lista enseña los %d (4 conseguidos, con su barra) y los secretos no dicen qué hacer (%s)"
		% [Logros.LISTA.size(), [Logros.is_unlocked("speedrunner"), got.size(), lista._count.text, artist_card.get_meta(&"texto"), GameState.achievements]])
	lista.queue_free()
	check(d.find_child("ChispasMoneda", false, false) != null and float(m._cozy_mat.get_shader_parameter("brillo")) > 1.2,
		"al entrar la moneda: golpe de luz, chispas doradas y el fondo se aviva")
	Events.piece_placed.disconnect(record)
	Events.flash_requested.disconnect(count_flash)
	Events.collectible_found.disconnect(record_found)
	Events.collectible_hung.disconnect(count_hung)
	await get_tree().create_timer(2.0).timeout
	check(not GameState.hud._done.visible, "el final de la historia no enseña el aviso de «completado»")
	await get_tree().create_timer(3.0).timeout
	check(main._fade.color.a > 0.05, "el final funde a negro (hacia los créditos) (%.2f)" % main._fade.color.a)
	var credits: Creditos = main.credits
	var wait_credits := 0.0
	while not credits.rolling and wait_credits < 8.0:
		await get_tree().create_timer(0.25).timeout
		wait_credits += 0.25
	check(credits.rolling and credits.lines().has("DIBUJOS ENCONTRADOS") and credits.lines().has("2 de 4"),
		"tras el fundido pasan los créditos, con los dibujos encontrados (2 de 4)")
	await get_tree().create_timer(1.2).timeout
	_click(Vector2(640, 360))
	await get_tree().create_timer(Creditos.FADE + 0.4).timeout
	check(not credits.visible and GameState.diorama.scene_file_path == GameState.MENU_LEVEL
		and main.menu.is_open() == GameState.menu_unlocked,
		"y después de los créditos, el menú (con el cerdito)")


## La bandeja enseña todas las piezas (las que aún no van, con candado y el porqué), se aparta al
## coger una pieza para poder soltar detrás de ella, y vuelve al soltar.
func _test_tray(d: Diorama, shown: Array[StringName]) -> void:
	for i in 2:                                    # el panel se maqueta un fotograma después
		await get_tree().process_frame
	var hud: Hud = GameState.hud
	var all_ids: Dictionary = {}
	for sl in d.slots:
		if not sl.offered and sl.scope == null:   # (las de un rincón salen al entrar en él)
			all_ids[sl.id] = true
	check(hud.cards().size() == all_ids.size() and hud.cards(true).size() == shown.size(),
		"la bandeja enseña todas las piezas del juego (%d), las que aún no van con candado (%d se pueden poner)" % [hud.cards().size(), hud.cards(true).size()])
	var otter := hud.item_for(&"peluche")
	check(otter != null and otter.locked and otter.reason.contains(Narrator.text("titulo_infancia")),
		"la nutria va con candado y dice de qué acto es (%s)" % (otter.reason if otter != null else ""))
	check(d.lock_reason(&"tejado").contains(Narrator.piece_name(&"cumbrera")) and d.lock_reason(&"hucha").contains("última"),
		"cada candado dice qué va antes: tejado (%s), hucha (%s)" % [d.lock_reason(&"tejado"), d.lock_reason(&"hucha")])
	if otter != null:
		hud._scroll.ensure_control_visible(otter)    # (con todas las piezas del kit, la bandeja es larga)
		for i in 3:
			await get_tree().process_frame
		_click(otter.get_global_rect().get_center())
		await get_tree().process_frame
		check(not GameState.is_dragging and hud.info_text().begins_with("Todavía no se puede poner") and hud.info_text().contains(otter.reason),
			"tocar una ficha con candado no la coge: tiembla y dice por qué (%s)" % hud.info_text().replace("\n", " / "))
		GameState.drag.begin(&"peluche", otter)
		check(not GameState.is_dragging, "ni a la fuerza: una pieza bloqueada no se puede arrastrar")
	var wall := hud.item_for(&"pared_fondo")
	var tray_spot := hud._panel.get_global_rect().get_center()
	GameState.drag.begin(&"pared_fondo", wall)
	await get_tree().create_timer(Hud.SLIDE_TIME + 0.15).timeout
	check(GameState.is_dragging and hud.tray_is_away() and not hud.is_over_panel(tray_spot)
		and float(_slot(d, &"pared_fondo")._ghost.get_shader_parameter("pulse")) == 1.0,
		"al coger una pieza la bandeja se aparta (se puede soltar donde estaba) y late su silueta")
	_mouse_button(hud._panel.get_global_rect().get_center(), false)     # soltar en el borde que asoma = nada
	await get_tree().create_timer(Hud.SLIDE_TIME + 0.15).timeout
	check(not GameState.is_dragging and not hud.tray_is_away() and not _slot(d, &"pared_fondo").filled,
		"al soltar en el borde de la bandeja no se pone nada, y la bandeja vuelve")


func _collectible(d: Diorama, id: StringName) -> Interactable:
	for it in d.interactables:
		if it.kind == NameRules.COLLECTIBLE and it.id == id:
			return it
	return null


func _pickup(d: Diorama, id: StringName) -> Interactable:
	for it in d.interactables:
		if it.kind == NameRules.PICKUP and it.id == id:
			return it
	return null


## escala_luces: las luces que trae un modelo (de Blender llegan con otras unidades) se ajustan
## para todo el nivel con un número, sin reexportar.
func _test_light_scale() -> void:
	var probe := (load("res://levels/level_01_desvan.tscn") as PackedScene).instantiate() as Diorama
	probe.escala_luces = 2.0
	add_child(probe)
	var farol := _slot(probe, LAMP)
	var lights: Array = farol.lights() if farol != null else []
	var got := float(lights[0][1]) if not lights.is_empty() else -1.0
	check(_farol_energy > 0.0 and is_equal_approx(got, _farol_energy * 2.0),
		"escala_luces multiplica las luces del modelo (%.2f con escala 2, %.2f sin escala)" % [got, _farol_energy])
	probe.queue_free()
	await get_tree().process_frame


# --- Ajustes, menú de inicio y pausa ---------------------------------------------------------

func _test_settings() -> void:
	Settings.load_from(TEST_SETTINGS)
	check(AudioServer.get_bus_index(&"Musica") != -1 and AudioServer.get_bus_index(&"Voz") != -1, "existen los buses Musica, Efectos y Voz")
	check(is_equal_approx(Settings.get_value("volumen_musica"), Settings.DEFAULTS.volumen_musica), "sin fichero, los ajustes son los de por defecto")
	Settings.set_value("volumen_musica", 0.25)
	Settings.set_value("volumen_efectos", 0.0)
	Settings.set_value("subtitulos", false)
	var bus := AudioServer.get_bus_index(&"Musica")
	check(absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.25)) < 0.01, "el volumen de música llega al bus Musica")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Efectos")), "efectos a 0 = bus Efectos en silencio")
	check(Settings.save_now() == OK, "los ajustes se guardan en disco")
	Settings.load_from("")
	check(is_equal_approx(Settings.get_value("volumen_musica"), Settings.DEFAULTS.volumen_musica), "(control) sin fichero vuelven los de por defecto")
	Settings.load_from(TEST_SETTINGS)
	check(is_equal_approx(Settings.get_value("volumen_musica"), 0.25) and Settings.get_value("subtitulos") == false, "al volver a leer el fichero, los ajustes siguen ahí")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))


## El arte de las artistas (assets/kit/): cada modelo se carga, trae mallas con UV (sin UV no se
## ven las texturas) y el material del escritorio lleva sus texturas; la preview aparte carga.
func _test_kit() -> void:
	var modelos := 0
	var sin_uv := PackedStringArray()
	var pendientes := ["res://assets/kit"]
	while not pendientes.is_empty():
		var dir: String = pendientes.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			pendientes.append(dir + "/" + sub)
		for f in DirAccess.get_files_at(dir):
			if f.get_extension() != "fbx":
				continue
			var escena := load(dir + "/" + f) as PackedScene
			var raiz := escena.instantiate() if escena != null else null
			var mallas := raiz.find_children("*", "MeshInstance3D", true, false) if raiz != null else []
			if mallas.is_empty():
				sin_uv.append(f)
			for m: MeshInstance3D in mallas:
				if m.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] == null:
					sin_uv.append("%s/%s" % [f, m.name])
			if raiz != null:
				raiz.free()
			modelos += 1
	check(modelos >= 14 and sin_uv.is_empty(), "los modelos del kit se cargan y todas sus piezas traen UV (%d modelos; sin UV: %s)" % [modelos, ", ".join(sin_uv)])
	var desk := load("res://assets/kit/materiales/M_Desk.tres") as StandardMaterial3D
	check(desk != null and desk.albedo_texture != null and desk.normal_enabled and desk.normal_texture != null
		and desk.roughness_texture == desk.ao_texture and desk.ao_texture != null,
		"el material del escritorio lleva su color, sus normales y la textura ARM (oclusión, rugosidad, metálico)")
	check(load("res://preview/preview_assets.tscn") is PackedScene, "la escena de preview de assets (aparte del juego) carga")
	# El tileset del kit: una escena por pieza, con escala 1 y alguna malla; y el diorama de prueba
	# (para editar a mano) hecho de instancias de esas piezas, ninguna redimensionada.
	var tileset := Array(DirAccess.get_files_at("res://assets/kit/piezas")).filter(func(f: String) -> bool: return f.get_extension() == "scn")
	var malas := tileset.filter(func(f: String) -> bool:
		var p := (load("res://assets/kit/piezas/" + f) as PackedScene).instantiate() as Node3D
		var mal := not p.scale.is_equal_approx(Vector3.ONE) or p.find_children("*", "MeshInstance3D", true, false).is_empty()
		p.free()
		return mal)
	check(tileset.size() >= 60 and malas.is_empty(), "el tileset del kit: %d piezas con escala 1 y su malla (mal: %s)" % [tileset.size(), malas])
	# Las texturas finales (TexturasFinales de Drive): cada conjunto pinta sus piezas.
	var sin_textura := PackedStringArray()
	for par: Array in [["SM_Floor", "Pack01"], ["SM_Pillar", "Pack01"], ["SM_Ceiling", "Pack_02"], ["SM_BoxA", "Boxes"],
			["SM_CoverBoxA", "Boxes"], ["SM_Lamp", "LampStool"], ["SM_Stool", "LampStool"], ["SM_DeskA", "Desk"]]:
		var p := (load("res://assets/kit/piezas/%s.scn" % par[0]) as PackedScene).instantiate()
		var m := p.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var mat := m.get_surface_override_material(0) as StandardMaterial3D
		if mat == null or mat.resource_path != "res://assets/kit/materiales/M_%s.tres" % par[1] or mat.albedo_texture == null:
			sin_textura.append(par[0])
		p.free()
	check(sin_textura.is_empty(), "las piezas del kit llevan las texturas finales de su conjunto (suelo, pilar, techo, cajas, lámpara, taburete, escritorio; sin: %s)" % ", ".join(sin_textura))
	var diorama := (load("res://preview/diorama_kit.tscn") as PackedScene).instantiate() as Node3D
	var instancias := diorama.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n.scene_file_path != "")
	var del_kit := instancias.filter(func(n: Node) -> bool: return n.scene_file_path.begins_with("res://assets/kit/piezas/"))
	var escaladas := instancias.filter(func(n: Node3D) -> bool: return not n.scale.is_equal_approx(Vector3.ONE))
	var nombres := instancias.map(func(n: Node) -> String: return n.scene_file_path.get_file().get_basename())
	check(instancias.size() >= 45 and del_kit.size() == instancias.size() and escaladas.is_empty()
		and nombres.has("SM_WallA") and nombres.has("SM_Window") and nombres.has("SM_Ceiling") and nombres.has("SM_ComodaA") and nombres.has("SM_TV"),
		"el diorama de prueba (preview/diorama_kit.tscn) son piezas del tileset sin redimensionar: hastial, ventana, faldón, cómoda, tele... (%d)" % instancias.size())
	# 18-oct: el diorama de prueba copia el blocking de las artistas (assets/kit/referencia/Blocking3.fbx)
	# con los assets nuevos (Pack06-08), se llena con adornos, cuerdas de bombillitas (una libre para los
	# dibujos) y el dibujo de la bailarina; y todo el kit lleva el estilo cozy (misma capa de tono).
	var nuevas := ["SM_Caballete", "SM_Mirror", "SM_CatBed", "SM_Rug", "SM_Hat", "SM_LitterBox", "SM_MusicBox",
		"SM_Pig", "SM_Lights", "SM_Cuerda", "SM_Bombilla", "SM_Polaroid", "SM_PolaroidA", "SM_ComodaC",
		"Dibujo_t_draw_03"]
	var faltan := nuevas.filter(func(n: String) -> bool: return not tileset.has(n + ".scn"))
	var tablones := nombres.filter(func(n: String) -> bool: return n.begins_with("FloorPlanks")).size()
	var sombrero := diorama.find_children("SM_Hat*", "Node3D", true, false)
	var inclinado := not sombrero.is_empty() and not (sombrero[0] as Node3D).basis.y.is_equal_approx(Vector3.UP)
	check(faltan.is_empty() and tablones == 12 and not nombres.has("SM_Floor") and inclinado
		and nombres.has("SM_Caballete") and nombres.has("SM_Mirror") and nombres.has("SM_CatBed") and nombres.has("SM_Burro"),
		"el diorama de prueba sigue el blocking: el suelo en 12 tablones, caballete, espejo, cama del gato, burro con el sombrero colgado (faltan en el tileset: %s; tablones %d)" % [faltan, tablones])
	var tramos := nombres.filter(func(n: String) -> bool: return n == "SM_Cuerda").size()
	var bombillas := nombres.filter(func(n: String) -> bool: return n == "SM_Bombilla").size()
	var luces := diorama.find_children("*", "OmniLight3D", true, false).size()
	var material_luces := load("res://assets/kit/materiales/provisional/luces.tres") as BaseMaterial3D
	var cuerda_dibujos := diorama.find_child("CuerdaDibujos", true, false)
	check(tramos >= 5 and bombillas == tramos * 3 and luces == 0 and not material_luces.emission_enabled
		and cuerda_dibujos != null and diorama.find_child("Adornos", true, false) != null
		and nombres.has("SM_MusicBox") and nombres.has("SM_Pig") and nombres.has("Dibujo_t_draw_03"),
		"el diorama de prueba, más lleno: cuerdas de bombillitas en varias paredes (%d tramos de SM_Cuerda con %d SM_Bombilla, 3 por tramo, apagadas; una libre para los dibujos), caja de música, hucha y el dibujo de la bailarina" % [tramos, bombillas])
	var sin_estilo := PackedStringArray()
	var tono: Texture2D = load("res://assets/kit/materiales/estilo/tono.tres")
	for dir in ["res://assets/kit/materiales/", "res://assets/kit/materiales/provisional/"]:
		for f in DirAccess.get_files_at(dir):
			var m := load(dir + f) as BaseMaterial3D if f.get_extension() == "tres" else null
			if m != null and (not m.detail_enabled or m.detail_albedo != tono or m.detail_mask == null):
				sin_estilo.append(f)
	var mezcla := ((load("res://assets/kit/materiales/estilo/mezcla.tres") as GradientTexture1D).gradient.colors[0] as Color).r
	check(tono != null and sin_estilo.is_empty() and mezcla > 0.1 and mezcla < 0.6,
		"el estilo cozy del kit: todos sus materiales mezclan su color con el mismo tono cálido (%d %%; sin estilo: %s)" % [roundi(mezcla * 100), ", ".join(sin_estilo)])
	diorama.free()


func _has_music(song: String) -> bool:
	for ext: String in Sfx.EXTENSIONS:
		if ResourceLoader.exists("res://assets/audio/musica/%s.%s" % [song, ext]):
			return true
	return false


## Devuelve false si no se puede seguir (sin título o sin menú, el resto no tiene sentido).
func _test_title_menu(main: Node) -> bool:
	await _test_splash(main)
	var t := GameState.diorama
	check(t != null and t.scene_file_path == GameState.MENU_LEVEL, "el juego arranca en el diorama del título")
	if t == null:
		return false
	check(GameState.mode == GameState.Mode.MENU and not main.menu.is_open(), "el menú empieza cerrado: hay que resolver el puzle")
	# El inicio, ordenado: el cerdito solo y sin frase; luego la bandeja para vestirlo; luego los botones.
	# La tarjeta de tarea y las estrellas de logros no salen (son de más adelante).
	var hud_t: Hud = GameState.hud
	var st := hud_t.entrance_state()
	check(t.intro_key == "" and Narrator.remaining() <= 0.0 and not hud_t._subtitle_box.visible
		and not st.bandeja and not st.botones and not st.tarea and not st.estrellas,
		"el cerdito empieza solo: sin frase, sin bandeja, sin botones, sin tarjeta de tarea ni estrellas de logros")
	var entrance_wait := 0.0                     # (esperando a que entre, no un tiempo fijo: con carga se retrasa)
	while not hud_t.entrance_state().bandeja and entrance_wait < 5.0:
		await get_tree().process_frame
		entrance_wait += get_process_delta_time()
	st = hud_t.entrance_state()
	check(st.bandeja and not st.botones and not st.tarea and entrance_wait > Hud.ENTRANCE_TRAY * 0.8,
		"luego entra la bandeja con las piezas para vestirlo (aún sin botones; a los %.1f s)" % entrance_wait)
	while not hud_t.entrance_state().botones and entrance_wait < 8.0:
		await get_tree().process_frame
		entrance_wait += get_process_delta_time()
	await get_tree().create_timer(0.5).timeout
	st = hud_t.entrance_state()
	check(st.bandeja and st.botones and not st.tarea and not st.estrellas,
		"y por último los botones de Menú y Pista; la tarjeta de tarea y las estrellas siguen sin salir")
	check(t.model_path.get_extension() == "glb" and t.get_node_or_null("Modelo") != null,
		"el diorama del título es un asset: se carga de un .glb (%s)" % t.model_path.get_file())
	check(t.slots.size() >= 18 and t.interactables.is_empty(), "el título son muchas piezas pequeñas, sin cajones ni escondidos (%d)" % t.slots.size())
	var stickers := t.slots.filter(func(sl: PieceSlot) -> bool: return String(sl.id).begins_with("pegatina_")).size()
	check(_slot(t, &"cuerpo") != null and _slot(t, &"hocico") != null and stickers >= 6,
		"el título es la hucha de cerdito, con pegatinas para decorarla (%d pegatinas)" % stickers)
	check(_slot(t, &"pegatina_nombre") == null and t.find_child("Cartel", true, false) == null,
		"el cerdito no lleva cartel con el nombre (el nombre lo pone el logo del menú)")
	check(t.count_of(&"pata") == 4 and _slots_with(t, &"pata") == 4, "las patas repetidas son la misma pieza: cuatro que valen en cualquier hueco de pata")
	var star := _slot(t, &"pegatina_estrella")
	var star_glows := star == null or not star.lights().is_empty()
	for m in (Visuals.meshes_under(star.prototype) if star != null else []):
		var mat := m.get_active_material(0) as StandardMaterial3D
		star_glows = star_glows or (mat != null and mat.emission_enabled)
	check(not star_glows, "la estrella del cerdito es solo una pegatina: ni luz ni brillo propio")
	check(main.get_viewport().use_hdr_2d, "el fondo se pinta con HDR 2D (sin él, el pastel se queda en un gris apagado)")
	check(GameState.hud._panel.visible and GameState.hud.cards(true).size() > 0, "durante el puzle del título se ve la bandeja de piezas")
	var fxs := ["boton_preseleccion", "boton_seleccion", "pieza_preseleccion", "pieza_seleccion", "colocar",
		"colocar_tablon", "colocar_pared", "colocar_tejado", "colocar_viga", "logro", "completar_puzzle", "guardar_inventario", "aparecer_capitulo"]
	check(fxs.all(func(n: String) -> bool: return Sfx.length(n) > 0.0), "los sonidos de Drive (FXS) están: botones, fichas, colocar, los del desván y el logro")
	var heard: Dictionary = Sfx.played.duplicate()
	var free_card: InventoryItem = GameState.hud.cards(true)[0]
	free_card.mouse_entered.emit()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	free_card._gui_input(press)
	GameState.drag.cancel()
	check(_more(heard, "pieza_preseleccion") and _more(heard, "pieza_seleccion") and not _more(heard, "boton_preseleccion"),
		"con el puntero sobre una ficha suena su preselección, y al cogerla, su selección")
	_check_lighting(main, "res://iluminacion/menu.tscn", "el título")
	var steps := 0
	while not t.completed and steps < 40:
		t.debug_solve_step()
		steps += 1
		await get_tree().process_frame
	check(t.completed, "el título se completa (%d pasos)" % steps)
	check(_heard(heard, "completar_puzzle") == 1 and Sfx.jingle_playing() == "completar_puzzle",
		"al completar el puzle del cerdito suena «COMPLETAR PUZZLE» (Drive FXS), una vez y entero")
	check(int(Sfx.played.get("colocar", 0)) - int(heard.get("colocar", 0)) >= steps, "cada pieza que encaja suena al colocarla (las gemelas, después, al encajar cada una)")
	await get_tree().process_frame
	check(not (main.effects as Efectos).get_children().any(func(c: Node) -> bool: return c.name == "Luces" or c.name == "Destellos"),
		"al completar el cerdito y pasar al menú, no salen partículas por delante")
	check(GameState.menu_unlocked and _saved(TEST_PROGRESS, "menu_desbloqueado") == true, "resolver el título desbloquea el menú y se guarda")
	var talk := Narrator.remaining()
	var outro: Array = Narrator._queue.map(func(e: Dictionary) -> String: return String(e.get("voice", "")))
	if Narrator.voice_playing():
		outro.append(Narrator._player.stream.resource_path)
	check(outro.any(func(v: String) -> bool: return v.ends_with("/fin_menu.ogg")) and Narrator.text("fin_menu").begins_with("¡Ha quedado como nueva!"),
		"al acabar el puzle del cerdito suena «¡Ha quedado como nueva! Ya podemos empezar.» con su voz")
	await get_tree().create_timer(main.MENU_DELAY + 0.3).timeout
	check(talk > main.MENU_DELAY + 0.6 and not main.menu.is_open(),
		"el menú no sale mientras el cerdito habla (le quedaban %.1f s de frases)" % talk)
	var menu_wait := 0.0
	while not main.menu.is_open() and menu_wait < 12.0:
		await get_tree().create_timer(0.25).timeout
		menu_wait += 0.25
	check(main.menu._panel.get_theme_stylebox("panel") is StyleBoxEmpty and main.menu.buttons.jugar.get_theme_stylebox("normal") is StyleBoxEmpty
		and main.pause._panel.get_theme_stylebox("panel") is StyleBoxFlat and main.menu.buttons.has("logros"),
		"el menú de inicio flota (sin recuadro, opciones en texto, con Logros); la pausa conserva su recuadro")
	check(main.menu.is_open() and Narrator.remaining() <= 0.0 and not GameState.hud._subtitle_box.visible,
		"el menú sale cuando el cerdito ha acabado de hablar, y sin frases encima")
	check(main.menu.is_open() and main.menu.page == "principal", "tras la onda de color se abre el menú")
	if not main.menu.is_open():
		return false
	check(not GameState.hud._panel.visible and not GameState.hud._done.visible, "con el menú abierto, el panel de piezas se esconde")
	check(main.menu.buttons.jugar.text == "Jugar", "sin progreso, el botón dice Jugar")
	for i in 2:
		await get_tree().process_frame
	var langs: Array[Button] = main.menu.languages
	_click(langs[1].get_global_rect().get_center())
	await get_tree().process_frame
	check(Settings.language() == "en" and langs[1].is_visible_in_tree() and langs[1].button_pressed
		and main.menu.buttons.jugar.tr(main.menu.buttons.jugar.text) == "Play" and main.menu.options.languages[1].button_pressed
		and main.menu._credits_text.text.contains("Thanks for playing"),
		"en el menú se cambia de idioma con un clic: English pasa la interfaz, los créditos y Opciones al inglés")
	_click(langs[0].get_global_rect().get_center())
	await get_tree().process_frame
	check(Settings.language() == "es" and langs[0].button_pressed and not langs[1].button_pressed
		and main.menu.buttons.jugar.tr(main.menu.buttons.jugar.text) == "Jugar" and main.menu.options.languages[0].button_pressed
		and Narrator.voiced(), "y con Español vuelve todo al español, con voz")
	heard = Sfx.played.duplicate()
	main.menu.buttons.opciones.mouse_entered.emit()
	main.menu.buttons.opciones.mouse_exited.emit()
	_click(langs[1].get_global_rect().get_center())
	_click(langs[0].get_global_rect().get_center())
	check(_more(heard, "boton_preseleccion") and int(Sfx.played.get("boton_seleccion", 0)) - int(heard.get("boton_seleccion", 0)) == 2,
		"los botones del menú suenan al pasar el puntero y al pulsarlos (una vez por clic)")
	var waited := 0.0
	while GameState.camera.cam.h_offset > -0.3 and waited < 1.5:
		waited += get_process_delta_time()
		await get_tree().process_frame
	check(GameState.camera.cam.h_offset < -0.3, "la cámara corre el diorama a la derecha del menú (h_offset %.2f)" % GameState.camera.cam.h_offset)
	var play_btn: Button = main.menu.buttons.jugar
	play_btn.mouse_entered.emit()
	await get_tree().create_timer(0.3).timeout
	var hovered_scale := play_btn.scale.x
	play_btn.button_down.emit()
	await get_tree().create_timer(0.12).timeout
	var pressed_scale := play_btn.scale.x
	play_btn.mouse_exited.emit()
	play_btn.button_up.emit()
	await get_tree().create_timer(0.6).timeout
	check(hovered_scale > 1.03 and pressed_scale < 0.95 and absf(play_btn.scale.x - 1.0) < 0.06,
		"los botones reaccionan: crecen con el ratón encima, se aplastan al pulsar y vuelven (%.2f / %.2f)" % [hovered_scale, pressed_scale])
	main.menu.show_page("opciones")
	var slider := main.menu.options.controls["volumen_voz"] as HSlider
	slider.value = 0.35
	check(is_equal_approx(Settings.get_value("volumen_voz"), 0.35), "mover el deslizador de voz cambia el ajuste")
	for i in 2:                                      # la página se maqueta un fotograma después
		await get_tree().process_frame
	var swatch: Button = main.menu.options.swatches[3]
	_click(swatch.get_global_rect().get_center())
	await get_tree().process_frame
	var bg := (main.get_node("Iluminacion/Fondo/Degradado") as CanvasItem).material as ShaderMaterial
	check(int(Settings.get_value("fondo_color")) == 3 and bg.get_shader_parameter("color_centro") == Fondos.COLORES[3].centro_3d,
		"en Opciones, tocar un color cambia el fondo al momento (%s)" % Fondos.COLORES[3].nombre)
	var vignette := (main.get_node("Iluminacion/Vineta/Sombra") as CanvasItem).material as ShaderMaterial
	var vig_color: Color = vignette.get_shader_parameter("color")
	check(vig_color.is_equal_approx(Fondos.dark(3)) and vig_color.v > 0.1 and absf(vig_color.h - Fondos.COLORES[3].borde.h) < 0.03,
		"la viñeta no es negra: es el oscuro del tono del fondo, y cambia con él")
	main.menu.options.motifs[3].pressed.emit()
	check((bg.get_shader_parameter("color_forma") as Color).a == 0.0, "y el motivo «Liso» quita las figuras del fondo")
	main.menu.options.motifs[1].pressed.emit()
	check((bg.get_shader_parameter("color_forma") as Color).a > 0.0 and int(bg.get_shader_parameter("forma")) == 2,
		"y «Corazones» pone corazones")
	var opts: OptionsPanel = main.menu.options
	var tabs_y := opts.tabs[0].get_global_rect().position.y
	opts.show_tab(2)
	for i in 3:
		await get_tree().process_frame
	check(absf(opts.tabs[0].get_global_rect().position.y - tabs_y) < 1.0, "las pestañas de Opciones no se mueven al cambiar de pestaña: lo de dentro se despliega hacia abajo")
	opts.show_tab(0)
	for i in 3:
		await get_tree().process_frame
	check(opts.tabs.size() == 3 and opts.pages[0].visible and not opts.pages[1].visible and swatch.is_visible_in_tree()
		and not (opts.controls["volumen_voz"] as Control).is_visible_in_tree(),
		"las opciones van por pestañas (Fondo, Sonido, Juego): se empieza en el fondo")
	opts.tabs[1].pressed.emit()
	check(opts.pages[1].visible and (opts.controls["volumen_voz"] as Control).is_visible_in_tree() and not swatch.is_visible_in_tree(),
		"y la de Sonido enseña los volúmenes")
	opts.show_tab(0)
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	check(main.menu.page == "principal", "Esc en una página vuelve a la principal")
	check(not main.menu.buttons.has("elegir") and not main.menu._pages.has("elegir"),
		"el menú no tiene selector de nivel: el juego es un solo diorama")
	main.menu.show_page("creditos")
	check(main.menu.page == "creditos", "la página de créditos se abre")
	main.menu.show_page("principal")
	for i in 2:                                      # el menú se maqueta un fotograma después
		await get_tree().process_frame
	check(Sfx.track == "menu" and _has_music("menu") and Sfx.music_looping(),
		"en el puzle del título y el menú suena su canción en bucle (musica/menu, Ankui)")
	_click(main.menu.buttons.jugar.get_global_rect().get_center())
	await get_tree().create_timer(main.BLACKOUT_TIME * 0.6).timeout
	check(Sfx.track == "juego" and _has_music("juego") and Sfx.music_looping(),
		"al darle a Jugar cambia a la canción de la partida (musica/juego, Loft), en bucle")
	check(main.blacking_out and main.menu.is_open() and main._fade.color.a > 0.2 and main._fade.mouse_filter == Control.MOUSE_FILTER_STOP,
		"al darle a Jugar, la pantalla se va a negro (y mientras no se puede tocar nada)")
	await get_tree().create_timer(main.BLACKOUT_TIME * 0.4 + main.BLACKOUT_HOLD + 0.1).timeout
	check(not main.menu.is_open() and GameState.mode == GameState.Mode.PLAYING and main._fade.color.a > 0.6 and not main.blacking_out,
		"clic en Jugar cierra el menú y empieza la partida, que aparece desde el negro")
	check(GameState.hud._panel.visible and is_zero_approx(GameState.camera.cam.h_offset), "en partida vuelven el panel de piezas y la cámara centrada")
	return true


func _test_pause(main: Node, d: Diorama) -> void:
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	check(main.pause.is_open() and get_tree().paused, "Esc en partida abre la pausa y para el juego")
	check(main.pause.buttons.menu.visible, "en partida la pausa ofrece volver al menú principal")
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	check(not main.pause.is_open() and not get_tree().paused, "Esc otra vez reanuda")
	var zone: Interactable = null
	for it in d.interactables:
		if it.kind == NameRules.ZOOM:
			zone = it
	if zone != null:
		d.enter_focus(zone)
		_key(KEY_ESCAPE)
		await get_tree().process_frame
		check(d.focus == null and not main.pause.is_open(), "dentro de un rincón, Esc sale del rincón (no pausa)")


func _test_back_to_menu(main: Node) -> void:
	check(GameState.is_completed(0) and SAMPLE_LEVEL in _saved(TEST_PROGRESS, "completados", []), "completar el nivel queda guardado en el progreso")
	await get_tree().create_timer(1.9).timeout
	var done: Button = GameState.hud._done_button
	check(GameState.hud._done.visible and done.text == "Volver al menú", "tras el último nivel, el panel ofrece volver al menú")
	await get_tree().process_frame
	_click(done.get_global_rect().get_center())
	await get_tree().process_frame
	var credits: Creditos = main.credits
	check(credits._bg_mat.get_shader_parameter("color_centro") == Fondos.color(Settings.get_value("fondo_color")).centro,
		"los créditos llevan el mismo fondo que eligió el jugador")
	Settings.set_value("fondo_color", 0)
	Settings.set_value("fondo_motivo", 0)
	check(credits.rolling and credits.visible and is_instance_valid(credits.logo) and credits._roll.get_child(0) == credits.logo
		and credits.lines()[credits.lines().size() - 1] == "¡Gracias por jugar!" and not main.menu.is_open(),
		"al acabar el juego pasan los créditos (del logo a «¡Gracias por jugar!»)")
	await get_tree().create_timer(1.2).timeout
	var y0 := credits._roll.position.y
	await get_tree().create_timer(0.5).timeout
	check(credits._roll.position.y < y0 - 5.0, "los créditos suben despacio (%.0f px en medio segundo)" % (y0 - credits._roll.position.y))
	var screen_h := credits._root.size.y
	check(credits.title_y() > 0.0 and credits.title_y() < screen_h * 0.8 and credits.roll_seconds() < 45.0,
		"los créditos empiezan con el nombre del juego ya a la vista y no siguen subiendo en blanco (a %.0f px, %.0f s en total)"
		% [credits.title_y(), credits.roll_seconds()])
	var who := Array(credits.lines())
	check(["Eva Fernandez Valero", "Carmen Esteban Fernandez-Vicenti", "Inés Jackson Martín", "Sandra", "Ana Climent Sapena",
			"Anaïs Soriano Gimeno"].all(func(n: String) -> bool: return who.has(n))
		and who.any(func(l: String) -> bool: return l.contains("ayuda de la IA"))
		and who.has("Licencia del juego: CC BY-SA 3.0") and who.any(func(l: String) -> bool: return l.contains("(licencia MIT)"))
		and not who.any(func(l: String) -> bool: return l.contains("(nombres") or l.contains("Claude")),
		"en los créditos, las seis del equipo, que la programación se hizo con ayuda de la IA, la licencia de la jam (CC BY-SA 3.0) y los recursos de terceros (sin huecos por rellenar)")
	_click(Vector2(640, 360))                      # un clic los acaba
	await get_tree().create_timer(Creditos.FADE + 0.4).timeout
	var t := GameState.diorama
	check(not credits.visible and t != null and t.scene_file_path == GameState.MENU_LEVEL and t.completed,
		"después de los créditos, el menú: el título sale ya montado")
	check(main.menu.is_open() and main.menu.page == "principal" and Narrator.remaining() <= 0.0,
		"y el menú se abre en su página principal, sin frases")
	check(main.menu.buttons.jugar.text == "Continuar", "con progreso, el botón dice Continuar")
	main.menu.show_page("opciones")
	var reset: Button = main.menu.options.reset_button
	reset.pressed.emit()
	check(GameState.has_progress(), "la primera pulsación de Borrar progreso solo pregunta")
	reset.pressed.emit()
	check(not GameState.has_progress() and not GameState.menu_unlocked and _saved(TEST_PROGRESS, "menu_desbloqueado") == false, "la segunda pulsación borra el progreso (también en disco)")


## Los niveles de verdad (data/levels.json): cargan, cada pieza tiene su modelo, y se completan.
## F8 (atajo de prueba) acaba el capítulo en curso; F9 monta el desván entero de golpe y se queda a la
## vista, sin fundido.
func _test_complete_shortcut(main: Node) -> void:
	GameState.levels = PackedStringArray(["res://levels/level_01_desvan.tscn"])
	main.play_level(0)
	await get_tree().process_frame
	var d := GameState.diorama
	# F8: el capítulo en curso, de uno en uno (para probar cada capítulo suelto).
	var f8 := func() -> void:
		var k8 := InputEventKey.new()
		k8.physical_keycode = KEY_F8
		k8.pressed = true
		get_viewport().push_input(k8, true)
	var first := d.sections[0]
	var tries := 0
	while not first.completed and tries < 3:
		f8.call()
		await get_tree().process_frame
		tries += 1
	check(first.completed and first.is_full() and not d.sections[1].opened and d.act_waiting() and not d.completed,
		"F8 acaba solo el capítulo en curso (el primero): sus piezas puestas y el siguiente espera al «Continuar»")
	f8.call()
	await get_tree().process_frame
	var kid := d.sections[1]
	check(kid.opened or kid.opening, "con el capítulo acabado, F8 abre el siguiente sin esperar")
	await get_tree().create_timer(0.3).timeout
	f8.call()
	await get_tree().process_frame
	var kid_things := kid.interactables.filter(func(it: Interactable) -> bool:
		return it.kind == NameRules.PICKUP or it.kind == NameRules.COLLECTIBLE)
	check(kid.completed and kid.is_full() and not d.sections[2].opened and d.act_waiting()
		and kid_things.all(func(it: Interactable) -> bool: return it.collected)
		and d.collectibles_found() == kid_things.filter(func(it: Interactable) -> bool: return it.kind == NameRules.COLLECTIBLE).size(),
		"y otra vez F8 acaba ese (%s) entero, con lo que guardaba y sus dibujos en la cuerda (%d); el resto, sin abrir" % [kid.name, d.collectibles_found()])
	var ended := [false]
	var on_end := func(_d: Node) -> void: ended[0] = true
	Events.level_completed.connect(on_end)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F9
	key.pressed = true
	get_viewport().push_input(key, true)
	await get_tree().process_frame
	var all_open := d.sections.all(func(s: Section) -> bool: return s.opened)
	var all_placed := d.slots.all(func(s: PieceSlot) -> bool: return s.filled)
	check(d.completed and ended[0] and all_open and all_placed and d.visible_inventory().is_empty(),
		"F9 monta el desván entero de golpe: todas las zonas abiertas y cada pieza en su sitio")
	var on_line := 0
	for k in d.collectible_total():
		for it in d.interactables:
			if it.kind == NameRules.COLLECTIBLE and it.target.visible and it.target.global_position.distance_to(d.spot(k).global_position) < 0.01:
				on_line += 1
	check(d.collectibles_found() == 4 and on_line == 4, "y con F9 los 4 dibujos están colgados en la cuerda (%d)" % on_line)
	await get_tree().create_timer(4.0).timeout
	check(GameState.diorama == d and GameState.hud._done.visible and main._fade.color.a < 0.1,
		"tras F9 el desván se queda a la vista (panel de fin, sin fundido a negro)")
	Events.level_completed.disconnect(on_end)


func _test_real_levels(main: Node) -> void:
	var listed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GameState.LEVELS_PATH))
	check(listed is Array and not (listed as Array).is_empty(), "data/levels.json lista niveles")
	if not (listed is Array):
		return
	check(not (listed as Array).has(main.PROTOTIPO) and ResourceLoader.exists(main.PROTOTIPO),
		"el desván prototipo se conserva aparte (%s), fuera de la partida" % main.PROTOTIPO.get_file())
	GameState.levels = PackedStringArray((listed as Array) + [main.PROTOTIPO])   # (y se sigue pudiendo jugar entero)
	for i in GameState.levels.size():
		var path := GameState.levels[i]
		main.play_level(i)
		await get_tree().process_frame
		GameState.camera.snap()                  # sin la entrada de cine: las medidas, con el encuadre del nivel
		var d := GameState.diorama
		check(d != null and d.scene_file_path == path, "%s carga" % path.get_file())
		if d == null or d.scene_file_path != path:
			continue
		var empty: Array[String] = []
		for sl in d.slots:
			if sl.meshes().is_empty():
				empty.append(String(sl.id))
		check(d.slots.size() >= 5 and empty.is_empty(), "%s: todos los huecos con su modelo (%d huecos; sin modelo: %s)" % [path.get_file(), d.slots.size(), empty])
		check(d.slots[0].is_ghost() and (d.slots[0]._ghost as ShaderMaterial).render_priority > Visuals.make_clay_overlay().render_priority,
			"%s: las siluetas se pintan después de la arcilla (si no, una pared grande las borra)" % path.get_file())
		await get_tree().process_frame
		# La pieza más grande y la más pequeña del panel: las pequeñas son las que se colarían.
		var cards: Array = GameState.hud.cards(true)
		cards.sort_custom(func(a: InventoryItem, b: InventoryItem) -> bool:
			return Visuals.local_aabb(d.prototype_for(a.piece_id)).size.length() > Visuals.local_aabb(d.prototype_for(b.piece_id)).size.length())
		for card: InventoryItem in ([cards.front(), cards.back()] if not cards.is_empty() else []):
			GameState.drag.begin(card.piece_id, card)
			_check_sweep(path.get_file())
			GameState.drag.cancel()
		var steps := 0
		while not d.completed and steps < 400:
			d.debug_solve_step()
			steps += 1
			await get_tree().process_frame
		var all_filled := true
		for sl in d.slots:
			all_filled = all_filled and sl.filled
		check(d.completed and all_filled and d.inventory.is_empty(), "%s se completa entero (%d pasos)" % [path.get_file(), steps])
		await get_tree().process_frame
		check(GameState.hud.cards().is_empty() and not GameState.hud.says_nothing_left(),
			"%s completo: el panel no dice que busques más piezas" % path.get_file())


## La luz activa es la esperada, es la que usa el mundo, y no se ha quedado otra a la vez.
func _check_lighting(main: Node, expected: String, who: String) -> void:
	var light := main.get_node_or_null("Iluminacion")
	check(light != null and light.scene_file_path == expected, "%s usa la luz %s" % [who, expected.get_file()])
	var we: WorldEnvironment = null
	for c in (light.get_children() if light != null else []):
		if c is WorldEnvironment:
			we = c
	check(we != null and get_viewport().find_world_3d().environment == we.environment, "%s: el mundo usa el ambiente de esa escena" % who)
	var envs := _count_in_main_world("WorldEnvironment")
	var stray := 0
	for sun in _in_main_world("DirectionalLight3D"):
		stray += 0 if light != null and light.is_ancestor_of(sun) else 1
	check(envs == 1 and stray == 0, "%s: un solo ambiente y ningún sol de otra escena de luz (%d y %d)" % [who, envs, stray])


## Solo los del mundo principal: las fichas del panel tienen su propio mundo con su propia luz.
func _count_in_main_world(type: String) -> int:
	return _in_main_world(type).size()


func _in_main_world(type: String) -> Array[Node]:
	var out: Array[Node] = []
	for x in get_tree().root.find_children("*", type, true, false):
		if x.is_inside_tree() and not x.is_queued_for_deletion() and x.get_viewport() == get_tree().root:
			out.append(x)
	return out


## Con una pieza en mano, recorre el diorama en rejilla: en ningún punto puede atravesar paredes,
## suelo ni muebles, y en buena parte tiene que quedar apoyada en algo (si no, el control no mide).
func _check_sweep(who: String) -> void:
	var checked := 0
	var inside := 0
	var rested := 0
	var piece := String(GameState.drag.piece_id)
	var view := get_viewport().get_visible_rect().size     # sin pantalla mide 1280x1280: la rejilla, a su medida
	for i in 8:
		for j in 6:
			_mouse_move(Vector2(view.x * (0.11 + i * 0.086), view.y * (0.15 + j * 0.14)))
			var n := GameState.drag.held_overlaps()
			if n < 0:
				continue
			checked += 1
			inside += 1 if n > 0 else 0
			rested += 1 if GameState.drag.last_rested else 0
	check(checked >= 20 and inside == 0, "%s: la pieza en mano (%s) no atraviesa nada en %d puntos (dentro: %d)" % [who, piece, checked, inside])
	# Control (que el instrumento mida algo): al menos 1 de cada 8 puntos tiene que apoyarse. No más:
	# un diorama que empieza casi vacío (el desván: solo suelo) tiene media pantalla de aire.
	check(rested * 8 >= checked, "%s: la pieza en mano se apoya en las superficies (%d de %d puntos)" % [who, rested, checked])


func _test_camera(d: Diorama) -> void:
	var c := GameState.camera
	c.configure(d)
	var home := c.home_center()
	_drag_mouse(MOUSE_BUTTON_MIDDLE, Vector2(500, 350), Vector2(800, 500))
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(500, 350), Vector2(800, 500), true)
	check(c.center.is_equal_approx(home), "la cámara no se desplaza (ni botón central ni Mayús+arrastrar)")
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(300, 350), Vector2(950, 350))
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(300, 350), Vector2(950, 350))
	check(is_equal_approx(c.yaw, c.yaw_min), "el giro se para en su límite (%.0f, mínimo %.0f)" % [c.yaw, c.yaw_min])
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(950, 350), Vector2(300, 350))
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(950, 350), Vector2(300, 350))
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(950, 350), Vector2(300, 350))
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(950, 350), Vector2(300, 350))
	check(is_equal_approx(c.yaw, c.yaw_max), "y por el otro lado también (%.0f, máximo %.0f)" % [c.yaw, c.yaw_max])
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(500, 100), Vector2(500, 650))
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(500, 100), Vector2(500, 650))
	check(c.pitch >= c.pitch_min and c.pitch <= c.pitch_max, "la inclinación se queda en sus límites (%.0f)" % c.pitch)
	c.configure(d)
	c.snap()
	var aim := Vector2(420, 300)
	var mid := get_viewport().get_visible_rect().size * 0.5
	var aimed := c._point_under(aim)
	for i in 6:
		_wheel(MOUSE_BUTTON_WHEEL_UP, aim)
	c.snap()
	await get_tree().process_frame
	var aimed_px := c.cam.unproject_position(aimed)
	check(aimed_px.distance_to(mid) < aim.distance_to(mid) * 0.75,
		"al hacer zoom, la zona señalada se va hacia el centro de la pantalla (%.0f px del centro, antes %.0f)" % [aimed_px.distance_to(mid), aim.distance_to(mid)])
	await get_tree().create_timer(0.6).timeout
	check((GameState.enfoque.state().centro as Vector2).distance_to(mid) < 20.0,
		"y el enfoque está en el centro de la pantalla: lo acercado, nítido; los bordes, desenfocados")
	c.configure(d)
	for i in 30:
		_wheel(MOUSE_BUTTON_WHEEL_UP, Vector2(420, 300))
	check(is_equal_approx(c.distance, c.min_distance), "el zoom tiene tope (%.2f)" % c.distance)
	check(not c.center.is_equal_approx(home), "el zoom se acerca hacia lo que señala el cursor")
	for i in 30:
		_wheel(MOUSE_BUTTON_WHEEL_DOWN, Vector2(420, 300))
	check(is_equal_approx(c.distance, c.max_distance) and c.center.is_equal_approx(home), "al alejar el zoom, la cámara vuelve a su sitio")
	c.configure(d)
	_drag_mouse(MOUSE_BUTTON_LEFT, Vector2(600, 350), Vector2(660, 350))
	var released := c.yaw
	check(c.is_spinning(), "al soltar el giro en pleno movimiento, la cámara sigue girando (inercia)")
	for i in 10:
		await get_tree().process_frame
	check(c.yaw < released and c.yaw >= c.yaw_min, "la inercia sigue en el mismo sentido y respeta los límites (%.1f -> %.1f)" % [released, c.yaw])
	c.configure(d)
	check(not c.is_spinning(), "(control) al recolocar la cámara se acaba la inercia")


## Pista: la cámara gira hacia el hueco y se ACERCA (como en Woodo), y salen chispas allí.
func _test_hint(d: Diorama) -> void:
	var c := GameState.camera
	c.configure(d)
	var home := c.home_center()
	var home_distance := c.distance
	var h := d.hint_target(GameState.hovered_piece)
	var before: int = (get_tree().root.find_child("Efectos", true, false) as Efectos).bursts
	GameState.hud.request_hint()
	var target := Visuals.global_aabb(h.node).get_center() if not h.is_empty() else home
	check(not h.is_empty() and c.distance < home_distance - 0.1 and c.center.distance_to(target) < home.distance_to(target) - 0.05,
		"la pista gira y acerca la cámara hacia el hueco (distancia %.2f -> %.2f)" % [home_distance, c.distance])
	check((get_tree().root.find_child("Efectos", true, false) as Efectos).bursts > before, "la pista enseña chispas en el sitio")
	var first_ready: Array[InventoryItem] = GameState.hud.cards(true)
	check(h.has("slot") and not first_ready.is_empty() and GameState.hud._hinted == h.slot and not GameState.hud.hint_mark.visible
		and (GameState.hovered_piece != &"" or h.piece == first_ready[0].piece_id),
		"la pista señala la siguiente pieza de la bandeja (su hueco late), sin flecha si no lleva rato atascada (%s)" % String(h.get("piece", "")))
	GameState.hud._clear_hint()
	var was_mode := GameState.mode
	GameState.mode = GameState.Mode.PLAYING
	GameState.hud._idle = GameState.hud.assist_after + 1.0   # mucho rato sin poner nada
	await get_tree().process_frame
	check(GameState.hud.hint_mark.visible and GameState.hud.hint_mark.target == h.node,
		"si lleva mucho rato sin poner una pieza, sale sola una flecha encima del sitio de la siguiente")
	for i in 3:
		await get_tree().process_frame
	var tip: Vector2 = GameState.hud.hint_mark.tip()
	var screen_at: Vector2 = c.cam.unproject_position(Visuals.global_aabb(h.node).get_center())
	check(get_viewport().get_visible_rect().has_point(tip) and tip.distance_to(screen_at) < 260.0,
		"la flecha de la pista está en pantalla, encima del hueco (%.0f px)" % tip.distance_to(screen_at))
	check(GameState.hud.hint_cooldown <= 10.0, "la pista se recarga pronto (%.0f s)" % GameState.hud.hint_cooldown)
	await get_tree().process_frame
	GameState.hud._idle = 0.0
	GameState.hud._clear_hint()
	GameState.mode = was_mode
	check(not GameState.hud.hint_mark.visible, "al quitar la pista, la flecha se va")
	c.configure(d)


## Pulsar, arrastrar en 10 pasos (con su desplazamiento relativo) y soltar.
func _drag_mouse(button: MouseButton, from: Vector2, to: Vector2, shift := false) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = button
	press.pressed = true
	press.shift_pressed = shift
	press.position = from
	press.global_position = from
	get_viewport().push_input(press, true)
	var last := from
	for i in range(1, 11):
		var p := from.lerp(to, i / 10.0)
		var m := InputEventMouseMotion.new()
		m.position = p
		m.global_position = p
		m.relative = p - last
		m.shift_pressed = shift
		get_viewport().push_input(m, true)
		last = p
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.position = to
	release.global_position = to
	get_viewport().push_input(release, true)


func _wheel(button: MouseButton, pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		get_viewport().push_input(e, true)


## Si la malla es la de esa pieza del kit de las artistas: de su .fbx o de su escena del tileset.
func _kit_mesh(m: MeshInstance3D, piece: String) -> bool:
	var path := m.mesh.resource_path
	return path.get_file().begins_with(piece + ".fbx") or path.begins_with("res://assets/kit/piezas/%s.scn" % piece)


## Si el efecto ha sonado desde `before` (una copia de Sfx.played).
func _more(before: Dictionary, sound: String) -> bool:
	return _heard(before, sound) > 0


## Cuántas veces ha sonado el efecto desde `before`.
func _heard(before: Dictionary, sound: String) -> int:
	return int(Sfx.played.get(sound, 0)) - int(before.get(sound, 0))


## Lee una clave del progreso guardado en disco (lo que vería la próxima partida).
func _saved(path: String, key: String, default: Variant = null) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return default
	return cfg.get_value(GameState.SECTION, key, default)


func _test_name_rules() -> void:
	var a := NameRules.parse("P_silla__after-mesa_001")
	check(a.get("kind") == NameRules.PIECE and a.get("id") == &"silla", "NameRules: P_silla__after-mesa_001 -> pieza 'silla'")
	check(NameRules.values(a.get("tokens", PackedStringArray()), "after") == [&"mesa"], "NameRules: token after-mesa")
	check(NameRules.parse("Cube").is_empty(), "NameRules: un nombre sin prefijo se ignora")
	check(NameRules.strip_copy_suffix("P_taza.003") == "P_taza", "NameRules: quita el .003 de Blender")


## Los eventos se entregan en coordenadas LOCALES del viewport: sin ventana (--headless) el
## tamaño de ventana es 0x0 y Godot escalaría las posiciones x0,05.
func _click(pos: Vector2) -> void:
	_mouse_button(pos, true)
	_mouse_button(pos, false)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = pressed
		get_viewport().push_input(e, true)


func _mouse_button(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	get_viewport().push_input(e, true)


func _mouse_move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(e, true)


func _slots_with(d: Diorama, id: StringName) -> int:
	return d.slots.filter(func(sl: PieceSlot) -> bool: return sl.id == id).size()


func _slot(d: Diorama, id: StringName) -> PieceSlot:
	for s in d.slots:
		if s.id == id:
			return s
	return null


func _interactable(d: Diorama, kind: String) -> Interactable:
	for it in d.interactables:
		if it.kind == kind:
			return it
	return null


func _end() -> void:
	if _fails == 0:
		print("SMOKE OK")
	else:
		print("SMOKE FALLO %d" % _fails)
	Sfx.quit(0 if _fails == 0 else 1)
