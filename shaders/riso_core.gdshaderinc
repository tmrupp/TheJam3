// Shared by riso_print.gdshader (the scene) and riso_ui.gdshader (the UI, printed finer and
// laid over it).
// Prints eight ink coverage plates (alpha = coverage) as a risograph sheet:
// per-ink misregistration, edge wobble, dot gain, an AM screen whose dots grow with
// coverage (grain only in tints and edges; solids stay solid), uneven laydown,
// missed-ink specks and paper texture. Inks multiply over the paper.
// Every imperfection is evaluated in world-pinned pixels (screen pixel + `pin`, the camera's
// offset), so the print stays on the paper as the camera moves; only the plates are sampled
// in screen space. Noise is read from a table of an exact integer hash (PCG, see
// riso_noise.gdshader), from a corner of it each plate, stream and sheet has to itself (`nz_*`, set
// by RisoPrint): the old fract() hash lost float precision at screen-sized coordinates, which lined
// specks and grain up in bands, and hashing every pixel was slow on integrated GPUs.
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
uniform float mixv = 0.0;
uniform vec2 pin = vec2(0.0);
// 0: every plate registers and wobbles on its own, as in the prototype, so paper slivers and dark
// overlaps open and close at the edges where inks meet. 1: night is trapped to blue (same offset,
// rotation and wobble) and all plates share the broad wobble, so edges close up.
uniform float trapped = 0.0;

// The noise table: NZ x NZ texels of three hash values each (riso_noise.gdshader), read wrapped.
uniform sampler2D noise : filter_linear, repeat_enable;
// Where each plate's noise streams start in the table, by plate (0 to 7, and 8 for the UI's paper),
// for this sheet (nz_*) and the next (nz2_*, while blending between sheets): a = the broad and fine
// wobble, b = the grain and the screen's threshold noise, c = the laydown and the specks. Whole
// texels, so the lattice stays where the hash had it. The paper's: its texture and its grain.
uniform vec4 nz_a[9]; uniform vec4 nz_b[9]; uniform vec4 nz_c[9];
uniform vec4 nz2_a[9]; uniform vec4 nz2_b[9]; uniform vec4 nz2_c[9];
uniform vec4 nz_paper;
// Each plate's halftone screen angle and its small rotation, as (cos, sin), by plate (the UI's paper
// last, registered with blue): RisoPrint.SCREEN_ANGLES and PLATE_ROTATIONS, trapped night taking
// blue's rotation.
uniform vec2 plate_screens[9];
uniform vec2 plate_turns[9];

const float NZ = 1024.0;
const int NZ_MASK = 1023;

// Value noise: smooth between the table's values at the lattice points round `p`, two streams at
// once. The hardware's bilinear filter does the blend, at the smoothstepped fraction.
vec2 vn2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return texture(noise, (mod(i, NZ) + f + 0.5) / NZ).rg;
}

float vn(vec2 p) {
	return vn2(p).r;
}

// The hash of the lattice cell holding `p`, in [0, 1].
float hs(vec2 p) {
	return texelFetch(noise, ivec2(floor(p)) & ivec2(NZ_MASK), 0).r;
}

// The same, to sixteen bits (two table values), for thresholds near 1 such as the specks'.
float hs16(vec2 p) {
	uvec2 k = uvec2(texelFetch(noise, ivec2(floor(p)) & ivec2(NZ_MASK), 0).rg * 255.0 + 0.5);
	return float(k.x * 256u + k.y) / 65536.0;
}

// Noise domains are turned off the pixel axes so no lattice direction shows.
const mat2 R1 = mat2(vec2(0.8253, 0.5646), vec2(-0.5646, 0.8253));
const mat2 R2 = mat2(vec2(0.3624, -0.9320), vec2(0.9320, 0.3624));

// The paper itself at world-pinned pixel `wp`: a faint mottle and grain.
vec3 paper_at(vec2 wp) {
	return paper * (0.97 + 0.03 * vn(R1 * wp * 0.045 + nz_paper.xy)) * (1.0 - 0.045 * hs(R2 * wp * 0.8 + nz_paper.zw));
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

// One plate's ink at screen pixel `px`, 0 to 1. `scr_cs` and `rot_cs` are the (cos, sin) of its
// screen angle and its rotation; `na`, `nb` and `nc` where its noise starts (see nz_a).
float print_ink(sampler2D s, vec2 px, vec2 off, vec2 scr_cs, vec2 rot_cs, vec4 na, vec4 nb, vec4 nc) {
	vec2 c = res * 0.5;
	vec2 p = px - c;
	p = vec2(rot_cs.x * p.x - rot_cs.y * p.y, rot_cs.y * p.x + rot_cs.x * p.y) + c + off;
	// The halftone screen is pinned to the paper.
	vec2 wp = px + pin;
	vec2 sp = vec2(scr_cs.x * wp.x - scr_cs.y * wp.y, scr_cs.y * wp.x + scr_cs.x * wp.y) / cell;
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
		vec2 wf = p + pin;
		float thr_f = 0.035 + scr * 0.93 + (hs(R2 * wf * 0.85 + nb.xy) - 0.5) * grain + (vn(R1 * wf * 0.3 + nb.zw) - 0.5) * grain * 0.6;
		return smoothstep(thr_f - 0.045, thr_f + 0.045, 0.0) * (1.0 - lay * 0.5);
	}
	// World-pinned position of this plate's (misregistered) sample point.
	vec2 wq = p + pin;
	// The broad edge wobble is the plate's own, or (trapped) shared by all plates so neighbouring
	// inks drift together (RisoPrint gives them all the same start then).
	vec2 w1 = vn2(R1 * wq * 0.16 + na.xy) - 0.5;
	vec2 w2 = vn2(R2 * wq * 0.85 + na.zw) - 0.5;
	vec2 d = w1 * wob * 2.2 + w2 * wob * 0.9;
	float cv = coverage(s, p + d);
	vec2 qw = wq + d;
	float solid = smoothstep(0.82, 0.98, cv);
	float thr = 0.035 + scr * 0.93 + ((hs(R2 * qw * 0.85 + nb.xy) - 0.5) * grain + (vn(R1 * qw * 0.3 + nb.zw) - 0.5) * grain * 0.6) * (1.0 - solid * 0.9);
	float v = smoothstep(thr - 0.045, thr + 0.045, cv);
	if (v <= 0.0) {
		return 0.0;
	}
	float laydown = 1.0 - lay + lay * vn(R2 * qw * 0.42 + nc.xy);
	float speck = specks > 0.0 ? step(1.0 - 0.0012 * specks, hs16(R1 * qw * 0.42 + nc.zw)) : 0.0;
	return v * laydown * (1.0 - speck * 0.85);
}

// Plate `k` (its screen, rotation and noise are plate_screens[k], plate_turns[k] and nz_*[k])
// printed on this sheet, blended toward the next while sheets blend.
float sheet(sampler2D s, vec2 px, vec2 off, int k) {
	float d = print_ink(s, px, off, plate_screens[k], plate_turns[k], nz_a[k], nz_b[k], nz_c[k]);
	if (mixv > 0.001) {
		d = mix(d, print_ink(s, px, off, plate_screens[k], plate_turns[k], nz2_a[k], nz2_b[k], nz2_c[k]), mixv);
	}
	return d;
}
