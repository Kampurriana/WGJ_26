// Contorno dorado que late alrededor de lo que llama la atención (el mueble que guarda algo, o el
// objeto ya a la vista). Va en una copia un poco más grande de cada malla de la que solo se pintan
// las caras de atrás: lo único que asoma es un borde por fuera de la silueta. Se lee sobre madera
// clara y sobre fondo oscuro (el brillo que suma luz, solo, no se veía sobre la madera).
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_mix;

uniform vec4 color : source_color = vec4(1.0, 0.84, 0.45, 1.0);

void fragment() {
	float late = 0.5 + 0.5 * sin(TIME * 3.2);
	ALBEDO = color.rgb * (0.9 + 0.25 * late);
	ALPHA = color.a * (0.7 + 0.3 * late);
}
