class_name BarrierMark
extends Node2D
## The mark by a barrier's mouth (Barriers): the mark of the relic move it is made for, in a small
## roundel on the rock over its way in, in the quiet inks (BarrierMarkArt): a note, not a prize. It
## is there while the wizard does not know the move, and gone once they do. Set up with the move and
## the side its pocket lies to (LevelGen.barriers).

## The move its barrier is made for, and the side (-1 left, 1 right) its pocket lies to of its cell
## (the floor at its mouth).
var move: StringName = &""
var side: int = 1
## The cell of rock over the way in it is printed on (the first rock up from the cell beside its
## mouth), and whether to show it now.
var on_rock: Vector2i = Vector2i.ZERO
var showing: bool = true
## How many cells up from the way in to look for the rock it is printed on.
const LOOK_UP: int = 3


func setup(info: MapInfo, v: Vector2i, extra: Variant) -> void:
	var how: Dictionary = extra if extra is Dictionary else {}
	move = StringName(how.get("move", &""))
	side = int(how.get("side", 1))
	var door: Vector2i = v + Vector2i(side, 0)
	on_rock = door
	for k: int in range(0, LOOK_UP + 1):
		if info.world.is_ground(door + Vector2i(0, -k)):
			on_rock = door + Vector2i(0, -k)
			break


func _process(_delta: float) -> void:
	var player: Player = Stage.player()
	showing = move != &"" and (player == null or not is_instance_valid(player) or Abilities.tier(player, move) <= 0)
