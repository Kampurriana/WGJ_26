extends Node
## Efectos y música. Se buscan por nombre en assets/audio/sfx|musica/<nombre>.(ogg|wav|mp3).
## Nombres que usa el código: colocar, reject, open, close, pickup, hint, complete, zoom_in, zoom_out...
## Los de Anaïs (Drive FXS, 18-oct): boton_preseleccion (el puntero entra en algo pulsable) y
## boton_seleccion (se pulsa), los dos para todo botón (ui/juice.gd); pieza_preseleccion (el puntero
## entra en una ficha de la bandeja que se puede poner) y pieza_seleccion (se coge para colocarla);
## colocar (la pieza encaja en el diorama). Y los del desván (Drive FXS, 18-oct), uno por tipo de pieza:
## colocar_tablon («Colocar madera del suelo desvan»), colocar_pared («Colocar madera pared del desvan»),
## colocar_tejado («Colocar techo del desvan»), colocar_pilar («Colocar VIGA TECHO del desvan») y, del 20-oct,
## colocar_viga («OBJETO LA VIGA»), colocar_poste, colocar_correa y colocar_cumbrera («Colocar VIGAS
## HORIZONTALES»). Una pieza suena con colocar_<su id> o el de su primera parte (tablon_largo → colocar_tablon) si
## está, y si no con colocar: para darle sonido propio a otra pieza basta con dejar su fichero aquí.
## abrir_caja/cerrar_caja («ABRIR/CERRAR CAJA CARTON»): las tapas de las cajas (Interactable). moneda_aparece y
## moneda_hucha: la moneda del final (Momentos). presentacion («MORTADELA LOGO INICIO»): la presentación.
## melodia_<pieza> (melody(): la caja de música, recortada con fundido): al ponerla y, ya puesta, al pulsarla.
## logro (Drive FXS, 18-oct; 4,9 s): la sintonía de un logro y de un dibujo encontrado, con jingle().
## aparecer_capitulo («Cuando aparecen las cosas del capitulo», 2,3 s): al abrirse un capítulo, cuando
## sus muebles y siluetas empiezan a crecer (Diorama._reveal_pending, tras el rótulo).
## Música (petición del equipo): musica/menu (Ankui) en el puzle del título y el menú; musica/juego
## (Loft) en bucle durante la partida, a volumen moderado. Siempre en bucle y con fundido cruzado.
## Suenan por los buses Efectos y Musica (los crea Settings), así les afectan las Opciones.
## Si falta un fichero se avisa UNA vez por nombre (un sonido mudo tiene que decirlo).

const EXTENSIONS := ["ogg", "wav", "mp3"]
const POOL_SIZE := 8
const MUSIC_FADE := 1.6                      ## segundos del fundido cruzado entre canciones
const QUIT_WAIT := 0.5                       ## al salir, lo que se espera a que el audio suelte la música y la voz (s; con 0,2 a veces no le daba tiempo)
const DUCK_DB := -6.0                        ## la música baja esto mientras suena una voz (guion v2)...
const DUCK_IN := 0.3
const DUCK_OUT := 1.0                        ## ...y vuelve en esto (s)
const MELODY_DUCK_DB := -14.0                ## mientras suena una melodía (la caja de música), la música casi se calla
const MELODY_FADE := 1.8                     ## una melodía que se corta antes de su final se apaga con este fundido (s)

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _cache: Dictionary = {}
var _warned: Dictionary = {}
var _jingle: AudioStreamPlayer               ## las sintonías (logro): aparte, para que los clics no las corten
var _jingle_name := ""
var _melody: AudioStreamPlayer               ## las melodías (la caja de música): aparte, se apagan con fundido
var _melody_name := ""
var _music: AudioStreamPlayer                ## la canción que suena (la otra se está yendo)
var _music_old: AudioStreamPlayer
var track := ""                               ## la canción pedida ("menu", "juego"; "" = ninguna)
var _quitting := false
var ducked := false
var played: Dictionary = {}                  ## (tests) nombre -> veces que ha sonado


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # la música y los clics del menú siguen en pausa
	get_tree().auto_accept_quit = false          # la X de la ventana pasa por quit()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"Efectos"
		add_child(p)
		_pool.append(p)
	_jingle = AudioStreamPlayer.new()
	_jingle.bus = &"Efectos"
	add_child(_jingle)
	_melody = AudioStreamPlayer.new()
	_melody.bus = &"Efectos"
	_melody.finished.connect(_update_duck)
	add_child(_melody)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = &"Musica"
		m.finished.connect(func() -> void:     # por si el formato no sabe hacer bucle (wav sin marcas)
			if m == _music:
				m.play())
		add_child(m)
		_music_old = _music
		_music = m


## Salir del juego: antes se para el sonido y se le da un momento al servidor de audio para soltarlo
## (si se cierra con la música sonando, su reproducción sigue viva y Godot avisa de una fuga). Lo usan
## los botones de Salir, la X de la ventana, las capturas y el test.
func quit(code := 0) -> void:
	if _quitting:
		return
	_quitting = true
	for p: AudioStreamPlayer in [_music, _music_old, _jingle, _melody] + _pool:
		p.stop()
		p.stream = null
	Narrator.clear()                         # una voz sonando al salir también se queda colgada
	_cache.clear()
	await get_tree().create_timer(QUIT_WAIT, true, false, true).timeout
	get_tree().quit(code)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit()


func play(sound: String, pitch_jitter := 0.08) -> void:
	var stream := _find("sfx", sound)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()
	played[sound] = int(played.get(sound, 0)) + 1


