// Aro que se abre en el suelo al encajar una pieza (Efectos): con la forma de la planta de la pieza (un
// rectángulo de esquinas redondas del tamaño `tam`, en metros; un tablón da un aro alargado) y de grosor
// fijo en metros (`grosor`), sea cual sea su forma. Plano, sin luz, aditivo y sin niebla (la niebla de la
// luz de la tarde teñía el plano entero y se veía un cuadrado). fuerza la baja el código de 1 a 0
// mientras el aro crece.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float fuerza = 1.0;
uniform vec2 tam = vec2(1.0);
uniform float grosor = 0.05;

void fragment() {
	vec2 p = (UV - 0.5) * tam;
	float r = min(min(tam.x, tam.y) * 0.5, grosor * 4.0);      // radio de las esquinas
	vec2 q = abs(p) - (tam * 0.5 - vec2(grosor + r));
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;   // < 0 dentro
	float aro = 1.0 - smoothstep(0.0, grosor, abs(d));
	ALBEDO = color.rgb * 1.1;
	ALPHA = aro * fuerza;
}
