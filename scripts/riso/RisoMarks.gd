class_name RisoMarks
extends RefCounted
## Printed marks shared by the props, the printed map, the HUD and the prompts: keys and their
## bows (one shape per colour), padlocks and gates, the switch emblem, the sigils that link a switch
## or a teleporter to its partner, chains, the wizard's ghost, chevrons, a smoke thread and the place
## marks. Pure shapes and ink, drawn into whatever
## InkCanvas is given.


# ------------------------------------------------------------------ places, without words
# A place reads as marks and numbers only: a world (a globe banded by two paper latitudes) before
# the world's number, a depth (a thick down arrow) before the depth's, and, in a side world, its
# door's mark (an upright portal) after them (Rules.place_numbers). Sized by `r`, a mark's half
# height; the gaps are shares of it.

## The space after a mark before its number, and between the world's number and the depth mark.
const PLACE_GAP: float = 0.45
const PLACE_SPACE: float = 1.1


## A globe: a disc with two paper latitudes knocked out of it.
static func world_glyph(ink: InkCanvas, at: Vector2, r: float, plate: int = RisoPrint.NIGHT, cover: float = 1.0) -> void:
	ink.ink(plate, cover, [RisoShapes.circle(at, r, 22)], false)
	var bands: Array[PackedVector2Array] = []
	for k: float in [-0.38, 0.38]:
		var y: float = at.y + r * k
		var half: float = sqrt(maxf(0.0, r * r - (r * k) * (r * k))) * 0.86
		bands.append(RisoShapes.rrect(at.x - half, y - r * 0.09, half * 2.0, r * 0.18, r * 0.09))
	ink.knock([plate], bands)


## Depth: a thick arrow pointing down, or, for a height above the start (`up`), pointing up.
static func depth_glyph(ink: InkCanvas, at: Vector2, r: float, plate: int = RisoPrint.NIGHT, cover: float = 1.0, up: bool = false) -> void:
	var flip: float = -1.0 if up else 1.0
	var arrow: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in [Vector2(-r * 0.36, -r), Vector2(r * 0.36, -r), Vector2(r * 0.36, 0.0), Vector2(r * 0.9, 0.0),
			Vector2(0.0, r), Vector2(-r * 0.9, 0.0), Vector2(-r * 0.36, 0.0)]:
		arrow.append(at + Vector2(p.x, p.y * flip))
	ink.ink(plate, cover, [arrow], false)


## A side world: an upright portal, its middle bare paper.
static func side_glyph(ink: InkCanvas, at: Vector2, r: float, plate: int = RisoPrint.NIGHT, cover: float = 1.0) -> void:
	ink.ink(plate, cover, [RisoShapes.rrect(at.x - r * 0.6, at.y - r, r * 1.2, r * 2.0, r * 0.6)], false)
	ink.knock([plate], [RisoShapes.rrect(at.x - r * 0.3, at.y - r * 0.68, r * 0.6, r * 1.36, r * 0.3)])


## How wide a place is printed with marks of half height `r` and numbers `widths` wide (world,
## depth), with a side world's mark when `side`.
static func place_width(r: float, widths: Vector2, side: bool) -> float:
	var w: float = r * 2.0 + r * PLACE_GAP + widths.x + r * PLACE_SPACE + r * 2.0 + r * PLACE_GAP + widths.y
	return w + (r * PLACE_SPACE + r * 1.2 if side else 0.0)


## Print a place's marks from `left`, centred on its y, for numbers `widths` wide; returns where
## the two numbers start (x of the world's, x of the depth's), for the caller's text. `up` turns
## the depth mark up, for a height above the start (Rules.place_numbers: a negative row).
static func place_marks(ink: InkCanvas, left: Vector2, r: float, widths: Vector2, side: bool, up: bool = false, plate: int = RisoPrint.NIGHT, cover: float = 1.0) -> Vector2:
	var x: float = left.x
	world_glyph(ink, Vector2(x + r, left.y), r, plate, cover)
	var world_x: float = x + r * 2.0 + r * PLACE_GAP
	x = world_x + widths.x + r * PLACE_SPACE
	depth_glyph(ink, Vector2(x + r, left.y), r, plate, cover, up)
	var depth_x: float = x + r * 2.0 + r * PLACE_GAP
	if side:
		side_glyph(ink, Vector2(depth_x + widths.y + r * PLACE_SPACE + r * 0.6, left.y), r, plate, cover)
	return Vector2(world_x, depth_x)


## The same colour-to-shape identity on keys, lock faces and map marks.
## Sun = square, ember = triangle, moss = circle, plum = diamond; skeleton keys are a bone, and
## relic unlocks the four-pointed star stamped on their seal (seal_shape), as a relic's motes are;
## seeds their own almond (seed_shape).
static func key_bow(c: Vector2, r: float, color: int) -> PackedVector2Array:
	if color == KeyRing.SKELETON:
		return bone(c, r, r * 0.7)
	if color == KeyRing.UNLOCK:
		return RisoShapes.sparkle(c, r * UNLOCK_BOW)
	if color == KeyRing.SEED:
		return RisoShapes.almond(c, r * 0.8, r * 1.2)
	if KeyRing.is_paper(color):
		return paper_shape(c, r / 14.0)[0]
	match posmod(color, Rules.KEY_COLOR_COUNT):
		1: return RisoShapes.tri(c + Vector2(0, -r), c + Vector2(r, r), c + Vector2(-r, r))
		2: return RisoShapes.circle(c, r, 24)
		3: return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	return RisoShapes.rrect(c.x - r, c.y - r, r * 2.0, r * 2.0, r * 0.12)


