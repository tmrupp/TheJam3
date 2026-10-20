extends RefCounted
class_name RisoSight
## Line of sight over the level's cells: which of the open space a point (the wizard's eye, a
## lantern's flame) can see past the rock. Rock is the cells marked `solid` (the TileMap's ground,
## cracked walls not yet broken, shut doors and gates); everything else lets light through. What
## it sees is one polygon round the point, reaching to the edge of a box (the view, or a light's
## reach) wherever nothing is in the way, and a band FACE deep into the faces of the rock it sees,
## the same depth all along a face (square to it, however slant the eye looks at it), so a lit
## floor, ceiling or wall reads as lit and flat (RisoLight prints from it).

## How deep (px) sight reaches into the face of the rock it meets, square to the face.
const FACE: float = 26.0
## How slant (the cosine of the angle off square) a ray may meet a face and still go the whole way
## to FACE deep: a ray grazing a face would have to go on a long way inside the rock to get there,
## so past this its band thins.
const SLANT: float = 0.06
## How many cells along a face the end of its band is looked for (past that it is taken to run on).
const FACE_RUN: int = 64
## How far either side of a rock corner (radians) the rays just past it are cast.
const GRAZE: float = 0.0004

## The cells that block sight, as a set.
var solid: Dictionary = {}
## Where cell (0, 0)'s top-left corner is (world px), and how wide a cell is.
var origin: Vector2 = Vector2.ZERO
var cell: float = 128.0
## Bumped whenever `solid` changes (a door opens, a wall breaks), so cached light can be redone.
var version: int = 0
## Which way the last ray `cast` met the rock went into it, square to the face it met (one step
## across the grid: right, left, down or up), and the cell of rock it went into.
var _entered: Vector2 = Vector2.ZERO
var _entered_cell: Vector2i = Vector2i.ZERO


func _init(top_left: Vector2 = Vector2.ZERO, cell_px: float = 128.0) -> void:
	origin = top_left
	cell = cell_px


## The cell a world point falls in.
func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / cell), floori((p.y - origin.y) / cell))


## Whether world point `p` is inside rock.
func blocked(p: Vector2) -> bool:
	return solid.has(cell_of(p))


## Mark cell `v` as blocking sight or not; returns whether that changed anything.
func set_solid(v: Vector2i, on: bool) -> bool:
	if solid.has(v) == on:
		return false
	if on:
		solid[v] = true
	else:
		solid.erase(v)
	version += 1
	return true


## What `eye` sees within `bounds`, as one polygon (star-shaped round the eye). From inside rock
## it sees the whole box (an astral wizard drifting through it).
func polygon(eye: Vector2, bounds: Rect2) -> PackedVector2Array:
	var box: PackedVector2Array = PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)])
	if blocked(eye) or not bounds.has_point(eye):
		return box
	# Rays go to every corner of the rock in the box, and just either side of it, and to the box's
	# own corners; what they hit, in order round the eye, outlines what it sees.
	var aims: PackedFloat32Array = PackedFloat32Array()
	for p: Vector2 in box:
		aims.append((p - eye).angle())
	var lo: Vector2i = cell_of(bounds.position)
	var hi: Vector2i = cell_of(bounds.end)
	for i: int in range(lo.x, hi.x + 2):
		for j: int in range(lo.y, hi.y + 2):
			if not _corner(i, j):
				continue
			var k: Vector2 = origin + Vector2(i, j) * cell
			var a: float = (k - eye).angle()
			aims.append(a - GRAZE)
			aims.append(a)
			aims.append(a + GRAZE)
			# And to the corners of the bands into the faces meeting there, so each band ends
			# square at its corner rather than tapering off along the face from the last ray before.
			for band: Vector2 in _band_corners(i, j):
				aims.append((k + band - eye).angle())
	# And to where a face of rock runs out of the box: a floor or wall that carries on past its edge
	# turns no corner inside it, and without a ray there the outline would cut across from the face
	# to the edge, leaving a wedge of what is seen dark.
	for j: int in range(lo.y + 1, hi.y + 1):
		var y: float = origin.y + float(j) * cell
		if solid.has(Vector2i(lo.x, j - 1)) != solid.has(Vector2i(lo.x, j)):
			aims.append((Vector2(bounds.position.x, y) - eye).angle())
		if solid.has(Vector2i(hi.x, j - 1)) != solid.has(Vector2i(hi.x, j)):
			aims.append((Vector2(bounds.end.x, y) - eye).angle())
	for i: int in range(lo.x + 1, hi.x + 1):
		var x: float = origin.x + float(i) * cell
		if solid.has(Vector2i(i - 1, lo.y)) != solid.has(Vector2i(i, lo.y)):
			aims.append((Vector2(x, bounds.position.y) - eye).angle())
		if solid.has(Vector2i(i - 1, hi.y)) != solid.has(Vector2i(i, hi.y)):
			aims.append((Vector2(x, bounds.end.y) - eye).angle())
	aims.sort()
	var out: PackedVector2Array = PackedVector2Array()
	var last: Vector2 = Vector2.INF
	for a: float in aims:
		var d: Vector2 = Vector2.from_angle(a)
		var reach: float = _to_edge(eye, d, bounds)
		var hit: float = cast(eye, d, reach)
		var p: Vector2 = eye + d * reach
		if hit < reach:
			# Into the face, on along the ray to FACE deep square to the face (so every point on
			# one face lies on one line along it, and its band is flat), but never out the far side
			# of the rock: near a corner the ray only clips it, and lighting past it would start the
			# corner's shadow away from the corner.
			var into: Vector2 = _entered
			var square: float = maxf(absf(d.dot(into)), SLANT)
			p = eye + d * (hit + minf(_depth(eye, d, hit, FACE / square), _under_face(eye + d * hit, into, _entered_cell, d)))
		if p.distance_squared_to(last) > 0.25:
			out.append(p)
			last = p
	return out


