shader_type canvas_item;
// La cortina de la presentación (ui/presentacion.gd): el color del fondo con un agujero redondo que
// crece desde el cerdito y deja ver el juego; el agujero lleva un borde blanco suave.

uniform vec4 color : source_color = vec4(0.816, 0.886, 0.965, 1.0);
uniform vec2 centro = vec2(0.5, 0.5);        // en UV de la pantalla
uniform float radio = -0.05;                 // en altos de pantalla (negativo = cerrada del todo)
uniform float aspecto = 1.7778;              // ancho / alto
uniform float suave = 0.006;
uniform float borde = 0.012;                 // el anillo blanco del filo

void fragment() {
	float r = length((UV - centro) * vec2(aspecto, 1.0));
	float fuera = smoothstep(radio, radio + suave, r);
	float anillo = (1.0 - smoothstep(radio + borde, radio + borde + suave, r)) * fuera;
	COLOR = vec4(mix(color.rgb, vec3(1.0), anillo * 0.9), fuera * color.a);
}
