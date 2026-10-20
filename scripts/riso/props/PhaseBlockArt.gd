extends RisoProp
## A sun block or a shade block (PhaseBlock): a square of dressed stone filling its cell, laid in
## three courses of stones in a brick bond over dark mortar, each stone with a pale top edge, and in
## the middle its mark on a round plate. A sun block's stones are pale, near paper, warmed with a
## touch of accent, its plate a yellow sun with turning rays; a shade block's are deep blue under
## night ink over black joints, its plate night ink with a pale crescent moon. Neighbouring blocks of
## a kind fill their cells edge to edge, so a group reads as one piece of masonry, its corners
## rounded (CORNER_R) where the group turns, outward or inward. While it bears no one it is only a
## subtle outline round its group (the owner's choice, an exception to the print's rule of no
## outlines), a band EDGE_W wide inside the group's rounded edge, unbroken from block to block, and
## its mark faint in the middle: a sun block's pale (it is passable in the dark), a shade block's
## black (it is passable in the light). The stone fills in as it turns solid. Both kinds shine a
## little, a spark firm and less as an outline (light), so they show in a dark crypt where the
## wizard's flame does not reach.
##
## Each block draws its own cell's share of its group's shape, worked out once from the blocks of
## its kind round it (`_shape`): the group's cells within a cell of it, joined, their corners rounded
## (opened and closed by CORNER_R), cut to its cell.

## The group's rounded corners (px), and the outline: how wide its band is (px), and how much it
## prints (a sun block's paper lifted and touched with accent, a shade block's night ink).
const CORNER_R: float = 24.0
const EDGE_W: float = 4.0
const OUTLINE: float = 0.55
const OUTLINE_ACCENT: float = 0.3
const OUTLINE_NIGHT: float = 0.85
## How much its mark still prints while it is only an outline.
const GHOST_MARK: float = 0.35
## The joints between its stones (px), how round a stone's corners are, and each stone's pale top
## edge: how tall (px) and how much ink it lifts.
const JOINT: float = 4.0
const STONE_CORNER: float = 3.0
const TOP: float = 4.0
const TOP_LIFT: float = 0.45
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
## The light it gives, firm and as an outline (as RisoLight.SPARK: reach, lift, tint).
const FIRM_LIGHT: Vector3 = Vector3(90.0, 0.08, 0.0)
const GHOST_LIGHT: Vector3 = Vector3(60.0, 0.05, 0.0)

## Its cell's share of its group's shape (`_body`, what it fills when firm), the outline's band in
## it (`_band`), and its stones and their pale top edges cut to the shape; empty until its block
## knows its place.
var _body: Array[PackedVector2Array] = []
var _band: Array[PackedVector2Array] = []
var _stones: Array[PackedVector2Array] = []
var _tops: Array[PackedVector2Array] = []
var _shaped: bool = false


## The PhaseBlock it dresses.
var block: PhaseBlock:
	get:
		return host as PhaseBlock


func shines() -> bool:
	return true


## A spark from its mark, smaller while it is only an outline.
func light() -> Array:
	var firm: float = block.firm if block != null else 1.0
	return _light(Vector2.ZERO, FIRM_LIGHT if firm >= 0.5 else GHOST_LIGHT, -1)


## Whether a block of the same kind stands at cell `v`.
func _same(v: Vector2i) -> bool:
	var w: LevelGen = block.map_info.world
	return w.is_valid(v) and w.get_cell(v).type == LevelGen.Type.PHASE_BLOCK and bool(w.get_cell(v).extra_info) == block.sun


## Its cell's share of its group's shape (see the class description), once its block knows its place.
func _shape() -> void:
	if _shaped or block == null or block.map_info == null or block.map_info.world == null or block.cell.x < 0:
		return
	_shaped = true
	var s: float = half
	# The group's cells round it: those beside it, and those on a diagonal joined to it through one
	# beside it, as squares in its own frame, joined into one shape.
	var near: Array[Vector2i] = [Vector2i.ZERO]
	for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		if _same(block.cell + d):
			near.append(d)
	for d: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]:
		if _same(block.cell + d) and (near.has(Vector2i(d.x, 0)) or near.has(Vector2i(0, d.y))):
			near.append(d)
	var joined: Array[PackedVector2Array] = []
	for d: Vector2i in near:
		var c: Vector2 = Vector2(d) * s * 2.0
		# A hair over the cell, so neighbours overlap and join without a seam.
		var square: PackedVector2Array = RisoShapes.rrect(c.x - s - 0.5, c.y - s - 0.5, s * 2.0 + 1.0, s * 2.0 + 1.0, 0.0)
		joined = _merge(joined, square)
	# Rounded: closed (inward corners) then opened (outward corners) by CORNER_R.
	var shape: Array[PackedVector2Array] = _offset(_offset(joined, CORNER_R), -CORNER_R)
	shape = _offset(_offset(shape, -CORNER_R), CORNER_R)
	var inner: Array[PackedVector2Array] = _offset(shape, -EDGE_W)
	# Cut to its cell in two halves, so no piece of the band is a ring (a polygon has no holes), and
	# to the corner of each empty cell on a diagonal where its group turns inward round it, whose
	# rounding is this block's to draw (no other block has both sides beside that corner).
	var pieces: Array[PackedVector2Array] = [RisoShapes.rrect(-s, -s, s, s * 2.0, 0.0), RisoShapes.rrect(0.0, -s, s, s * 2.0, 0.0)]
	for d: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]:
		if near.has(Vector2i(d.x, 0)) and near.has(Vector2i(0, d.y)) and not near.has(d):
			var at: Vector2 = Vector2(d) * s
			var r: float = CORNER_R + 1.0
			pieces.append(RisoShapes.rrect(at.x + minf(0.0, float(d.x) * r), at.y + minf(0.0, float(d.y) * r), r, r, 0.0))
	for piece: PackedVector2Array in pieces:
		for part: PackedVector2Array in _cut(shape, piece):
			_body.append(part)
			var rest: Array[PackedVector2Array] = [part]
			for hole: PackedVector2Array in inner:
				var next: Array[PackedVector2Array] = []
				for r: PackedVector2Array in rest:
					for left: PackedVector2Array in Geometry2D.clip_polygons(r, hole):
						if not Geometry2D.is_polygon_clockwise(left):
							next.append(left)
				rest = next
			_band.append_array(rest)
	# The stones, three courses in a brick bond (two in the top and bottom courses, a whole one
	# between two halves in the middle), cut to the shape where its corners are rounded.
	var course: float = s * 2.0 / 3.0
	for row: int in range(3):
		var cuts: PackedFloat32Array = PackedFloat32Array([-s, 0.0, s] if row != 1 else [-s, -s * 0.5, s * 0.5, s])
		for k: int in range(cuts.size() - 1):
			var x0: float = cuts[k] + JOINT * 0.5
			var w: float = cuts[k + 1] - cuts[k] - JOINT
			var y0: float = -s + course * float(row) + JOINT * 0.5
			var stone: PackedVector2Array = RisoShapes.rrect(x0, y0, w, course - JOINT, STONE_CORNER)
			var inside: Array[PackedVector2Array] = _cut(shape, stone)
			_stones.append_array(inside)
			if not inside.is_empty():
				_tops.append_array(_cut(shape, RisoShapes.rrect(x0 + 2.0, y0 + 1.0, w - 4.0, TOP, 1.5)))