## Teeth past the bit of a rarer key, one per step of rarity (Rules.KEY_RARITY): how far down
## each hangs, in turn.
const KEY_TEETH: Array[float] = [8.0, 10.0, 7.0]
## Teeth past a skeleton key's bit, as a moss key's (see KEY_TEETH); and how much bigger than another
## key's bow a relic unlock's star is on the map.
const SKELETON_TEETH: int = 2
const UNLOCK_BOW: float = 1.5
## A relic unlock's seal, at a key's size: how far its points reach up and down from its middle (px),
## how wide it is against that, and how far the star stamped on it reaches against that.
const SEAL_R: float = 17.0
const SEAL_W: float = 0.8
const SEAL_STAR: float = 0.62


## A relic unlock (KeyRing.UNLOCK) at `s` times a key's size, centred on `o`: a seal, a diamond
## taller than it is wide, and the four-pointed star stamped on it (a relic's mote), in that order.
static func seal_shape(o: Vector2, s: float) -> Array[PackedVector2Array]:
	var r: float = SEAL_R * s
	var w: float = r * SEAL_W
	return [PackedVector2Array([o + Vector2(0, -r), o + Vector2(w, 0), o + Vector2(0, r), o + Vector2(-w, 0)]),
		RisoShapes.sparkle(o, r * SEAL_STAR)]


## A seed (KeyRing.SEED), at `s` times a key's size, centred on `o`: an almond standing on its
## point, leaning a little, its seam down the middle (lifted to paper), and a curl of sprout from its
## top, in that order.
const SEED_R: Vector2 = Vector2(10.0, 15.0)
const SEED_LEAN: float = 0.35

static func seed_shape(o: Vector2, s: float) -> Array[PackedVector2Array]:
	var xf: Transform2D = Transform2D(SEED_LEAN, Vector2(s, s), 0.0, o)
	var body: PackedVector2Array = xf * RisoShapes.almond(Vector2.ZERO, SEED_R.x, SEED_R.y)
	var seam: PackedVector2Array = xf * RisoShapes.strand(Vector2(0, -SEED_R.y * 0.6), Vector2(0, SEED_R.y * 0.5), 1.6)
	var sprout: PackedVector2Array = xf * RisoShapes.crescent(Vector2(3, -SEED_R.y - 4), 6.0, Vector2(3, 2))
	return [body, seam, sprout]


## A bone `hw` across and `hh` high from its middle out, centred on `c`: a bar with two round knobs
## at each end.
static func bone(c: Vector2, hw: float, hh: float) -> PackedVector2Array:
	return Transform2D(0.0, Vector2(hw, hh), 0.0, c) * RisoShapes.smooth(PackedVector2Array([
		Vector2(-0.62, -0.42), Vector2(0.62, -0.42), Vector2(0.78, -1.0), Vector2(1.0, -0.62), Vector2(0.9, 0.0),
		Vector2(1.0, 0.62), Vector2(0.78, 1.0), Vector2(0.62, 0.42), Vector2(-0.62, 0.42), Vector2(-0.78, 1.0),
		Vector2(-1.0, 0.62), Vector2(-0.9, 0.0), Vector2(-1.0, -0.62), Vector2(-0.78, -1.0)]))


## A key with a colour-specific bow, in world pixels, centred near `o`. The rarer its colour, the
## longer its shaft and the more teeth on its bit (a plum key has four), so rarity reads at a glance.
## An exam paper is its sheet (paper_shape) and a relic unlock its seal (seal_shape).
static func key_shape(o: Vector2, s: float, color: int = 0) -> Array[PackedVector2Array]:
	if KeyRing.is_paper(color):
		return paper_shape(o, s)
	if color == KeyRing.UNLOCK:
		return seal_shape(o, s)
	if color == KeyRing.SEED:
		return seed_shape(o, s)
	# A skeleton key has the bit of a rare key (three teeth) and a bone's knobbed base for its bow.
	var skeleton: bool = color == KeyRing.SKELETON
	var extra: int = SKELETON_TEETH if skeleton else clampi(color, 0, KEY_TEETH.size())
	var c: Vector2 = o - Vector2(2.5 * extra, 0) * s
	var out: Array[PackedVector2Array] = []
	if skeleton:
		out.append(RisoShapes.circle(c + Vector2(-14, -5) * s, 6.0 * s, 16))
		out.append(RisoShapes.circle(c + Vector2(-14, 5) * s, 6.0 * s, 16))
		out.append(RisoShapes.rrect(c.x - 15.0 * s, c.y - 3.5 * s, 14.0 * s, 7.0 * s, 3.5 * s))
	else:
		out.append(key_bow(c + Vector2(-10, 0) * s, 11.0 * s, color))
	out.append(RisoShapes.rrect(c.x - 3.0 * s, c.y - 3.5 * s, (24.0 + 5.0 * extra) * s, 7.0 * s, 3.5 * s))
	out.append(RisoShapes.rrect(c.x + 12.0 * s, c.y, 6.0 * s, 11.0 * s, 3.0 * s))
	for k: int in range(extra):
		out.append(RisoShapes.rrect(c.x + (20.0 + 5.0 * k) * s, c.y, 3.0 * s, KEY_TEETH[k] * s, 1.5 * s))
	return out


## What is cut back out of `band`'s emblem round `c` once it is printed (emblem): the skull's eyes; none
## for the others.
static func emblem_holes(band: StringName, c: Vector2) -> Array[PackedVector2Array]:
	if band == &"cemetery":
		return [RisoShapes.circle(c + Vector2(-3.2, -2.0), 2.2, 10), RisoShapes.circle(c + Vector2(3.2, -2.0), 2.2, 10)]
	return []


