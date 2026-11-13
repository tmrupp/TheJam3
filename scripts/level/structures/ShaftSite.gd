class_name ShaftSite
extends Structure
## The bramble's shaft in its gate levels (BrambleShaft.cut).

## Its open cells.
var inside: Rect2i = Rect2i()
## The floor the way on stands on, or null.
var on: Variant = null
## Where its relic lies.
var relic: Vector2i = Structure.NONE
## The knot at its head, the bramble's.
var knot: Rect2i = Rect2i()
## Its ledges.
var ledges: Array = []
## Its bulbs' cells.
var bulbs: Array = []
## Its vines.
var vines: Array = []


## One laid, holding what it is first laid with.
static func make(inside_: Rect2i, on_: Variant, relic_: Vector2i, knot_: Rect2i, ledges_: Array, bulbs_: Array) -> ShaftSite:
	var it: ShaftSite = ShaftSite.new()
	it.inside = inside_
	it.on = on_
	it.relic = relic_
	it.knot = knot_
	it.ledges = ledges_
	it.bulbs = bulbs_
	return it


## None: what a level holds, or is handed, where there is no such thing (is_empty).
static func none() -> ShaftSite:
	var it: ShaftSite = ShaftSite.new()
	it.laid = false
	return it
