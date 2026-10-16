// Foco de los momentos de la historia: oscurece la pantalla FUERA de una elipse que sigue al objeto
// (como un cañón de teatro). fuerza = 0 no hace nada; 1 = negro total fuera (el espejo).
shader_type canvas_item;

uniform vec2 centro = vec2(640.0, 360.0);    // en coordenadas de la interfaz (las de unproject_position)
uniform vec2 radio = vec2(220.0, 220.0);     // semiejes de la elipse, en píxeles
uniform float suave = 0.35;                  // borde difuminado (fracción del radio)
uniform float fuerza = 0.0;
uniform vec2 tam = vec2(1280.0, 720.0);      // tamaño del rectángulo (lo pone el código)

void fragment() {
	vec2 p = UV * tam;
	float d = length((p - centro) / max(radio, vec2(1.0)));
	float a = smoothstep(1.0, 1.0 + suave, d);
	COLOR = vec4(0.0, 0.0, 0.0, a * fuerza);
}
