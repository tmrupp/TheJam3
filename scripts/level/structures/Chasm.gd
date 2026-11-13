class_name Chasm
extends Structure
## A chasm or gap cut across a level (Chasms).

## The cells its bridge's planks take.
var planks: Array = []
## The floor's row.
var row: int = 0
## The last floor cell before it.
var left: Vector2i = Structure.NONE
## The first floor cell after it.
var right: Vector2i = Structure.NONE


## One laid, holding what it is first laid with.
static func make(planks_: Array, row_: int, left_: Vector2i, right_: Vector2i) -> Chasm:
	var it: Chasm = Chasm.new()
	it.planks = planks_
	it.row = row_
	it.left = left_
	it.right = right_
	return it
