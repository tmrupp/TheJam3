shader_type canvas_item;
render_mode unshaded;
// The UI's print (HUD, interaction prompts), laid over the scene's: the same riso print (see
// riso_core.gdshaderinc) of the UI's own plates, with finer settings set by RisoPrint, plus a
// paper plate for the plaques and discs the UI sits on. Transparent where the UI lays nothing.

#include "res://shaders/riso_core.gdshaderinc"

uniform sampler2D plate_paper : filter_linear, repeat_disable;

void fragment() {
	vec2 px = SCREEN_UV * res;
	vec3 col = paper_at(px + pin);
	// The paper registers with blue, the plaques' tint (its screen, rotation and noise are the
	// ninth, see RisoPrint.SCREEN_ANGLES).
	float a = sheet(plate_paper, px, off1, 8);
	float d;
	d = sheet(plate0, px, off0, 0); a = max(a, d); col *= mix(vec3(1.0), ink0, d);
	d = sheet(plate1, px, off1, 1); a = max(a, d); col *= mix(vec3(1.0), ink1, d);
	d = sheet(plate2, px, off2, 2); a = max(a, d); col *= mix(vec3(1.0), ink2, d);
	d = sheet(plate3, px, off3, 3); a = max(a, d); col *= mix(vec3(1.0), ink3, d);
	d = sheet(plate4, px, off4, 4); a = max(a, d); col *= mix(vec3(1.0), ink4, d);
	d = sheet(plate5, px, off5, 5); a = max(a, d); col *= mix(vec3(1.0), ink5, d);
	d = sheet(plate6, px, off6, 6); a = max(a, d); col *= mix(vec3(1.0), ink6, d);
	d = sheet(plate7, px, off7, 7); a = max(a, d); col *= mix(vec3(1.0), ink7, d);
	COLOR = vec4(col, a);
}
