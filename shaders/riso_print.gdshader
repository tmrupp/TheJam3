shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Prints six ink coverage plates (alpha = coverage) as a risograph sheet:
// per-ink misregistration, edge wobble, dot gain, an AM screen whose dots grow with
// coverage (grain only in tints and edges; solids stay solid), uneven laydown,
// missed-ink specks and paper texture. Inks multiply over the paper.
// Every imperfection is evaluated in world-pinned pixels (screen pixel + `pin`, the camera's
// offset), so the print stays on the paper as the camera moves; only the plates are sampled
// in screen space. Noise uses an exact integer hash (PCG): the old fract() hash lost float
// precision at screen-sized coordinates, which lined specks and grain up in bands.
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
uniform vec2 pin = vec2(0.0);
// Trapping, in pixels: colour plates spread this far into their own knockout in the night, so
// misregistration doesn't open hairline paper rims at the edges of shapes.
uniform float trap = 0.0;

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

float print_ink(sampler2D s, vec2 px, vec2 off, float ang, float rot, float sd, float wsd, float tr) {
	vec2 c = res * 0.5;
	vec2 p = px - c;
	p = vec2(cos(rot) * p.x - sin(rot) * p.y, sin(rot) * p.x + cos(rot) * p.y) + c + off;
	// World-pinned position of this plate's (misregistered) sample point.
	vec2 wq = p + pin;
	uint so = seed_u(sd);
	// The broad edge wobble is shared by all plates so neighbouring inks drift together (no paper gaps).
	uint sw = seed_u(wsd);
	vec2 w1 = vec2(vn(R1 * wq * 0.16, sw), vn(R1 * wq * 0.16, sw + 17u)) - 0.5;
	vec2 w2 = vec2(vn(R2 * wq * 0.85, so), vn(R2 * wq * 0.85, so + 29u)) - 0.5;
	vec2 d = w1 * wob * 2.2 + w2 * wob * 0.9;
	float cv = coverage(s, p + d);
	if (tr > 0.01) {
		vec2 tp = vec2(tr) / res;
		vec2 uv = (p + d) / res;
		float spread = max(max(texture(s, uv + vec2(tp.x, 0.0)).a, texture(s, uv - vec2(tp.x, 0.0)).a),
			max(texture(s, uv + vec2(0.0, tp.y)).a, texture(s, uv - vec2(0.0, tp.y)).a));
		cv = max(cv, spread * 0.92);
	}
	vec2 qw = wq + d;
	// The halftone screen is pinned to the paper too.
	vec2 wp = px + pin;
	float a = radians(ang);
	vec2 sp = vec2(cos(a) * wp.x - sin(a) * wp.y, sin(a) * wp.x + cos(a) * wp.y) / cell;
	float scr = 0.5 - 0.25 * (cos(6.28318 * sp.x) + cos(6.28318 * sp.y));
	float solid = smoothstep(0.82, 0.98, cv);
	float thr = 0.035 + scr * 0.93 + ((hs(R2 * qw * 0.85, so + 3u) - 0.5) * grain + (vn(R1 * qw * 0.3, so + 5u) - 0.5) * grain * 0.6) * (1.0 - solid * 0.75);
	float v = smoothstep(thr - 0.045, thr + 0.045, cv);
	float laydown = 1.0 - lay + lay * vn(R2 * qw * 0.42, so + 7u);
	float speck = step(0.9988, hs(R1 * qw * 0.42, so + 11u));
	return v * laydown * (1.0 - speck * 0.85);
}

float sheet(sampler2D s, vec2 px, vec2 off, float ang, float rot, float k, float tr) {
	float d = print_ink(s, px, off, ang, rot, seed + k * 13.1, seed, tr);
	if (mixv > 0.001) {
		d = mix(d, print_ink(s, px, off, ang, rot, seed2 + k * 13.1, seed2, tr), mixv);
	}
	return d;
}

void fragment() {
	vec2 px = SCREEN_UV * res;
	vec2 wp = px + pin;
	uint ps = seed_u(seed + 71.0);
	vec3 col = paper * (0.97 + 0.03 * vn(R1 * wp * 0.045, ps)) * (1.0 - 0.045 * hs(R2 * wp * 0.8, ps + 1u));
	// Night is registered to blue (same offset, rotation and wobble), like a trapped plate: where
	// the rock or robe meets the night there is no paper rim, which would read as an outline.
	col *= mix(vec3(1.0), ink0, sheet(plate0, px, off1, 30.0, 0.0007, 1.0, 0.0));
	col *= mix(vec3(1.0), ink1, sheet(plate1, px, off1, 75.0, 0.0007, 1.0, trap));
	col *= mix(vec3(1.0), ink2, sheet(plate2, px, off2, 15.0, 0.0001, 2.0, trap));
	col *= mix(vec3(1.0), ink3, sheet(plate3, px, off3, 45.0, 0.0005, 3.0, trap));
	col *= mix(vec3(1.0), ink4, sheet(plate4, px, off4, 45.0, 0.0004, 4.0, trap));
	col *= mix(vec3(1.0), ink5, sheet(plate5, px, off5, 60.0, 0.0004, 5.0, trap));
	COLOR = vec4(col, 1.0);
}
