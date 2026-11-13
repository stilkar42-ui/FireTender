shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform vec4 ink : source_color = vec4(1.0);
uniform vec4 ember_ink : source_color = vec4(0.95, 0.27, 0.08, 1.0);
uniform sampler2D brush_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float brush_weight = 0.0;
uniform float brush_center = 0.34;
uniform int surface_kind = 0; // Stone, bark, end grain, organic, charcoal, ash, split wood.
uniform bool vertex_pigment = false;
uniform bool grain_along_y = false;
uniform float moisture = 0.0;
uniform float scorch = 0.0;
uniform float ember = 0.0;
uniform float resin = 0.0;
uniform float ash_cover = 0.0;
uniform float brush_seed = 0.0;

varying vec3 paint_point;
varying vec3 paint_normal;
varying vec3 corner_color;

#include "res://hearth/painted_surface.gdshaderinc"

void vertex() {
	paint_point = VERTEX;
	paint_normal = NORMAL;
	corner_color = COLOR.rgb;
}

void fragment() {
	vec2 strokes = paint_point.xz;
	if (surface_kind == 1) {
		strokes = vec2(paint_point.x * 1.4, atan(paint_point.y, paint_point.z) * 0.55);
		if (grain_along_y) {
			strokes = vec2(paint_point.y * 4.5, atan(paint_point.x, paint_point.z) * 0.55);
		}
	} else if (surface_kind == 2) {
		strokes = paint_point.zy * 0.48 + vec2(0.54, 0.48);
	} else if (surface_kind == 6) {
		strokes = vec2(paint_point.x * 1.1, paint_point.z * 0.64 + paint_point.y * 0.24);
	} else {
		strokes += vec2(paint_point.y * 0.53, paint_point.y * 0.82);
	}
	strokes += vec2(brush_seed * 0.33, brush_seed * 0.71);
	float brush = brush_grain(strokes + (surface_kind == 2 ? vec2(0.12) : vec2(0.0)));
	vec3 base = ink.rgb;
	if (vertex_pigment) {
		base *= corner_color;
	}
	float stroke_contrast = surface_kind == 2 ? 0.28 : 0.47;
	base *= 1.0 + (brush - 0.49) * stroke_contrast;
	if (brush_weight > 0.0) {
		vec3 image_paint = surface_kind == 2 ? texture(brush_map, strokes).rgb : painted_swatch(brush_map, strokes);
		base *= mix(vec3(1.0), clamp((image_paint - vec3(brush_center)) * 1.55 + vec3(1.0), 0.63, 1.35), brush_weight);
	}
	vec2 grain = strokes * vec2(2.3, 11.0);
	float crack = smoothstep(0.70, 0.92, pigment_noise(grain + brush * 0.9));
	float grain_high = smoothstep(0.28, 0.80, brush);
	if (surface_kind == 1 || surface_kind == 6) {
		float knot = smoothstep(0.57, 0.79, pigment_noise(strokes * vec2(5.0, 7.0)));
		base = mix(base, base * vec3(1.26, 1.01, 0.70), resin * knot);
		base *= 1.0 - crack * 0.16;
	} else if (surface_kind == 2) {
		float ring = distance((strokes - vec2(0.54, 0.48)) * vec2(0.88, 1.17), vec2(0.0));
		float rings = sin(ring * 84.0 + brush * 3.2 + strokes.x * 2.0);
		base *= 0.96 + 0.045 * rings;
	}
	base = mix(base, base * vec3(0.52, 0.60, 0.71), moisture * (0.82 + brush * 0.18));
	base += vec3(0.050, 0.056, 0.060) * moisture * crack * smoothstep(0.0, 0.7, paint_normal.y);
	base = mix(base, mix(vec3(0.095, 0.042, 0.024), vec3(0.024, 0.017, 0.016), scorch),
		smoothstep(0.0, 0.69, scorch) * (0.91 + 0.09 * grain_high));
	if (surface_kind == 4) {
		base *= 0.75 + brush * 0.49 - crack * 0.23;
		float deposit = smoothstep(0.50, 0.78, ash_cover + brush * 0.37 + paint_normal.y * 0.08);
		base = mix(base, vec3(0.35, 0.30, 0.25) * (0.74 + brush * 0.37), deposit);
	}
	if (surface_kind == 5) {
		float powder = 1.0 - smoothstep(0.48, 1.01, length(paint_point.xz) + brush * 0.13);
		base *= mix(vec3(0.45, 0.40, 0.35), vec3(1.0), powder) * (0.80 + brush * 0.30);
	}
	ALBEDO = base;
	ROUGHNESS = 1.0;
	EMISSION = ember_ink.rgb * ember * (0.42 + 0.67 * crack + 0.26 * grain_high);
}
