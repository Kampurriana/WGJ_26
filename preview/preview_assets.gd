extends Node3D
## Preview de los assets de las artistas (assets/kit/), APARTE del juego: no se juega y no toca nada
## del prototipo. Cada pieza se pone en un catálogo ordenado, a su tamaño real, en las mismas
## condiciones que el nivel del desván:
##  - su luz (la escena de iluminacion/ que usa el nivel), con el fondo y la viñeta que eligió el
##    jugador en Opciones; la luz, en su estado final (el desván completo), que es como se verá el
##    dressing. L cambia a la luz del principio (fría) y vuelta;
##  - la misma cámara (DioramaCamera: ángulos, campo de visión, distancia, muelles y respiración del
##    nivel), así los muebles se ven del tamaño que tendrán en partida; aquí se puede girar del todo
##    y alejar hasta verlo todo; rueda = zoom;
##  - el mismo enfoque de cine (Enfoque) y HDR 2D.
## Disposición: delante, los muebles y las cajas (donde mira la cámara), en filas del ancho del
## desván; detrás, los dibujos 2D de pie; y al fondo la estructura (suelo, paredes, techo, vigas...).
## Las piezas se cogen de cada .fbx/.glb: primero las sueltas (modelos/) y luego las de los paquetes
## (paquetes/) que no estén ya. Texturas: una pieza cuyo nombre contiene el de una carpeta de
## assets/kit/texturas/ (SM_DeskA -> Desk) lleva el material assets/kit/materiales/M_<carpeta>.tres.
## Dos vistas (Tab cambia): el CATÁLOGO de piezas y el DIORAMA de prueba (preview/diorama_kit.gd: un
## rincón del desván montado solo con el kit, con la arquitectura de la referencia de las artistas).
## Abrir en el editor y F6, o:  godot --path . res://preview/preview_assets.tscn
## Captura:  godot --path . --resolution 1280x720 res://preview/preview_assets.tscn -- --capture=build/preview.png
##           [--vista=diorama] [--capture-after=S] [--yaw=G] [--pitch=G] [--zoom=F] [--luz=inicio]

const NIVEL := "res://levels/level_01_desvan.tscn"   ## de aquí salen la luz y los ajustes de cámara
const KIT := "res://assets/kit"
const MODEL_EXT := ["fbx", "glb", "gltf"]
const IMAGE_EXT := ["png", "jpg", "jpeg", "webp"]
## Piezas de los paquetes que también llegan sueltas con su nombre bueno (las cajas de Boxes.fbx son
## SM_BoxA..E; la tele de Pack04, SM_TV): no se montan dos veces. Las de nombre SM_ repetido se
## descartan solas. Comoda.fbx (la cómoda fundida en una sola malla) no se trae: están sus piezas.
const REPETIDAS := ["Box01", "Box073", "Box074", "Box075", "Box077", "TV01", "TV05"]
const EXCLUIDOS := ["Comoda.fbx"]
## Nombres buenos para las piezas que llegan con el nombre por defecto de 3ds Max.
const ALIAS := {"Box072": "SM_Burro", "CoverDesk": "SM_CoverDesk", "Vase001": "SM_Vase",
	"Cylinder025": "SM_BrushA", "Cylinder026": "SM_BrushB", "Cylinder027": "SM_BrushC"}
## Piezas que llegan en trozos colocados entre sí (prefijo -> una sola pieza): el MP3 con su cable.
const GRUPOS := {"MP3": "SM_MP3"}
## Qué va delante (la cámara mira ahí): muebles y cajas. Lo demás es estructura y va detrás.
const PROPS := ["Desk", "Lamp", "Stool", "Box", "Object", "Comoda", "TV", "Burro", "CoverDesk", "Vase", "Brush", "MP3"]
const HUECO := 0.3                           ## separación entre piezas del catálogo (m)
const FILA_MAX := 9.0                        ## ancho máximo de una fila de estructura (m)
const FILA_PROPS := 5.0                      ## y de una de muebles: el ancho del desván (cabe en el encuadre)
const DIBUJO_ALTO := 0.55                    ## alto de cada dibujo 2D (m)

var cam: DioramaCamera
var contenido: Node3D                        ## el catálogo (piezas y dibujos)
var diorama: Node3D                          ## el diorama de prueba
var vista := "catalogo"                      ## lo que se ve: "catalogo" o "diorama"
var piezas: Array[String] = []               ## nombres de las piezas montadas (para el informe)
var _props_caja := AABB()                    ## lo de delante: donde mira la cámara al empezar
var _ajustes: Dictionary = {}
var _rig: Node3D
var _sol: DirectionalLight3D
var _luz_final := true
var _capture := ""
var _capture_after := 3.0
var _t := 0.0


