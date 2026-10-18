extends RisoProp
## A glyph seal (GlyphSeal): a slab of pale marble across a doorway (blue screened back on paper,
## SLAB), shading to night at its foot,
## its top rounded, bearing a paper disc with the mark of the spell it asks for (RisoGlyph) in night
## ink, ringed by six small sigils. A blow that is not its spell glances off: it
## jolts and its sigils flash. Broken, it splits down the middle and the halves sink into the floor.

## The slab's half width and height (px), the disc's radius, and how big the mark is on it.
const HALF_W: float = 42.0
const TALL: float = 126.0
const DISC: float = 25.0
const MARK: float = 0.72
## How much of the blue ink the slab takes, on paper: pale, so it reads against the dark rooms.
const SLAB: float = 0.5


func _draw_art() -> void:
	var seal: GlyphSeal = host as GlyphSeal
	if seal == null:
		return
	var g: float = _ground()
	var jolt: float = sin(seal.since_glance * 60.0) * 5.0 * exp(-seal.since_glance * 8.0) if seal.since_glance < 0.6 else 0.0
	var crumble: float = maxf(seal.crumbling, 0.0) / GlyphSeal.CRUMBLE
	var sink: float = crumble * crumble * TALL
	# Whole, one slab; broken, its two halves parting.
	var halves: Array[PackedVector2Array] = []
	var gap: float = crumble * 14.0
	var top: Array[Vector2] = [Vector2(HALF_W, g - TALL + 26.0), Vector2(HALF_W * 0.7, g - TALL + 6.0), Vector2(0, g - TALL)]
	if crumble <= 0.0:
		halves.append(Transform2D(0.0, Vector2(jolt, 0.0)) * RisoShapes.smooth(PackedVector2Array([Vector2(-HALF_W, g), Vector2(HALF_W, g), top[0], top[1], top[2],
			Vector2(-top[1].x, top[1].y), Vector2(-top[0].x, top[0].y)]), 2))
	else:
		for side: float in [-1.0, 1.0]:
			var half_slab: PackedVector2Array = PackedVector2Array([Vector2(0, g), Vector2(side * HALF_W, g), Vector2(side * top[0].x, top[0].y), Vector2(side * top[1].x, top[1].y), top[2]])
			halves.append(Transform2D(0.0, Vector2(jolt + side * gap, sink)) * half_slab)
	ink.knock(RisoPrint.ALL_PLATES, halves)
	ink.ink(RisoPrint.BLUE, SLAB, halves)
	ink.ink(RisoPrint.NIGHT, 0.35, [Transform2D(0.0, Vector2(jolt, sink)) * RisoShapes.rrect(-HALF_W, g - 30.0, HALF_W * 2.0, 30.0, 2.0)], false)
	if crumble > 0.0:
		return
	var c: Vector2 = Vector2(jolt, g - TALL * 0.55)
	_disc(seal, c, DISC, MARK)
	var flash: float = 1.0 if seal.since_glance < 0.3 else 0.0
	var sigils: Array[PackedVector2Array] = []
	for k: int in range(6):
		var a: float = TAU * float(k) / 6.0 + t * 0.4
		sigils.append(RisoShapes.circle(c + Vector2.from_angle(a) * (DISC + 9.0), 3.0, 8))
	if flash > 0.0:
		ink.knock(RisoPrint.ALL_PLATES, sigils)
	else:
		ink.ink(RisoPrint.NIGHT, 0.7, sigils, false)


## Its paper disc at `c`, `r` px across, with its spell's mark `scale` big in night ink.
func _disc(seal: GlyphSeal, c: Vector2, r: float, scale: float) -> void:
	ink.knock(RisoPrint.ALL_PLATES, [RisoShapes.circle(c, r, 28)])
	if seal.spell == &"":
		return
	var mark: Array[PackedVector2Array] = []
	for poly: PackedVector2Array in RisoGlyph.of(seal.spell, Vector2.ZERO, t):
		mark.append(Transform2D(0.0, Vector2(scale, scale), 0.0, c) * poly)
	ink.ink(RisoPrint.NIGHT, 1.0, mark, false)
