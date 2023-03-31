#ifndef WaveFunctionCollapse_H
#define WaveFunctionCollapse_H

#include <godot_cpp/classes/sprite2d.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/global_constants.hpp>
#include <godot_cpp/classes/viewport.hpp>

#include <godot_cpp/core/binder_common.hpp>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/Array.hpp>
#include <godot_cpp/classes/Texture2D.hpp>
#include <godot_cpp/classes/Image.hpp>

// #include "utils/array2D.hpp"
// #include "utils/array3D.hpp"
// #include "direction.hpp"
// #include "propagator.hpp"
// #include "wave.hpp"
// #include "wfc.hpp"
// #include "overlapping_wfc.hpp"

#include "overlapping_wfc.hpp"
#include "tiling_wfc.hpp"
#include "utils/array3D.hpp"
#include "wfc.hpp"


namespace godot {

class WaveFunctionCollapse : public Sprite2D {
    GDCLASS(WaveFunctionCollapse, Sprite2D)

private:
    float time_passed;
    Vector2i output_size;
    int seed;
    int symmetry;
    int pattern_size;

protected:
    static void _bind_methods();

public:
    WaveFunctionCollapse();
    ~WaveFunctionCollapse();

    void _process(float delta);

    Vector2i get_size();
    void set_size(Vector2i _size);

    int get_seed();
    void set_seed(int _seed);

    int get_symmetry();
    void set_symmetry(int _symmetry);

    int get_pattern_size();
    void set_pattern_size(int _pattern_size);

    Array collapse();
};

}

#endif