func _ready() -> void:
	get_viewport().use_hdr_2d = true         # como main.gd: sin HDR 2D el fondo pastel se queda gris
	_ajustes = _ajustes_del_nivel()
	_montar_luz(String(_ajustes.get("iluminacion", "")))
	contenido = Node3D.new()
	contenido.name = "Contenido"
	add_child(contenido)
	_montar_catalogo()
	diorama = preload("res://preview/diorama_kit.gd").new()
	diorama.name = "Diorama"
	add_child(diorama)
	diorama.montar(_materiales())
	cam = DioramaCamera.new()
	cam.name = "Camara"
	add_child(cam)
	mostrar("catalogo")
	var enfoque := Enfoque.new()
	enfoque.name = "Enfoque"
	add_child(enfoque)
	_montar_ayuda()
	_leer_argumentos()
	print("PREVIEW %d piezas: %s" % [piezas.size(), ", ".join(piezas)])


## Los ajustes del nivel tal como están guardados en su escena (sin instanciarlo: no arranca nada
## del juego); lo que no está guardado es el valor por defecto de core/diorama.gd.
func _ajustes_del_nivel() -> Dictionary:
	var out := {}
	var script := load("res://core/diorama.gd") as Script
	for p in script.get_script_property_list():
		var n := String(p.name)
		if n.begins_with("camera_") or n == "iluminacion":
			out[n] = script.get_property_default_value(n)
	var state := (load(NIVEL) as PackedScene).get_state()
	for i in state.get_node_property_count(0):
		var n := String(state.get_node_property_name(0, i))
		if out.has(n):
			out[n] = state.get_node_property_value(0, i)
	return out


func _montar_luz(path: String) -> void:
	var escena := load(path if path != "" else "res://iluminacion/luz_por_defecto.tscn") as PackedScene
	_rig = escena.instantiate()
	_rig.name = "Iluminacion"
	_rig.process_mode = Node.PROCESS_MODE_DISABLED   # su progreso lo da el nivel; aquí lo fijamos
	add_child(_rig)
	_sol = _rig.get_node_or_null(_rig.get("luz_principal")) as DirectionalLight3D
	var rect := _rig.get_node_or_null("Fondo/Degradado") as CanvasItem
	if rect != null:
		Fondos.apply(rect.material as ShaderMaterial, true, Settings.get_value("fondo_color"), Settings.get_value("fondo_motivo"))
	var vineta := _rig.get_node_or_null("Vineta/Sombra") as CanvasItem
	if vineta != null and vineta.material is ShaderMaterial:
		(vineta.material as ShaderMaterial).set_shader_parameter("color", Fondos.dark(Settings.get_value("fondo_color")))
	_poner_luz(true)


func _poner_luz(final: bool) -> void:
	_luz_final = final
	_rig.set("progreso", 1.0 if final else 0.0)
	_rig.call("_apply")


func _montar_catalogo() -> void:
	var props: Array[Node3D] = []
	var estructura: Array[Node3D] = []
	for pieza in _cargar_piezas():
		var es_prop := PROPS.any(func(p: String) -> bool: return pieza.name.begins_with("SM_" + p) or pieza.name.begins_with(p))
		(props if es_prop else estructura).append(pieza)
	# Delante, los muebles: de los más bajos (delante) a los más altos (detrás), en filas del ancho
	# del desván, así caben en el encuadre del nivel.
	props.sort_custom(func(a: Node3D, b: Node3D) -> bool: return _caja(a).size.y < _caja(b).size.y)
	var z := _filas(props, 0.0, FILA_PROPS)
	_props_caja = _caja_de(props)
	z = _montar_dibujos(z - HUECO)
	# Detrás, la estructura (de las más bajas a las más altas: las paredes, al fondo).
	estructura.sort_custom(func(a: Node3D, b: Node3D) -> bool: return _caja(a).size.y < _caja(b).size.y)
	_filas(estructura, z - HUECO * 3.0, FILA_MAX)


