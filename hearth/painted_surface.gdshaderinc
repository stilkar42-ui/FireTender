// Broad pigment and fine dry-brush grain, in surface coordinates.
float pigment_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float pigment_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(pigment_hash(cell), pigment_hash(cell + vec2(1, 0)), f.x),
		mix(pigment_hash(cell + vec2(0, 1)), pigment_hash(cell + vec2(1, 1)), f.x), f.y);
}

float brush_grain(vec2 p) {
	float broad = pigment_noise(p * vec2(2.1, 4.8) + vec2(12.1, 6.2));
	float streak = pigment_noise(p * vec2(6.0, 29.0) + broad);
	float tooth = pigment_noise(p * 91.0);
	return broad * 0.42 + streak * 0.38 + tooth * 0.20;
}

// Cross-fade shifted repeats so the swatch edge never becomes a straight seam.
vec3 painted_swatch(sampler2D art, vec2 p) {
	vec2 blend = smoothstep(vec2(0.14), vec2(0.86), abs(fract(p) - 0.5) * 2.0);
	vec2 q = p + vec2(0.5);
	vec3 low = mix(texture(art, p).rgb, texture(art, vec2(q.x, p.y)).rgb, blend.x);
	vec3 high = mix(texture(art, vec2(p.x, q.y)).rgb, texture(art, q).rgb, blend.x);
	return mix(low, high, blend.y);
}
