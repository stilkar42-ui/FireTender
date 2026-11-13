shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha, fog_disabled, shadows_disabled;

uniform sampler2D slope_paint : source_color, filter_linear_mipmap, repeat_disable;
uniform float daylight = 1.0;
uniform float twilight = 0.0;
uniform float storm_light = 0.0;
uniform float rain_band = 0.0;

void fragment() {
	vec4 brush = texture(slope_paint, vec2((UV.x - 0.5) * 1.23 + 0.56, UV.y));
	vec3 ink = mix(brush.rgb * vec3(0.23, 0.27, 0.35), brush.rgb, daylight);
	ink = mix(ink, ink * vec3(1.19, 0.88, 0.72), twilight * 0.48);
	ink = mix(ink, ink * vec3(0.68, 0.78, 0.86), storm_light * 0.79);
	ink += vec3(0.09, 0.105, 0.11) * rain_band * daylight * (1.0 - smoothstep(0.34, 0.85, UV.y));
	ALBEDO = ink;
	ALPHA = brush.a * smoothstep(0.0, 0.11, UV.x) * (1.0 - smoothstep(0.89, 1.0, UV.x));
}
