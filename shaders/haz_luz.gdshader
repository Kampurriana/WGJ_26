// El haz de luz que entra por la ventana (core/luz_ventana.gd): un volumen de aire iluminado que se
// suma a lo que hay detrás (blend_add). La malla es un cubo de lado 1 que el nodo deforma en el prisma
// que dibuja la ventana al avanzar la luz: X e Y = el hueco de la ventana, Z = a lo largo de la luz
// (0 = la ventana, 1 = el suelo). Cada píxel recorre el rayo de la cámara dentro del prisma (10 pasos)
// y suma cuánta luz atraviesa: así se ve como un volumen (más denso donde se cruza más aire), con
// bordes suaves, que se apaga hacia el suelo y con rayos lentos, como la luz entre las hojas de una
// tarde de verano. Sin borde: la luz cae en campana desde el centro y nunca se ve la forma del prisma.
// Y sin niebla (fog_disabled): la niebla de la luz de la tarde se sumaba entera sobre la caja y se veía
// un rectángulo de bordes rectos contra la pared («cuadrado»). La profundidad de la escena no se puede
// leer aquí (en Compatibility llega a 1,0 en esta pasada; medido), así que no se recorta con ella.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.76, 0.48, 1.0);
uniform float fuerza = 1.6;             // luz que suma cada metro de haz atravesado
uniform float aparicion = 1.0;          // 0 = apagado (sin la ventana puesta)

uniform vec3 camara = vec3(0.0, 0.0, -3.0);   // la cámara en coordenadas del cubo (la pone el nodo)
uniform mat3 prisma = mat3(1.0);              // cubo -> mundo (para medir en metros)

varying vec3 local;

void vertex() {
	local = VERTEX;
}

// Ruido de valor 3D (suave): el aire no es igual de denso en todo el haz.
float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float ruido(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float densidad(vec3 q) {
	// El hueco es redondo (el ojo de buey del desván). Sin borde: la luz cae como una campana desde el
	// centro y llega a 0 antes del prisma, así nunca se ve su forma.
	vec2 c = (q.xy - 0.5) * 2.0;
	float r2 = dot(c, c);
	float edge = exp(-2.6 * r2) * (1.0 - smoothstep(0.55, 1.0, r2));
	// La cruz del marco deja dos franjas de sombra suaves a lo largo del haz.
	float cruz = mix(0.62, 1.0, smoothstep(0.02, 0.1, abs(c.x))) * mix(0.62, 1.0, smoothstep(0.02, 0.1, abs(c.y)));
	// Más fuerte junto a la ventana; entra despacio (el grueso de la pared no hace de borde) y se
	// apaga mucho antes del suelo.
	float along = smoothstep(0.0, 0.18, q.z) * (1.0 - smoothstep(0.08, 0.95, q.z));
	// Aire que se mueve: bultos lentos de polvo y unos rayos suaves que se mecen.
	float aire = 0.45 + 0.75 * ruido(vec3(q.x * 5.0, q.y * 5.0, q.z * 3.0) + vec3(TIME * 0.05, TIME * 0.03, -TIME * 0.04));
	float rays = 0.75 + 0.25 * sin(q.x * 17.0 + sin(q.y * 5.0 + TIME * 0.2) * 1.4 + TIME * 0.11);
	return edge * cruz * along * aire * rays;
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
