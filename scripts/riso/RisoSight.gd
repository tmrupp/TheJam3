extends RefCounted
class_name RisoSight
## Line of sight over the level's cells: which of the open space a point (the wizard's eye, a
## lantern's flame) can see past the rock. Rock is the cells marked `solid` (the TileMap's ground,
## cracked walls not yet broken, shut doors and gates); everything else lets light through. What
## it sees is one polygon round the point, reaching to the edge of a box (the view, or a light's
## reach) wherever nothing is in the way, and a little way into the faces of the rock it sees, so
## a lit wall's face reads as lit (RisoLight prints from it).

## How far (px) sight reaches into the face of the rock it meets.
const FACE: float = 26.0
## How far either side of a rock corner (radians) the rays just past it are cast.
const GRAZE: float = 0.0004

## The cells that block sight, as a set.
var solid: Dictionary = {}
## Where cell (0, 0)'s top-left corner is (world px), and how wide a cell is.
var origin: Vector2 = Vector2.ZERO
var cell: float = 128.0
## Bumped whenever `solid` changes (a door opens, a wall breaks), so cached light can be redone.
var version: int = 0


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
			var a: float = (origin + Vector2(i, j) * cell - eye).angle()
			aims.append(a - GRAZE)
			aims.append(a)
			aims.append(a + GRAZE)
	aims.sort()
	var out: PackedVector2Array = PackedVector2Array()
	var last: Vector2 = Vector2.INF
	for a: float in aims:
		var d: Vector2 = Vector2.from_angle(a)
		var reach: float = _to_edge(eye, d, bounds)
		var hit: float = cast(eye, d, reach)
		var p: Vector2 = eye + d * (hit + FACE if hit < reach else reach)
		if p.distance_squared_to(last) > 0.25:
			out.append(p)
			last = p
	return out


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
		else:
			t = next_y
			at.y += step.y
			next_y += each_y
		if t < reach and solid.has(at):
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
