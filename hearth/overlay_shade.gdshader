shader_type canvas_item;
render_mode unshaded;

uniform vec2 canvas_size = vec2(1280.0, 820.0);

void fragment() {
	vec2 at = UV * canvas_size;
	float right_edge = canvas_size.x - at.x;
	float bottom_edge = canvas_size.y - at.y;
	float top = 0.60 * (1.0 - smoothstep(22.0, 170.0, at.y));
	float bottom = 0.83 * (1.0 - smoothstep(25.0, 165.0, bottom_edge));
	float left = 0.64 * (1.0 - smoothstep(30.0, 325.0, at.x));
	float right = 0.73 * (1.0 - smoothstep(40.0, 330.0, right_edge));
	right *= mix(0.48, 1.0, 1.0 - smoothstep(350.0, 630.0, at.y));
	float shade = 1.0 - (1.0 - max(top, bottom)) * (1.0 - max(left, right));
	COLOR = vec4(0.055, 0.039, 0.032, shade);
}
