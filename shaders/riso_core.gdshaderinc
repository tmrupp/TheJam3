// Shared by riso_print.gdshader (the scene) and riso_ui.gdshader (the UI, printed finer and
// laid over it).
// Prints eight ink coverage plates (alpha = coverage) as a risograph sheet:
// per-ink misregistration, edge wobble, dot gain, an AM screen whose dots grow with
// coverage (grain only in tints and edges; solids stay solid), uneven laydown,
// missed-ink specks and paper texture. Inks multiply over the paper.
// Every imperfection is evaluated in world-pinned pixels (screen pixel + `pin`, the camera's
// offset), so the print stays on the paper as the camera moves; only the plates are sampled
// in screen space. Noise uses an exact integer hash (PCG): the old fract() hash lost float
// precision at screen-sized coordinates, which lined specks and grain up in bands.
// Plate order: 0 night, 1 blue, 2 pink, 3 accent, 4 eye yellow, 5 hat glow, 6 robe, 7 traveler cloth.

uniform sampler2D plate0 : filter_linear, repeat_disable;
uniform sampler2D plate1 : filter_linear, repeat_disable;
uniform sampler2D plate2 : filter_linear, repeat_disable;
uniform sampler2D plate3 : filter_linear, repeat_disable;
uniform sampler2D plate4 : filter_linear, repeat_disable;
uniform sampler2D plate5 : filter_linear, repeat_disable;
uniform sampler2D plate6 : filter_linear, repeat_disable;
uniform sampler2D plate7 : filter_linear, repeat_disable;
uniform vec2 res = vec2(1280.0, 720.0);
uniform vec3 paper = vec3(0.894, 0.875, 0.91);
uniform vec3 ink0; uniform vec3 ink1; uniform vec3 ink2; uniform vec3 ink3; uniform vec3 ink4; uniform vec3 ink5; uniform vec3 ink6; uniform vec3 ink7;
uniform vec2 off0; uniform vec2 off1; uniform vec2 off2; uniform vec2 off3; uniform vec2 off4; uniform vec2 off5; uniform vec2 off6; uniform vec2 off7;
uniform float cell = 5.0;
uniform float wob = 0.8;
uniform float grain = 0.1;
uniform float gain = 1.0;
uniform float lay = 0.1;
// How many missed-ink specks (flecks of bare paper) the print shows: 0 none, 1 the prototype's.
uniform float specks = 0.0;
uniform float seed = 3.1;
uniform float seed2 = 4.47;
uniform float mixv = 0.0;
uniform vec2 pin = vec2(0.0);
// 0: every plate registers and wobbles on its own, as in the prototype, so paper slivers and dark
// overlaps open and close at the edges where inks meet. 1: night is trapped to blue (same offset,
// rotation and wobble) and all plates share the broad wobble, so edges close up.
uniform float trapped = 0.0;

// PCG 3D (Jarzynski & Olano): an exact integer hash, uniform at any coordinate.
uvec3 pcg3(uvec3 v) {
	v = v * 1664525u + 1013904223u;
	v.x += v.y * v.z; v.y += v.z * v.x; v.z += v.x * v.y;
	v ^= v >> 16u;
	v.x += v.y * v.z; v.y += v.z * v.x; v.z += v.x * v.y;
	return v;
}

// Hash of an integer lattice cell and a seed, in [0, 1).
float hs(vec2 cell_p, uint sd) {
	ivec2 c = ivec2(floor(cell_p));
	return float(pcg3(uvec3(uint(c.x), uint(c.y), sd)).x >> 8u) / 16777216.0;
}

float vn(vec2 p, uint sd) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hs(i, sd), hs(i + vec2(1.0, 0.0), sd), f.x), mix(hs(i + vec2(0.0, 1.0), sd), hs(i + vec2(1.0, 1.0), sd), f.x), f.y);
}

// Noise domains are turned off the pixel axes so no lattice direction shows.
const mat2 R1 = mat2(vec2(0.8253, 0.5646), vec2(-0.5646, 0.8253));
const mat2 R2 = mat2(vec2(0.3624, -0.9320), vec2(0.9320, 0.3624));

// Each sheet's seed becomes an unrelated integer stream.
uint seed_u(float sd) {
	return pcg3(uvec3(uint(sd * 1000.0), 7919u, 104729u)).x;
}

float coverage(sampler2D s, vec2 q) {
	vec2 uv = q / res;
	vec2 g = vec2(gain) / res;
	return texture(s, uv).a * 0.4 + (texture(s, uv + vec2(g.x, 0.0)).a + texture(s, uv - vec2(g.x, 0.0)).a
		+ texture(s, uv + vec2(0.0, g.y)).a + texture(s, uv - vec2(0.0, g.y)).a) * 0.15;
}