## `shapes` grown (or shrunk, negative) by `by`, rounding the corners it turns.
static func _offset(shapes: Array[PackedVector2Array], by: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for p: PackedVector2Array in shapes:
		# Wound as a shape, not a hole, so it grows outward.
		var outward: PackedVector2Array = p.duplicate()
		if Geometry2D.is_polygon_clockwise(outward):
			outward.reverse()
		for q: PackedVector2Array in Geometry2D.offset_polygon(outward, by, Geometry2D.JOIN_ROUND):
			if not Geometry2D.is_polygon_clockwise(q):
				out.append(q)
	return _join(out)


## `shapes` joined with `extra`.
static func _merge(shapes: Array[PackedVector2Array], extra: PackedVector2Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = shapes.duplicate()
	out.append(extra)
	return _join(out)


## The overlapping shapes of `shapes` joined into one.
static func _join(shapes: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for p: PackedVector2Array in shapes:
		var merged: bool = false
		for i: int in range(out.size()):
			var outers: Array[PackedVector2Array] = []
			for q: PackedVector2Array in Geometry2D.merge_polygons(out[i], p):
				if not Geometry2D.is_polygon_clockwise(q):
					outers.append(q)
			if outers.size() == 1:
				out[i] = outers[0]
				merged = true
				break
		if not merged:
			out.append(p)
	return out


## The parts of `shapes` inside `box`.
static func _cut(shapes: Array[PackedVector2Array], box: PackedVector2Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for p: PackedVector2Array in shapes:
		for q: PackedVector2Array in Geometry2D.intersect_polygons(p, box):
			if not Geometry2D.is_polygon_clockwise(q):
				out.append(q)
	return out


func _draw_art() -> void:
	_shape()
	var sun: bool = block == null or block.sun
	var firm: float = block.firm if block != null else 1.0
	var body: Array[PackedVector2Array] = _body
	var stones: Array[PackedVector2Array] = _stones
	var tops: Array[PackedVector2Array] = _tops
	if body.is_empty():
		body = [RisoShapes.rrect(-half, -half, half * 2.0, half * 2.0, 0.0)]
	# Filled as it turns solid: the mortar hides what is behind, then the stones.
	if firm > 0.0:
		ink.lift_ink(RisoPrint.ALL_PLATES, firm, body)
		if sun:
			ink.ink(RisoPrint.BLUE, SUN_MORTAR * firm, body, false)
			ink.lift_ink(RisoPrint.ALL_PLATES, firm, stones)
			ink.ink(RisoPrint.BLUE, SUN_STONE.x * firm, stones, false)
			ink.ink(RisoPrint.ACCENT, SUN_STONE.y * firm, stones, false)
		else:
			ink.ink(RisoPrint.NIGHT, SHADE_MORTAR * firm, body, false)
			ink.ink(RisoPrint.BLUE, SHADE_STONE.x * firm, stones, false)
			ink.ink(RisoPrint.NIGHT, SHADE_STONE.y * firm, stones, false)
		ink.lift_ink([RisoPrint.NIGHT, RisoPrint.BLUE], TOP_LIFT * firm, tops)
	_outline(sun, 1.0 - firm)
	_mark(sun, lerpf(GHOST_MARK, 1.0, firm))


## The outline round its group, `cover` of it: pale on a sun block, black on a shade block.
func _outline(sun: bool, cover: float) -> void:
	if cover <= 0.0 or _band.is_empty():
		return
	if sun:
		ink.lift_ink(RisoPrint.ALL_PLATES, OUTLINE * cover, _band)
		ink.ink(RisoPrint.ACCENT, OUTLINE_ACCENT * cover, _band, false)
	else:
		ink.ink(RisoPrint.NIGHT, OUTLINE_NIGHT * cover, _band, false)


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
