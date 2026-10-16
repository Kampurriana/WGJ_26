class_name NameRules
extends RefCounted
## Convención de nombres que usan las artistas en Blender (ver docs/ARTE-PIPELINE.md).
##
##   PREFIJO_id__token__token
##
##   P_   pieza que falta (su hueco blanco aparece en el diorama y la pieza en el inventario)
##   H_   pieza escondida: hay que encontrarla y pulsarla para que pase al inventario
##   OD_  cajón (se desliza por su eje local +Z; tokens x, nx, y, ny, z, nz)
##   OR_  puerta (gira 90º alrededor de su origen = la bisagra; token n = al otro lado;
##        token x = bisagra horizontal: una tapa que se levanta, como la de un baúl)
##   Z_   sub-diorama con zoom (token reward-<id>: al completarlo da esa pieza)
##   S_   sección: S_<orden>_<nombre> (S_2_infancia). Lo que cuelga de ella se abre cuando se
##        completa la sección anterior: sus piezas aparecen, sus luces se encienden
##   Tokens en P_: after-<id> = esta pieza solo aparece cuando las <id> ya están puestas;
##        clave = va la última de su sección (y la cierra); flash = destello blanco al colocarla.
##
## Blender añade ".001" a las copias y Godot lo convierte en "_001": se ignora,
## así dos sillas iguales comparten id y cualquiera vale en cualquier hueco de silla.

const PIECE := "P_"
const PICKUP := "H_"
const DRAWER := "OD_"
const DOOR := "OR_"
const ZOOM := "Z_"
const SECTION := "S_"
const PREFIXES := [DRAWER, DOOR, PIECE, PICKUP, ZOOM, SECTION]


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


## "2_infancia" -> 2 ; sin número delante -> -1 (se ordena por aparición).
static func section_order(id: StringName) -> int:
	var head := String(id).get_slice("_", 0)
	return head.to_int() if head.is_valid_int() else -1


## "2_infancia" -> "infancia"
static func section_name(id: StringName) -> String:
	var s := String(id)
	return s.substr(s.find("_") + 1) if section_order(id) >= 0 and s.contains("_") else s
