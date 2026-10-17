extends SceneTree
## Calcula los colores "_3d" de ui/fondos.gd: qué hay que meter en el fondo del 3D para que, tras el
## tonemap y el resplandor de la luz del desván, se vea en pantalla el pastel que se eligió (centro,
## borde, forma). Busca cada uno por tanteo medido (12 pasos, leyendo el píxel). Necesita ventana:
##   xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --resolution 1280x720 --script res://tools/calibrar_fondo.gd
## Imprime una línea por color, lista para copiar en Fondos.COLORES. Hay que repetirlo si cambia la
## luz (iluminacion/desvan.tscn: tonemap, resplandor) o si se añade un color.

const LIGHT := "res://iluminacion/desvan.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.use_hdr_2d = true                       # como en el juego (main.gd)
	var light: Node = load(LIGHT).instantiate()
	root.add_child(light)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 0, 10)
	(light.get_node("Vineta") as CanvasLayer).hide()
	var mat := (light.get_node("Fondo/Degradado") as CanvasItem).material as ShaderMaterial
	mat.set_shader_parameter("exposicion", 1.0)
	mat.set_shader_parameter("saturacion", 1.0)
	mat.set_shader_parameter("color_forma", Color(0, 0, 0, 0))
	for c: Dictionary in Fondos.COLORES:
		var out := []
		for key: String in ["centro", "borde", "forma"]:
			out.append(await _solve(mat, c[key]))
		print("%s: \"centro_3d\": %s, \"borde_3d\": %s, \"forma_3d\": %s" % [c.nombre, _fmt(out[0]), _fmt(out[1]), _fmt(out[2])])
	quit()


func _solve(mat: ShaderMaterial, target: Color) -> Color:
	var inp := target
	for i in 12:
		mat.set_shader_parameter("color_centro", inp)
		mat.set_shader_parameter("color_borde", inp)
		for f in 3:
			await process_frame
		var seen := root.get_texture().get_image().get_pixel(640, 360)
		inp = Color(clampf(inp.r * pow(target.r / maxf(seen.r, 0.001), 1.2), 0.0, 4.0),
			clampf(inp.g * pow(target.g / maxf(seen.g, 0.001), 1.2), 0.0, 4.0),
			clampf(inp.b * pow(target.b / maxf(seen.b, 0.001), 1.2), 0.0, 4.0))
	return inp


static func _fmt(c: Color) -> String:
	return "Color(%.3f, %.3f, %.3f)" % [c.r, c.g, c.b]
