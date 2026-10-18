extends Node
## Efectos y música. Se buscan por nombre en assets/audio/sfx|musica/<nombre>.(ogg|wav|mp3).
## Nombres que usa el código: snap, reject, open, close, pickup, hint, complete, zoom_in, zoom_out, click.
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

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _cache: Dictionary = {}
var _warned: Dictionary = {}
var _music: AudioStreamPlayer                ## la canción que suena (la otra se está yendo)
var _music_old: AudioStreamPlayer
var track := ""                               ## la canción pedida ("menu", "juego"; "" = ninguna)
var _quitting := false
var _duck: AudioEffectAmplify                ## en el bus Musica: lo que baja con las voces
var ducked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # la música y los clics del menú siguen en pausa
	get_tree().auto_accept_quit = false          # la X de la ventana pasa por quit()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"Efectos"
		add_child(p)
		_pool.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = &"Musica"
		m.finished.connect(func() -> void:     # por si el formato no sabe hacer bucle (wav sin marcas)
			if m == _music:
				m.play())
		add_child(m)
		_music_old = _music
		_music = m
	var bus := AudioServer.get_bus_index(&"Musica")   # (Settings crea los buses antes: va antes en autoload)
	if bus >= 0:
		_duck = AudioEffectAmplify.new()
		AudioServer.add_bus_effect(bus, _duck)


## Salir del juego: antes se para el sonido y se le da un momento al servidor de audio para soltarlo
## (si se cierra con la música sonando, su reproducción sigue viva y Godot avisa de una fuga). Lo usan
## los botones de Salir, la X de la ventana, las capturas y el test.
func quit(code := 0) -> void:
	if _quitting:
		return
	_quitting = true
	for p: AudioStreamPlayer in [_music, _music_old] + _pool:
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
	if p.has_meta(&"fade"):
		var old: Variant = p.get_meta(&"fade")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var tw := create_tween()
	p.set_meta(&"fade", tw)
	tw.tween_property(p, "volume_linear", to, maxf(seconds, 0.01)).set_trans(Tween.TRANS_SINE)
	if to <= 0.0:
		tw.tween_callback(p.stop)


## Lo que dura un efecto (0 si no hay fichero).
func length(sound: String) -> float:
	var stream := _find("sfx", sound)
	return stream.get_length() if stream != null else 0.0


## La música baja mientras habla una voz y vuelve despacio al callarse (lo llama el Narrador).
func duck(on: bool) -> void:
	ducked = on
	if _duck == null:
		return
	if has_meta(&"duck"):
		var old: Variant = get_meta(&"duck")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var tw := create_tween()
	set_meta(&"duck", tw)
	tw.tween_property(_duck, "volume_db", DUCK_DB if on else 0.0, DUCK_IN if on else DUCK_OUT).set_trans(Tween.TRANS_SINE)


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
