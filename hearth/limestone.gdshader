shader_type spatial;
render_mode cull_disabled, specular_disabled;

varying vec3 stone_ink;
varying vec3 rock_point;

float grain(vec3 p) {
	return fract(sin(dot(p, vec3(19.9, 67.2, 123.7))) * 43758.54);
}

float mottling(vec3 p) {
	vec3 i = floor(p);
	vec3 f = smoothstep(vec3(0.0), vec3(1.0), fract(p));
	float low = mix(mix(grain(i), grain(i + vec3(1, 0, 0)), f.x),
		mix(grain(i + vec3(0, 1, 0)), grain(i + vec3(1, 1, 0)), f.x), f.y);
	float high = mix(mix(grain(i + vec3(0, 0, 1)), grain(i + vec3(1, 0, 1)), f.x),
		mix(grain(i + vec3(0, 1, 1)), grain(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(low, high, f.z);
}

void vertex() {
	stone_ink = COLOR.rgb;
	rock_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float stain = mottling(rock_point * vec3(2.3, 4.8, 2.6));
	float bedding = smoothstep(-0.15, 0.38, sin(rock_point.y * 47.0 + rock_point.x * 1.4 + stain * 3.3));
	float grit = grain(floor(rock_point * 142.0));
	ALBEDO = stone_ink * (0.72 + stain * 0.28 + bedding * 0.15 + grit * 0.035);
	ROUGHNESS = 1.0;
}
