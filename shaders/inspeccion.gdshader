// Fondo de la inspección de un dibujo encontrado (ui/inspeccion.gd): el juego queda detrás, apagado
// con un oscuro del tono del fondo; detrás del dibujo, un halo más claro y unos rayos suaves que
// giran despacio (como el aviso de "badge" de la referencia de la sexta nota).
shader_type canvas_item;

uniform vec4 color : source_color = vec4(0.16, 0.2, 0.3, 1.0);
uniform float alpha = 0.0;                   // 0 = no se ve (se abre y se cierra con esto)
uniform vec2 tam = vec2(1280.0, 720.0);      // tamaño del rectángulo (lo pone el código)
uniform vec2 centro = vec2(0.5, 0.48);       // dónde está el dibujo (UV)

void fragment() {
	vec2 p = (UV - centro) * vec2(tam.x / max(tam.y, 1.0), 1.0);
	float r = length(p);
	float ang = atan(p.y, p.x);
	float rays = smoothstep(0.55, 1.0, 0.5 + 0.5 * sin(ang * 14.0 + TIME * 0.2));
	rays *= 1.0 - smoothstep(0.08, 0.62, r);
	float halo = 1.0 - smoothstep(0.0, 0.45, r);
	vec3 c = color.rgb * (1.0 + 0.8 * halo) + vec3(0.05) * rays;
	COLOR = vec4(c, alpha * (0.94 - 0.2 * halo));
}