## A department's emblem, by the band it studies (Institute.DEPARTMENTS), round `c`, about 24 px
## across: a sprout (two leaves on a stem) for the garden, a skull for the cemetery, three pointed
## crystals for the crags, a star for the sky; the institute's own a pediment over three columns (a
## department's portal, DepartmentArt; a door's prerequisite, ExamDoorArt; the timetable board, BoardArt).
static func emblem(band: StringName, c: Vector2) -> Array[PackedVector2Array]:
	match band:
		&"garden":
			# A sprout: two leaves on a stem.
			return [RisoShapes.rrect(c.x - 1.3, c.y - 3.0, 2.6, 15.0, 1.3),
				Transform2D(-0.9, c + Vector2(-5.5, -4.0)) * RisoShapes.almond(Vector2.ZERO, 4.0, 8.0, 12),
				Transform2D(0.9, c + Vector2(5.5, -4.0)) * RisoShapes.almond(Vector2.ZERO, 4.0, 8.0, 12)]
		&"cemetery":
			return [RisoShapes.circle(c + Vector2(0, -2.0), 8.0, 16), RisoShapes.rrect(c.x - 4.5, c.y + 3.0, 9.0, 6.0, 2.0)]
		&"crags":
			# Three pointed crystals out of one base, the middle tallest.
			var spike: PackedVector2Array = PackedVector2Array([Vector2(-3.5, 0), Vector2(-3.5, -12), Vector2(0, -17), Vector2(3.5, -12), Vector2(3.5, 0)])
			return [Transform2D(0.0, c + Vector2(0, 11)) * spike, Transform2D(-0.5, Vector2(0.75, 0.75), 0.0, c + Vector2(-4.5, 11)) * spike,
				Transform2D(0.5, Vector2(0.75, 0.75), 0.0, c + Vector2(4.5, 11)) * spike]
		&"sky":
			return [RisoShapes.sparkle(c, 12.0)]
	var out: Array[PackedVector2Array] = [PackedVector2Array([c + Vector2(-11, -4), c + Vector2(0, -11), c + Vector2(11, -4)])]
	for x: float in [-7.0, 0.0, 7.0]:
		out.append(RisoShapes.rrect(c.x + x - 1.6, c.y - 3.0, 3.2, 12.0, 0.8))
	return out


## An exam paper (KeyRing.paper) centred on `o`, `s` its size, a scroll: its whole outline first
## (printed bare paper), then its two rolled ends (PAPER_ROLLS: the top's and the bottom's, wider
## than the sheet between them), then three ruled lines (printed in night).
static func paper_shape(o: Vector2, s: float) -> Array[PackedVector2Array]:
	var w: float = SCROLL_SHEET.x * 0.5
	var h: float = SCROLL_SHEET.y * 0.5
	var r: float = SCROLL_ROLL.x * 0.5
	var t: float = SCROLL_ROLL.y
	# The outline: the top roll, down the sheet's right side, the bottom roll, up its left side.
	var outline: PackedVector2Array = PackedVector2Array([
		Vector2(-r + 1.5, -h - t * 0.5), Vector2(r - 1.5, -h - t * 0.5), Vector2(r, -h - t * 0.5 + 1.5), Vector2(r, -h + t * 0.5 - 1.5), Vector2(r - 1.5, -h + t * 0.5),
		Vector2(w, -h + t * 0.5), Vector2(w, h - t * 0.5),
		Vector2(r - 1.5, h - t * 0.5), Vector2(r, h - t * 0.5 + 1.5), Vector2(r, h + t * 0.5 - 1.5), Vector2(r - 1.5, h + t * 0.5), Vector2(-r + 1.5, h + t * 0.5),
		Vector2(-r, h + t * 0.5 - 1.5), Vector2(-r, h - t * 0.5 + 1.5), Vector2(-r + 1.5, h - t * 0.5),
		Vector2(-w, h - t * 0.5), Vector2(-w, -h + t * 0.5),
		Vector2(-r + 1.5, -h + t * 0.5), Vector2(-r, -h + t * 0.5 - 1.5), Vector2(-r, -h - t * 0.5 + 1.5)])
	var place: Transform2D = Transform2D(0.0, Vector2(s, s), 0.0, o)
	var out: Array[PackedVector2Array] = [place * outline]
	for y: float in [-h, h]:
		out.append(place * RisoShapes.rrect(-r, y - t * 0.5, 2.0 * r, t, t * 0.5))
	for k: int in range(3):
		out.append(RisoShapes.rrect(o.x - 5.5 * s, o.y + (-4.5 + 4.5 * k) * s, 11.0 * s, 1.6 * s, 0.8 * s))
	return out


## The glints along an exam paper's two rolled ends (paper_shape) at `o`, `s` its size: a thin strip
## of bare paper near the top of each roll, so the rolls read as round.
static func scroll_glints(o: Vector2, s: float) -> Array[PackedVector2Array]:
	var place: Transform2D = Transform2D(0.0, Vector2(s, s), 0.0, o)
	var r: float = SCROLL_ROLL.x * 0.5 - 3.0
	var out: Array[PackedVector2Array] = []
	for y: float in [-SCROLL_SHEET.y * 0.5, SCROLL_SHEET.y * 0.5]:
		out.append(place * RisoShapes.rrect(-r, y - SCROLL_ROLL.y * 0.5 + 1.2, 2.0 * r, 1.4, 0.7))
	return out


## An exam paper's scroll (paper_shape), for a size of 1 (px): its sheet between the rolls (across,
## and from one roll's middle to the other's), and each roll (across, and thick). The rolls stand
## out past the sheet either side, so it reads as a scroll rather than a sheet.
const SCROLL_SHEET: Vector2 = Vector2(17, 22)
const SCROLL_ROLL: Vector2 = Vector2(23, 6)
## Where an exam paper's rolled ends are in paper_shape's list (from, to): printed bare paper on a
## tinted sheet, in pink on a stolen one.
const PAPER_ROLLS: Vector2i = Vector2i(1, 3)


