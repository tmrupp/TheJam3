shader_type canvas_item;
render_mode unshaded, blend_disabled;
// The print's noise table (see riso_core.gdshaderinc), drawn once: each texel holds three values of
// an exact integer hash (PCG) of its lattice cell, eight bits each. The print reads it wrapped, from
// a different corner for each plate, stream and sheet, rather than hashing every pixel, as 32-bit
// integer multiplies are slow on integrated GPUs.

// PCG 3D (Jarzynski & Olano): an exact integer hash, uniform at any coordinate.
uvec3 pcg3(uvec3 v) {
	v = v * 1664525u + 1013904223u;
	v.x += v.y * v.z; v.y += v.z * v.x; v.z += v.x * v.y;
	v ^= v >> 16u;
	v.x += v.y * v.z; v.y += v.z * v.x; v.z += v.x * v.y;
	return v;
}

void fragment() {
	uvec3 h = pcg3(uvec3(uint(FRAGCOORD.x), uint(FRAGCOORD.y), 7919u));
	COLOR = vec4(vec3(h >> 24u) / 255.0, 1.0);
}
