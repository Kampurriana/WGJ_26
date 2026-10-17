// La "versión blanca" de una pieza que falta, en su hueco (como en Woodo): blanca, opaca e
// iluminada por la escena, con un borde que se enciende un poco hacia los cantos. Al ser opaca, varias
// siluetas que se solapan se leen como objetos (la translúcida de antes se mezclaba y costaba verlas).
//  - bloqueada = 1: aún no se puede poner (le falta una anterior): gris y sin borde.
//  - pulse = 1: late (la pista, o mientras se arrastra la pieza que va ahí).
//  - aparicion 0 -> 1: se materializa con una trama (al abrirse su sección).
// Un pelo más pequeña que la pieza: al encajarla, la de verdad la tapa entera (sin parpadeo).
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.94, 0.93, 0.91, 1.0);
uniform float pulse = 0.0;
uniform float aparicion = 1.0;
uniform float bloqueada = 0.0;

void vertex() {
	VERTEX -= NORMAL * 0.0015;
}

void fragment() {
	// Trama fija en pantalla: al aparecer, los puntos se van encendiendo.
	float n = fract(sin(dot(floor(FRAGCOORD.xy * 0.5), vec2(12.9898, 78.233))) * 43758.5453);
	if (n > aparicion) {
		discard;
	}
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float wave = 0.5 + 0.5 * sin(TIME * 4.0);
	vec3 grey = vec3(0.56, 0.55, 0.54);
	ALBEDO = mix(tint.rgb, grey, bloqueada);
	ROUGHNESS = 0.8;
	SPECULAR = 0.3;
	// Un poco de luz propia: sobre el fondo oscuro y la madera, la silueta siempre se distingue.
	EMISSION = vec3(1.0, 0.97, 0.92) * ((0.32 + rim * 0.3) * (1.0 - 0.7 * bloqueada) + pulse * wave * 0.35);
}
