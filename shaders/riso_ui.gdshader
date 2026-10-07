shader_type canvas_item;
render_mode unshaded;
// The UI's print (HUD, interaction prompts), laid over the scene's: the same riso print (see
// riso_core.gdshaderinc) of the UI's own plates, with finer settings set by RisoPrint, plus a
// paper plate for the plaques and discs the UI sits on. Transparent where the UI lays nothing.

#include "res://shaders/riso_core.gdshaderinc"

uniform sampler2D plate_paper : filter_linear, repeat_disable;

void fragment() {
	vec2 px = SCREEN_UV * res;
	vec2 wp = px + pin;
	uint ps = seed_u(seed + 71.0);
	vec3 col = paper * (0.97 + 0.03 * vn(R1 * wp * 0.045, ps)) * (1.0 - 0.045 * hs(R2 * wp * 0.8, ps + 1u));
	// The paper registers with blue, the plaques' tint.
	float a = sheet(plate_paper, px, off1, 75.0, 0.0007, 6.0);
	float d;
	d = sheet(plate0, px, off0, 30.0, 0.0, 0.0); a = max(a, d); col *= mix(vec3(1.0), ink0, d);
	d = sheet(plate1, px, off1, 75.0, 0.0007, 1.0); a = max(a, d); col *= mix(vec3(1.0), ink1, d);
	d = sheet(plate2, px, off2, 15.0, -0.0006, 2.0); a = max(a, d); col *= mix(vec3(1.0), ink2, d);
	d = sheet(plate3, px, off3, 45.0, 0.0005, 3.0); a = max(a, d); col *= mix(vec3(1.0), ink3, d);
	d = sheet(plate4, px, off4, 45.0, -0.0003, 4.0); a = max(a, d); col *= mix(vec3(1.0), ink4, d);
	d = sheet(plate5, px, off5, 60.0, 0.0004, 5.0); a = max(a, d); col *= mix(vec3(1.0), ink5, d);
	d = sheet(plate6, px, off6, 75.0, -0.0005, 7.0); a = max(a, d); col *= mix(vec3(1.0), ink6, d);
	d = sheet(plate7, px, off7, 75.0, 0.0003, 8.0); a = max(a, d); col *= mix(vec3(1.0), ink7, d);
	COLOR = vec4(col, a);
}
