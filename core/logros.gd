class_name Logros
extends Node
## Los logros (tablero de feedback de la UI: "lista de logros"). Se ganan jugando, se guardan con
## el progreso (GameState.achievements) y avisan con Events.achievement_unlocked (el HUD saca una
## notificación). Se ven todos en la pausa y en el menú de inicio (ui/logros_lista.gd).
##   infancia, adolescencia, adultez: al completar esa sección del desván (sus recuerdos).
##   dibujos: al encontrar todos los dibujos escondidos.
##   speedrunner: acabar el desván (el juego) en menos de SPEEDRUN segundos, sin el atajo F9.
##   alma_artista: jugar más de un minuto con, al menos, dos combinaciones de fondo distintas
##     (color y motivo de Opciones): un minuto con cada una.
## Los "secreto" no enseñan qué hay que hacer hasta conseguirlos (ui/logros_lista.gd).

const SPEEDRUN := 120.0                      ## 2 minutos (feedback)
const ARTIST_SECONDS := 60.0                 ## lo que hay que jugar con cada fondo
const ARTIST_BACKGROUNDS := 2
const LISTA := [
	{"id": "infancia", "nombre": "Recuerdos de la infancia", "texto": "Desbloquea los recuerdos de la infancia."},
	{"id": "adolescencia", "nombre": "Recuerdos de la adolescencia", "texto": "Desbloquea los recuerdos de la adolescencia."},
	{"id": "adultez", "nombre": "Recuerdos de la profesión", "texto": "Desbloquea los recuerdos de la profesión."},
	{"id": "dibujos", "nombre": "Todos mis dibujos", "texto": "Recupera todos los dibujos de cuando era pequeña."},
	{"id": "speedrunner", "nombre": "Speedrunner", "texto": "Acaba el juego en menos de 2 minutos.", "secreto": true},
	{"id": "alma_artista", "nombre": "Alma de artista", "texto": "Juega más de un minuto con dos fondos distintos.", "secreto": true},
]

var _start_ms := -1                          ## cuándo empezó el desván (-1 = no se cronometra)
var backgrounds: Dictionary = {}             ## "color,motivo" -> segundos jugados con ese fondo (alma_artista)


func _ready() -> void:
	Events.section_completed.connect(func(sec: RefCounted) -> void:
		var n := String((sec as Section).name)
		if info(n).size() > 0:
			unlock(n))
	Events.collectible_found.connect(func(_item: Node, found: int, total: int) -> void:
		if total > 0 and found >= total:
			unlock("dibujos"))
	Events.level_started.connect(func(d: Node) -> void:
		var dio := d as Diorama
		_start_ms = Time.get_ticks_msec() if dio != null and dio.fundido_final and GameState.mode == GameState.Mode.PLAYING else -1)
	Events.level_completed.connect(func(d: Node) -> void:
		var dio := d as Diorama
		if _start_ms >= 0 and dio != null and dio.fundido_final and elapsed() < SPEEDRUN:   # F9 quita el fundido: no cuenta
			unlock("speedrunner"))


func _process(delta: float) -> void:
	if GameState.mode != GameState.Mode.PLAYING or get_tree().paused or is_unlocked("alma_artista"):
		return
	var key := "%d,%d" % [int(Settings.get_value("fondo_color")), int(Settings.get_value("fondo_motivo"))]
	backgrounds[key] = float(backgrounds.get(key, 0.0)) + delta
	if backgrounds.values().filter(func(s: float) -> bool: return s >= ARTIST_SECONDS).size() >= ARTIST_BACKGROUNDS:
		unlock("alma_artista")


func unlock(id: String) -> void:
	if GameState.unlock_achievement(id):
		Events.achievement_unlocked.emit(id)


## Segundos desde que empezó el desván (o -1).
func elapsed() -> float:
	return (Time.get_ticks_msec() - _start_ms) / 1000.0 if _start_ms >= 0 else -1.0


static func is_secret(id: String) -> bool:
	return bool(info(id).get("secreto", false))


static func is_unlocked(id: String) -> bool:
	return GameState.achievements.has(id)


static func info(id: String) -> Dictionary:
	for l: Dictionary in LISTA:
		if l.id == id:
			return l
	return {}
