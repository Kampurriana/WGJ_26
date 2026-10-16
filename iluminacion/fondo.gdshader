// Fondo oscuro con un halo cálido detrás del diorama. Va en una capa 2D por DETRÁS del 3D
// (el Ambiente usa "Background → Mode: Canvas"). Colores y tamaño, en el Inspector.
shader_type canvas_item;

uniform vec4 color_centro : source_color = vec4(0.17, 0.115, 0.08, 1.0);
uniform vec4 color_borde : source_color = vec4(0.025, 0.02, 0.018, 1.0);
uniform vec2 centro = vec2(0.44, 0.52);      // dónde está el halo (0-1 de la pantalla)
uniform float radio : hint_range(0.1, 2.0) = 0.62;

void fragment() {
	vec2 d = UV - centro;
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;   // círculo, no óvalo
	float t = smoothstep(0.0, radio, length(d));
	COLOR = vec4(mix(color_centro.rgb, color_borde.rgb, t), 1.0);
}
