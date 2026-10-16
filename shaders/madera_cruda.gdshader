// Madera cruda (sin pintar): la capa que cubre el diorama hasta que llega la pintura (así empieza
// cada escena de Woodo). Se dibuja ENCIMA del material real (material_overlay) y, donde hay
// pintura, se vuelve transparente y deja ver el color de verdad.
// La pintura son esferas que crecen desde cada pieza colocada: el Diorama las va actualizando
// (pintura[i] = centro xyz + radio w). Un solo material para todo el diorama.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

const int MAX_PINTURA = 64;

uniform vec4 color_claro : source_color = vec4(0.86, 0.74, 0.58, 1.0);
uniform vec4 color_veta : source_color = vec4(0.68, 0.53, 0.38, 1.0);
uniform float anillos_por_metro = 9.0;
uniform float rugosidad : hint_range(0.0, 1.0) = 0.85;
uniform float borde_pintura = 0.14;          // lo que mide el borde irregular de la mancha (m)
uniform vec4 pintura[MAX_PINTURA];
uniform int n_pintura = 0;
uniform float todo_pintado : hint_range(0.0, 1.0) = 0.0;

varying vec3 pos_local;
varying vec3 normal_local;
varying vec3 pos_mundo;

void vertex() {
	pos_local = VERTEX;
	normal_local = NORMAL;
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float ruido(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void fragment() {
	// Veta de tablón: rayas onduladas que corren a lo largo de cada cara (en el suelo y las mesas,
	// a lo largo de X; en paredes y frentes, en horizontal). Nunca anillos de testa en una pared.
	vec3 n = abs(normal_local);
	float across;
	float along;
	if (n.y >= n.x && n.y >= n.z) {
		across = pos_local.z;
		along = pos_local.x;
	} else if (n.x >= n.z) {
		across = pos_local.y;
		along = pos_local.z;
	} else {
		across = pos_local.y;
		along = pos_local.x;
	}
	float torcido = ruido(vec3(along * 1.1, across * 2.5, 0.5)) * 1.3 + ruido(vec3(along * 4.0, across * 9.0, 2.5)) * 0.3;
	float anillo = fract(across * anillos_por_metro + torcido);
	float linea = 1.0 - smoothstep(0.0, 0.1, anillo) + smoothstep(0.9, 1.0, anillo);   // línea fina
	vec3 madera = mix(color_claro.rgb, color_veta.rgb, clamp(linea * 0.85 + anillo * 0.3, 0.0, 1.0));
	madera *= 0.95 + 0.05 * ruido(vec3(along * 3.0, across * 80.0, 4.5));   // fibra fina
	ALBEDO = madera;
	ROUGHNESS = rugosidad;
	SPECULAR = 0.25;

	// Pintura: dentro de cualquier esfera, transparente. El borde se tuerce con ruido para que
	// parezca pintura que empapa la madera, no un círculo perfecto.
	float pintado = todo_pintado;
	float irregular = (ruido(pos_mundo * 6.0) - 0.5) * borde_pintura * 1.4;
	for (int i = 0; i < n_pintura; i++) {
		vec4 e = pintura[i];
		float d = distance(pos_mundo, e.xyz) + irregular;
		pintado = max(pintado, 1.0 - smoothstep(e.w - borde_pintura, e.w, d));
	}
	ALPHA = 1.0 - pintado;
}
