extends RisoProp
## A sun block or a shade block (PhaseBlock): a square of dressed stone filling its cell, laid in
## three courses of stones in a brick bond over dark mortar, each stone with a pale top edge, and in
## the middle its mark on a round plate. A sun block's stones are pale, near paper, warmed with a
## touch of accent, its plate a yellow sun with turning rays; a shade block's are deep blue under
## night ink over black joints, its plate night ink with a pale crescent moon. So the two kinds tell
## apart at a glance. While it bears no one it falls apart into a ghost of itself: its mortar gone,
## each stone shrunk to GHOST_SIZE of itself and faint, drifting a little round where it belongs,
## its mark still showing (GHOST_MARK); it gathers back into a block as it turns solid. Both kinds
## shine a little, a spark firm and less as a ghost (light), so they show in a dark crypt where
## the wizard's flame does not reach. No outlines.

## How big a ghost's stones are against a firm block's, how faint they print, how much their paper
## shows through, and how far they drift (px).
const GHOST_SIZE: float = 0.42
const GHOST_INK: float = 0.55
const GHOST_LIFT: float = 0.45
const GHOST_DRIFT: float = 4.0
## How much a ghost's mark still prints.
const GHOST_MARK: float = 0.55
## How far in from its cell's edge the block is drawn (px), how round its corners are, the joints
## between its stones (px), and how round a stone's corners are.
const INSET: float = 2.0
const CORNER: float = 6.0
const JOINT: float = 4.0
const STONE_CORNER: float = 3.0
## The pale top edge of each stone: how tall (px) and how much ink it lifts.
const EDGE: float = 4.0
const EDGE_LIFT: float = 0.45
## A sun block: its mortar's blue, its stones' blue and accent warmth.
const SUN_MORTAR: float = 0.6
const SUN_STONE: Vector2 = Vector2(0.18, 0.22)
## A shade block: its mortar's night, its stones' blue and night.
const SHADE_MORTAR: float = 0.95
const SHADE_STONE: Vector2 = Vector2(0.75, 0.12)
## Its mark: the plate's radius, the sun's disc and rays (px from its middle), and the crescent.
const PLATE_R: float = 21.0
const SUN_R: float = 8.0
const RAY: Vector2 = Vector2(11.0, 18.0)
const MOON_R: float = 13.0
## The light it gives, firm and as a ghost (as RisoLight.SPARK: reach, lift, tint).
const FIRM_LIGHT: Vector3 = Vector3(90.0, 0.08, 0.0)
const GHOST_LIGHT: Vector3 = Vector3(60.0, 0.05, 0.0)


## The PhaseBlock it dresses.
var block: PhaseBlock:
	get:
		return host as PhaseBlock


func shines() -> bool:
	return true


## A spark from its mark, smaller as a ghost.
func light() -> Array:
	var firm: float = block.firm if block != null else 1.0
	return _light(Vector2.ZERO, FIRM_LIGHT if firm >= 0.5 else GHOST_LIGHT, -1)


func _draw_art() -> void:
	var sun: bool = block == null or block.sun
	var firm: float = block.firm if block != null else 1.0
	var s: float = half - INSET
	# The mortar, which hides what is behind the block: only while it is (all but) firm.
	var square: PackedVector2Array = RisoShapes.rrect(-s, -s, s * 2.0, s * 2.0, CORNER)
	ink.lift_ink(RisoPrint.ALL_PLATES, firm, [square])
	if sun:
		ink.ink(RisoPrint.BLUE, SUN_MORTAR * firm, [square], false)
	else:
		ink.ink(RisoPrint.NIGHT, SHADE_MORTAR * firm, [square], false)
	# The stones, three courses in a brick bond: two in the top and bottom courses, a whole one
	# between two halves in the middle.
	var size: float = lerpf(GHOST_SIZE, 1.0, firm)
	var cover: float = lerpf(GHOST_INK, 1.0, firm)
	var course: float = s * 2.0 / 3.0
	var stones: Array[PackedVector2Array] = []
	var edges: Array[PackedVector2Array] = []
	var i: int = 0
	for row: int in range(3):
		var cuts: PackedFloat32Array = PackedFloat32Array([-s, 0.0, s] if row != 1 else [-s, -s * 0.5, s * 0.5, s])
		for k: int in range(cuts.size() - 1):
			var w: float = (cuts[k + 1] - cuts[k] - JOINT) * size
			var h: float = (course - JOINT) * size
			var drift: Vector2 = Vector2(sin(t * 1.3 + phase + float(i) * 1.7), cos(t * 1.1 + phase + float(i) * 2.3)) * GHOST_DRIFT * (1.0 - firm)
			var c: Vector2 = Vector2((cuts[k] + cuts[k + 1]) * 0.5, -s + course * (float(row) + 0.5)) + drift
			stones.append(RisoShapes.rrect(c.x - w * 0.5, c.y - h * 0.5, w, h, STONE_CORNER))
			edges.append(RisoShapes.rrect(c.x - w * 0.5 + 2.0, c.y - h * 0.5 + 1.0, w - 4.0, minf(EDGE, h * 0.3), 1.5))
			i += 1
	if sun:
		ink.lift_ink(RisoPrint.ALL_PLATES, lerpf(GHOST_LIFT, 1.0, firm), stones)
		ink.ink(RisoPrint.BLUE, SUN_STONE.x * cover, stones, false)
		ink.ink(RisoPrint.ACCENT, SUN_STONE.y * cover, stones, false)
	else:
		ink.ink(RisoPrint.BLUE, SHADE_STONE.x * cover, stones, false)
		ink.ink(RisoPrint.NIGHT, SHADE_STONE.y * cover, stones, false)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], EDGE_LIFT * cover, edges)
	_mark(sun, maxf(firm, GHOST_MARK))


## Its mark in the middle, `cover` of it: a sun or a crescent on a round plate.
func _mark(sun: bool, cover: float) -> void:
	var plate: PackedVector2Array = RisoShapes.circle(Vector2.ZERO, PLATE_R, 28)
	if sun:
		ink.lift_ink(RisoPrint.ALL_PLATES, cover, [plate])
		var rays: Array[PackedVector2Array] = [RisoShapes.circle(Vector2.ZERO, SUN_R, 20)]
		for k: int in range(8):
			var d: Vector2 = Vector2.from_angle(TAU * float(k) / 8.0 + t * 0.3)
			rays.append(PackedVector2Array([d * RAY.x + d.orthogonal() * 2.8, d * RAY.y, d * RAY.x - d.orthogonal() * 2.8]))
		ink.ink(RisoPrint.ACCENT, cover, rays, false)
	else:
		ink.ink(RisoPrint.NIGHT, cover, [plate], false)
		var moon: PackedVector2Array = RisoShapes.crescent(Vector2(-2.0, 0.0), MOON_R, Vector2(6.0, -4.0), 32)
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], 0.9 * cover, [moon])
