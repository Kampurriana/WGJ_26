// Silueta blanca de una pieza que falta (el "hueco" donde va).
// pulse = 1.0 la hace latir (lo usa la pista).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float base_alpha = 0.55;
uniform float pulse = 0.0;
uniform float aparicion = 1.0;   // 0 -> 1 cuando la pieza se desbloquea (aparece con un fundido)

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float wave = 0.5 + 0.5 * sin(TIME * 4.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp(base_alpha + rim * 0.45 + pulse * wave * 0.5, 0.0, 1.0) * aparicion;
}
