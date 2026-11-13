class_name Barrier
extends Structure
## A barrier made for one relic move (Barriers): a pocket off the level, a shape in its mouth.

## Which shape (Barriers.Kind).
var kind: int = -1
## The move it is made for.
var move: StringName = &""
## The floor cell beside its way in, where its mark stands.
var mouth: Vector2i = Structure.NONE
## The side of its mouth the pocket lies to (-1 left, 1 right).
var side: int = 0
## The cells carved open.
var open: Array = []
## The open cells thorns are laid in.
var thorns: Array = []
## Its reward's cell.
var reward: Vector2i = Structure.NONE
## Every cell of it and the rock round it.
var rock: Array = []


## One laid, holding what it is first laid with.
static func make(open_: Array, thorns_: Array, reward_: Vector2i, rock_: Array) -> Barrier:
	var it: Barrier = Barrier.new()
	it.open = open_
	it.thorns = thorns_
	it.reward = reward_
	it.rock = rock_
	return it
