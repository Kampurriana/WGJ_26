// Brillo de "aquí hay algo": un borde cálido que late sobre un mueble que guarda el siguiente objeto
// (o sobre el objeto, si ya se ve). Va en una copia de cada malla, encima, sumando luz.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform vec4 color : source_color = vec4(1.0, 0.76, 0.38, 1.0);
uniform float fuerza = 1.0;
uniform float grosor = 0.004;      // cuánto se hincha la copia (m)

void vertex() {
	VERTEX += NORMAL * grosor;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float late = 0.5 + 0.5 * sin(TIME * 3.2);
	// Todo el mueble se templa un poco (en una caja, el borde solo no se ve de frente) y el borde más.
	ALBEDO = color.rgb * (0.14 + 0.2 * late + rim * (0.55 + 0.6 * late)) * fuerza;
}
