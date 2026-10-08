extends RisoProp
## A switch: a lever in a stone base, thrown or not.


## The Switch it dresses.
var lever: Switch:
	get:
		return host as Switch


## A switch: a stone base on the floor with a lever in it. Before it is thrown the lever leans left
## with a pink knob, swaying a little; thrown, it leans right, its knob and a halo in accent ink.
## A paper plate on the front of the base bears its sigil, the one what it works shows too.
func _draw_art() -> void:
	var g: float = _ground()
	var thrown: bool = lever.thrown()
	var base: PackedVector2Array = RisoShapes.rrect(-44, g - 42, 88, 42, 11)
	var slot: PackedVector2Array = RisoShapes.rrect(-20, g - 42, 40, 7, 3.5)
	var tilt: float = (0.6 if thrown else -0.6) + (0.0 if thrown else sin(t * 2.0 + phase) * 0.06)
	var pivot: Vector2 = Vector2(0, g - 39)
	var arm: Transform2D = Transform2D(tilt, pivot)
	var knob: Vector2 = arm * Vector2(0, -70)
	if thrown:
		ink.ink(RisoPrint.ACCENT, 0.3, [RisoShapes.circle(knob, 26.0, 22)])
	# The lever in blue, behind the base, so it reads against the night.
	ink.ink(RisoPrint.BLUE, 1.0, [arm * RisoShapes.rrect(-4.5, -68.0, 9.0, 68.0, 4.5)])
	ink.ink(RisoPrint.BLUE, 1.0, [base])
	ink.ink(RisoPrint.NIGHT, 0.35, [RisoShapes.rrect(-44, g - 10, 88, 10, 5)], false)
	ink.ink(RisoPrint.NIGHT, 0.6, [slot], false)
	RisoMarks.sigil_plate(ink, Vector2(0, g - 19.0), 1.3, 1.0, Sigils.of(host), false)
	var ball: PackedVector2Array = RisoShapes.circle(knob, 13.0, 20)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [ball])
	ink.ink(RisoPrint.ACCENT if thrown else RisoPrint.PINK, 1.0, [ball], false)
	ink.knock([RisoPrint.ACCENT, RisoPrint.PINK], [RisoShapes.circle(knob + Vector2(-2.5, -2.5), 2.6, 8)])
