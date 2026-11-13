#include "res://hearth/painted_surface.gdshaderinc"
uniform sampler2D brush_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D hearth_paint : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_hearth_paint = false;
uniform float brush_weight = 0.0;
uniform float brush_center = 0.34;

vec3 soil_color(vec2 point) {
	float ridge = pigment_noise(point * 2.7);
	float sand = brush_grain(point * 1.75);
	float grit = pigment_noise(point * 38.0);
	float range = length(point * vec2(1.0, 1.13));
	float inside = 1.0 - smoothstep(0.77, 1.17, range + ridge * 0.22);
	vec3 clay = mix(vec3(0.29, 0.224, 0.160), vec3(0.097, 0.065, 0.052), inside * 0.91);
	vec3 dust = clay * (0.51 + 0.41 * ridge + 0.38 * sand + 0.22 * grit);
	if (brush_weight > 0.0) {
		vec3 paint = painted_swatch(brush_map, point * vec2(0.85, 0.91));
		dust *= mix(vec3(1.0), clamp((paint - vec3(brush_center)) * 2.14 + vec3(1.0), 0.58, 1.48), brush_weight);
	}
	if (has_hearth_paint) {
		vec3 scumble = painted_swatch(hearth_paint, point * 0.79 + vec2(0.4, 0.31));
		dust *= mix(vec3(1.0), clamp(1.0 + (scumble - vec3(0.35, 0.19, 0.11)) * 1.9, 0.50, 1.47), 0.57 + inside * 0.27);
	}
	float falloff = 1.0 - smoothstep(0.93, 4.05, range) * 0.34;
	return dust * falloff;
}
