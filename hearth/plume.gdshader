shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float phase;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform vec4 smoke_color : source_color = vec4(0.60, 0.55, 0.49, 1.0);
uniform bool vapor = false;
uniform bool steam = false;
uniform vec3 flame_bend = vec3(0.0);

void vertex() {
	if (!vapor && !steam) {
		float rise = pow(1.0 - UV.y, 1.8);
		float gust = 0.90 + 0.10 * sin(TIME * 7.1 + phase);
		VERTEX += inverse(mat3(MODEL_MATRIX)) * flame_bend * (rise * gust);
	}
}

float tongue(vec2 uv, float height, float width, float offset, float beat) {
	float t = (1.0 - uv.y) / height;
	float side = offset * (1.0 - t * 0.40);
	side += sin(t * 7.0 - TIME * 6.7 + beat) * t * 0.12;
	float edge = width * pow(max(0.0, 1.0 - t), 0.77);
	return (1.0 - smoothstep(edge * 0.58, edge + 0.018, abs(uv.x - 0.5 - side)))
		* smoothstep(0.0, 0.10, t) * (1.0 - smoothstep(0.85, 1.0, t));
}

void fragment() {
	if (steam) {
		float rise = 1.0 - UV.y;
		float wave = TIME * 2.6 + phase;
		float trail = sin(rise * 8.4 - wave) * rise * 0.22;
		float edge = mix(0.058, 0.19, rise);
		float strand = 1.0 - smoothstep(edge * 0.21, edge, abs(UV.x - 0.48 - trail));
		float thread = 1.0 - smoothstep(0.016, 0.092, abs(UV.x - 0.67 + trail * 0.75));
		float release = 0.55 + 0.45 * sin(rise * 10.0 - wave * 1.25);
		float fade = smoothstep(0.0, 0.20, rise) * (1.0 - smoothstep(0.52, 1.0, rise));
		ALBEDO = vec3(0.92, 0.91, 0.84);
		ALPHA = clamp((strand * release + thread * release * rise * 0.47) * fade * opacity, 0.0, 1.0);
	} else if (vapor) {
		vec2 p = (UV - vec2(0.5)) * 2.0;
		float ripple = sin(p.y * 7.0 + TIME * 1.7 + phase) * 0.15;
		vec2 folded = vec2(p.x + ripple, p.y);
		float core = 1.0 - smoothstep(0.08, 0.93, length(folded));
		float curl = 1.0 - smoothstep(0.02, 0.62, length(folded + vec2(0.24 * sin(TIME * 0.88 + phase), -0.26)));
		float edge = 1.0 - smoothstep(0.68, 1.0, length(p));
		ALBEDO = smoke_color.rgb;
		ALPHA = (core * core * 0.74 + curl * curl * 0.26) * edge * opacity;
	} else {
		float beat = TIME * 9.0 + phase;
		float a = tongue(UV, 0.93 + 0.065 * sin(beat), 0.16, 0.02, phase);
		float b = tongue(UV, 0.72 + 0.11 * sin(beat + 1.3), 0.13, -0.17, phase + 2.0);
		float c = tongue(UV, 0.58 + 0.10 * sin(beat - 2.3), 0.12, 0.17, phase + 4.0);
		float fire = max(a, max(b, c));
		vec3 tint = mix(vec3(0.85, 0.16, 0.026), vec3(1.0, 0.68, 0.18), smoothstep(0.23, 0.93, fire));
		tint = mix(tint, vec3(1.0, 0.90, 0.58), smoothstep(0.58, 0.95, UV.y) * fire);
		ALBEDO = tint;
		ALPHA = fire * opacity;
	}
}