## The wizard's astral silhouette where they died, in glow ink, with the stars it holds circling.
static func ghost_shape(at: Transform2D, facing: float = 1.0) -> Array[PackedVector2Array]:
	return [
		at * RisoShapes.smooth(PackedVector2Array([Vector2(-3.8, -15), Vector2(-6.6, -7), Vector2(-9, -2.2), Vector2(9, -2.2), Vector2(6.6, -7), Vector2(3.8, -15)])),
		at * RisoShapes.smooth(PackedVector2Array([Vector2(-5, -21.4), Vector2(-2.9, -28.4), Vector2(-facing * 4.6, -37), Vector2(2.9, -28.4), Vector2(5, -21.4)])),
	]


static func chevron(at: Vector2, dir: Vector2, k: float) -> PackedVector2Array:
	var side: Vector2 = Vector2(-dir.y, dir.x)
	return PackedVector2Array([at + dir * 10.0 * k, at + (side * 22.0 - dir * 12.0) * k, at + (side * 16.0 - dir * 18.0) * k,
		at - dir * 2.0 * k, at + (-side * 16.0 - dir * 18.0) * k, at + (-side * 22.0 - dir * 12.0) * k])


## The switch emblem (also on its gate): a lever leaning out of a round base, about 20 * `s` wide.
static func switch_emblem(c: Vector2, s: float) -> Array[PackedVector2Array]:
	return [RisoShapes.rrect(c.x - 9.0 * s, c.y + 2.0 * s, 18.0 * s, 6.0 * s, 3.0 * s), Transform2D(0.55, c + Vector2(0, 3.0) * s) * RisoShapes.rrect(-1.8 * s, -12.0 * s, 3.6 * s, 13.0 * s, 1.8 * s),
		RisoShapes.circle(c + Vector2(6.6, -7.0) * s, 3.4 * s, 12)]


## How far a portcullis's outer bars reach either side of its middle, and a bar's width (px): the
## gates' bodies are as wide as this (switch_gate.tscn and the others: 90), so the wizard stops at
## the iron.
const PORTCULLIS_HALF: float = 45.0
const PORTCULLIS_BAR: float = 12.0


## A portcullis filling its corridor cell: a header beam at the ceiling, four iron bars ending
## in spikes just above the floor, and one cross-rail hung with a padlock in the key colour it
## needs (padlock; a switch gate, `key_color` -1, shows the switch's emblem and its switch's
## sigil `sigil_kind` on a paper plate instead, sigil_plate). `lift` (0 closed, 1 open) winches
## the grate up into the header: the bars shorten from the bottom. `fade` scales every ink.
## A portcullis's `key_color` for one with no lock or switch plate on it (a toll gate, whose price is
## printed over it instead).
const NO_LOCK: int = -2

static func portcullis(ink: InkCanvas, g: float, half: float, key_color: int, lift: float, fade: float, sigil_kind: int = -1) -> void:
	var top: float = g - 2.0 * half
	var bottom: float = lerpf(g - 14.0, top + 14.0, clampf(lift, 0.0, 1.0))
	var span: float = bottom - (top + 10.0)
	if span > 6.0:
		var iron: Array[PackedVector2Array] = []
		var step: float = (PORTCULLIS_HALF - PORTCULLIS_BAR * 0.5) * 2.0 / 3.0
		for k: int in range(4):
			var x: float = -PORTCULLIS_HALF + PORTCULLIS_BAR * 0.5 + step * float(k)
			iron.append(RisoShapes.rrect(x - PORTCULLIS_BAR * 0.5, top + 10.0, PORTCULLIS_BAR, span, 4.0))
			iron.append(RisoShapes.tri(Vector2(x - 8.0, bottom - 3.0), Vector2(x + 8.0, bottom - 3.0), Vector2(x, bottom + 12.0)))
		var ly: float = top + 10.0 + span * 0.5
		iron.append(RisoShapes.rrect(-52, ly - 6.0, 104, 12, 6))
		_gate_iron(ink, key_color, fade, iron)
		if span > 40.0 and key_color != NO_LOCK:
			if key_color < 0:
				# A switch gate: the switch's emblem and its sigil on a paper plate.
				sigil_plate(ink, Vector2(0, ly), GATE_PLATE_SCALE, fade, sigil_kind, true)
			else:
				# A padlock in its key's colour hangs from the cross-rail, as on a cemetery's bells.
				padlock(ink, Vector2(0, ly - 4.0), key_color, 1.6, fade)
	_gate_iron(ink, key_color, fade, [RisoShapes.rrect(-half, top - 2.0, 2.0 * half, 14, 4)])


## A gondola's line as a little chain (a station's gate and board, GateArt and StationArt): a cable
## `wide` across centred on `c`, with a node for each of its `n` stations, bottom (left) to top, lit
## in accent with a paper glint while `on(i)` (on), a small night disc while not; and station
## `here`'s node bigger, with a night pointer under it (this is the one). `s` scales it.
static func station_chain(ink: InkCanvas, c: Vector2, wide: float, n: int, here: int, on: Callable, s: float = 1.0) -> void:
	if n <= 0:
		return
	var step: float = wide / float(maxi(n - 1, 1))
	var x0: float = c.x - wide * 0.5 if n > 1 else c.x
	ink.ink(RisoPrint.NIGHT, 0.55, [RisoShapes.rrect(x0, c.y - 1.2 * s, wide if n > 1 else 0.0, 2.4 * s, 0.0)], false)
	var lit: Array[PackedVector2Array] = []
	var glints: Array[PackedVector2Array] = []
	var dark: Array[PackedVector2Array] = []
	for i: int in range(n):
		var p: Vector2 = Vector2(x0 + step * float(i), c.y)
		var big: float = 1.6 if i == here else 1.0
		if bool(on.call(i)):
			lit.append(RisoShapes.circle(p, 4.5 * s * big, 14))
			glints.append(RisoShapes.circle(p + Vector2(-1.2, -1.2) * s * big, 1.5 * s * big, 8))
		else:
			dark.append(RisoShapes.circle(p, 3.6 * s * big, 12))
		if i == here:
			var tip: Vector2 = p + Vector2(0.0, 9.5 * s)
			dark.append(PackedVector2Array([tip, tip + Vector2(4.5, 6.0) * s, tip + Vector2(-4.5, 6.0) * s]))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], lit)
	ink.ink(RisoPrint.ACCENT, 1.0, lit, false)
	ink.knock([RisoPrint.ACCENT], glints)
	ink.ink(RisoPrint.NIGHT, 1.0, dark, false)


