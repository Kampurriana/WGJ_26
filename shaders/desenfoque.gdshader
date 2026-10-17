// Enfoque de cine (postproceso): todo un poco desdibujado y, fuera de la zona de foco (una elipse
// que sigue a lo importante), más desenfocado, como una maqueta fotografiada con poca profundidad
// de campo. Lee la pantalla ya pintada (3D + fondo) y la difumina con 12 muestras en disco.
// Va por debajo de la interfaz: los textos y la bandeja no se desenfocan.
shader_type canvas_item;

uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;
uniform vec2 centro = vec2(640.0, 380.0);    // zona nítida, en coordenadas de la interfaz
uniform vec2 radio = vec2(460.0, 230.0);     // semiejes de la zona nítida
uniform float suave = 0.8;                   // transición (fracción del radio)
uniform float fuera = 2.4;                   // radio del desenfoque lejos del foco (px)
uniform float dentro = 0.45;                 // desenfoque leve en todo (px)
uniform vec2 tam = vec2(1280.0, 720.0);      // tamaño del rectángulo (lo pone el código)

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
	COLOR = vec4(c.rgb / 13.0, 1.0);
}
