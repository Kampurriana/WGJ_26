// Fondo del juego (quinta nota): un color pastel con una forma repetida (estrellas) en filas
// DIAGONALES (la rejilla va girada), que se desplaza entera sin fin en diagonal. La forma es del mismo tono, un poco
// más oscura. Un halo suave más claro detrás del diorama. Va en una capa 2D por DETRÁS del 3D (el
// Ambiente usa "Background → Mode: Canvas") y pasa por el tonemap: los colores salen algo más
// apagados de lo que pone aquí (trampa 17). Colores, tamaño y velocidad, en el Inspector.
shader_type canvas_item;

uniform vec4 color_centro : source_color = vec4(0.86, 0.9, 0.98, 1.0);   // el pastel, detrás del diorama
uniform vec4 color_borde : source_color = vec4(0.74, 0.8, 0.92, 1.0);    // y hacia los bordes
uniform vec2 centro = vec2(0.44, 0.52);      // dónde está el halo (0-1 de la pantalla)
uniform float radio : hint_range(0.1, 2.0) = 0.85;
uniform vec4 color_forma : source_color = vec4(0.95, 0.97, 1.0, 0.35);   // la forma (alfa = cuánto se nota)
uniform int forma : hint_range(0, 2) = 0;    // 0 estrella · 1 círculo · 2 corazón
uniform float tam_forma : hint_range(20.0, 300.0) = 190.0;  // separación del patrón (px a 720 de alto)
uniform float tam_figura : hint_range(0.05, 0.45) = 0.2;    // tamaño de cada figura (fracción de la separación)
uniform float angulo_patron : hint_range(-1.6, 1.6) = 0.785;   // giro de la rejilla: 0,785 rad = 45º (filas en diagonal)
uniform float velocidad : hint_range(0.0, 200.0) = 18.0;    // px por segundo, en diagonal
uniform float giro : hint_range(-3.2, 3.2) = 0.25;          // giro de cada figura (rad)
// El tonemap del 3D apaga y agrisa el fondo (trampa 17): esto lo compensa para que en pantalla
// salga el pastel que se eligió (medido con capturas: tools/medir_luz.py no hace falta, basta un píxel).
uniform float exposicion : hint_range(0.5, 3.0) = 1.0;
uniform float saturacion : hint_range(0.0, 4.0) = 1.0;

float sd_estrella(vec2 p, float r) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-0.809016994375, -0.587785252292);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = 0.45 * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

float sd_corazon(vec2 p, float r) {
	p /= r * 1.1;
	p.y = p.y + 0.55;                            // la punta abajo (c ya viene con y hacia arriba)
	p.x = abs(p.x);
	float d;
	if (p.y + p.x > 1.0) {
		d = sqrt(dot(p - vec2(0.25, 0.75), p - vec2(0.25, 0.75))) - sqrt(2.0) / 4.0;
	} else {
		d = sqrt(min(dot(p - vec2(0.0, 1.0), p - vec2(0.0, 1.0)),
			dot(p - 0.5 * max(p.x + p.y, 0.0), p - 0.5 * max(p.x + p.y, 0.0)))) * sign(p.x - p.y);
	}
	return d * r * 1.1;
}

void fragment() {
	vec2 d = UV - centro;
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;   // círculo, no óvalo
	vec3 base = mix(color_centro.rgb, color_borde.rgb, smoothstep(0.0, radio, length(d)));
	// El patrón, en píxeles "de 720" (igual en cualquier resolución), desplazándose en diagonal.
	vec2 p = UV * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0) * 720.0;
	// La rejilla, girada: sus filas van en diagonal; y todo el patrón avanza a lo largo de una de
	// ellas (se mueve en conjunto, sin que cambie la disposición).
	mat2 a = mat2(vec2(cos(angulo_patron), sin(angulo_patron)), vec2(-sin(angulo_patron), cos(angulo_patron)));
	vec2 q = transpose(a) * p;
	q.x += TIME * velocidad;
	vec2 g = q / tam_forma;                      // misma separación en las dos diagonales
	vec2 c = (fract(g) - 0.5) * tam_forma;
	c = a * c;                                   // la figura, derecha en pantalla...
	c = mat2(vec2(cos(giro), sin(giro)), vec2(-sin(giro), cos(giro))) * c;   // ...con un pelín de giro
	c.y = -c.y;                                  // la estrella, con la punta hacia arriba
	float r = tam_figura * tam_forma * 0.85;
	float sd;
	if (forma == 1) {
		sd = length(c) - r * 0.75;
	} else if (forma == 2) {
		sd = sd_corazon(c, r);
	} else {
		sd = sd_estrella(c, r) - r * 0.12;       // puntas redondeadas
	}
	float k = 1.0 - smoothstep(-0.8, 0.8, sd);
	vec3 col = mix(base, color_forma.rgb, k * color_forma.a);
	float gris = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(gris), col, saturacion) * exposicion;
	COLOR = vec4(col, 1.0);
}
