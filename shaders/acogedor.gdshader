// Fondo del final (la hucha y la moneda, cuarta nota: "mucho más cozy"): un degradado cálido, como
// una habitación a la luz de una lámpara, con luces desenfocadas (bokeh de guirnalda) que flotan
// despacio y titilan. Va en una capa 2D por DETRÁS del 3D (fondo por capa) y pasa por el tonemap:
// los colores van más altos de lo que parece (trampa 17).
shader_type canvas_item;

uniform float alpha = 0.0;                   // 0 = no se ve; 1 = el fondo entero
uniform float brillo = 1.0;                  // las luces se avivan un momento al entrar la moneda
uniform vec2 tam = vec2(1280.0, 720.0);      // tamaño del rectángulo (lo pone el código)
uniform vec4 color_centro : source_color = vec4(0.42, 0.25, 0.13, 1.0);
uniform vec4 color_borde : source_color = vec4(0.07, 0.04, 0.03, 1.0);

const int LUCES = 18;

float azar(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	float aspect = tam.x / max(tam.y, 1.0);
	vec2 p = (UV - vec2(0.5, 0.46)) * vec2(aspect, 1.0);
	float r = length(p);
	vec3 col = mix(color_centro.rgb, color_borde.rgb, smoothstep(0.0, 0.95, r));
	for (int i = 0; i < LUCES; i++) {
		float fi = float(i);
		vec2 c = vec2(azar(fi + 1.0) * 1.1 - 0.05, azar(fi + 7.3) * 0.9 + 0.05);
		c += vec2(cos(TIME * 0.05 + fi * 1.7) * 0.02, sin(TIME * 0.07 + fi) * 0.025);   // flotan despacio
		float size = mix(0.025, 0.075, azar(fi + 3.1));
		float d = length((UV - c) * vec2(aspect, 1.0));
		float disco = smoothstep(size, size * 0.8, d);
		float borde = disco * smoothstep(size * 0.55, size, d);   // el borde un poco más vivo, como un bokeh
		float titila = 0.6 + 0.4 * sin(TIME * (0.4 + azar(fi + 5.0) * 0.5) + fi * 2.3);
		vec3 tono = mix(vec3(1.0, 0.55, 0.22), vec3(1.0, 0.8, 0.45), azar(fi + 9.0));
		float lejos = smoothstep(0.12, 0.5, length((c - vec2(0.5, 0.46)) * vec2(aspect, 1.0)));   // detrás de la hucha, menos
		col += tono * (disco * 0.22 + borde * 0.14) * titila * brillo * (0.35 + 0.65 * lejos);
	}
	COLOR = vec4(col, alpha);
}
