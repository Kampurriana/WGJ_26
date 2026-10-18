class_name Logo
extends Control
## El logo del juego montado en motor con las piezas de las artistas (assets/ui/logo/), para que cada
## una se mueva por su cuenta. Es UNA pegatina: las piezas van juntas como en la composición de las
## artistas (los bordes blancos se funden), detrás llevan una silueta blanca común que las une y una
## sola sombra, y el logo entero flota despacio. Los movimientos son tranquilos y van encadenados:
## la moneda da una vuelta de vez en cuando, «what I never» y «SAID» se mecen lentísimo, el cerdito da
## un saltito y, al caer, «SAID» se aplasta un pelín, como si le diera un golpecito. Ninguna pieza tapa
## el dibujo de otra (solo se tocan los bordes blancos). Encima del menú de inicio y en los créditos.
## Sin las imágenes, sale el nombre del juego en letra, como antes.

const DIR := "res://assets/ui/logo/"
## Las piezas: una imagen por pieza, recortada a su dibujo (las prepara tools/partir_logo.py).
const FILES := {"moneda": "logo_moneda.png", "what": "logo_what.png", "said": "logo_said.png", "cerdito": "logo_cerdito.png"}
## Lo que mide el borde blanco de pegatina de cada imagen (px de la imagen).
const BORDER_TEX := {"moneda": 31.0, "what": 26.0, "said": 26.0, "cerdito": 33.0}
## La caja de cada pieza (con su borde blanco) en px de la referencia de maquetación (960 de ancho):
## «what I never» y «SAID» como las colocaron las artistas en su imagen (los bordes se solapan 5 px); la
## moneda a la izquierda de «what I never» y el cerdito a la derecha de «SAID», bajo «never», con los
## bordes solapados ~6 px. Entre los dibujos de color quedan 20-25 px: el movimiento no los junta.
const REF_RECTS := {
	"moneda": Rect2(76, 68.5, 119, 119),
	"what": Rect2(189, 72, 640, 115),
	"said": Rect2(63, 180, 534, 274),
	"cerdito": Rect2(591, 181, 297, 290),
}
## Lo que ocupa el logo entero en la referencia (las cajas, la pegatina común y la sombra).
const REF_FRAME := Rect2(51, 56, 849, 435)
## Desde dónde se mueve cada pieza (fracción de su tamaño): el cerdito y «SAID», desde abajo.
const PIVOTS := {"moneda": Vector2(0.5, 0.5), "what": Vector2(0.5, 0.6), "said": Vector2(0.5, 1.0), "cerdito": Vector2(0.5, 1.0)}
const ORDER := ["moneda", "what", "said", "cerdito"]
const BACKING_GROW := 5.0                    ## la pegatina común: lo que engorda cada silueta (px de la referencia)
const SHADOW_GROW := 7.0
const SHADOW_OFFSET := Vector2(0, 7)
const SHADOW_COLOR := Color(0.2, 0.16, 0.32, 0.2)
const COIN_EVERY := 6.0                      ## la moneda da una vuelta cada esto (s)...
const COIN_TURN := 0.9                       ## ...que dura esto
const HOP_EVERY := 4.2                       ## el cerdito salta cada esto (s)...
const HOP_TIME := 0.55                       ## ...el salto dura esto...
const HOP_HEIGHT := 7.0                      ## ...y sube esto (px de la referencia)
const SQUASH_TIME := 0.5                     ## lo que dura el golpecito en «SAID» al caer el cerdito
const SQUASH := 0.018                        ## y cuánto se aplasta (fracción de su alto)

var pieces: Dictionary = {}                  ## nombre -> TextureRect (la pieza, del tamaño de su dibujo)
var backing: Array[TextureRect] = []         ## la pegatina común y la sombra (siluetas engordadas)
var squash := 0.0                            ## (tests) el aplastón de «SAID» ahora mismo
var _stage: Control                          ## todo el logo junto: flota como una sola cosa
var _k := 1.0                                ## px de pantalla por px de la referencia
var _t := 0.0
var _label: Label                            ## sin imágenes: el nombre en letra


## width = lo ancho que se ve el logo (px). textures = las piezas ya cargadas (si no, las de DIR).
func _init(width := 430.0, textures: Dictionary = {}) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # se ve 3-4 veces más pequeño que la imagen
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
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size = custom_minimum_size
	add_child(_stage)
	for key: String in ORDER:                    # primero la sombra de todas, luego la pegatina blanca de todas
		_silhouette(tex[key], REF_RECTS[key], SHADOW_GROW, SHADOW_COLOR, SHADOW_OFFSET, 2.5)
	for key: String in ORDER:
		_silhouette(tex[key], REF_RECTS[key], BACKING_GROW, Color.WHITE, Vector2.ZERO, 1.0)
	for key: String in ORDER:                    # y encima, las piezas
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
		img.set_meta(&"border", float(BORDER_TEX[key]) * fit * _k)
		_stage.add_child(img)
		pieces[key] = img


