extends Node
## Efectos y música. Se buscan por nombre en assets/audio/sfx|musica/<nombre>.(ogg|wav|mp3).
## Nombres que usa el código: snap, reject, open, close, pickup, hint, complete, zoom_in, zoom_out, click.
## Suenan por los buses Efectos y Musica (los crea Settings), así les afectan las Opciones.
## Si falta un fichero se avisa UNA vez por nombre (un sonido mudo tiene que decirlo).

const EXTENSIONS := ["ogg", "wav", "mp3"]
const POOL_SIZE := 8

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _cache: Dictionary = {}
var _warned: Dictionary = {}
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # la música y los clics del menú siguen en pausa
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"Efectos"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -8.0
	_music.bus = &"Musica"
	add_child(_music)


func play(sound: String, pitch_jitter := 0.08) -> void:
	var stream := _find("sfx", sound)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func music(track: String) -> void:
	var stream := _find("musica", track)
	if stream == null or _music.stream == stream:
		return
	_music.stream = stream
	_music.play()


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
