shader_type spatial;
render_mode diffuse_lambert;

varying vec2 floor_pos;
uniform vec2 rain_film = vec2(0.0);
#include "res://hearth/soil_palette.gdshaderinc"

void vertex() {
	floor_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float wet = rain_film.x;
	ALBEDO = soil_color(floor_pos) * (1.0 - wet * 0.42);
	ROUGHNESS = mix(1.0, 0.31, wet);
	SPECULAR = 0.11 + wet * 0.38;
}
