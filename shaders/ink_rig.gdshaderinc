// Ink printed through a rig (InkCanvas.rig), shared by ink_rig.gdshader (ink laid) and
// ink_rig_lift.gdshader (ink lifted): each shape is drawn once, in its rest pose, and placed every
// frame here, on the GPU, by the rig's bones and its warp.
//
// A vertex names up to three bones in its UV, as whole numbers: x = a + 128 b, y = c + 128 wa +
// 32768 wb, its weights in 255ths (c takes what a and b leave); a shape bound to one bone names it
// three times with all the weight on a. A bone is an affine map, its basis (x.x, x.y, y.x, y.y) and
// its origin. Then the warp (RisoWizard's bow and its lean against a
// wall, in the same steps as RisoWizard._smv): the bow turns each point above a pivot about it, by
// `turn` times u squared, u its height over the pivot in `length`s (up to 1.5); against a wall,
// whatever reaches past the knee lies flat on the wall's face, softened over `soft`.

const int RIG_BONES = 96;
uniform vec4 bone_basis[RIG_BONES];
uniform vec2 bone_origin[RIG_BONES];
uniform vec4 warp_bow = vec4(0.0);  // pivot x, pivot y, turn, length
uniform vec4 warp_wall = vec4(0.0); // amount, side, knee, soft

vec2 rig_bone(int i, vec2 v) {
	vec4 m = bone_basis[i];
	return vec2(m.x * v.x + m.z * v.y, m.y * v.x + m.w * v.y) + bone_origin[i];
}

vec2 rig_place(vec2 v, vec2 uv) {
	int ux = int(uv.x + 0.5);
	int uy = int(uv.y + 0.5);
	int a = ux % 128;
	int b = ux / 128;
	int c = uy % 128;
	float wa = float((uy / 128) % 256) / 255.0;
	float wb = float(uy / 32768) / 255.0;
	vec2 p = rig_bone(a, v) * wa;
	if (wa < 0.999) {
		p += rig_bone(b, v) * wb + rig_bone(c, v) * max(0.0, 1.0 - wa - wb);
	}
	if (warp_bow.z != 0.0) {
		float u = clamp((warp_bow.y - p.y) / warp_bow.w, 0.0, 1.5);
		if (u > 0.0) {
			vec2 d = p - warp_bow.xy;
			float an = warp_bow.z * u * u;
			p = warp_bow.xy + vec2(d.x * cos(an) - d.y * sin(an), d.x * sin(an) + d.y * cos(an));
		}
	}
	if (warp_wall.x > 0.001) {
		float s = p.x * warp_wall.y;
		if (s > warp_wall.z) {
			float flat_by = warp_wall.w * tanh((s - warp_wall.z) / warp_wall.w);
			p = mix(p, vec2(warp_wall.y * (warp_wall.z + flat_by), p.y), warp_wall.x);
		}
	}
	return p;
}

void vertex() {
	VERTEX = rig_place(VERTEX, UV);
}

void fragment() {
	COLOR = vec4(1.0, 1.0, 1.0, COLOR.a);
}
