shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

#include "res://hearth/hollow_sky.gdshaderinc"

uniform float rain_lean = 0.0;
varying vec3 world_point;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 valley_ink(vec2 paint) {
	vec3 shale = mix(vec3(0.040, 0.032, 0.030), vec3(0.116, 0.091, 0.071), daylight * (1.0 - storm_light * 0.59));
	if (paint.y > 1.44) {
		return shale;
	}
	vec3 base = texture(valley_paint, paint).rgb;
	float above_hills = 1.0 - smoothstep(0.56, 0.624, paint.y);
	vec3 night_ink = base * mix(vec3(0.20, 0.24, 0.30), vec3(0.20, 0.27, 0.43), above_hills) +
		mix(vec3(0.015, 0.016, 0.019), vec3(0.023, 0.029, 0.050), above_hills);
	vec3 ink = mix(night_ink, base, daylight);
	ink = mix(ink, ink * vec3(1.25, 0.82, 0.65) + vec3(0.050, 0.010, 0.0),
		twilight * (0.22 + 0.65 * above_hills));
	ink = mix(ink, ink * vec3(0.69, 0.76, 0.85), storm_light * 0.86);

	// The painted front drifts on the chapter clock. Rain advances across
	// the far slopes with the projected wind as its veil becomes stronger.
	vec2 weather_uv = vec2(0.5 + (paint.x - 0.5) * 1.64 + 0.074 - drift.x * 0.052 - rain_lean * max(0.0, paint.y - 0.39) * 0.10,
		paint.y * 1.36 - 0.19 - rain_band * 0.075);
	vec4 front = texture(storm_paint, weather_uv);
	float cloud_weight = smoothstep(0.15, 0.84, cloud);
	float rain_weight = smoothstep(0.37, 0.62, weather_uv.y);
	float front_strength = mix(cloud_weight * 0.60, rain_band * 0.85, rain_weight);
	front_strength *= 1.0 - smoothstep(0.66, 0.92, weather_uv.y);
	vec3 front_ink = front.rgb * mix(vec3(0.62, 0.70, 0.86), vec3(0.93, 0.99, 1.04), daylight);
	ink = mix(ink, front_ink, front.a * front_strength);
	return mix(ink, shale, smoothstep(0.98, 1.44, paint.y));
}

void fragment() {
	vec3 ink = valley_ink(UV);
	if (UV.y < 0.62) {
		vec3 direction = normalize(world_point - CAMERA_POSITION_WORLD);
		ink = mix(overhead_ink(direction), ink, smoothstep(0.52, 0.62, UV.y));
	}
	ALBEDO = ink;
}
