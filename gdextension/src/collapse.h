#ifndef COLLAPSE_H
#define COLLAPSE_H

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/vector2i.hpp>

namespace godot {

/**
 * The overlapping wave function collapse as a plain function (docs/CODE_REVIEW.md
 * 2.3): from a sample picture, a size and a seed to the cells laid out. It is no
 * node and keeps nothing between calls, so it is safe on any thread, and nothing
 * of it lives in a scene.
 */
class Collapse : public RefCounted {
    GDCLASS(Collapse, RefCounted)

protected:
    static void _bind_methods();

public:
    /**
     * Collapse `sample` into `size` cells on `seed`, cutting it into pieces
     * `pattern_size` across and using the first `symmetry` of each piece's eight
     * versions, or those of `symmetry_mask` (a bit each) when it is not 0. The
     * cells as columns of colours, or an empty array where it never settled.
     */
    static Array run(const Ref<Image> &sample, Vector2i size, int seed, int pattern_size, int symmetry, int symmetry_mask);
};

}

#endif
