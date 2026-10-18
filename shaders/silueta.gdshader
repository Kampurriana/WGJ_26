shader_type canvas_item;
// La silueta de una pieza del logo, engordada (ui/logo.gd): con las de todas las piezas se hace la
// pegatina blanca que las une en una sola, y su sombra. El rectángulo es más grande que la pieza
// (`margen`, en fracción de la pieza por cada lado) para que quepa lo que engorda.

uniform vec4 color : source_color = vec4(1.0);
uniform vec2 margen = vec2(0.1, 0.1);
uniform vec2 radio = vec2(0.02, 0.02);       // cuánto engorda (fracción de la pieza)
uniform float borroso = 1.0;                 // nivel de mipmap con el que se lee (más = más suave)
uniform float corte = 0.35;                  // dónde se corta el borde (más bajo = más gordo)

void fragment() {
	vec2 uv = UV * (1.0 + 2.0 * margen) - margen;
	float a = 0.0;
	for (int i = 0; i < 33; i++) {           // el centro y dos anillos de 16: engorda sin dejar huecos
		vec2 p = uv;
		if (i > 0) {
			float ang = float((i - 1) % 16) * 0.3927;
			p += vec2(cos(ang), sin(ang)) * radio * (i <= 16 ? 1.0 : 0.5);
		}
		float dentro = step(0.0, p.x) * step(0.0, p.y) * step(p.x, 1.0) * step(p.y, 1.0);
		a = max(a, dentro * textureLod(TEXTURE, clamp(p, vec2(0.0), vec2(1.0)), borroso).a);
	}
	COLOR = vec4(color.rgb, color.a * smoothstep(corte - 0.2, corte + 0.2, a));
}