## Pone las piezas en filas centradas en x (como mucho `ancho_max` de ancho), la primera con su
## borde de delante en z y las siguientes detrás. Devuelve dónde acaba la última (z).
func _filas(lista: Array[Node3D], z: float, ancho_max: float) -> float:
	var resto := lista.duplicate()
	while not resto.is_empty():
		var fila: Array[Node3D] = []
		var ancho := 0.0
		while not resto.is_empty() and (fila.is_empty() or ancho + _caja(resto[0]).size.x <= ancho_max):
			ancho += _caja(resto[0]).size.x + HUECO
			fila.append(resto.pop_front())
		z -= _fila(fila, z) + HUECO
	return z


## Coloca una fila centrada en x, con su borde de delante en z (las piezas se apoyan en y = 0).
## Devuelve su fondo (lo que ocupa en z).
func _fila(fila: Array[Node3D], z: float) -> float:
	var ancho := 0.0
	var fondo := 0.0
	for p in fila:
		ancho += _caja(p).size.x + HUECO
		fondo = maxf(fondo, _caja(p).size.z)
	var x := -(ancho - HUECO) * 0.5
	for p in fila:
		var c := _caja(p)
		p.position += Vector3(x - c.position.x, -c.position.y, z - c.end.z)
		x += c.size.x + HUECO
	return fondo


## Cada malla de cada modelo, en su propio nodo (con la transformación que traía), sin repetir.
func _cargar_piezas() -> Array[Node3D]:
	var materiales := _materiales()
	var out: Array[Node3D] = []
	for carpeta in ["modelos", "paquetes"]:
		for path in _ficheros(KIT + "/" + carpeta, MODEL_EXT):
			if path.get_file() in EXCLUIDOS:
				continue
			var escena := load(path) as PackedScene
			if escena == null:
				push_error("Preview: no se carga %s" % path)
				continue
			var modelo := escena.instantiate() as Node3D
			modelo.name = "_fbx_" + path.get_file()  # (si se llamara como su pieza, la pieza se renombraría)
			contenido.add_child(modelo)
			for m in _mallas(modelo):
				var nombre := String(ALIAS.get(String(m.name), String(m.name)))
				for prefijo: String in GRUPOS:
					if nombre.begins_with(prefijo):
						nombre = GRUPOS[prefijo]
				var pieza := contenido.get_node_or_null(nombre) as Node3D if nombre in GRUPOS.values() else null
				if pieza == null and (nombre in piezas or nombre in REPETIDAS):
					continue
				for clave: String in materiales:
					if nombre.contains(clave):
						m.material_override = materiales[clave]
				if pieza == null:
					piezas.append(nombre)
					pieza = Node3D.new()
					pieza.name = nombre
					contenido.add_child(pieza)
					out.append(pieza)
				var xf := m.global_transform
				m.get_parent().remove_child(m)
				pieza.add_child(m)
				m.global_transform = xf
				m.owner = null
			modelo.queue_free()
	return out


## {"Desk": M_Desk.tres, ...}: un material por carpeta de texturas que tenga el suyo.
func _materiales() -> Dictionary:
	var out := {}
	var d := DirAccess.open(KIT + "/texturas")
	if d == null:
		return out
	for carpeta in d.get_directories():
		var path := "%s/materiales/M_%s.tres" % [KIT, carpeta]
		if ResourceLoader.exists(path):
			out[carpeta] = load(path)
		else:
			push_warning("Preview: hay texturas en texturas/%s pero no el material %s" % [carpeta, path])
	return out


## Los dibujos 2D, de pie en fila detrás de los muebles y algo elevados (como colgados), cara a la
## cámara. Devuelve dónde acaba la fila (z).
func _montar_dibujos(z: float) -> float:
	var fila: Array[MeshInstance3D] = []
	var ancho := 0.0
	for path in _ficheros(KIT + "/dibujos", IMAGE_EXT):
		var tex := load(path) as Texture2D
		var quad := QuadMesh.new()
		quad.size = Vector2(DIBUJO_ALTO * tex.get_width() / float(tex.get_height()), DIBUJO_ALTO)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.roughness = 0.9
		var m := MeshInstance3D.new()
		m.name = path.get_file().get_basename()
		m.mesh = quad
		m.material_override = mat
		fila.append(m)
		ancho += quad.size.x + 0.12
	var x := -(ancho - 0.12) * 0.5
	for m in fila:
		var w := (m.mesh as QuadMesh).size.x
		m.position = Vector3(x + w * 0.5, DIBUJO_ALTO * 0.5 + 0.45, z)
		contenido.add_child(m)
		x += w + 0.12
	return z if fila.is_empty() else z - 0.1


