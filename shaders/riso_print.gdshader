shader_type canvas_item;
render_mode unshaded, blend_disabled;
// The scene's print: see riso_core.gdshaderinc.

#include "res://shaders/riso_core.gdshaderinc"

void fragment() {
	vec2 px = SCREEN_UV * res;
	vec2 wp = px + pin;
	uint ps = seed_u(seed + 71.0);
	vec3 col = paper * (0.97 + 0.03 * vn(R1 * wp * 0.045, ps)) * (1.0 - 0.045 * hs(R2 * wp * 0.8, ps + 1u));
	// Night prints on its own registration, rotation and wobble, so where the rock or robe meets
	// the night a paper sliver opens on one side and the inks overlap dark on the other. Trapped,
	// it takes blue's (no rim at those edges).
	bool trap = trapped > 0.5;
	col *= mix(vec3(1.0), ink0, sheet(plate0, px, trap ? off1 : off0, 30.0, trap ? 0.0007 : 0.0, trap ? 1.0 : 0.0));
	col *= mix(vec3(1.0), ink1, sheet(plate1, px, off1, 75.0, 0.0007, 1.0));
	col *= mix(vec3(1.0), ink2, sheet(plate2, px, off2, 15.0, -0.0006, 2.0));
	col *= mix(vec3(1.0), ink3, sheet(plate3, px, off3, 45.0, 0.0005, 3.0));
	col *= mix(vec3(1.0), ink4, sheet(plate4, px, off4, 45.0, -0.0003, 4.0));
	col *= mix(vec3(1.0), ink5, sheet(plate5, px, off5, 60.0, 0.0004, 5.0));
	col *= mix(vec3(1.0), ink6, sheet(plate6, px, off6, 75.0, -0.0005, 7.0));
	col *= mix(vec3(1.0), ink7, sheet(plate7, px, off7, 75.0, 0.0003, 8.0));
	COLOR = vec4(col, 1.0);
}
