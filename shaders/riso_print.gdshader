shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Prints six ink coverage plates (alpha = coverage) as a risograph sheet:
// per-ink misregistration, edge wobble, dot gain, an AM screen whose dots grow with
// coverage (grain only in tints and edges; solids stay solid), uneven laydown,
// missed-ink specks and paper texture. Inks multiply over the paper.
// Plate order: 0 night, 1 blue, 2 pink, 3 accent, 4 eye yellow, 5 hat glow.

uniform sampler2D plate0 : filter_linear, repeat_disable;
uniform sampler2D plate1 : filter_linear, repeat_disable;
uniform sampler2D plate2 : filter_linear, repeat_disable;
uniform sampler2D plate3 : filter_linear, repeat_disable;
uniform sampler2D plate4 : filter_linear, repeat_disable;
uniform sampler2D plate5 : filter_linear, repeat_disable;
uniform vec2 res = vec2(1280.0, 720.0);
uniform vec3 paper = vec3(0.894, 0.875, 0.91);
uniform vec3 ink0; uniform vec3 ink1; uniform vec3 ink2; uniform vec3 ink3; uniform vec3 ink4; uniform vec3 ink5;
uniform vec2 off0; uniform vec2 off1; uniform vec2 off2; uniform vec2 off3; uniform vec2 off4; uniform vec2 off5;
uniform float cell = 5.0;
uniform float wob = 0.8;
uniform float grain = 0.1;
uniform float gain = 1.0;
uniform float lay = 0.1;
uniform float seed = 3.1;
uniform float seed2 = 4.47;
uniform float mixv = 0.0;

float h(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}

// A per-sheet offset from hashing the seed: each new sheet gets unrelated grain, instead of
// the same grain slid along by the seed (which read as a repetitive shimmer).
vec2 sheet_offset(float sd) {
	return vec2(h(vec2(sd * 0.137, 3.7)), h(vec2(9.1, sd * 0.271))) * 97.0;
}

float coverage(sampler2D s, vec2 q) {
	vec2 uv = q / res;
	vec2 g = vec2(gain) / res;
	return texture(s, uv).a * 0.4 + (texture(s, uv + vec2(g.x, 0.0)).a + texture(s, uv - vec2(g.x, 0.0)).a
		+ texture(s, uv + vec2(0.0, g.y)).a + texture(s, uv - vec2(0.0, g.y)).a) * 0.15;
}

float print_ink(sampler2D s, vec2 px, vec2 off, float ang, float rot, float sd, float wsd) {
	vec2 c = res * 0.5;
	vec2 p = px - c;
	p = vec2(cos(rot) * p.x - sin(rot) * p.y, sin(rot) * p.x + cos(rot) * p.y) + c + off;
	vec2 o = sheet_offset(sd);
	// The broad edge wobble is shared by all plates so neighbouring inks drift together (no paper gaps).
	vec2 ow = sheet_offset(wsd);
	vec2 w1 = vec2(vn(p * 0.16 + ow), vn(p * 0.16 + ow.yx + 31.0)) - 0.5;
	vec2 w2 = vec2(vn(p * 0.85 + o * 1.7), vn(p * 0.85 + o.yx * 2.3 + 7.0)) - 0.5;
	vec2 q = p + w1 * wob * 2.2 + w2 * wob * 0.9;
	float cv = coverage(s, q);
	float a = radians(ang);
	vec2 sp = vec2(cos(a) * px.x - sin(a) * px.y, sin(a) * px.x + cos(a) * px.y) / cell;
	float scr = 0.5 - 0.25 * (cos(6.28318 * sp.x) + cos(6.28318 * sp.y));
	float solid = smoothstep(0.82, 0.98, cv);
	float thr = 0.035 + scr * 0.93 + ((h(floor(q * 0.85) + o) - 0.5) * grain + (vn(q * 0.3 + o.yx * 4.0) - 0.5) * grain * 0.6) * (1.0 - solid * 0.75);
	float v = smoothstep(thr - 0.045, thr + 0.045, cv);
	float laydown = 1.0 - lay + lay * vn(q * 0.42 + o * 3.0);
	float speck = step(0.9988, h(floor(q * 0.42) + o.yx * 5.0));
	return v * laydown * (1.0 - speck * 0.85);
}

float sheet(sampler2D s, vec2 px, vec2 off, float ang, float rot, float k) {
	float d = print_ink(s, px, off, ang, rot, seed + k * 13.1, seed);
	if (mixv > 0.001) {
		d = mix(d, print_ink(s, px, off, ang, rot, seed2 + k * 13.1, seed2), mixv);
	}
	return d;
}

void fragment() {
	vec2 px = SCREEN_UV * res;
	vec2 po = sheet_offset(seed);
	vec3 col = paper * (0.97 + 0.03 * vn(px * 0.045 + po)) * (1.0 - 0.045 * h(floor(px * 0.8) + po.yx));
	// Night is registered to blue (same offset, rotation and wobble), like a trapped plate: where
	// the rock or robe meets the night there is no paper rim, which would read as an outline.
	col *= mix(vec3(1.0), ink0, sheet(plate0, px, off1, 30.0, 0.0007, 1.0));
	col *= mix(vec3(1.0), ink1, sheet(plate1, px, off1, 75.0, 0.0007, 1.0));
	col *= mix(vec3(1.0), ink2, sheet(plate2, px, off2, 15.0, 0.0001, 2.0));
	col *= mix(vec3(1.0), ink3, sheet(plate3, px, off3, 45.0, 0.0005, 3.0));
	col *= mix(vec3(1.0), ink4, sheet(plate4, px, off4, 45.0, 0.0004, 4.0));
	col *= mix(vec3(1.0), ink5, sheet(plate5, px, off5, 60.0, 0.0004, 5.0));
	COLOR = vec4(col, 1.0);
}
