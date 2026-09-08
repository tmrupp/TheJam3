shader_type canvas_item;
render_mode unshaded;
uniform vec2 rect_size;
uniform vec2 points[512];
uniform vec2 centers[4];
uniform vec2 motion[4];
uniform vec4 inner_colors[4];
uniform vec4 outer_colors[4];
uniform float unresolved[4];
uniform int object_count = 0;
uniform int line_count = 4;
uniform float spacing = 2.0;
uniform float line_width = 0.65;
uniform float merge_radius = 10.0;
uniform float max_distortion = 7.0;
uniform float phase;
uniform bool solid_shapes = false;

void fragment() {
    vec2 p = UV * rect_size;
    float field = 100000.0;
    vec4 inner = vec4(0.0);
    vec4 outer = vec4(0.0);
    float activity = 0.0;
    for (int object = 0; object < 4; object++) {
        if (object >= object_count) { break; }
        float speed = length(motion[object]);
        vec2 direction = motion[object] / max(speed, 0.0001);
        vec2 relative = p - centers[object];
        // Stretch along travel and add speed-scaled waves, even at full convergence.
        vec2 q = p - direction * dot(relative, direction) * (0.22 * speed);
        float amplitude = max_distortion * speed + 2.5 * unresolved[object];
        // Lengthen waves as amplitude grows to avoid folding the contour into fragments.
        float wavelength_scale = 1.0 / (1.0 + amplitude * 0.1);
        q += amplitude * vec2(sin(relative.y * 0.14 * wavelength_scale + phase * 5.0), sin(relative.x * 0.12 * wavelength_scale - phase * 4.0)) * 0.65;
        float distance = 100000.0;
        bool inside = false;
        for (int i = 0; i < 128; i++) {
            vec2 a = points[object * 128 + i];
            vec2 b = points[object * 128 + (i + 1) % 128];
            vec2 edge = b - a;
            float t = clamp(dot(q - a, edge) / max(dot(edge, edge), 0.000001), 0.0, 1.0);
            distance = min(distance, length(q - a - edge * t));
            if ((a.y > q.y) != (b.y > q.y)) {
                if (q.x < a.x + (q.y - a.y) * edge.x / edge.y) { inside = !inside; }
            }
        }
        if (inside) { distance = -distance; }
        // Smooth union removes internal overlapping outlines and blends their colors.
        float h = clamp(0.5 + 0.5 * (distance - field) / merge_radius, 0.0, 1.0);
        field = mix(distance, field, h) - merge_radius * h * (1.0 - h);
        inner = mix(inner_colors[object], inner, h);
        outer = mix(outer_colors[object], outer, h);
        activity = mix(clamp(speed + unresolved[object], 0.0, 1.0), activity, h);
    }
    vec3 ink_sum = vec3(0.0);
    float coverage = 0.0;
    float aa = max(fwidth(field) * 0.65, 0.35);
    for (int ring = 0; ring < 8; ring++) {
        if (ring >= line_count) { break; }
        float d = abs(field - float(ring) * spacing);
        float stroke = 1.0 - smoothstep(line_width * 0.5, line_width * 0.5 + aa, d);
        vec4 ink = mix(inner, outer, float(ring) / float(max(line_count - 1, 1)));
        float alpha = (stroke + 0.07 * exp(-d / 1.3)) * ink.a;
        if (solid_shapes) { alpha *= smoothstep(0.02, 0.65, activity); }
        ink_sum += ink.rgb * alpha;
        coverage += alpha;
    }
    if (solid_shapes) {
        float fill_alpha = (1.0 - smoothstep(-aa, aa, field)) * inner.a;
        vec3 fill_color = mix(inner.rgb, outer.rgb, 0.12);
        float line_alpha = clamp(coverage, 0.0, 1.0) * (1.0 - fill_alpha);
        float alpha = fill_alpha + line_alpha;
        vec3 color = (fill_color * fill_alpha + ink_sum / max(coverage, 0.0001) * line_alpha) / max(alpha, 0.0001);
        COLOR = vec4(color, alpha) * COLOR;
    } else {
        COLOR = vec4(ink_sum / max(coverage, 0.0001), clamp(coverage, 0.0, 1.0)) * COLOR;
    }
}
