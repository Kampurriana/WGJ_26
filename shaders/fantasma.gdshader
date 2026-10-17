// La moneda fantasma del final (sexta nota): una copia blanca y translúcida de la moneda que enseña,
// en bucle, el gesto de meterla en la hucha hasta que el jugador coge la de verdad (core/momentos.gd).
// Sin luz propia de la escena (unshaded): se lee igual en la penumbra cálida del final. Más opaca en
// los cantos, como un fantasma. alpha = cuánto se ve (la anima Momentos: aparece, entra y se va).
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never;

uniform vec4 color : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform float alpha = 0.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = color.rgb;
	ALPHA = alpha * (0.5 + 0.5 * rim);
}
