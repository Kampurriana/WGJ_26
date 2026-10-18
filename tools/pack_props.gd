extends "res://tools/build_sample_level.gd"
## Lo que los generadores del desván (tools/build_attic_level.gd y tools/build_kit_level.gd) usan del pack
## de props Modern Japanese Home Props (MIT, assets/modelos/ModernJapaneseHomePropsLite): sus modelos,
## a su tamaño real (metros) e instanciados por referencia (no se copian), y la luz de la lámpara.
## (Era la base de la habitación japonesa, tools/build_room_level.gd, que se borró el 18-oct con lo que no
## se usaba del pack: los generadores heredaban de ella y no arrancaban.) Del pack quedan solo estos 7.

const PACK := "res://assets/modelos/ModernJapaneseHomePropsLite/addons/modern_japanese_home_props/models/"
const MODELS := {
	"book_01": "books/book_01.glb", "manga_01": "books/manga_01.glb", "clock_01": "electronics/clock_01.glb",
	"speaker_01": "electronics/speaker_01.glb", "chair_01": "furniture/chair_01.glb",
	"lamp_01": "lighting/lamp_01.glb", "mug_01": "tableware/mug_01.glb",
}


func _prop(parent: Node, n: String, model: String, pos: Vector3, rot_y := 0.0) -> Node3D:
	var holder := _node(parent, n, pos)
	holder.rotation_degrees.y = rot_y
	_instance(holder, model)
	return holder


## La lámpara del escritorio alumbra de verdad: un foco cálido desde la pantalla hacia la mesa.
## Cuelga de la pieza, así está apagado hasta colocarla y entonces se enciende (PieceSlot.fill).
func _lamp_light(lamp: Node3D) -> void:
	var box := Visuals.local_aabb(lamp)
	var luz := SpotLight3D.new()
	luz.name = "Luz"
	luz.position = Vector3(box.get_center().x, box.end.y - 0.04, box.get_center().z)
	luz.rotation_degrees = Vector3(-90, 0, 0)
	luz.light_color = Color(1.0, 0.8, 0.55)
	luz.light_energy = 1.1                         # quinta nota: quemaba la mesa (medido)
	luz.spot_range = 1.2
	luz.spot_angle = 55.0
	luz.spot_attenuation = 1.2
	lamp.add_child(luz)


func _instance(parent: Node, model: String) -> Node3D:
	var scene := load(PACK + MODELS[model]) as PackedScene
	var inst := scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	inst.name = "Modelo"
	parent.add_child(inst)
	return inst


## Como el de la muestra, pero sin entrar en los modelos instanciados: se guardan como referencia
## al .glb (si se adueñara de sus hijos, se copiarían enteros dentro del .tscn).
func _own(n: Node) -> void:
	for c in n.get_children():
		c.owner = _root
		if c.scene_file_path == "":
			_own(c)
