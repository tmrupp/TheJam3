class_name Tower
extends Structure
## A tower a crags level built (CragsArchetype._tower): a watchtower, or a hoard tower.

## Its cells.
var box: Rect2i = Rect2i()
## Whether it is a hoard tower (no hatch, no windows, stars in its top room).
var hoard: bool = false
## The stair holes in its floors.
var holes: Array = []
## The ledge under each hole.
var ledges: Array = []
## Its top room's floor cells.
var top: Array = []
## The spire on a watchtower's roof, or NONE.
var spire: Vector2i = Structure.NONE
## Its switch's cell, or NONE.
var switch: Vector2i = Structure.NONE
## What a watchtower's top room holds (a LevelGen.Type), or -1.
var reward: int = -1
## Whether it stands cold until an empowered strike wakes it.
var cold: bool = false


## One laid, holding what it is first laid with.
static func make(box_: Rect2i, hoard_: bool, holes_: Array, ledges_: Array, top_: Array) -> Tower:
	var it: Tower = Tower.new()
	it.box = box_
	it.hoard = hoard_
	it.holes = holes_
	it.ledges = ledges_
	it.top = top_
	return it
