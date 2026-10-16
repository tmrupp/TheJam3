shader_type canvas_item;
render_mode unshaded, blend_disabled;
// The scene's print: see riso_core.gdshaderinc.

#include "res://shaders/riso_core.gdshaderinc"

void fragment() {
	vec2 px = SCREEN_UV * res;
	vec3 col = paper_at(px + pin);
	// Night prints on its own registration, rotation and wobble, so where the rock or robe meets
	// the night a paper sliver opens on one side and the inks overlap dark on the other. Trapped,
	// it takes blue's (no rim at those edges; RisoPrint gives it blue's rotation and noise then).
	bool trap = trapped > 0.5;
	col *= mix(vec3(1.0), ink0, sheet(plate0, px, trap ? off1 : off0, 0));
	col *= mix(vec3(1.0), ink1, sheet(plate1, px, off1, 1));
	col *= mix(vec3(1.0), ink2, sheet(plate2, px, off2, 2));
	col *= mix(vec3(1.0), ink3, sheet(plate3, px, off3, 3));
	col *= mix(vec3(1.0), ink4, sheet(plate4, px, off4, 4));
	col *= mix(vec3(1.0), ink5, sheet(plate5, px, off5, 5));
	col *= mix(vec3(1.0), ink6, sheet(plate6, px, off6, 6));
	col *= mix(vec3(1.0), ink7, sheet(plate7, px, off7, 7));
	COLOR = vec4(col, 1.0);
}
