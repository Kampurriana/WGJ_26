// Silueta de una pieza que falta (el "hueco" donde va). Todas se ven desde el principio:
//  - disponible (bloqueada = 0): casi blanca, con un toque del color de su acto;
//  - bloqueada (bloqueada = 1, aún no toca): más tenue y del color de su acto, para que cada zona
//    se distinga de las otras.
// pulse = 1.0 la hace latir (la pista, o al arrastrar la pieza que va ahí).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);   // color del acto
uniform float base_alpha = 0.55;
uniform float pulse = 0.0;
uniform float aparicion = 1.0;   // 0 -> 1: aparece con un fundido
uniform float bloqueada = 0.0;   // 1 = aún no toca (tenue y del color del acto); 0 = ya se puede poner

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float wave = 0.5 + 0.5 * sin(TIME * 4.0);
	vec3 ready = mix(vec3(1.0), tint.rgb, 0.3);
	vec3 locked = tint.rgb * 0.9;
	ALBEDO = mix(ready, locked, bloqueada);
	float a = base_alpha + rim * 0.45 + pulse * wave * 0.5;
	a *= mix(1.0, 0.4, bloqueada);
	ALPHA = clamp(a, 0.0, 1.0) * aparicion;
}