## Una silueta engordada de una pieza, quieta en su sitio (la pegatina común o su sombra).
func _silhouette(t: Texture2D, box: Rect2, grow: float, color: Color, offset: Vector2, blur: float) -> void:
	var pad := grow + 6.0
	var s := TextureRect.new()
	s.texture = t
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.stretch_mode = TextureRect.STRETCH_SCALE
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.position = (box.position - Vector2(pad, pad) + offset - REF_FRAME.position) * _k
	s.size = (box.size + Vector2(pad, pad) * 2.0) * _k
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/silueta.gdshader")
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("margen", Vector2(pad, pad) / box.size)
	mat.set_shader_parameter("radio", Vector2(grow, grow) / box.size)
	mat.set_shader_parameter("borroso", blur)
	mat.set_shader_parameter("corte", 0.35)
	s.material = mat
	_stage.add_child(s)
	backing.append(s)


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


## (Tests) La caja que ocupa ahora una pieza en pantalla (con su borde blanco, su giro y su escala).
func piece_box(key: String) -> Rect2:
	return _box(key, 0.0)


## (Tests) La caja de su dibujo de color (sin el borde blanco).
func drawing_box(key: String) -> Rect2:
	return _box(key, float(pieces[key].get_meta(&"border")))


func _box(key: String, inset: float) -> Rect2:
	var img: TextureRect = pieces[key]
	var xf := img.get_global_transform()
	var a := Vector2(inset, inset)
	var b := img.size - a
	var box := Rect2(xf * a, Vector2.ZERO)
	for c: Vector2 in [Vector2(b.x, a.y), b, Vector2(a.x, b.y)]:
		box = box.expand(xf * c)
	return box


## Entra: la pegatina común aparece y las piezas, una tras otra (sin crecer por encima de su tamaño).
func play_intro(delay := 0.0) -> void:
	for s in backing:
		s.modulate.a = 0.0
		s.create_tween().tween_property(s, "modulate:a", 1.0, 0.4).set_delay(delay)
	var i := 0
	for key: String in ORDER:
		if not pieces.has(key):
			continue
		var img: TextureRect = pieces[key]
		img.modulate.a = 0.0
		img.scale = Vector2.ONE * 0.85
		var tw := img.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(img, "modulate:a", 1.0, 0.35).set_delay(delay + 0.1 + 0.12 * i)
		tw.tween_property(img, "scale", Vector2.ONE, 0.45).set_delay(delay + 0.1 + 0.12 * i)
		i += 1


## Los movimientos: lentos, pequeños y encadenados (px de la referencia).
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if _label != null:                           # sin piezas: el nombre flota como antes
		_label.rotation_degrees = -3.0 + sin(_t * 1.1) * 1.5
		_label.scale = Vector2.ONE * (1.0 + 0.02 * sin(_t * 1.7))
		return
	_stage.position.y = sin(_t * 0.7) * 3.0 * _k  # el logo entero flota, como una sola pegatina
	var coin: TextureRect = pieces.moneda        # una vuelta sobre sí misma de vez en cuando
	if not _intro_running(coin):
		var turn := clampf((fmod(_t, COIN_EVERY) - (COIN_EVERY - COIN_TURN)) / COIN_TURN, 0.0, 1.0)
		coin.scale.x = cos(_smooth(turn) * TAU)
	_bob(coin, sin(_t * 0.9) * 1.5)
	var what: TextureRect = pieces.what          # se mece lentísimo
	what.rotation_degrees = sin(_t * 0.55 + 2.0) * 0.4
	_bob(what, sin(_t * 0.7 + 1.0) * 1.0)
	var pig: TextureRect = pieces.cerdito        # un saltito de vez en cuando, ladeándose un poco
	var h := fmod(_t + 1.5, HOP_EVERY)
	var hop := clampf(h / HOP_TIME, 0.0, 1.0) if h < HOP_TIME else 0.0
	_bob(pig, -sin(PI * hop) * HOP_HEIGHT)
	pig.rotation_degrees = sin(TAU * hop) * 3.0
	var said: TextureRect = pieces.said          # se mece lentísimo y, al caer el cerdito, un golpecito
	said.rotation_degrees = sin(_t * 0.5) * 0.5
	var q := (h - HOP_TIME) / SQUASH_TIME
	squash = sin(TAU * q) * (1.0 - q) * SQUASH if q >= 0.0 and q <= 1.0 else 0.0
	if not _intro_running(said):
		said.scale = Vector2(1.0 + squash * 0.5, 1.0 - squash)


func _bob(img: TextureRect, y_ref: float) -> void:
	img.position = (img.get_meta(&"base") as Vector2) + Vector2(0, y_ref * _k)


func _smooth(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


func _intro_running(img: TextureRect) -> bool:
	return img.modulate.a < 0.999