## A gate's ironwork: blue, or for a bone gate (a skeleton lock), pale bone grey.
static func _gate_iron(ink: InkCanvas, key_color: int, fade: float, polys: Array[PackedVector2Array]) -> void:
	if key_color == KeyRing.SKELETON:
		ink.lift_ink(RisoPrint.ALL_PLATES, 0.72 * fade, polys)
	else:
		ink.ink(RisoPrint.BLUE, fade, polys)


## A padlock on `c` (its body's top middle), `s` its size: a pale body tinted with its key's
## colour (pale, so it reads even on something of that colour), a dark shackle and keyhole.
## Bells, lateral exits and the garden's gates hang the same one.
static func padlock(ink: InkCanvas, c: Vector2, color: int, s: float, fade: float) -> void:
	var body: PackedVector2Array = RisoShapes.rrect(c.x - 11.0 * s, c.y, 22.0 * s, 17.0 * s, 4.0 * s)
	var shackle: Array[PackedVector2Array] = RisoDecor.strip(PackedVector2Array([c + Vector2(-6.5, 1) * s, c + Vector2(-6.5, -7) * s, c + Vector2(0, -12) * s, c + Vector2(6.5, -7) * s, c + Vector2(6.5, 1) * s]), 3.4 * s, 3.4 * s)
	ink.ink(RisoPrint.NIGHT, fade, shackle, false)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], 0.9 * fade, [body])
	# A skeleton lock's body stays bare bone-white; the rest are tinted with their colour.
	if color != KeyRing.SKELETON:
		for layer: Array in RisoPrint.key_layers(color):
			ink.ink(int(layer[0]), 0.8 * fade * float(layer[1]), [body], false)
	ink.ink(RisoPrint.NIGHT, fade, [key_bow(c + Vector2(0, 6.5) * s, 4.5 * s * (1.3 if color == KeyRing.SKELETON else 1.0), color)], false)


## A boss's seal on `c`, `r` across: a pink disc (pink: danger) with the boss's own mark on it in
## bare paper (boss_mark; an eye watching for no boss named), barring a gate level's way on while the
## boss lives (Bosses). `fade` scales every ink.
static func boss_seal(ink: InkCanvas, c: Vector2, r: float, fade: float = 1.0, boss: StringName = &"") -> void:
	_boss_disc(ink, c, r, fade, boss, RisoPrint.PINK)


## A boss's trophy on `c`, `r` across (Trophy): its seal won, in the accent (a reward) where the seal
## was pink, with the boss's mark on it. `fade` scales every ink.
static func trophy(ink: InkCanvas, c: Vector2, r: float, fade: float = 1.0, boss: StringName = &"") -> void:
	_boss_disc(ink, c, r, fade, boss, RisoPrint.ACCENT)


## A disc of `plate` on `c`, `r` across, with boss `boss`'s mark (boss_mark) on it in bare paper.
static func _boss_disc(ink: InkCanvas, c: Vector2, r: float, fade: float, boss: StringName, plate: int) -> void:
	var disc: PackedVector2Array = RisoShapes.circle(c, r, 28)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], [disc])
	ink.ink(plate, fade, [disc], false)
	var mark: Array = boss_mark(boss, c, r * BOSS_MARK)
	ink.knock([plate], mark[0])
	if not (mark[1] as Array).is_empty():
		ink.ink(plate, fade, mark[1], false)
	if not (mark[2] as Array).is_empty():
		ink.knock([plate], mark[2])


## How big a boss's mark is on its disc, against the disc's radius.
const BOSS_MARK: float = 0.62
## The worm's head on its mark (in the mark's unit; its disc's radius is 1 / BOSS_MARK): where its
## middle sits, off to the lower left so the disc's edge cuts its back away, how big it is, and how
## wide its jaws open (radians either side).
const WORM_HEAD: Vector2 = Vector2(-0.8, 0.15)
const WORM_R: float = 1.4
const WORM_GAPE: float = 0.62
## The bramble's vine on its mark (in the mark's unit): how far up and down it runs (past the disc,
## which cuts it), how often it waves and how far to either side, and half its thickness; where its
## thorns stand along it (up and down, alternating sides), half the width of each at the vine, how
## far each stands off it, and how far its tip hooks up the vine.
const VINE_REACH: float = 1.9
const VINE_WAVE: float = 1.5
const VINE_SWAY: float = 0.26
const VINE_HALF: float = 0.15
const VINE_THORNS: Array[float] = [0.95, 0.0, -0.95]
const THORN_BASE: float = 0.3
const THORN_LONG: float = 0.62
const THORN_HOOK: float = 0.3
## How far a thorn's sides bend (against half its width at the vine), giving it its hook.
const THORN_BEND: float = 0.45
## How much bigger than the unit asked for the marks that sit whole on their disc are drawn (the
## golem's, the necromancer's, the beast's, the whale's, the eye), so they fill it.
const MARK_GROW: float = 1.3


