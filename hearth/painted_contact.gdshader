shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, depth_draw_never;

void fragment() {
	float falloff = length((UV - vec2(0.5)) * 2.0);
	ALBEDO = vec3(0.045, 0.031, 0.027);
	ALPHA = 0.41 * (1.0 - smoothstep(0.15, 1.0, falloff));
}
