extends RisoProp
## A garden plot (Plot): a mound of dark turned earth heaped on the floor, its crown a little
## lighter, a clod or two at its foot. Bare, a marker stake stands in it with a paper tag showing a
## seed: what it is for, as a lock's face shows its key.
## Planted, a plant stands in it whose size shows what it will bear when picked (Plot.tier): a sprout
## of two seed leaves while the wizard has not been away; a stem with a gold bud (stars); a taller
## one opening a bone-white flower (a skeleton key); the tallest, crowned with a great gold bloom
## round a paper star (a hyperspace door); its leaves reach up the stem, a pair a tier. Ripe, it
## sways and shines (RisoLight). A plot whose plant became a door prints nothing: the door stands
## there.

## The mound: its half width and its height (px), and how far under the cell's middle its foot lies
## (the floor is half a cell down).
const MOUND: Vector2 = Vector2(52.0, 30.0)
const FOOT: float = 62.0
## How much of its night its crown sheds, catching the light.
const CROWN_LIFT: float = 0.35
## Clods of earth at its foot: across from its middle (x, px) and their size (z, px).
const CLODS: Array[Vector3] = [Vector3(-60.0, 0.0, 6.0), Vector3(57.0, 0.0, 4.5)]
## The marker stake, standing in the earth on its right: across from its middle (x, px), how high
## its top stands over the floor (y, px) and how wide it is (z, px).
const STAKE: Vector3 = Vector3(38.0, 70.0, 3.5)
## How much of the stake's blue is shaded by night (bark, as the bramble's).
const STAKE_NIGHT: float = 0.5
## The paper tag tied to the stake near its top: its size (px), how far under the stake's top its
## top edge hangs (px), how far it leans (radians), and the seed on it (RisoMarks.seed_shape), at
## that share of a key's size.
const TAG: Vector2 = Vector2(22.0, 17.0)
const TAG_DROP: float = 4.0
const TAG_LEAN: float = -0.12
const TAG_SEED: float = 0.42
## The plant's height (px) by tier: a sprout, then each reward's.
const HEIGHTS: Array[float] = [20.0, 46.0, 72.0, 100.0]
const STEM_W: float = 4.0
## Leaves: their half length and half width (px), and how far they reach up from level (radians).
const LEAF: Vector2 = Vector2(13.0, 5.0)
const LEAF_LIFT: float = 0.6
## A sprout's two seed leaves, splayed in a V at its top: their half length and half width (px), and
## how far they reach up from level (radians).
const SEED_LEAF: Vector2 = Vector2(7.5, 4.5)
const SEED_LEAF_LIFT: float = 0.75


var plot: Plot:
	get:
		return host as Plot


func shines() -> bool:
	return true


func light() -> Array:
	if plot == null or plot.tier() == 0:
		return []
	return _light(Vector2(0, FOOT - MOUND.y - HEIGHTS[plot.tier()]), RisoLight.GLEAM, RisoPrint.ACCENT)


func _draw_art() -> void:
	var p: Plot = plot
	if p == null or p.door():
		return
	_draw_mound()
	if p.planted():
		_draw_plant(p.tier())
	else:
		_draw_stake()


## The mound: a flat foot on the floor, its sides rising to a rounded crown a little lighter, and a
## clod or two at its foot.
func _draw_mound() -> void:
	var mound: PackedVector2Array = RisoShapes.smooth(PackedVector2Array([
		Vector2(-MOUND.x, FOOT), Vector2(-MOUND.x * 0.75, FOOT - MOUND.y * 0.5), Vector2(-MOUND.x * 0.4, FOOT - MOUND.y * 0.92),
		Vector2(0, FOOT - MOUND.y), Vector2(MOUND.x * 0.4, FOOT - MOUND.y * 0.92), Vector2(MOUND.x * 0.75, FOOT - MOUND.y * 0.5),
		Vector2(MOUND.x, FOOT)]))
	ink.ink(RisoPrint.NIGHT, 1.0, [mound])
	ink.ink(RisoPrint.BLUE, 0.3, [mound])
	ink.lift_ink([RisoPrint.NIGHT], CROWN_LIFT, [RisoShapes.ellipse(Vector2(-MOUND.x * 0.12, FOOT - MOUND.y * 0.72), MOUND.x * 0.5, MOUND.y * 0.22, 18)])
	var clods: Array[PackedVector2Array] = []
	for c: Vector3 in CLODS:
		clods.append(RisoShapes.ellipse(Vector2(c.x, FOOT - c.z), c.z, c.z * 0.8, 10))
	ink.ink(RisoPrint.NIGHT, 1.0, clods)
	ink.ink(RisoPrint.BLUE, 0.3, clods)


