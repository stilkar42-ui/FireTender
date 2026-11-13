uniform sampler2D valley_paint : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D storm_paint : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D star_paint : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D moon_paint : source_color, filter_linear_mipmap, repeat_disable;
uniform float daylight = 1.0;
uniform float twilight = 0.0;
uniform float cloud = 0.1;
uniform float rain_band = 0.0;
uniform float storm_light = 0.0;
uniform vec2 drift = vec2(0.0);
uniform float chapter_time = 0.0;
uniform float moon_angle = 0.92;

#include "res://hearth/painted_surface.gdshaderinc"

vec2 sky_grain(vec2 cell) {
	return fract(sin(vec2(dot(cell, vec2(127.1, 311.7)), dot(cell, vec2(269.5, 183.3)))) * 43758.5453);
}

vec3 overhead_ink(vec3 direction) {
	// A world direction drives the painted cloud band. Its poles fade into
	// the upper-sky ink, and the two ends blend behind the shelter.
	float bearing = atan(direction.x, direction.z);
	float elevation = asin(clamp(direction.y, -1.0, 1.0));
	float height = smoothstep(-0.50, 1.36, elevation);
	float around = bearing / TAU + 0.5;
	float cloud_row = mix(0.49, 0.06, height);
	float seam = 1.0 - smoothstep(0.0, 0.14, min(around, 1.0 - around));
	vec3 painted = mix(texture(valley_paint, vec2(around, cloud_row)).rgb,
		texture(valley_paint, vec2(fract(around + 0.5), cloud_row)).rgb, seam);
	painted = mix(painted, vec3(0.45, 0.50, 0.55), smoothstep(0.83, 1.50, elevation));
	vec3 day = mix(painted, vec3(0.35, 0.45, 0.53), 0.18 + height * 0.56);
	vec2 cloud_space = vec2(bearing * 1.55, elevation * 3.7);
	float sweep = pigment_noise(cloud_space + vec2(drift.x * 0.14, 0.0));
	float haze = smoothstep(0.32, 0.73, sweep * 0.73 + brush_grain(cloud_space * 1.35) * 0.27);
	vec3 pale = mix(vec3(0.38, 0.45, 0.50), vec3(0.66, 0.67, 0.64), haze);
	day = mix(day, pale, 0.84 + 0.11 * height);
	day = mix(day, day * vec3(1.28, 0.83, 0.71) + vec3(0.08, 0.02, 0.0), twilight * (1.0 - height * 0.72));
	vec3 night = mix(vec3(0.16, 0.18, 0.23), vec3(0.032, 0.047, 0.091), height) + painted * 0.035;
	vec3 ink = mix(night, day, daylight);
	float clear_night = pow(1.0 - daylight, 2.0) * (1.0 - smoothstep(0.24, 0.79, cloud));

	if (clear_night > 0.001) {
		// Map the painted Milky Way onto the vault without stretching it
		// at the zenith. A scattering of smaller stars extends around it.
		vec3 band = vec3(0.0, 0.80, 0.60);
		float facing = dot(direction, band);
		if (facing > 0.0) {
			vec2 brush = vec2(direction.x * 0.56 + 0.5, 0.55 - dot(direction, vec3(0.0, 0.60, -0.80)) * 0.64);
			vec2 edge = smoothstep(vec2(0.0), vec2(0.14), min(brush, 1.0 - brush));
			vec4 galaxy = texture(star_paint, brush);
			ink += galaxy.rgb * galaxy.a * edge.x * edge.y * smoothstep(0.12, 0.76, facing) * clear_night * 0.76;
		}
		// The minor stars use a cube projection so their shapes stay small
		// when looking nearly straight up.
		vec3 axis = abs(direction);
		vec2 tile;
		float face;
		if (axis.y >= max(axis.x, axis.z)) {
			tile = direction.xz / axis.y;
			face = 2.0 + sign(direction.y);
		} else if (axis.x >= axis.z) {
			tile = direction.zy / axis.x;
			face = 5.0 + sign(direction.x);
		} else {
			tile = direction.xy / axis.z;
			face = 8.0 + sign(direction.z);
		}
		vec2 grid = (tile + 1.0) * 23.0;
		vec2 seed = sky_grain(floor(grid) + vec2(face * 53.0, face * 19.0));
		vec2 delta = abs(fract(grid) - mix(vec2(0.20), vec2(0.80), seed));
		float pin = (1.0 - smoothstep(0.012, 0.070, delta.x + delta.y)) * step(0.64, seed.x);
		ink += vec3(0.70, 0.77, 0.94) * pin * clear_night * (0.16 + seed.y * 0.38) *
			smoothstep(-0.35, 0.07, elevation);

		float moon_rise = 0.38 + (mod(chapter_time, 360.0) - 300.0) * 0.0020;
		vec3 moon = normalize(vec3(-0.30, moon_rise, 0.91));
		vec3 lunar_right = normalize(cross(vec3(0.0, 1.0, 0.0), moon));
		vec2 lunar = vec2(dot(direction, lunar_right), -dot(direction, cross(moon, lunar_right))) / 0.023;
		if (dot(direction, moon) > 0.0 && length(lunar) < 1.20) {
			vec4 disc = texture(moon_paint, lunar * 0.43 + 0.5);
			float face_light = lunar.x * sin(moon_angle) + sqrt(max(0.0, 1.0 - dot(lunar, lunar))) * cos(moon_angle);
			ink = mix(ink, disc.rgb * vec3(0.88, 0.92, 1.0),
				disc.a * smoothstep(-0.095, 0.042, face_light) * clear_night);
		}
	}

	// Advancing brushwork uses the same weather clock as the valley.
	vec2 front_uv = vec2(0.53 + bearing * 0.29 - drift.x * 0.055, 0.46 - elevation * 0.57 - drift.y * 0.035);
	vec4 front = texture(storm_paint, front_uv);
	float edge = smoothstep(0.0, 0.13, min(front_uv.x, 1.0 - front_uv.x)) * smoothstep(0.0, 0.13, front_uv.y);
	float gathering = smoothstep(0.12, 0.84, cloud);
	vec3 overcast = mix(vec3(0.087, 0.105, 0.14), vec3(0.31, 0.36, 0.42), daylight);
	ink = mix(ink, overcast, storm_light * (0.43 + height * 0.24));
	ink = mix(ink, front.rgb * mix(vec3(0.30, 0.37, 0.51), vec3(0.79, 0.89, 1.0), daylight),
		front.a * edge * max(gathering * 0.44, rain_band * 0.70));
	return ink;
}