// Whether plate `s` holds any ink within reach of `p` (screen px): as far as the wobble can move its
// sample (1.55 wob either way) and the dot gain spreads it, looked for at the middle and at eight
// points round it. Most of the paper holds no ink of most plates, and there the print skips them.
bool ink_near(sampler2D s, vec2 p) {
	vec2 uv = p / res;
	vec2 r = vec2(wob * 1.55 + gain) / res;
	float near = texture(s, uv).a;
	near = max(near, texture(s, uv + vec2(r.x, 0.0)).a);
	near = max(near, texture(s, uv - vec2(r.x, 0.0)).a);
	near = max(near, texture(s, uv + vec2(0.0, r.y)).a);
	near = max(near, texture(s, uv - vec2(0.0, r.y)).a);
	near = max(near, texture(s, uv + r).a);
	near = max(near, texture(s, uv - r).a);
	near = max(near, texture(s, uv + vec2(r.x, -r.y)).a);
	near = max(near, texture(s, uv + vec2(-r.x, r.y)).a);
	return near > 0.0;
}

float print_ink(sampler2D s, vec2 px, vec2 off, float ang, float rot, float sd, float wsd) {
	vec2 c = res * 0.5;
	vec2 p = px - c;
	p = vec2(cos(rot) * p.x - sin(rot) * p.y, sin(rot) * p.x + cos(rot) * p.y) + c + off;
	// The halftone screen is pinned to the paper.
	vec2 wp = px + pin;
	float a = radians(ang);
	vec2 sp = vec2(cos(a) * wp.x - sin(a) * wp.y, sin(a) * wp.x + cos(a) * wp.y) / cell;
	float scr = 0.5 - 0.25 * (cos(6.28318 * sp.x) + cos(6.28318 * sp.y));
	// With no ink of this plate near, it prints only a stray fleck, where the grain pulls a dot's
	// threshold under nothing: only near a dot's middle, where the screen is low enough for the
	// grain (at most 0.8 grain) to bring the threshold under 0.045. There the fleck is worked out
	// from the same grain read without the wobble (which only shifts where it is read), at the
	// laydown's mean; anywhere else it prints nothing. Either way the work below is skipped.
	if (!ink_near(s, p)) {
		if (scr * 0.93 >= 0.01 + 0.8 * grain) {
			return 0.0;
		}
		uint sf = seed_u(sd);
		vec2 wf = p + pin;
		float thr_f = 0.035 + scr * 0.93 + (hs(R2 * wf * 0.85, sf + 3u) - 0.5) * grain + (vn(R1 * wf * 0.3, sf + 5u) - 0.5) * grain * 0.6;
		return smoothstep(thr_f - 0.045, thr_f + 0.045, 0.0) * (1.0 - lay * 0.5);
	}
	// World-pinned position of this plate's (misregistered) sample point.
	vec2 wq = p + pin;
	uint so = seed_u(sd);
	// The broad edge wobble is the plate's own, or (trapped) shared by all plates so neighbouring
	// inks drift together.
	uint sw = trapped > 0.5 ? seed_u(wsd) : so + 41u;
	vec2 w1 = vec2(vn(R1 * wq * 0.16, sw), vn(R1 * wq * 0.16, sw + 17u)) - 0.5;
	vec2 w2 = vec2(vn(R2 * wq * 0.85, so), vn(R2 * wq * 0.85, so + 29u)) - 0.5;
	vec2 d = w1 * wob * 2.2 + w2 * wob * 0.9;
	float cv = coverage(s, p + d);
	vec2 qw = wq + d;
	float solid = smoothstep(0.82, 0.98, cv);
	float thr = 0.035 + scr * 0.93 + ((hs(R2 * qw * 0.85, so + 3u) - 0.5) * grain + (vn(R1 * qw * 0.3, so + 5u) - 0.5) * grain * 0.6) * (1.0 - solid * 0.9);
	float v = smoothstep(thr - 0.045, thr + 0.045, cv);
	float laydown = 1.0 - lay + lay * vn(R2 * qw * 0.42, so + 7u);
	float speck = specks > 0.0 ? step(1.0 - 0.0012 * specks, hs(R1 * qw * 0.42, so + 11u)) : 0.0;
	return v * laydown * (1.0 - speck * 0.85);
}

float sheet(sampler2D s, vec2 px, vec2 off, float ang, float rot, float k) {
	float d = print_ink(s, px, off, ang, rot, seed + k * 13.1, seed);
	if (mixv > 0.001) {
		d = mix(d, print_ink(s, px, off, ang, rot, seed2 + k * 13.1, seed2), mixv);
	}
	return d;
}
