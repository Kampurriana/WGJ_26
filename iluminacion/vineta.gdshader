// Viñeta: oscurece un poco las esquinas de la imagen (encima del 3D y debajo de la interfaz).
// Ayuda a que la vista vaya al centro del diorama. fuerza 0 = sin viñeta.
shader_type canvas_item;

uniform float fuerza : hint_range(0.0, 1.0) = 0.4;
uniform float suavidad : hint_range(0.1, 1.0) = 0.55;

void fragment() {
	vec2 d = UV - vec2(0.5);
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float v = smoothstep(0.85 - suavidad, 0.95, length(d) * 1.25);
	COLOR = vec4(0.0, 0.0, 0.0, v * fuerza);
}