## Enseña una de las dos vistas y pone la cámara a mirarla: el catálogo, desde delante y a la distancia
## del nivel (los muebles, a su tamaño de partida); el diorama, en diagonal desde su esquina abierta,
## como la referencia de las artistas.
func mostrar(v: String) -> void:
	vista = "diorama" if v == "diorama" else "catalogo"
	contenido.visible = vista == "catalogo"
	diorama.visible = vista == "diorama"
	var todo := Visuals.global_aabb(contenido if vista == "catalogo" else diorama)
	var dist := float(_ajustes.get("camera_distance", 8.0))
	var centro := _props_caja.get_center()
	cam.yaw = float(_ajustes.get("camera_yaw_deg", 0.0))
	cam.pitch = float(_ajustes.get("camera_pitch_deg", 30.0))
	if vista == "diorama":
		dist = todo.size.length() * 1.05
		centro = todo.get_center() + Vector3(0, -todo.size.y * 0.12, 0)
		cam.yaw = 40.0
		cam.pitch = 30.0
	cam.yaw_min = -180.0                     # aquí se mira todo, también por detrás
	cam.yaw_max = 180.0
	cam.pitch_min = float(_ajustes.get("camera_pitch_min_deg", 10.0))
	cam.pitch_max = float(_ajustes.get("camera_pitch_max_deg", 65.0))
	cam._set_home(centro, dist, float(_ajustes.get("camera_min_distance", 2.0)),
		maxf(dist, todo.size.length() * 1.3), todo.size.length() * 0.6)
	cam.snap()


func _montar_ayuda() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 2
	add_child(capa)
	var l := Label.new()
	l.text = "PREVIEW DE ASSETS  ·  Tab: catálogo / diorama  ·  arrastra: girar  ·  rueda: zoom  ·  L: luz inicio/final"
	l.add_theme_font_override("font", UiTheme.FONT)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	l.add_theme_color_override("font_outline_color", UiTheme.BLUE_DEEP)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(18, 12)
	capa.add_child(l)


func _leer_argumentos() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		var v := kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"vista": mostrar(v)
			"capture": _capture = v
			"capture-after": _capture_after = float(v)
			"yaw": cam.yaw = float(v)
			"pitch": cam.pitch = float(v)
			"zoom": cam.distance *= float(v)
			"luz": _poner_luz(v != "inicio")
			"informe": _informe()
	cam.snap()


## (--informe) Dónde ha quedado cada pieza del catálogo y hacia dónde mira la cámara.
func _informe() -> void:
	for c in contenido.get_children():
		if c is Node3D and not c.is_queued_for_deletion():
			var b := Visuals.global_aabb(c)
			print("PIEZA %-28s centro %s  tamaño %s" % [c.name, b.get_center().snapped(Vector3.ONE * 0.01), b.size.snapped(Vector3.ONE * 0.01)])
	print("CAMARA centro %s  posición %s" % [cam.center, cam.cam.global_position])


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		match (e as InputEventKey).physical_keycode:
			KEY_L: _poner_luz(not _luz_final)
			KEY_TAB: mostrar("catalogo" if vista == "diorama" else "diorama")


func _process(delta: float) -> void:
	# Lo que hace el rig de luz con el nivel: girar con la cámara y ajustar el alcance de la sombra.
	_rig.rotation.y = cam.cam.global_rotation.y * float(_rig.get("seguir_camara"))
	if _sol != null:
		var caja := _props_caja if vista == "catalogo" else Visuals.global_aabb(diorama)
		var alcance := cam.cam.global_position.distance_to(cam.center) + caja.size.length() * float(_rig.get("margen_sombra"))
		_sol.directional_shadow_max_distance = clampf(alcance, 4.0, 40.0)
	_t += delta
	if _capture != "" and _t >= _capture_after:
		var img := get_viewport().get_texture().get_image()
		var out := ProjectSettings.globalize_path("res://" + _capture)
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var err := img.save_png(out)
		print("CAPTURA %s %dx%d err=%d" % [out, img.get_width(), img.get_height(), err])
		_capture = ""
		Sfx.quit()


func _caja(n: Node3D) -> AABB:
	return Visuals.global_aabb(n)


func _caja_de(nodos: Array[Node3D]) -> AABB:
	var out := AABB()
	for i in nodos.size():
		out = _caja(nodos[i]) if i == 0 else out.merge(_caja(nodos[i]))
	return out


func _ficheros(dir: String, exts: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_ficheros(dir + "/" + sub, exts))
	for f in d.get_files():
		if f.get_extension().to_lower() in exts:
			out.append(dir + "/" + f)
	return out


func _mallas(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_mallas(c))
	return out
