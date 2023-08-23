#include "wave_function_collapse.h"
#include <godot_cpp/variant/utility_functions.hpp>


using namespace godot;

void WaveFunctionCollapse::_bind_methods() {
    ClassDB::bind_method(D_METHOD("collapse"), &WaveFunctionCollapse::collapse);

	ClassDB::bind_method(D_METHOD("get_size"), &WaveFunctionCollapse::get_size);
	ClassDB::bind_method(D_METHOD("set_size", "position"), &WaveFunctionCollapse::set_size);
    ADD_PROPERTY(PropertyInfo(Variant::VECTOR2I, "output_size"), "set_size", "get_size");

	ClassDB::bind_method(D_METHOD("get_seed"), &WaveFunctionCollapse::get_seed);
	ClassDB::bind_method(D_METHOD("set_seed"), &WaveFunctionCollapse::set_seed);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "seed"), "set_seed", "get_seed");

	ClassDB::bind_method(D_METHOD("get_symmetry"), &WaveFunctionCollapse::get_symmetry);
	ClassDB::bind_method(D_METHOD("set_symmetry"), &WaveFunctionCollapse::set_symmetry);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "symmetry"), "set_symmetry", "get_symmetry");

	ClassDB::bind_method(D_METHOD("get_pattern_size"), &WaveFunctionCollapse::get_pattern_size);
	ClassDB::bind_method(D_METHOD("set_pattern_size"), &WaveFunctionCollapse::set_pattern_size);
    ADD_PROPERTY(PropertyInfo(Variant::INT, "pattern_size"), "set_pattern_size", "get_pattern_size");
}

WaveFunctionCollapse::WaveFunctionCollapse() {
    // initialize any variables here
    time_passed = 0.0;
}

WaveFunctionCollapse::~WaveFunctionCollapse() {
    // add your cleanup here
}

/*
Array Example::test_array() const {
	Array arr;

	arr.resize(2);
	arr[0] = Variant(1);
	arr[1] = Variant(2);

	return arr;
}
*/

Vector2i WaveFunctionCollapse::get_size() {
    return output_size;
}

void WaveFunctionCollapse::set_size(Vector2i _size) {
    output_size = _size;
}

// seed
// symmetry
// pattern_size

int WaveFunctionCollapse::get_seed() {return seed;}

void WaveFunctionCollapse::set_seed(int _seed) {seed = _seed;}

int WaveFunctionCollapse::get_symmetry() {return symmetry;}

void WaveFunctionCollapse::set_symmetry(int _symmetry) {symmetry = _symmetry;}

int WaveFunctionCollapse::get_pattern_size() {return pattern_size;}

void WaveFunctionCollapse::set_pattern_size(int _pattern_size) {pattern_size = _pattern_size;}

Array WaveFunctionCollapse::collapse() {
    Ref<Image> im = get_texture()->get_image();

    Array2D<int32_t>* m = new Array2D<int32_t>(im->get_width(), im->get_height());
    for (size_t i = 0; i < m->height; i++) {
        for (size_t j = 0; j < m->width; j++) {
            // Color c = im->get_pixel(i, j);
            // int32_t wfcc = c.to_rgba32(); // int32_t{c.get_r8()};
            // m->data[i*im->get_width()+j] = wfcc;
            // UtilityFunctions::print("pixel @ i=", i, " j=", j, " is ", c);
            m->get(i, j) = im->get_pixel(i, j).to_rgba32();
        }
    }

    OverlappingWFCOptions options = {false, false, (unsigned int) output_size.x, (unsigned int) output_size.y, symmetry, false, pattern_size};
    OverlappingWFC<int32_t> wfc(*m, options, seed);
    std::optional<Array2D<int32_t>> success = wfc.run();

    Array result = Array();

    if (success.has_value()) {
        for (size_t i = 0; i < success->height; i++) {
            Array row = Array();
            for (size_t j = 0; j < success->width; j++) {
                // uint32_t c = success->data[i*success->width+j];
                uint32_t c = success->get(i, j);
                row.append(Variant(Color::hex(c)));
            }
            result.append(Variant(row));
        }
    }

    return result;
}

void WaveFunctionCollapse::_process(float delta) {
    time_passed += delta;

    Vector2 new_position = Vector2(10.0 + (10.0 * sin(time_passed * 20)), 10.0 + (10.0 * cos(time_passed * 10)));

    set_position(new_position);
}