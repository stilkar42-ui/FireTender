shader_type spatial;
render_mode diffuse_lambert, depth_prepass_alpha, cull_disabled;

varying vec2 floor_pos;
uniform vec2 rain_film = vec2(0.0);
#include "res://hearth/soil_palette.gdshaderinc"

void vertex() {
	floor_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float fall = smoothstep(1.21, 1.55, floor_pos.y);
	float stain = mottling(floor_pos * 4.7);
	vec3 stone = mix(vec3(0.101, 0.075, 0.055), vec3(0.221, 0.178, 0.131), stain);
	ALBEDO = mix(soil_color(floor_pos), stone, fall);
	ROUGHNESS = 1.0;
	float seep = 1.0 - smoothstep(0.10, 0.72, distance(floor_pos, vec2(0.69, -3.15)) + (stain - 0.5) * 0.29);
	float sheltered = smoothstep(1.62, 2.36, -floor_pos.y) * smoothstep(1.17, 2.2, -floor_pos.x);
	float inner_floor = smoothstep(1.35, 2.25, -floor_pos.y);
	vec3 limestone_dust = vec3(0.142, 0.120, 0.100) * (0.67 + stain * 0.68);
	ALBEDO = mix(ALBEDO, limestone_dust, inner_floor * 0.50);
	ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.29, 1.14, 0.90), sheltered * 0.71);
	ALBEDO = mix(ALBEDO, vec3(0.085, 0.108, 0.107) * (0.60 + stain * 0.72), seep * 0.89);
	ROUGHNESS = mix(1.0, 0.51, seep);
	float splash_wet = rain_film.x * smoothstep(-0.32, 0.62, floor_pos.y - rain_film.y + (stain - 0.5) * 0.12);
	ALBEDO *= 1.0 - splash_wet * (0.28 + stain * 0.24);
	ROUGHNESS = mix(ROUGHNESS, 0.29, splash_wet);
	SPECULAR = 0.13 + 0.36 * splash_wet;
	float foreground = smoothstep(0.025, 0.49, -VERTEX.z);
	float outcrop = 1.0 - smoothstep(1.49, 2.43, floor_pos.y + stain * 0.13);
	ALPHA = foreground * outcrop;
}
