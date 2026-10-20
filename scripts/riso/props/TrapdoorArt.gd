extends RisoProp
## A trapdoor (Trapdoor) in a watchtower's roof: a slab of planks across the top of its cell, in the
## rock's blue with a night shade along its underside, two night iron straps across it, and a paper
## ring hanging under it (it is pulled open from below).


func _draw_art() -> void:
	var top: float = -half
	var thick: float = Trapdoor.SLAB
	var slab: PackedVector2Array = RisoShapes.rrect(-half + 2.0, top, half * 2.0 - 4.0, thick, 3.0)
	ink.knock([RisoPrint.NIGHT, RisoPrint.PINK, RisoPrint.ACCENT], [slab])
	ink.ink(RisoPrint.BLUE, 1.0, [slab])
	ink.ink(RisoPrint.NIGHT, 0.4, [RisoShapes.rrect(-half + 2.0, top + thick * 0.55, half * 2.0 - 4.0, thick * 0.45, 2.0)], false)
	# Its planks' seams and two iron straps across them.
	var seams: Array[PackedVector2Array] = []
	for k: int in range(1, 4):
		var x: float = -half + half * 0.5 * float(k)
		seams.append(RisoShapes.rrect(x - 1.0, top + 2.0, 2.0, thick - 4.0, 0.0))
	ink.ink(RisoPrint.NIGHT, 0.35, seams, false)
	var straps: Array[PackedVector2Array] = []
	for x: float in [-half * 0.55, half * 0.55]:
		straps.append(RisoShapes.rrect(x - 5.0, top - 1.0, 10.0, thick + 2.0, 2.0))
	ink.ink(RisoPrint.NIGHT, 0.8, straps, false)
	# The ring it is pulled open by, hanging under it.
	var ring: Array[PackedVector2Array] = [RisoShapes.crescent(Vector2(0.0, top + thick + 9.0), 8.0, Vector2(0.0, -3.0))]
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], ring)
