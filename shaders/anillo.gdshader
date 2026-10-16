// Anillo que se abre en el suelo al encajar una pieza (Efectos). Plano, sin luz, aditivo.
// fuerza la baja el código de 1 a 0 mientras el anillo crece.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float fuerza = 1.0;
uniform float grosor = 0.08;

void fragment() {
	float d = distance(UV, vec2(0.5)) * 2.0;
	float aro = smoothstep(1.0 - grosor * 2.0, 1.0 - grosor, d) * (1.0 - smoothstep(1.0 - grosor * 0.5, 1.0, d));
	ALBEDO = color.rgb * 1.1;
	ALPHA = aro * fuerza;
}
