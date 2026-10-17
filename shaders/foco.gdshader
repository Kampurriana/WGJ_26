// Foco de los momentos de la historia: oscurece la pantalla alrededor de una elipse que sigue al
// objeto (como un cañón de teatro). fuerza = 0 no hace nada; 1 = del todo (el espejo, en negro).
// Sexta nota: oscuro pero del tono del fondo (color; lo pone Momentos) y muy degradado, sin borde:
// empieza a oscurecer ya dentro de la elipse (dentro < 1) y acaba lejos (1 + suave).
shader_type canvas_item;

uniform vec2 centro = vec2(640.0, 360.0);    // en coordenadas de la interfaz (las de unproject_position)
uniform vec2 radio = vec2(220.0, 220.0);     // semiejes de la elipse, en píxeles
uniform float suave = 0.35;                  // hasta dónde llega el degradado (fracción del radio, fuera)
uniform float dentro = 1.0;                  // dónde empieza (fracción del radio)
uniform float fuerza = 0.0;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 tam = vec2(1280.0, 720.0);      // tamaño del rectángulo (lo pone el código)

void fragment() {
	vec2 p = UV * tam;
	float d = length((p - centro) / max(radio, vec2(1.0)));
	float a = smoothstep(dentro, 1.0 + suave, d);
	COLOR = vec4(color.rgb, a * fuerza);
}