## The marker stake in the earth, and its paper tag with a seed on it.
func _draw_stake() -> void:
	var top: Vector2 = Vector2(STAKE.x, FOOT - STAKE.y)
	var stake: Array[PackedVector2Array] = [RisoShapes.strand(Vector2(STAKE.x, FOOT - MOUND.y * 0.3), top, STAKE.z)]
	ink.ink(RisoPrint.BLUE, 1.0, stake)
	ink.ink(RisoPrint.NIGHT, STAKE_NIGHT, stake, false)
	var xf: Transform2D = Transform2D(TAG_LEAN, top + Vector2(0, TAG_DROP))
	ink.lift_ink(RisoPrint.ALL_PLATES, 1.0, [xf * RisoShapes.rrect(-TAG.x * 0.5, 0.0, TAG.x, TAG.y, 3.0)])
	var mark: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in RisoMarks.seed_shape(Vector2(0, TAG.y * 0.5 + 1.0), TAG_SEED):
		mark.append(xf * poly)
	RisoPrint.ink_key(ink, KeyRing.SEED, 1.0, mark)


## The plant growing from the crown, by `tier` (Plot.tier).
func _draw_plant(tier: int) -> void:
	var ground: float = FOOT - MOUND.y * 0.85
	var h: float = HEIGHTS[tier]
	var sway: float = sin(t * 1.6 + phase) * (0.06 if tier > 0 else 0.02)
	var xf: Transform2D = Transform2D(sway, Vector2(0, ground))
	var top: Vector2 = Vector2(0, -h)
	ink.ink(RisoPrint.BLUE, 1.0, [xf * RisoShapes.strand(Vector2.ZERO, top, STEM_W)])
	if tier == 0:
		# A sprout: two round seed leaves splayed in a V at its top.
		var seed_leaves: Array[PackedVector2Array] = []
		for side: float in [-1.0, 1.0]:
			var out: Vector2 = Vector2(side * cos(SEED_LEAF_LIFT), -sin(SEED_LEAF_LIFT))
			seed_leaves.append(xf * RisoShapes.spindle(top + out * SEED_LEAF.x * 0.9, SEED_LEAF.x, SEED_LEAF.y, out.angle(), 14))
		ink.ink(RisoPrint.BLUE, 1.0, seed_leaves)
		return
	# Leaves reaching up the stem, a pair a tier.
	var leaves: Array[PackedVector2Array] = []
	for i: int in range(tier):
		var y: float = -h * (0.3 + 0.5 * float(i) / float(tier))
		for side: float in [-1.0, 1.0]:
			var out: Vector2 = Vector2(side * cos(LEAF_LIFT), -sin(LEAF_LIFT))
			leaves.append(xf * RisoShapes.spindle(Vector2(0, y) + out * LEAF.x * 0.85, LEAF.x, LEAF.y, out.angle(), 14))
	ink.ink(RisoPrint.BLUE, 1.0, leaves)
	ink.ink(RisoPrint.NIGHT, 0.3, leaves)
	match tier:
		1:
			# A gold bud.
			ink.ink(RisoPrint.ACCENT, 1.0, [xf * RisoShapes.almond(top + Vector2(0, -6), 7.0, 11.0)])
		2:
			# A bone-white flower: paper petals round a gold eye.
			var petals: Array[PackedVector2Array] = []
			for k: int in range(5):
				var a: float = TAU * float(k) / 5.0 + t * 0.3
				petals.append(xf * RisoShapes.spindle(top + Vector2.from_angle(a) * 10.0, 10.0, 5.0, a, 12))
			ink.lift_ink(RisoPrint.ALL_PLATES, 1.0, petals)
			ink.ink(RisoPrint.ACCENT, 1.0, [xf * RisoShapes.circle(top, 5.0, 14)])
		3:
			# A great gold bloom round a paper star.
			var bloom: Array[PackedVector2Array] = []
			for k: int in range(8):
				var a: float = TAU * float(k) / 8.0 + t * 0.4
				bloom.append(xf * RisoShapes.spindle(top + Vector2.from_angle(a) * 16.0, 15.0, 7.0, a, 12))
			ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 1.0, bloom)
			ink.ink(RisoPrint.ACCENT, 1.0, bloom)
			ink.lift_ink(RisoPrint.ALL_PLATES, 1.0, [xf * RisoShapes.sparkle(top, 11.0)])
