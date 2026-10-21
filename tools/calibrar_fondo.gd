extends SceneTree
## Calcula qué color hay que meter en el fondo del 3D para que en pantalla se vea el pastel que eligió el
## jugador (Fondos.COLORES: centro, borde, forma, "tal como se ven"). Ese fondo pasa por TODO lo que ve el
## jugador: el tonemap, el resplandor y los ajustes de su escena de luz, y el postproceso de cine
## (shaders/desenfoque.gdshader, que dora las luces: sin contarlo, el azul salía gris y cálido; 21-oct,
## trampa 54). Lo busca por tanteo medido (16 pasos, leyendo el píxel del centro) para cada escena de luz
## de iluminacion/ que tiene fondo, y lo deja en data/fondo_calibrado.json (lo lee Fondos.apply).
## Necesita ventana:
##   xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --resolution 320x180 --script res://tools/calibrar_fondo.gd
## (una ventana pequeña da lo mismo, el fondo es liso, y va mucho más deprisa: lee la pantalla en cada paso)
## Hay que repetirlo si cambia una luz (tonemap, resplandor, ajustes), el etalonaje del postproceso o los
## colores, o si se añade una escena de luz. Sin ventana no mide (trampa 41).

const LIGHTS := "res://iluminacion/"
const POST := "res://shaders/desenfoque.gdshader"
const STEPS := 16


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.use_hdr_2d = true                       # como en el juego (main.gd)
	var out := {}
	for file in DirAccess.get_files_at(LIGHTS):
		if file.get_extension() != "tscn":
			continue
		var light: Node = load(LIGHTS + file).instantiate()
		var bg := light.get_node_or_null("Fondo/Degradado") as CanvasItem
		if bg == null:
			light.free()
			continue
		root.add_child(light)
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.position = Vector3(0, 0, 100)        # (nada del 3D delante: solo el fondo)
		cam.current = true
		var vignette := light.get_node_or_null("Vineta") as CanvasLayer
		if vignette != null:
			vignette.hide()
		var post := _post()
		root.add_child(post)
		var mat := bg.material as ShaderMaterial
		mat.set_shader_parameter("exposicion", 1.0)
		mat.set_shader_parameter("saturacion", 1.0)
		mat.set_shader_parameter("color_forma", Color(0, 0, 0, 0))
		var colors := []
		for c: Dictionary in Fondos.COLORES:
			var entry := {}
			var worst := 0.0
			for key: String in ["centro", "borde", "forma"]:
				var got: Array = await _solve(mat, c[key])
				entry[key] = [snappedf(got[0].r, 0.001), snappedf(got[0].g, 0.001), snappedf(got[0].b, 0.001)]
				worst = maxf(worst, got[1])
			colors.append(entry)
			print("%-22s %-10s se ve a %.0f/255 como mucho del pastel" % [file, c.nombre, worst * 255.0])
		out[file.get_basename()] = colors
		light.queue_free()
		cam.queue_free()
		post.queue_free()
		await process_frame
	var lights := PackedStringArray()             # (una línea por color: se lee y se compara a mano)
	for light: String in out:
		var rows := PackedStringArray()
		for e: Dictionary in out[light]:
			rows.append("\t\t" + JSON.stringify(e))
		lights.append("\t\"%s\": [\n%s\n\t]" % [light, ",\n".join(rows)])
	var f := FileAccess.open(Fondos.CALIBRATED, FileAccess.WRITE)
	f.store_string("{\n" + ",\n".join(lights) + "\n}\n")
	f.close()
	print("FONDO OK (%d luces) -> %s" % [out.size(), Fondos.CALIBRATED])
	quit()


## El postproceso como en el juego (core/enfoque.gd), sin el grano (se mide un solo píxel).
func _post() -> CanvasLayer:
	var layer := CanvasLayer.new()
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = load(POST)
	m.set_shader_parameter("dentro", 0.45)
	m.set_shader_parameter("grano", 0.0)
	var size := root.get_visible_rect().size
	m.set_shader_parameter("centro", size * 0.5)
	m.set_shader_parameter("tam", size)
	rect.material = m
	layer.add_child(rect)
	return layer


## [lo que hay que meter, lo más que se aleja en pantalla del objetivo (0..1)].
func _solve(mat: ShaderMaterial, target: Color) -> Array:
	var inp := target
	var seen := Color.BLACK
	for i in STEPS:
		mat.set_shader_parameter("color_centro", inp)
		mat.set_shader_parameter("color_borde", inp)
		for f in 3:
			await process_frame
		var img := root.get_texture().get_image()      # (la imagen va a la resolución de la ventana)
		seen = img.get_pixel(img.get_width() / 2, img.get_height() / 2)
		inp = Color(clampf(inp.r * pow(target.r / maxf(seen.r, 0.001), 1.2), 0.0, 4.0),
			clampf(inp.g * pow(target.g / maxf(seen.g, 0.001), 1.2), 0.0, 4.0),
			clampf(inp.b * pow(target.b / maxf(seen.b, 0.001), 1.2), 0.0, 4.0))
	var miss := maxf(absf(seen.r - target.r), maxf(absf(seen.g - target.g), absf(seen.b - target.b)))
	return [inp, miss]