## Boss `boss`'s mark round `c`, `u` its unit (its marks reach about `u` from `c`): three lists of
## shapes, laid in turn, [what is marked, holes cut back out of it, marks inside those holes]. The
## worm, its maw in profile, jaws open and toothed, big and coming up off the disc's edge (cut to the
## disc, WORM_HEAD); the bramble, a vine running the disc end to end with big hooked thorns (cut to
## the disc, VINE_REACH); the rest drawn MARK_GROW bigger, to fill their disc: the
## golem, its lodestone (Golem.body_shape) leaning, a roundel in it; the necromancer, a skull; the
## beast, three eyes; the whale, its tail. For no boss named, an eye.
static func boss_mark(boss: StringName, c: Vector2, u: float) -> Array:
	var fill: Array[PackedVector2Array] = []
	var holes: Array[PackedVector2Array] = []
	var dots: Array[PackedVector2Array] = []
	var at: Transform2D = Transform2D(0.0, Vector2(u, u), 0.0, c)
	# The marks that sit whole on their disc, drawn bigger to fill it (MARK_GROW).
	var big: Transform2D = Transform2D(0.0, Vector2(u, u) * MARK_GROW, 0.0, c)
	# The disc, for the marks cut to it (the worm's, the vine).
	var disc: PackedVector2Array = RisoShapes.circle(Vector2.ZERO, 1.0 / BOSS_MARK, 40)
	match boss:
		&"worm":
			# A round head seen side on, its jaws open to the right, teeth on both: big, coming up
			# from off the disc's lower left as the worm comes partly out of the ground, cut to the
			# disc's outline so only its front and open jaws show.
			var o: Vector2 = WORM_HEAD
			var head: PackedVector2Array = PackedVector2Array([o])
			for k: int in range(33):
				var a: float = lerpf(WORM_GAPE, TAU - WORM_GAPE, float(k) / 32.0)
				head.append(o + Vector2(cos(a), sin(a)) * WORM_R)
			var teeth: Array[PackedVector2Array] = [head]
			for jaw: float in [-1.0, 1.0]:
				for along: float in [0.42, 0.7]:
					var p: Vector2 = o + Vector2(cos(WORM_GAPE), sin(WORM_GAPE) * jaw) * along * WORM_R
					var tip: Vector2 = p + Vector2(0.1, -jaw * 0.32)
					teeth.append(PackedVector2Array([p - Vector2(0.15, 0.0), p + Vector2(0.15, 0.0), tip]))
			for shape: PackedVector2Array in teeth:
				for piece: PackedVector2Array in Geometry2D.intersect_polygons(shape, disc):
					fill.append(at * piece)
			holes.append(at * RisoShapes.circle(o + Vector2(-0.12, -0.66), 0.19, 12))
		&"bramble":
			# A vine running the disc from end to end in a long wave, cut to the disc's outline, big
			# hooked thorns standing off it, one side then the other.
			var stem: PackedVector2Array = PackedVector2Array()
			for k: int in range(25):
				var y: float = lerpf(VINE_REACH, -VINE_REACH, float(k) / 24.0)
				stem.append(Vector2(sin(y * VINE_WAVE) * VINE_SWAY, y))
			var vine: Array[PackedVector2Array] = []
			vine.append_array(Geometry2D.offset_polyline(stem, VINE_HALF, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND))
			for k: int in range(VINE_THORNS.size()):
				var y: float = VINE_THORNS[k]
				var p: Vector2 = Vector2(sin(y * VINE_WAVE) * VINE_SWAY, y)
				# Up the vine (toward its tip), and out from it on this thorn's side.
				var up: Vector2 = Vector2(-cos(y * VINE_WAVE) * VINE_SWAY * VINE_WAVE, -1.0).normalized()
				var side: float = 1.0 if k % 2 == 0 else -1.0
				var out: Vector2 = Vector2(-up.y, up.x) * side
				var tip: Vector2 = p + out * (VINE_HALF + THORN_LONG) + up * THORN_HOOK
				# A rose's thorn: broad at the vine, both sides bent the same way, so its underside
				# bulges and its top dips into a tip hooked up the vine.
				var lower: Vector2 = p - up * THORN_BASE
				var upper: Vector2 = p + up * THORN_BASE
				var thorn: PackedVector2Array = _quad(lower, (lower + tip) * 0.5 - up * THORN_BASE * THORN_BEND, tip, 6)
				thorn.append_array(_quad(tip, (upper + tip) * 0.5 - up * THORN_BASE * THORN_BEND, upper, 6))
				thorn.append(upper)
				vine.append(thorn)
			for shape: PackedVector2Array in vine:
				for piece: PackedVector2Array in Geometry2D.intersect_polygons(shape, disc):
					fill.append(at * piece)
		&"golem":
			# Its lodestone, leaning, a paper roundel where its heart is.
			var stone: PackedVector2Array = Golem.body_shape(Vector2.ZERO, -PI * 0.5 + 0.3, 1.0)
			var reach: float = 0.0
			for p: Vector2 in stone:
				reach = maxf(reach, p.length())
			var fit: Transform2D = Transform2D(0.0, Vector2(u, u) * (MARK_GROW * 0.9 / reach), 0.0, c)
			fill.append(fit * stone)
			holes.append(big * RisoShapes.circle(Vector2(0.06, 0.08), 0.18, 12))
		&"necromancer":
			# A skull: its crown and jaw, eyes, nose and the gaps between its teeth.
			fill.append(big * RisoShapes.circle(Vector2(0, -0.15), 0.62, 24))
			fill.append(big * RisoShapes.rrect(-0.36, 0.22, 0.72, 0.48, 0.1))
			holes.append(big * RisoShapes.circle(Vector2(-0.24, -0.12), 0.17, 12))
			holes.append(big * RisoShapes.circle(Vector2(0.24, -0.12), 0.17, 12))
			holes.append(big * PackedVector2Array([Vector2(0, 0.08), Vector2(0.09, 0.26), Vector2(-0.09, 0.26)]))
			holes.append(big * RisoShapes.rrect(-0.15, 0.48, 0.07, 0.22, 0.02))
			holes.append(big * RisoShapes.rrect(0.08, 0.48, 0.07, 0.22, 0.02))
		&"beast":
			# Three eyes, each open, its pupil marked.
			for e: Vector3 in [Vector3(-0.38, -0.25, 0.32), Vector3(0.38, -0.15, 0.28), Vector3(-0.02, 0.42, 0.32)]:
				var o: Vector2 = Vector2(e.x, e.y)
				fill.append(big * RisoShapes.circle(o, e.z, 18))
				holes.append(big * RisoShapes.almond(o, e.z * 0.78, e.z * 0.42, 12))
				dots.append(big * RisoShapes.circle(o, e.z * 0.3, 10))
		&"whale":
			# Its tail, thick: a broad stalk and two flukes swept up from it.
			fill.append(big * RisoShapes.rrect(-0.16, -0.05, 0.32, 0.9, 0.1))
			var fluke: PackedVector2Array = PackedVector2Array()
			fluke.append_array(_quad(Vector2(0, 0.12), Vector2(-0.5, 0.08), Vector2(-0.92, -0.62), 8))
			fluke.append_array(_quad(Vector2(-0.92, -0.62), Vector2(-0.38, -0.5), Vector2(0, -0.32), 8))
			fluke.append_array(_quad(Vector2(0, -0.32), Vector2(0.38, -0.5), Vector2(0.92, -0.62), 8))
			fluke.append_array(_quad(Vector2(0.92, -0.62), Vector2(0.5, 0.08), Vector2(0, 0.12), 8))
			fill.append(big * fluke)
		_:
			fill.append(big * RisoShapes.almond(Vector2.ZERO, 1.16, 0.68, 14))
			holes.append(big * RisoShapes.circle(Vector2.ZERO, 0.39, 14))
	return [fill, holes, dots]


