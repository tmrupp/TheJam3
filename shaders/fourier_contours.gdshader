shader_type canvas_item;
render_mode unshaded;

// Radial Fourier coefficients: x = cosine amplitude, y = sine amplitude.
uniform vec2 coefficients[32];
uniform int harmonic_count = 12;
uniform bool closed_contour = false;
uniform vec2 contour_points[128];
uniform float mean_radius = 0.23;
uniform vec2 rect_size = vec2(480.0);
uniform float phase = 0.0;
uniform float convergence : hint_range(0.0, 1.0) = 0.5;
uniform int line_count : hint_range(2, 16) = 9;
uniform float spacing : hint_range(0.003, 0.025) = 0.012;
uniform float line_width : hint_range(0.5, 4.0) = 1.2;
uniform float turbulence : hint_range(0.0, 0.1) = 0.045;
uniform vec4 inner_color : source_color = vec4(1.0, 0.39, 0.08, 1.0);
uniform vec4 outer_color : source_color = vec4(1.0, 0.16, 0.64, 1.0);
uniform float glow : hint_range(0.0, 1.0) = 0.22;

void fragment() {
    float short_side = max(min(rect_size.x, rect_size.y), 1.0);
    vec2 p = (UV - vec2(0.5)) * rect_size / short_side;
    float angle = atan(p.y, p.x);
    float radius = length(p);
    float pixel = 1.0 / short_side;
    float aa = max(fwidth(radius), pixel * 0.5);
    vec3 accumulated = vec3(0.0);
    float coverage = 0.0;
    float outline_distance = 10.0;
    if (closed_contour) {
        bool inside = false;
        for (int i = 0; i < 128; i++) {
            vec2 a = contour_points[i];
            vec2 b = contour_points[(i + 1) % 128];
            vec2 edge = b - a;
            float t = clamp(dot(p - a, edge) / max(dot(edge, edge), 0.0000001), 0.0, 1.0);
            outline_distance = min(outline_distance, length(p - a - t * edge));
            if ((a.y > p.y) != (b.y > p.y)) {
                if (p.x < a.x + (p.y - a.y) * edge.x / edge.y) { inside = !inside; }
            }
        }
        if (inside) { outline_distance = -outline_distance; }
    }

    for (int ring = 0; ring < 16; ring++) {
        if (ring >= line_count) { break; }
        float layer = float(ring) / float(max(line_count - 1, 1));
        // Outer traces lag, but every trace reaches full convergence at 1.
        float resolved = clamp(convergence - 0.23 * layer * (1.0 - convergence), 0.0, 1.0);
        float cutoff = resolved * float(harmonic_count + 1);
        float contour = mean_radius;
        float slope = 0.0;
        if (!closed_contour) {
        for (int harmonic = 0; harmonic < 32; harmonic++) {
            if (harmonic >= harmonic_count) { break; }
            float n = float(harmonic + 1);
            float weight = smoothstep(n - 1.0, n, cutoff);
            float c = cos(n * angle);
            float s = sin(n * angle);
            contour += weight * dot(coefficients[harmonic], vec2(c, s));
            slope += weight * n * dot(coefficients[harmonic], vec2(-s, c));
        }
        float a = 3.0 * angle + phase * 0.8 + layer * 2.4;
        float b = 7.0 * angle - phase * 0.55 - layer * 3.0;
        float residual = turbulence * (1.0 - resolved);
        contour += residual * (sin(a) + 0.35 * sin(b));
        slope += residual * (3.0 * cos(a) + 2.45 * cos(b));
        contour += float(ring) * spacing;
        }
        // Approximate normal distance keeps strokes even on steep contours.
        float distance_to_line = abs(radius - contour) / sqrt(1.0 + pow(slope / max(contour, 0.02), 2.0));
        if (closed_contour) {
            float wobble = turbulence * (1.0 - resolved) * (sin(3.0 * angle + phase * 0.8 + layer * 2.4) + 0.35 * sin(7.0 * angle - phase * 0.55 - layer * 3.0));
            distance_to_line = abs(outline_distance - float(ring) * spacing - wobble);
        }
        float core = 1.0 - smoothstep(line_width * pixel * 0.5, line_width * pixel * 0.5 + aa, distance_to_line);
        float halo = exp(-distance_to_line / (pixel * 3.0)) * glow;
        vec4 ink = mix(inner_color, outer_color, layer);
        float alpha = clamp(core + halo, 0.0, 1.0) * ink.a;
        accumulated += ink.rgb * alpha;
        coverage += alpha;
    }
    // Straight alpha: leave the center and space between lines transparent.
    vec4 tint = COLOR;
    COLOR = vec4(accumulated / max(coverage, 0.0001), clamp(coverage, 0.0, 1.0)) * tint;
}
