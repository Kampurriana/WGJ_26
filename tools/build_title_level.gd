extends "res://tools/build_sample_level.gd"
## Genera el diorama del título: la HUCHA DE CERDITO de la protagonista, la del kit de las artistas
## (assets/kit/piezas/SM_Pig.scn: montada como SM_pig_compo.fbx, con sus ojos y sus cinco pegatinas), sobre
## el tocón de madera (SM_Peana, con su textura), hecha piezas. Se monta como todo el juego (bandeja de la
## derecha, siluetas): primero el cuerpo; luego patas, orejas, ojos, hocico, corona y cola; y las PEGATINAS
## (corazón, estrella, rayo, nube y arcoíris). Sin cartel (el nombre lo pone el logo del menú). Al acabar
## sale el menú. Ejecutar (después de tools/piezas_kit.gd si cambia la hucha):
##   godot --headless --path . --script res://tools/build_title_level.gd
##
## Escribe:
##   levels/titulo/titulo_kit.tscn   el modelo: el tocón (decorado) y la hucha en piezas P_ (la convención)
##   levels/titulo/mallas/*.res      las mallas de sus trozos (las de la hucha son de su escena importada)
##   levels/menu_titulo.tscn         el nivel: solo el Diorama con sus ajustes; carga el modelo al empezar

const TITLE_OUT := "res://levels/menu_titulo.tscn"
const MODEL_OUT := "res://levels/titulo/titulo_kit.tscn"
const MESHES_OUT := "res://levels/titulo/mallas/"
const TILESET := "res://assets/kit/piezas/"
const PIG_YAW := -145.0                      ## la hucha mira de tres cuartos: se le ve la cara (la del kit mira a su -Z)
## Cada trozo de la hucha del kit, su pieza (las patas y las orejas, iguales); las pegatinas, cada una la suya.
const PARTES := {"SM_PigA": "pata", "SM_PigB": "pata", "SM_PigC": "pata", "SM_PigD": "pata",
	"SM_PigE": "cuerpo", "SM_PigF": "oreja", "SM_PigG": "oreja", "SM_PigH": "hocico", "SM_PigI": "ojo",
	"SM_PigJ": "ojo", "SM_PigK": "corona", "SM_PigL": "cola", "Plane001": "pegatina_corazon",
	"Plane002": "pegatina_estrella", "Plane003": "pegatina_rayo", "Plane005": "pegatina_nube",
	"Plane006": "pegatina_arcoiris"}


func _initialize() -> void:
	var model := Node3D.new()
	model.name = "Cerdito"
	_root = model
	# El tocón: decorado (empieza en madera cruda y se pinta), la hucha encima.
	var stump := (load(TILESET + "SM_Peana.scn") as PackedScene).instantiate() as Node3D
	stump.name = "Tocon"
	model.add_child(stump)
	var top := Visuals.local_aabb(stump).end.y
	var pig := _node(model, "Hucha", Vector3(0, top, 0))
	pig.rotation_degrees.y = PIG_YAW
	var kit_pig := (load(TILESET + "SM_Pig.scn") as PackedScene).instantiate() as Node3D
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MESHES_OUT))
	var used := {}
	for m in Visuals.meshes_under(kit_pig):
		var part: String = PARTES.get(String(m.name), "")
		if part == "":
			continue
		var n: int = used.get(part, 0)
		used[part] = n + 1
		var tokens := "" if part == "cuerpo" else "__after-cuerpo"
		var piece := _node(pig, "P_%s%s%s" % [part, tokens, "" if n == 0 else "_%03d" % n], Vector3.ZERO)
		var copy := m.duplicate() as MeshInstance3D
		copy.transform = m.transform                 # (el tileset ya la tiene montada, con el pivote abajo)
		var path := MESHES_OUT + "%s.res" % String(m.name).to_lower()
		ResourceSaver.save(m.mesh.duplicate(), path)
		copy.mesh = load(path)
		piece.add_child(copy)
	kit_pig.free()
	_own_kit(model)
	var packed := PackedScene.new()
	var err := packed.pack(model)
	if err == OK:
		err = ResourceSaver.save(packed, MODEL_OUT)
	print("MODELO TITULO %s err=%d (%d piezas)" % [MODEL_OUT, err, used.values().reduce(func(a: int, b: int) -> int: return a + b, 0)])
	model.free()
	if err != OK:
		quit(1)
		return

	# El cerdito de verdad mide unos 40 cm sobre un tocón de 72: la cámara, a su medida.
	var level := Node3D.new()
	level.name = "MenuTitulo"
	level.set_script(load("res://core/diorama.gd"))
	level.set("level_title", "")
	level.set("modelo", "")
	level.set("modelo_provisional", MODEL_OUT)
	level.set("outro_key", "fin_menu")
	level.set("color_radius", 0.16)
	level.set("camera_distance", 1.7)
	level.set("camera_min_distance", 0.6)
	level.set("camera_max_distance", 2.6)
	level.set("camera_pitch_deg", 18.0)
	level.set("camera_yaw_deg", 0.0)
	level.set("camera_yaw_min_deg", -55.0)          ## las pegatinas tienen que verse
	level.set("camera_yaw_max_deg", 55.0)
	level.set("camera_pitch_min_deg", 6.0)
	level.set("camera_pitch_max_deg", 55.0)
	level.set("iluminacion", "res://iluminacion/menu.tscn")
	packed = PackedScene.new()
	err = packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, TITLE_OUT)
	print("NIVEL TITULO %s err=%d" % [TITLE_OUT, err])
	level.free()
	quit(0 if err == OK else 1)


## Como _own, pero sin meterse dentro de las escenas instanciadas (el tocón se guarda como instancia).
func _own_kit(n: Node) -> void:
	for c in n.get_children():
		c.owner = _root
		if c.scene_file_path == "":
			_own_kit(c)