## Points along the quadratic curve from `a` to `b` bent toward `ctrl`, `n` steps (without `b`).
static func _quad(a: Vector2, ctrl: Vector2, b: Vector2, n: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for k: int in range(n):
		var t: float = float(k) / float(n)
		out.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	return out


## A switch's plate hung on `c` where a padlock would hang (`c` its top middle, `s` the padlock's
## size): the switch emblem and the switch's sigil `sigil_kind` on a paper plate (sigil_plate).
static func switch_plate(ink: InkCanvas, c: Vector2, s: float, fade: float, sigil_kind: int) -> void:
	var k: float = s * SWITCH_PLATE_SCALE
	sigil_plate(ink, c + Vector2(0, PLATE_H * 0.5 * k), k, fade, sigil_kind, true)


# ------------------------------------------------------------------ sigils
# The shapes that tie linked things together (Sigils): a pair of teleporters, a switch and what it
# works. Solid and unlike one another at a glance and at the map's size, and none of them a mark
# that means something else (no chevrons, sparks, keys or hearts).

## How many sigils there are.
const SIGILS: int = 12
## A sigil plate's height, and its width with and without the switch emblem, at size 1.
const PLATE_H: float = 26.0
const PLATE_W: float = 24.0
const PLATE_W_EMBLEM: float = 48.0
## How much smaller than a padlock of the same size a switch's plate is hung.
const SWITCH_PLATE_SCALE: float = 1.0
## The size of the plate on a switch gate's cross-rail.
const GATE_PLATE_SCALE: float = 1.8


## Sigil `kind` (0 to SIGILS - 1), about 2 * `r` across, centred on `c`: a disc, a triangle, a
## square, a diamond, a triangle pointing down, a crescent, a cross, a saltire, a five-pointed
## star, an hourglass, a dome or three dots.
static func sigil(kind: int, c: Vector2, r: float) -> Array[PackedVector2Array]:
	match kind:
		0:
			return [RisoShapes.circle(c, r * 0.85, 18)]
		1:
			return [RisoShapes.tri(c + Vector2(0, -r), c + Vector2(r, r * 0.75), c + Vector2(-r, r * 0.75))]
		2:
			return [RisoShapes.rrect(c.x - r * 0.75, c.y - r * 0.75, r * 1.5, r * 1.5, r * 0.15)]
		3:
			return [PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)])]
		4:
			return [RisoShapes.tri(c + Vector2(0, r), c + Vector2(-r, -r * 0.75), c + Vector2(r, -r * 0.75))]
		5:
			return [RisoShapes.crescent(c, r * 0.95, Vector2(r * 0.55, -r * 0.25), 36)]
		6:
			return [_cross(c, r, 0.0)]
		7:
			return [_cross(c, r, PI * 0.25)]
		8:
			return [_star(c, r, 5, 0.45)]
		9:
			return [RisoShapes.tri(c + Vector2(-r * 0.8, -r), c + Vector2(r * 0.8, -r), c + Vector2(0, -r * 0.06)),
				RisoShapes.tri(c + Vector2(0, r * 0.06), c + Vector2(r * 0.8, r), c + Vector2(-r * 0.8, r))]
		10:
			return [_dome(c, r)]
	var dots: Array[PackedVector2Array] = []
	for k: int in range(3):
		dots.append(RisoShapes.circle(c + Vector2.from_angle(-PI * 0.5 + TAU * float(k) / 3.0) * r * 0.55, r * 0.4, 12))
	return dots


## A cross of two bars, `r` from the middle to the end of each arm, turned by `turn`.
static func _cross(c: Vector2, r: float, turn: float) -> PackedVector2Array:
	var a: float = r * 0.3
	var pts: PackedVector2Array = PackedVector2Array([Vector2(-a, -r), Vector2(a, -r), Vector2(a, -a), Vector2(r, -a), Vector2(r, a), Vector2(a, a),
		Vector2(a, r), Vector2(-a, r), Vector2(-a, a), Vector2(-r, a), Vector2(-r, -a), Vector2(-a, -a)])
	return Transform2D(turn, c) * pts


