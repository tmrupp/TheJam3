class_name KeepSite
extends Structure
## The golem's lode hall at the top of the crags' gate levels (LodeHall.cut).

## Its cells.
var box: Rect2i = Rect2i()
## Its open cells.
var inside: Rect2i = Rect2i()
## Its floors' rows.
var floors: Array = []
## The gaps in its floors.
var gaps: Array = []
## Its stairs.
var stairs: Array = []
## Its ledges.
var ledges: Array = []
## The floor the way on stands on, or null.
var on: Variant = null
## The golem's cell.
var lair: Vector2i = Structure.NONE
## Its doorways.
var doors: Array = []
## Its crossbows' cells (LodeHall.arm).
var crossbows: Array = []


## One laid, holding what it is first laid with.
static func make(box_: Rect2i, inside_: Rect2i, floors_: Array, gaps_: Array, stairs_: Array, ledges_: Array, on_: Variant, lair_: Vector2i, doors_: Array) -> KeepSite:
	var it: KeepSite = KeepSite.new()
	it.box = box_
	it.inside = inside_
	it.floors = floors_
	it.gaps = gaps_
	it.stairs = stairs_
	it.ledges = ledges_
	it.on = on_
	it.lair = lair_
	it.doors = doors_
	return it


## None: what a level holds, or is handed, where there is no such thing (is_empty).
static func none() -> KeepSite:
	var it: KeepSite = KeepSite.new()
	it.laid = false
	return it
