shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform sampler2D brush_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float brush_weight = 0.0;
uniform float brush_center = 0.29;
varying vec3 stone_ink;
varying vec3 rock_point;
varying vec3 rock_normal;

#include "res://hearth/painted_surface.gdshaderinc"

void vertex() {
	stone_ink = COLOR.rgb;
	rock_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	rock_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 p = rock_point;
	vec3 blend = pow(abs(normalize(rock_normal)), vec3(3.0));
	blend /= max(0.001, blend.x + blend.y + blend.z);
	vec2 x_face = vec2(p.z, p.y) * vec2(0.72, 1.14);
	vec2 y_face = p.xz * vec2(0.64, 0.69);
	vec2 z_face = p.xy * vec2(0.72, 1.14);
	float pigment = brush_grain(x_face * 1.9) * blend.x + brush_grain(y_face * 1.9) * blend.y + brush_grain(z_face * 1.9) * blend.z;
	float dark_wash = pigment_noise(vec2(p.x + p.z * 0.41, p.y) * vec2(2.3, 2.9));
	float strata = pigment_noise(vec2((p.x + p.z) * 0.57, p.y * 8.7 + dark_wash * 0.72));
	vec3 tint = mix(stone_ink, vec3(dot(stone_ink, vec3(0.30, 0.53, 0.17))) * vec3(0.97, 1.02, 1.09), 0.30);
	vec3 ink = tint * (0.61 + 0.42 * pigment + 0.18 * strata + 0.18 * dark_wash);
	if (brush_weight > 0.0) {
		vec3 swatch = painted_swatch(brush_map, x_face) * blend.x
			+ painted_swatch(brush_map, y_face) * blend.y + painted_swatch(brush_map, z_face) * blend.z;
		ink *= mix(vec3(1.0), clamp((swatch - vec3(brush_center)) * 2.18 + vec3(1.0), 0.54, 1.36), brush_weight);
	}
	float mineral = smoothstep(0.70, 0.91, strata * 0.72 + pigment * 0.28);
	ink += vec3(0.062, 0.047, 0.034) * mineral;
	ALBEDO = ink;
	ROUGHNESS = 1.0;
}
