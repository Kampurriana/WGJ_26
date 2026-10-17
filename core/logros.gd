class_name Logros
extends Node
## Los logros (tablero de feedback de la UI: "lista de logros"). Se ganan jugando, se guardan con
## el progreso (GameState.achievements) y avisan con Events.achievement_unlocked (el HUD saca una
## notificación). Se ven todos en la pausa y en el menú de inicio (ui/logros_lista.gd).
##   infancia, adolescencia, adultez: al completar esa sección del desván (sus recuerdos).
##   dibujos: al encontrar los 7 dibujos escondidos.
##   speedrunner: acabar el desván (el juego) en menos de SPEEDRUN segundos, sin el atajo F9.

const SPEEDRUN := 480.0                      ## 8 minutos
const LISTA := [
	{"id": "infancia", "nombre": "Recuerdos de la infancia", "texto": "Desbloquea los recuerdos de la infancia."},
	{"id": "adolescencia", "nombre": "Recuerdos de la adolescencia", "texto": "Desbloquea los recuerdos de la adolescencia."},
	{"id": "adultez", "nombre": "Recuerdos de la adultez", "texto": "Desbloquea los recuerdos de la adultez."},
	{"id": "dibujos", "nombre": "Los siete dibujos", "texto": "Recupera los 7 dibujos de cuando era pequeña."},
	{"id": "speedrunner", "nombre": "Speedrunner", "texto": "Acaba el juego en menos de 8 minutos."},
]

var _start_ms := -1                          ## cuándo empezó el desván (-1 = no se cronometra)


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


func unlock(id: String) -> void:
	if GameState.unlock_achievement(id):
		Events.achievement_unlocked.emit(id)


## Segundos desde que empezó el desván (o -1).
func elapsed() -> float:
	return (Time.get_ticks_msec() - _start_ms) / 1000.0 if _start_ms >= 0 else -1.0


static func is_unlocked(id: String) -> bool:
	return GameState.achievements.has(id)


static func info(id: String) -> Dictionary:
	for l: Dictionary in LISTA:
		if l.id == id:
			return l
	return {}
