class_name TempleSite
extends Structure
## A temple a sky level built (SkyArchetype.build_temples).

## Its cells.
var box: Rect2i = Rect2i()
## The open hall's rows.
var hall: Rect2i = Rect2i()
## The altar's cell.
var altar: Vector2i = Structure.NONE
## Its star clusters' cells, there once it is opened.
var hoard: Array = []


## One laid, holding what it is first laid with.
static func make(box_: Rect2i, hall_: Rect2i, altar_: Vector2i, hoard_: Array) -> TempleSite:
	var it: TempleSite = TempleSite.new()
	it.box = box_
	it.hall = hall_
	it.altar = altar_
	it.hoard = hoard_
	return it


## None: what is handed back where there is no such thing (is_empty).
static func none() -> TempleSite:
	var it: TempleSite = TempleSite.new()
	it.laid = false
	return it
