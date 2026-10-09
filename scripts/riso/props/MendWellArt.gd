extends "res://scripts/riso/props/ShrineArt.gd"
## A mending bowl standing on its own (MendWell): the shrine's mending station on a short plinth of
## its own, its bead gone once it is used.


## The MendWell it dresses.
var well: MendWell:
	get:
		return host as MendWell


func _draw_art() -> void:
	var g: float = _ground()
	var used: bool = well.used()
	ink.ink(RisoPrint.BLUE, 1.0, [RisoShapes.rrect(-36.0, g - 22, 72.0, 22, 8)])
	ink.ink(RisoPrint.ACCENT, 0.35 if used else 1.0, [RisoShapes.rrect(-30.0, g - 27, 60.0, 7, 3.5)])
	_mend_bowl(0.0, g, sin(t * 2.0 + phase) * 3.0, not well.can_mend(), used, well.heal_price())