## Where (px from grid corner (i, j), a corner of the rock) the bands into the faces meeting there
## have their corners. In a corner of a room (three cells of rock round it) the two bands meet in a
## mitre, FACE in from both faces. At an outer corner (one cell of rock, or two across from each
## other) each face's band ends square at the corner, FACE in, and where the eye sees both faces
## the two meet in a mitre inside the rock.
func _band_corners(i: int, j: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var rock: Array[Vector2i] = []
	var air: Array[Vector2i] = []
	for s: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		var way: Vector2i = Vector2i(s.x * 2 + 1, s.y * 2 + 1)
		if solid.has(Vector2i(i, j) + s):
			rock.append(way)
		else:
			air.append(way)
	if rock.size() == 3:
		out.append(-Vector2(air[0]) * FACE)
	else:
		for way: Vector2i in rock:
			out.append(Vector2(way) * FACE)
			out.append(Vector2(way.x, 0) * FACE)
			out.append(Vector2(0, way.y) * FACE)
	return out


## How far (px) a ray along unit `d` that met the rock at `h`, going in `into` (square to the face)
## into cell `rock`, may go on inside it and still lie under that face: its band ends where the face does, square to
## it, and in a corner of a room, where another face rises from its end, FACE further on, so the
## two bands meet in a mitre. Without this a ray grazing a floor ran on under the wall at its end,
## lighting a long sliver of rock beside nothing lit.
func _under_face(h: Vector2, into: Vector2, rock: Vector2i, d: Vector2) -> float:
	var along: Vector2 = Vector2(0.0, signf(d.y)) if into.x != 0.0 else Vector2(signf(d.x), 0.0)
	var speed: float = d.dot(along)
	if speed <= 0.0:
		return INF
	# Taken from the cell the ray went into, not from where it met the rock: a ray meeting it right
	# on a corner of the grid could find the wrong cell either side.
	var air: Vector2i = rock - Vector2i(into)
	var step: Vector2i = Vector2i(along)
	var k: int = 1
	while k < FACE_RUN and solid.has(rock + step * k) and not solid.has(air + step * k):
		k += 1
	var last: Vector2i = rock + step * (k - 1)
	var end: float
	var from: float
	if step.x != 0:
		end = origin.x + float(last.x + (1 if step.x > 0 else 0)) * cell
		from = h.x
	else:
		end = origin.y + float(last.y + (1 if step.y > 0 else 0)) * cell
		from = h.y
	var past: float = FACE if solid.has(rock + step * k) and solid.has(air + step * k) else 0.0
	return maxf((end - from) * (along.x + along.y) + past, 0.0) / speed


## Whether grid corner (i, j) is a corner of the rock: one or three of the cells round it are
## rock, or two diagonally across from each other.
func _corner(i: int, j: int) -> bool:
	var a: bool = solid.has(Vector2i(i - 1, j - 1))
	var b: bool = solid.has(Vector2i(i, j - 1))
	var c: bool = solid.has(Vector2i(i - 1, j))
	var d: bool = solid.has(Vector2i(i, j))
	var n: int = int(a) + int(b) + int(c) + int(d)
	return n == 1 or n == 3 or (n == 2 and a == d)


## How far a ray from `p` (inside `bounds`) along unit `d` goes before it leaves the box.
static func _to_edge(p: Vector2, d: Vector2, bounds: Rect2) -> float:
	var t: float = INF
	if d.x > 0.0:
		t = minf(t, (bounds.end.x - p.x) / d.x)
	elif d.x < 0.0:
		t = minf(t, (bounds.position.x - p.x) / d.x)
	if d.y > 0.0:
		t = minf(t, (bounds.end.y - p.y) / d.y)
	elif d.y < 0.0:
		t = minf(t, (bounds.position.y - p.y) / d.y)
	return maxf(t, 0.0)


## How far a ray from `p` along unit `d` goes before it enters rock, up to `reach`: it steps cell
## by cell along the grid.
func cast(p: Vector2, d: Vector2, reach: float) -> float:
	var at: Vector2i = cell_of(p)
	var step: Vector2i = Vector2i(int(signf(d.x)), int(signf(d.y)))
	var next_x: float = INF
	var next_y: float = INF
	var each_x: float = INF
	var each_y: float = INF
	if step.x != 0:
		var edge_x: float = origin.x + float(at.x + (1 if step.x > 0 else 0)) * cell
		next_x = (edge_x - p.x) / d.x
		each_x = cell / absf(d.x)
	if step.y != 0:
		var edge_y: float = origin.y + float(at.y + (1 if step.y > 0 else 0)) * cell
		next_y = (edge_y - p.y) / d.y
		each_y = cell / absf(d.y)
	var t: float = 0.0
	while t < reach:
		if next_x < next_y:
			t = next_x
			at.x += step.x
			next_x += each_x
			_entered = Vector2(step.x, 0.0)
		else:
			t = next_y
			at.y += step.y
			next_y += each_y
			_entered = Vector2(0.0, step.y)
		if t < reach and solid.has(at):
			_entered_cell = at
			return t
	return reach


## How far a ray from `p` along unit `d` that enters rock `hit` px along goes on inside it, up to
## `most`: it steps cell by cell until it comes out into the open.
func _depth(p: Vector2, d: Vector2, hit: float, most: float) -> float:
	var inside: Vector2 = p + d * (hit + 0.01)
	var through: float = cast_open(inside, d, most)
	return minf(through + 0.01, most)


## How far a ray from `p` (inside rock) along unit `d` goes before it comes out of the rock, up to
## `reach`: `cast` turned about.
func cast_open(p: Vector2, d: Vector2, reach: float) -> float:
	var at: Vector2i = cell_of(p)
	var step: Vector2i = Vector2i(int(signf(d.x)), int(signf(d.y)))
	var next_x: float = INF
	var next_y: float = INF
	var each_x: float = INF
	var each_y: float = INF
	if step.x != 0:
		next_x = (origin.x + float(at.x + (1 if step.x > 0 else 0)) * cell - p.x) / d.x
		each_x = cell / absf(d.x)
	if step.y != 0:
		next_y = (origin.y + float(at.y + (1 if step.y > 0 else 0)) * cell - p.y) / d.y
		each_y = cell / absf(d.y)
	var t: float = 0.0
	while t < reach:
		if next_x < next_y:
			t = next_x
			at.x += step.x
			next_x += each_x
		else:
			t = next_y
			at.y += step.y
			next_y += each_y
		if t < reach and not solid.has(at):
			return t
	return reach


## The parts of `shape` that `eye`'s sight polygon `seen` covers.
static func lit(shape: PackedVector2Array, seen: PackedVector2Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(shape, seen):
		if not Geometry2D.is_polygon_clockwise(piece):
			out.append(piece)
	return out


## The parts of `rect` outside every one of `holes`, as plain outlines with no holes in them (the
## print fills simple outlines only): where a cut would leave a hole, the piece is split in two
## through the hole and each half cut again.
static func outside(rect: Rect2, holes: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = [PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])]
	for hole: PackedVector2Array in holes:
		if hole.size() < 3:
			continue
		var cut: Array[PackedVector2Array] = []
		for piece: PackedVector2Array in pieces:
			cut.append_array(_minus(piece, hole, 0))
		pieces = cut
	return pieces


## `piece` less `hole`, split through any hole the cut leaves (see outside).
static func _minus(piece: PackedVector2Array, hole: PackedVector2Array, depth: int) -> Array[PackedVector2Array]:
	var outers: Array[PackedVector2Array] = []
	var inner: PackedVector2Array = PackedVector2Array()
	# Clipper hands back outlines anticlockwise and holes clockwise, whichever way the input runs.
	for p: PackedVector2Array in Geometry2D.clip_polygons(piece, hole):
		if Geometry2D.is_polygon_clockwise(p):
			inner = p
		else:
			outers.append(p)
	if inner.is_empty() or depth > 6:
		return outers
	var box: Rect2 = Rect2(piece[0], Vector2.ZERO)
	for p: Vector2 in piece:
		box = box.expand(p)
	var mid: float = 0.0
	for p: Vector2 in inner:
		mid += p.x
	mid /= float(inner.size())
	var out: Array[PackedVector2Array] = []
	for half: Rect2 in [Rect2(box.position, Vector2(mid - box.position.x, box.size.y)), Rect2(Vector2(mid, box.position.y), Vector2(box.end.x - mid, box.size.y))]:
		var slab: PackedVector2Array = PackedVector2Array([half.position, Vector2(half.end.x, half.position.y), half.end, Vector2(half.position.x, half.end.y)])
		for part: PackedVector2Array in Geometry2D.intersect_polygons(piece, slab):
			if not Geometry2D.is_polygon_clockwise(part):
				out.append_array(_minus(part, hole, depth + 1))
	return out
