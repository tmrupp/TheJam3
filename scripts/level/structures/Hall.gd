class_name Hall
extends Structure
## A hall of marble an institute level built (Institute).

## What it is: a lecture hall, the library, the bell room, the beast's chamber...
var kind: StringName = &""
## Its cells, walls and all.
var box: Rect2i = Rect2i()
## Its open box.
var inside: Rect2i = Rect2i()
## Its doorways.
var doors: Array = []
## The floor outside each doorway.
var steps: Array = []
## The cells stood on inside, sorted.
var floors: Array = []
## Which way a classroom faces from its lectern's wall (+1 the lectern at the left wall, -1 at the right; 0 for the rest).
var front: int = 0
## A lecture hall's department, the spell it teaches.
var dept: StringName = &""


## One laid, holding what it is first laid with.
static func make(kind_: StringName, box_: Rect2i, inside_: Rect2i, doors_: Array, steps_: Array, front_: int) -> Hall:
	var it: Hall = Hall.new()
	it.kind = kind_
	it.box = box_
	it.inside = inside_
	it.doors = doors_
	it.steps = steps_
	it.front = front_
	return it


## None: what a level holds, or is handed, where there is no such thing (is_empty).
static func none() -> Hall:
	var it: Hall = Hall.new()
	it.laid = false
	return it
