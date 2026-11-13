#include "collapse.h"

#include "overlapping_wfc.hpp"
#include "utils/array2D.hpp"

#include <godot_cpp/variant/color.hpp>

using namespace godot;

void Collapse::_bind_methods() {
    ClassDB::bind_static_method("Collapse", D_METHOD("run", "sample", "size", "seed", "pattern_size", "symmetry", "symmetry_mask"), &Collapse::run);
}

Array Collapse::run(const Ref<Image> &sample, Vector2i size, int seed, int pattern_size, int symmetry, int symmetry_mask) {
    Array result = Array();
    if (sample.is_null()) {
        return result;
    }
    // Read as the game has always read it (the sample turned on its side), so a level is laid
    // out as it was when this was a sprite reading its own texture.
    Array2D<int32_t> m(sample->get_width(), sample->get_height());
    for (size_t i = 0; i < m.height; i++) {
        for (size_t j = 0; j < m.width; j++) {
            m.get(i, j) = sample->get_pixel(i, j).to_rgba32();
        }
    }

    OverlappingWFCOptions options = {false, false, (unsigned int) size.x, (unsigned int) size.y, (unsigned int) symmetry, false, (unsigned int) pattern_size, (unsigned int) symmetry_mask};
    OverlappingWFC<int32_t> wfc(m, options, seed);
    std::optional<Array2D<int32_t>> success = wfc.run();

    if (success.has_value()) {
        for (size_t i = 0; i < success->height; i++) {
            Array row = Array();
            for (size_t j = 0; j < success->width; j++) {
                uint32_t c = success->get(i, j);
                row.append(Variant(Color::hex(c)));
            }
            result.append(Variant(row));
        }
    }
    return result;
}
