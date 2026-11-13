class_name Crypt
extends Structure
## A crypt a cemetery level built (Crypts).

## Its cells, walls and all.
var box: Rect2i = Rect2i()
## Its open cells.
var inside: Array = []
## Its doorways.
var doors: Array = []
## The floor outside each doorway.
var steps: Array = []
## The floors reached inside, shallowest first.
var floors: Array = []
## Its deepest floor, or NONE.
var deep: Vector2i = Structure.NONE
## The steps set in to join its floors.
var stairs: Array = []
## Its trials (CryptTrial).
var trials: Array = []
## Its prize's cell, or NONE.
var prize: Vector2i = Structure.NONE


## One laid, holding what it is first laid with.
static func make(box_: Rect2i, inside_: Array, doors_: Array, steps_: Array, floors_: Array, deep_: Vector2i, stairs_: Array, trials_: Array) -> Crypt:
	var it: Crypt = Crypt.new()
	it.box = box_
	it.inside = inside_
	it.doors = doors_
	it.steps = steps_
	it.floors = floors_
	it.deep = deep_
	it.stairs = stairs_
	it.trials = trials_
	return it
