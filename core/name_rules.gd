class_name NameRules
extends RefCounted
## Convención de nombres que usan las artistas en Blender (ver docs/ARTE-PIPELINE.md).
##
##   PREFIJO_id__token__token
##
##   P_   pieza que falta (su hueco blanco aparece en el diorama y la pieza en el inventario)
##   H_   pieza escondida: hay que encontrarla y pulsarla para que pase al inventario
##   OD_  cajón (se desliza por su eje local +Z; tokens x, nx, y, ny, z, nz)
##   OR_  puerta (gira 90º alrededor de su origen = la bisagra; token n = al otro lado)
##   Z_   sub-diorama con zoom (token reward-<id>: al completarlo da esa pieza)
##   Token en P_: after-<id> = esta pieza solo encaja cuando las <id> ya están puestas.
##
## Blender añade ".001" a las copias y Godot lo convierte en "_001": se ignora,
## así dos sillas iguales comparten id y cualquiera vale en cualquier hueco de silla.

const PIECE := "P_"
const PICKUP := "H_"
const DRAWER := "OD_"
const DOOR := "OR_"
const ZOOM := "Z_"
const PREFIXES := [DRAWER, DOOR, PIECE, PICKUP, ZOOM]


## Devuelve {kind, id, tokens} o {} si el nombre no sigue la convención.
static func parse(node_name: String) -> Dictionary:
	var clean := strip_copy_suffix(node_name)
	for prefix: String in PREFIXES:
		if clean.begins_with(prefix):
			var parts := clean.substr(prefix.length()).split("__")
			if parts[0].is_empty():
				return {}
			return {
				"kind": prefix,
				"id": StringName(parts[0].to_lower()),
				"tokens": parts.slice(1),
			}
	return {}


## "P_silla_001" -> "P_silla" ; "P_taza.002" -> "P_taza"
static func strip_copy_suffix(s: String) -> String:
	var out := s
	while true:
		var i := maxi(out.rfind("_"), out.rfind("."))
		if i <= 1 or not out.substr(i + 1).is_valid_int():
			break
		out = out.substr(0, i)
	return out


## Valores de los tokens "clave-valor": values(["after-mesa", "after-mantel"], "after") -> [&"mesa", &"mantel"]
static func values(tokens: PackedStringArray, key: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for t in tokens:
		if t.begins_with(key + "-"):
			out.append(StringName(t.substr(key.length() + 1).to_lower()))
	return out


static func has_token(tokens: PackedStringArray, token: String) -> bool:
	return tokens.has(token)
