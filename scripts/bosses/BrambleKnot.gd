class_name BrambleKnot
extends StaticBody2D
## The bramble's knot (Bramble): the solid body under its crown that walls off the head of its shaft,
## on the environment's layer, so nothing gets past it to the way on. A hex bolt stops on it as on
## rock, and the crown quivers where it struck (Bramble.struck_knot).

## The bramble it belongs to.
var bramble: Bramble


## A hex bolt has struck it, heading `dir`: no wound, the crown quivers.
func hex_hit(_damage: int, dir: Vector2) -> void:
	if bramble != null:
		bramble.struck_knot(dir)
