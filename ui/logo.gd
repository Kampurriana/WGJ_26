class_name Logo
extends Control
## El logo del juego montado en motor con las piezas de las artistas (assets/ui/logo/), para que cada
## una se mueva a su aire: la moneda gira sobre sí misma, «what I never» se mece, «SAID» respira y el
## cerdito da saltitos. La disposición es la de la referencia de maquetación (960 px de ancho): cada
## pieza ocupa su caja de REF_RECTS (la imagen, recortada a lo que tiene dibujo, se ajusta dentro sin
## deformarse) y su movimiento no la saca de su caja más que unos px: entre ellas nunca se tapan.
## Lo usan el menú de inicio (encima de las opciones) y los créditos (arriba del todo).
## Sin las imágenes, sale el nombre del juego en letra, como antes.

const DIR := "res://assets/ui/logo/"
## Las piezas: una imagen por pieza, recortada a su dibujo (el texto llega en una imagen con las dos
## líneas: se parte en dos al traerlo, «what I never» y «SAID»).
const FILES := {"moneda": "logo_moneda.png", "what": "logo_what.png", "said": "logo_said.png", "cerdito": "logo_cerdito.png"}
## La caja de cada pieza en la referencia de maquetación (px de la referencia: 960 × 500).
const REF_RECTS := {
	"moneda": Rect2(88, 82, 90, 90),
	"what": Rect2(205, 86, 625, 80),
	"said": Rect2(86, 243, 492, 205),
	"cerdito": Rect2(613, 186, 267, 234),
}
## Lo que ocupa el logo entero en la referencia (las cajas, con sitio para que se muevan).
const REF_FRAME := Rect2(78, 72, 812, 386)
## Desde dónde se mueve cada pieza (fracción de su tamaño): el cerdito, desde las patas; «SAID», desde abajo.
const PIVOTS := {"moneda": Vector2(0.5, 0.5), "what": Vector2(0.5, 0.6), "said": Vector2(0.5, 1.0), "cerdito": Vector2(0.5, 1.0)}

var pieces: Dictionary = {}                  ## nombre -> TextureRect (la pieza, del tamaño de su dibujo)
var _k := 1.0                                ## px de pantalla por px de la referencia
var _t := 0.0
var _label: Label                            ## sin imágenes: el nombre en letra


## width = lo ancho que se ve el logo (px). textures = las piezas ya cargadas (si no, las de DIR).
func _init(width := 430.0, textures: Dictionary = {}) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_k = width / REF_FRAME.size.x
	var tex := textures if not textures.is_empty() else load_pieces()
	if tex.is_empty():
		_label = Label.new()
		_label.text = GameState.game_title()
		UiTheme.style_title(_label, int(72.0 * width / 430.0))
		_label.resized.connect(func() -> void: _label.pivot_offset = _label.size * 0.5)
		add_child(_label)
		return
	custom_minimum_size = REF_FRAME.size * _k
	for key: String in REF_RECTS:
		var t: Texture2D = tex[key]
		var box: Rect2 = REF_RECTS[key]
		var fit := minf(box.size.x / t.get_width(), box.size.y / t.get_height())
		var size_ref := Vector2(t.get_width(), t.get_height()) * fit
		var img := TextureRect.new()
		img.name = key
		img.texture = t
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_SCALE
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.size = size_ref * _k
		img.position = (box.position + (box.size - size_ref) * 0.5 - REF_FRAME.position) * _k
		img.pivot_offset = img.size * (PIVOTS[key] as Vector2)
		img.set_meta(&"base", img.position)
		add_child(img)
		pieces[key] = img


## Las piezas de DIR, o {} si falta alguna.
static func load_pieces() -> Dictionary:
	var out := {}
	for key: String in FILES:
		var path := DIR + String(FILES[key])
		if not ResourceLoader.exists(path):
			return {}
		out[key] = load(path)
	return out


## (Tests) ¿Está montado con las piezas (y no con el nombre en letra)?
func has_pieces() -> bool:
	return not pieces.is_empty()


## (Tests) La caja que ocupa ahora el dibujo de una pieza en pantalla (con su giro y su escala).
func piece_box(key: String) -> Rect2:
	var img: TextureRect = pieces[key]
	var xf := img.get_global_transform()
	var box := Rect2(xf * Vector2.ZERO, Vector2.ZERO)
	for c: Vector2 in [Vector2(img.size.x, 0), img.size, Vector2(0, img.size.y)]:
		box = box.expand(xf * c)
	return box


## Aparecen una tras otra (sin crecer por encima de su tamaño: así no se pisan al entrar).
func play_intro(delay := 0.0) -> void:
	var i := 0
	for key: String in ["moneda", "what", "said", "cerdito"]:
		if not pieces.has(key):
			continue
		var img: TextureRect = pieces[key]
		img.modulate.a = 0.0
		img.scale = Vector2.ONE * 0.8
		var tw := img.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(img, "modulate:a", 1.0, 0.35).set_delay(delay + 0.12 * i)
		tw.tween_property(img, "scale", Vector2.ONE, 0.45).set_delay(delay + 0.12 * i)
		i += 1


## Cada pieza, su movimiento (en px de la referencia, pequeños: no salen de su caja).
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if _label != null:                           # sin piezas: el nombre flota como antes
		_label.rotation_degrees = -3.0 + sin(_t * 1.1) * 1.5
		_label.scale = Vector2.ONE * (1.0 + 0.02 * sin(_t * 1.7))
		return
	var coin: TextureRect = pieces.moneda        # gira sobre sí misma de vez en cuando y flota
	var spin := fmod(_t, 4.0)
	coin.scale.x = cos(clampf((spin - 2.8) / 1.2, 0.0, 1.0) * TAU) if not _intro_running(coin) else coin.scale.x
	_bob(coin, sin(_t * 1.6) * 3.0)
	var what: TextureRect = pieces.what          # se mece
	what.rotation_degrees = sin(_t * 0.9 + 1.0) * 0.8
	_bob(what, sin(_t * 1.1 + 0.5) * 2.0)
	var said: TextureRect = pieces.said          # respira
	if not _intro_running(said):
		said.scale = Vector2.ONE * (1.0 + 0.022 * sin(_t * 1.4 + 2.0))
	var pig: TextureRect = pieces.cerdito        # saltitos, meciéndose sobre las patas
	var hop := absf(sin(_t * 2.2))
	_bob(pig, -pow(hop, 3.0) * 5.0)
	pig.rotation_degrees = sin(_t * 2.2) * 2.5


func _bob(img: TextureRect, y_ref: float) -> void:
	img.position = (img.get_meta(&"base") as Vector2) + Vector2(0, y_ref * _k)


func _intro_running(img: TextureRect) -> bool:
	return img.modulate.a < 0.999
