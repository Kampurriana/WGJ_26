// Viñeta: oscurece un poco las esquinas de la imagen (encima del 3D y debajo de la interfaz).
// Ayuda a que la vista vaya al centro del diorama. fuerza 0 = sin viñeta.
// Sexta nota: no negra, sino del tono del fondo, oscuro (color: lo pone main.gd con ui/fondos.gd,
// el del fondo que eligió el jugador), y un degradado largo y blando, sin borde que se note.
shader_type canvas_item;

uniform float fuerza : hint_range(0.0, 1.0) = 0.22;
uniform float suavidad : hint_range(0.1, 1.0) = 0.6;
uniform vec4 color : source_color = vec4(0.12, 0.15, 0.22, 1.0);

void fragment() {
	vec2 d = UV - vec2(0.5);
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float v = smoothstep(0.85 - suavidad, 1.45, length(d) * 1.25);
	COLOR = vec4(color.rgb, v * fuerza);
}