## Una sintonía (un efecto con melodía, como logro): sin cambiarle el tono (desafinaría) y en su
## propio reproductor (los efectos cortos no la cortan). Si ya está sonando no vuelve a empezar: el
## último dibujo se encuentra y gana su logro a la vez, y suena una sola.
func jingle(sound: String) -> void:
	var stream := _find("sfx", sound)
	if stream == null or (_jingle.playing and _jingle.stream == stream):
		return
	_jingle.stream = stream
	_jingle.play()
	_jingle_name = sound
	played[sound] = int(played.get(sound, 0)) + 1


## (Tests) La sintonía que está sonando ("" si ninguna).
func jingle_playing() -> String:
	return _jingle_name if _jingle.playing else ""


## Una melodía larga (la caja de música): en su propio reproductor (los clics no la cortan), sin cambio
## de tono y con la música de la partida casi callada mientras suena. seconds > 0 = se apaga con un
## fundido para durar eso (si el fichero dura más). Si ya sonaba, vuelve a empezar.
func melody(sound: String, seconds := 0.0) -> void:
	var stream := _find("sfx", sound)
	if stream == null:
		return
	_kill_fade(_melody)
	_melody.stream = stream
	_melody.volume_db = 0.0
	_melody.play()
	_melody_name = sound
	played[sound] = int(played.get(sound, 0)) + 1
	if seconds > 0.0 and seconds < stream.get_length():
		var tw := create_tween()
		_melody.set_meta(&"fade", tw)
		tw.tween_interval(maxf(seconds - MELODY_FADE, 0.0))
		tw.tween_property(_melody, "volume_linear", 0.0, MELODY_FADE).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func() -> void:
			_melody.stop()
			_update_duck())
	_update_duck()


## Se apaga la melodía (con un fundido de `fade` s; 0 = ya).
func stop_melody(fade := 0.4) -> void:
	if not _melody.playing:
		return
	if fade > 0.0:
		_fade(_melody, 0.0, fade)
		get_tree().create_timer(fade + 0.05, true, false, true).timeout.connect(_update_duck)
		return
	_kill_fade(_melody)
	_melody.stop()
	_update_duck()


## (Tests) La melodía que está sonando ("" si ninguna).
func melody_playing() -> String:
	return _melody_name if _melody.playing else ""


## Pone una canción en bucle a `volume_db`, con fundido cruzado desde la que sonaba. Si ya suena,
## solo ajusta el volumen. Si no hay fichero, la anterior se va igual (no se queda la del menú).
func music(song: String, volume_db := -8.0, fade := MUSIC_FADE) -> void:
	track = song
	var stream := _find("musica", song)
	if stream != null and _music.stream == stream and _music.playing:
		_fade(_music, db_to_linear(volume_db), fade)
		return
	var out := _music
	_music = _music_old
	_music_old = out
	_fade(out, 0.0, fade)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	_music.stream = stream
	_music.volume_linear = 0.0
	_music.play()
	_fade(_music, db_to_linear(volume_db), fade)


## (Tests) Si la canción pedida está sonando en bucle.
func music_looping() -> bool:
	var s := _music.stream
	if s == null or not _music.playing:
		return false
	if s is AudioStreamOggVorbis:
		return (s as AudioStreamOggVorbis).loop
	if s is AudioStreamMP3:
		return (s as AudioStreamMP3).loop
	return true                                  # wav: vuelve a empezar al acabar (finished)


func _fade(p: AudioStreamPlayer, to: float, seconds: float) -> void:
	_kill_fade(p)
	var tw := create_tween()
	p.set_meta(&"fade", tw)
	tw.tween_property(p, "volume_linear", to, maxf(seconds, 0.01)).set_trans(Tween.TRANS_SINE)
	if to <= 0.0:
		tw.tween_callback(p.stop)


func _kill_fade(p: AudioStreamPlayer) -> void:
	if p.has_meta(&"fade"):
		var old: Variant = p.get_meta(&"fade")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()


## Si hay fichero para ese efecto (sin avisar si no: para elegir entre varios).
func has(sound: String) -> bool:
	var key := "sfx/" + sound
	if _cache.has(key):
		return _cache[key] != null
	return EXTENSIONS.any(func(ext: String) -> bool: return ResourceLoader.exists("res://assets/audio/sfx/%s.%s" % [sound, ext]))


## Lo que dura un efecto (0 si no hay fichero).
func length(sound: String) -> float:
	var stream := _find("sfx", sound)
	return stream.get_length() if stream != null else 0.0


## La música baja mientras habla una voz y vuelve despacio al callarse (lo llama el Narrador).
func duck(on: bool) -> void:
	ducked = on
	_update_duck()


## La música, a lo que piden la voz y la melodía (lo más bajo de las dos); baja en DUCK_IN y sube en DUCK_OUT.
func _update_duck() -> void:
	var goal := minf(DUCK_DB if ducked else 0.0, MELODY_DUCK_DB if _melody.playing else 0.0)
	if has_meta(&"duck"):
		var old: Variant = get_meta(&"duck")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var tw := create_tween()
	set_meta(&"duck", tw)
	tw.tween_method(Settings.set_music_duck, Settings.music_duck_db, goal,
		DUCK_IN if goal < Settings.music_duck_db else DUCK_OUT).set_trans(Tween.TRANS_SINE)   # (en el volumen del bus: en la Web no hay efectos)


func _find(folder: String, sound: String) -> AudioStream:
	var key := folder + "/" + sound
	if _cache.has(key):
		return _cache[key]
	for ext: String in EXTENSIONS:
		var path := "res://assets/audio/%s/%s.%s" % [folder, sound, ext]
		if ResourceLoader.exists(path):
			_cache[key] = load(path)
			return _cache[key]
	if not _warned.has(key):
		_warned[key] = true
		push_warning("Sfx: no hay audio para '%s' (assets/audio/%s/%s.ogg)" % [sound, folder, sound])
	_cache[key] = null
	return null
