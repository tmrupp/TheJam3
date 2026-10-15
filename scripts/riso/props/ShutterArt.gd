extends RisoProp
## A shutter in the gondola's chute through a band of rock (Shutter): two heavy leaves of stone
## meeting across the chute, paler than the rock round them (it bars the way), studded with bare
## paper rivets, a dark seam where they meet, that slide apart into the rock while the car passes.

## The studs on each leaf: how many across, and how big.
const STUDS: int = 3
const STUD: float = 4.0


## The Shutter it dresses.
var gate: Shutter:
	get:
		return host as Shutter


func _draw_art() -> void:
	var s: Shutter = gate
	if s == null or not s.area.has_area():
		return
	var box: Rect2 = Rect2(to_local(s.area.position), s.area.size)
	var shut: float = 1.0 - s.open
	if shut <= 0.01:
		return
	# Each leaf covers half the chute when shut, sliding out to its side as it opens.
	var leaf_w: float = box.size.x * 0.5 * shut
	var leaves: Array[PackedVector2Array] = [
		RisoShapes.rrect(box.position.x, box.position.y, leaf_w, box.size.y, 0.0),
		RisoShapes.rrect(box.end.x - leaf_w, box.position.y, leaf_w, box.size.y, 0.0),
	]
	ink.knock([RisoPrint.NIGHT], leaves)
	ink.ink(RisoPrint.BLUE, 0.85, leaves)
	var studs: Array[PackedVector2Array] = []
	for leaf: int in range(2):
		var x0: float = box.position.x if leaf == 0 else box.end.x - leaf_w
		for i: int in range(STUDS):
			for j: int in range(2):
				var p: Vector2 = Vector2(x0 + leaf_w * (float(i) + 0.5) / float(STUDS), box.position.y + box.size.y * (0.3 + 0.4 * float(j)))
				studs.append(RisoShapes.circle(p, STUD, 8))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], studs)
	# The seam where the leaves meet.
	ink.ink(RisoPrint.NIGHT, 0.9, [RisoShapes.rrect(box.get_center().x - 2.0, box.position.y, 4.0, box.size.y, 0.0)], false)