## A star of `points` points, `r` to each tip and `inner` of that to the notches, one tip up.
static func _star(c: Vector2, r: float, points: int, inner: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(points * 2):
		out.append(c + Vector2.from_angle(-PI * 0.5 + PI * float(i) / float(points)) * r * (1.0 if i % 2 == 0 else inner))
	return out


## A dome: a half disc on a flat base, `r` out either way, standing so it sits centred on `c`.
static func _dome(c: Vector2, r: float) -> PackedVector2Array:
	var base: Vector2 = c + Vector2(0, r * 0.45)
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in range(17):
		out.append(base + Vector2.from_angle(PI + PI * float(i) / 16.0) * r)
	return out


## A sigil on a paper plate centred on `c`, `s` its size: sigil `kind` in night ink, with `emblem`
## the switch emblem before it (on what a switch works: "the switch with this sigil"). A plate
## with no sigil (-1) shows the emblem alone. `fade` scales every ink.
static func sigil_plate(ink: InkCanvas, c: Vector2, s: float, fade: float, kind: int, emblem: bool) -> void:
	var both: bool = emblem and kind >= 0
	var w: float = (PLATE_W_EMBLEM if both else PLATE_W) * s
	var plate: PackedVector2Array = RisoShapes.rrect(c.x - w * 0.5, c.y - PLATE_H * 0.5 * s, w, PLATE_H * s, 7.0 * s)
	ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT, RisoPrint.EYE], fade, [plate])
	var mark: Vector2 = c + Vector2(w * 0.5 - PLATE_W * 0.5 * s, 0) if both else c
	if emblem:
		var lever: Vector2 = c + Vector2(-w * 0.5 + PLATE_W * 0.5 * s, s) if both else c + Vector2(0, s)
		ink.ink(RisoPrint.NIGHT, fade, switch_emblem(lever, 0.75 * s), false)
	if kind >= 0:
		ink.ink(RisoPrint.NIGHT, fade, sigil(kind, mark, 8.5 * s), false)


## A chain along `path`: links `link` long, alternating an open loop seen face on and a bar seen
## edge on, `w` thick, in `plate`.
static func chain(ink: InkCanvas, path: PackedVector2Array, link: float, w: float, plate: int, cover: float) -> void:
	var polys: Array[PackedVector2Array] = []
	var k: int = 0
	for i: int in range(path.size() - 1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var along: float = (b - a).angle()
		var n: int = maxi(1, int(a.distance_to(b) / (link * 0.78)))
		for j: int in range(n):
			var p: Vector2 = a.lerp(b, (float(j) + 0.5) / float(n))
			if k % 2 == 0:
				polys.append_array(RisoDecor.strip(loop_points(p, link * 0.55, link * 0.32, along), w, w))
			else:
				polys.append(Transform2D(along, p) * RisoShapes.rrect(-link * 0.45, -w * 0.75, link * 0.9, w * 1.5, w * 0.75))
			k += 1
	ink.ink(plate, cover, polys)


## Points round an oval `rx` by `ry` on `c`, turned by `angle`, closed (for a loop of chain).
static func loop_points(c: Vector2, rx: float, ry: float, angle: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for k: int in range(17):
		var a: float = TAU * float(k) / 16.0
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(angle))
	return out


static func arc_points(c: Vector2, r: float, a0: float, a1: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for k: int in range(9):
		var a: float = lerpf(a0, a1, float(k) / 8.0)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


## One narrow curling strand, attached to the wick and fading away as it rises. Used both on
## burned-out lanterns in the world and on the HUD's extinguished protection candle, in pink; with
## `pale`, lifted to paper instead (cold air, or the smoke of a flame snuffed at a font), its cover
## scaled by `strength`.
static func smoke_thread(canvas: InkCanvas, frame: Transform2D, time: float, height: float,
		width: float, drift: float, punch: bool = false, pale: bool = false, strength: float = 1.0) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var widths: PackedFloat32Array = PackedFloat32Array()
	var covers: PackedFloat32Array = PackedFloat32Array()
	const SECTIONS: int = 24
	for i: int in range(SECTIONS + 1):
		var u: float = float(i) / float(SECTIONS)
		var curl: float = drift * pow(u, 0.7) * sin(u * TAU - time * 1.8)
		points.append(Vector2(curl, -height * u))
		widths.append(width * 0.5 * lerpf(1.0, 0.35, u))
		covers.append(0.45 * strength * (1.0 - smoothstep(0.4, 1.0, u)))
	# Keep the whole strand in one polygon: the print renderer discards tiny isolated shapes,
	# so individual cross-sections would disappear even when the full thread is visible.
	var outline: PackedVector2Array = PackedVector2Array()
	var alpha: PackedFloat32Array = PackedFloat32Array()
	for i: int in range(SECTIONS + 1):
		outline.append(points[i] + Vector2(-widths[i], 0))
		alpha.append(covers[i])
	for i: int in range(SECTIONS, -1, -1):
		outline.append(points[i] + Vector2(widths[i], 0))
		alpha.append(covers[i])
	if pale:
		canvas.lift_ink_graded([RisoPrint.NIGHT, RisoPrint.BLUE], [frame * outline], [alpha])
	else:
		canvas.ink_graded(RisoPrint.PINK, [frame * outline], [alpha], punch)


## Bending, for the creatures: a point turns about the feet (the origin) by `amount`, scaled by how
## high it is over `tall` (squared), so a body curls rather than tilting stiffly or squashing.
static func bent_v(p: Vector2, amount: float, tall: float) -> Vector2:
	var u: float = clampf(-p.y / tall, 0.0, 1.4)
	return p.rotated(amount * u * u)


static func bent(poly: PackedVector2Array, amount: float, tall: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(poly.size())
	for i: int in range(poly.size()):
		out[i] = bent_v(poly[i], amount, tall)
	return out
