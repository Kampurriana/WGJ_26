// Enfoque de cine (postproceso): todo un poco desdibujado y, fuera de la zona de foco (una elipse
// que sigue a lo importante), más desenfocado, como una maqueta fotografiada con poca profundidad
// de campo. Lee la pantalla ya pintada (3D + fondo) y la difumina con 12 muestras en disco.
// Va por debajo de la interfaz: los textos y la bandeja no se desenfocan.
// Y el acabado de cine (18-oct, "lo más cinematográfico posible"), en la misma pasada: aberración
// cromática hacia las esquinas, etalonaje cálido (sombras un pelín frías, luces doradas), un levantado
// suave de los negros y grano de película que se mueve.
shader_type canvas_item;

uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;
uniform vec2 centro = vec2(640.0, 380.0);    // zona nítida, en coordenadas de la interfaz
uniform vec2 radio = vec2(460.0, 230.0);     // semiejes de la zona nítida
uniform float suave = 0.8;                   // transición (fracción del radio)
uniform float fuera = 2.4;                   // radio del desenfoque lejos del foco (px)
uniform float dentro = 0.45;                 // desenfoque leve en todo (px)
uniform vec2 tam = vec2(1280.0, 720.0);      // tamaño del rectángulo (lo pone el código)
uniform float aberracion = 1.6;              // px de separación de colores en las esquinas
uniform vec3 tinte_sombras = vec3(0.97, 0.98, 1.04);
uniform vec3 tinte_luces = vec3(1.045, 1.0, 0.93);
uniform float negros = 0.018;                // levantado de los negros (película)
uniform float grano = 0.028;

const vec2 DISCO[12] = {
	vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457), vec2(-0.203, 0.621),
	vec2(0.962, -0.195), vec2(0.473, -0.480), vec2(0.519, 0.767), vec2(0.185, -0.893),
	vec2(0.507, 0.064), vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598)
};

void fragment() {
	vec2 p = UV * tam;
	float d = length((p - centro) / max(radio, vec2(1.0)));
	float r = mix(dentro, fuera, smoothstep(1.0, 1.0 + suave, d));
	vec2 step_px = SCREEN_PIXEL_SIZE * r;
	vec4 c = texture(pantalla, SCREEN_UV);
	for (int i = 0; i < 12; i++) {
		c += texture(pantalla, SCREEN_UV + DISCO[i] * step_px);
	}
	vec3 col = c.rgb / 13.0;
	// Aberración: el rojo y el azul se separan un poco hacia fuera, solo lejos del centro.
	vec2 off = SCREEN_UV - 0.5;
	vec2 ca = off * dot(off, off) * 4.0 * SCREEN_PIXEL_SIZE * aberracion * 2.0;
	col.r = mix(col.r, texture(pantalla, SCREEN_UV + ca).r, 0.85);
	col.b = mix(col.b, texture(pantalla, SCREEN_UV - ca).b, 0.85);
	// Etalonaje: sombras algo frías, luces doradas (la tarde de verano), negros de película.
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col *= mix(tinte_sombras, tinte_luces, smoothstep(0.15, 0.85, l));
	col = negros + col * (1.0 - negros);
	// Grano: ruido que cambia cada fotograma, más en los tonos medios.
	float n = fract(sin(dot(floor(p) + fract(TIME * 7.3) * 91.7, vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grano * (1.0 - abs(l - 0.5) * 1.2);
	COLOR = vec4(col, 1.0);
}
