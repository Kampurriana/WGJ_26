// El haz de luz que entra por la ventana (core/luz_ventana.gd): un volumen de aire iluminado que se
// suma a lo que hay detrás (blend_add). La malla es un cubo de lado 1 que el nodo deforma en el prisma
// que dibuja la ventana al avanzar la luz: X e Y = el hueco de la ventana, Z = a lo largo de la luz
// (0 = la ventana, 1 = el suelo). Cada píxel recorre el rayo de la cámara dentro del prisma (10 pasos)
// y suma cuánta luz atraviesa: así se ve como un volumen (más denso donde se cruza más aire), con
// bordes suaves, que se apaga hacia el suelo y con rayos lentos, como la luz entre las hojas de una
// tarde de verano.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.76, 0.48, 1.0);
uniform float fuerza = 0.16;            // luz que suma cada metro de haz atravesado
uniform float aparicion = 1.0;          // 0 = apagado (sin la ventana puesta)

uniform vec3 camara = vec3(0.0, 0.0, -3.0);   // la cámara en coordenadas del cubo (la pone el nodo)
uniform mat3 prisma = mat3(1.0);              // cubo -> mundo (para medir en metros)

varying vec3 local;

void vertex() {
	local = VERTEX;
}

float densidad(vec3 q) {
	// El hueco es redondo (el ojo de buey del desván): sección circular, de borde suave.
	vec2 c = (q.xy - 0.5) * 2.0;
	float edge = 1.0 - smoothstep(0.62, 0.98, length(c));
	// La cruz del marco deja dos franjas de sombra a lo largo del haz.
	float cruz = mix(0.45, 1.0, smoothstep(0.02, 0.07, abs(c.x))) * mix(0.45, 1.0, smoothstep(0.02, 0.07, abs(c.y)));
	float along = smoothstep(0.0, 0.06, q.z) * (1.0 - smoothstep(0.3, 1.0, q.z));
	// Rayos: franjas a lo largo de la luz que se mecen despacio.
	float w = sin(q.y * 6.0 + TIME * 0.21) * 1.3;
	float rays = 0.55 + 0.45 * sin(q.x * 21.0 + w + TIME * 0.13) * sin(q.x * 9.0 - q.y * 11.0 - TIME * 0.09);
	return edge * cruz * along * rays;
}

void fragment() {
	// El píxel está en t = 1 del rayo cámara -> local. Entrada y salida del rayo en el cubo [-0,5, 0,5]³:
	// solo pinta la cara por la que entra (una capa por píxel, por delante de lo que haya dentro), o la
	// de salida si la cámara está dentro del haz.
	vec3 rd = local - camara;
	vec3 t1 = (vec3(-0.5) - camara) / rd;
	vec3 t2 = (vec3(0.5) - camara) / rd;
	vec3 tn = min(t1, t2);
	vec3 tf = max(t1, t2);
	float t_in = max(max(tn.x, tn.y), tn.z);
	float t_out = min(min(tf.x, tf.y), tf.z);
	bool dentro = t_in < 0.0;
	if (!dentro && abs(1.0 - t_in) > abs(1.0 - t_out)) {
		discard;
	}
	t_in = max(t_in, 0.0);
	vec3 a = camara + rd * t_in;
	vec3 seg = rd * (t_out - t_in);
	float metros = length(prisma * seg);
	float suma = 0.0;
	for (int i = 0; i < 12; i++) {
		suma += densidad(a + seg * ((float(i) + 0.5) / 12.0) + 0.5);
	}
	suma *= metros / 12.0;
	// La luz va en el color y no en ALPHA: en Compatibility, blend_add suma el color entero (ALPHA = 1
	// da lo mismo con cualquier modo de mezcla).
	ALBEDO = color.rgb * clamp(suma * fuerza * aparicion, 0.0, 1.0);
	ALPHA = 1.0;
}
