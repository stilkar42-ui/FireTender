float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float mottling(vec2 p) {
	vec2 tile = floor(p);
	vec2 f = fract(p);
	vec2 s = f * f * (3.0 - 2.0 * f);
	return mix(mix(grain(tile), grain(tile + vec2(1.0, 0.0)), s.x),
		mix(grain(tile + vec2(0.0, 1.0)), grain(tile + vec2(1.0, 1.0)), s.x), s.y);
}

vec3 soil_color(vec2 point) {
	float ridge = mottling(point * 4.0);
	float sand = mottling(point * 46.0);
	float fleck = grain(floor(point * 220.0));
	float range = length(point * vec2(1.0, 1.135));
	float inside = 1.0 - smoothstep(0.94, 1.09, range + ridge * 0.08);
	vec3 clay = mix(vec3(0.238, 0.169, 0.132), vec3(0.116, 0.075, 0.052), inside * 0.88);
	float rock = 0.70 + 0.47 * ridge + 0.19 * sand + 0.065 * fleck;
	float falloff = 1.0 - smoothstep(0.93, 3.05, range) * 0.48;
	return clay * rock * falloff;
}
