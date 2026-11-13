shader_type sky;

#include "res://hearth/hollow_sky.gdshaderinc"

void sky() {
	// Local lighting is supplied by the existing hearth and daylight lights.
	COLOR = AT_CUBEMAP_PASS ? vec3(0.25) : overhead_ink(EYEDIR);
}
