extends Node2D
class_name RisoTerrain
## Terrain printed from the TileMap's ground layer as one contiguous mass: rounded outer
## corners, concave fillets where walls meet floors, one rounded cap strip per walkable run,
## and two screened bands of night ink inset from every exposed edge, so the shading follows
## the rock's outline instead of stepping cell by cell.
## Built stone (LevelGen.masonry: the crags' castle ruins) prints apart from the bare rock: square
## cornered, with no fillets where it meets anything, in an ink of its own (MASONRY_LOOKS), and a
## coping of darker stone along its walkable tops in place of the rock's cap strip.
## The air inside a building (LevelGen.interiors: a keep's halls, a tower's rooms) prints over a back
## wall of stone in place of the sky: the rock's ink, dimmed with night, in courses two to a cell
## with their joints staggered, under everything else.

const SHADE_NEAR: float = 22.0
const SHADE_FAR: float = 58.0
const SHADE_COVER: float = 0.16
## The inks built stone can print in, as [plate, cover] laid one over another: sandstone (the
## realm's accent over its rock ink, a warm dressed stone), slate (the travelers' federal blue
## alone, a cool built stone), or dark (night over the rock ink, a weathered grey). `masonry_look`
## picks one.
const MASONRY_LOOKS: Dictionary = {
	&"sandstone": [[RisoPrint.BLUE, 1.0], [RisoPrint.ACCENT, 0.4]],
	&"slate": [[RisoPrint.CLOTH, 0.85]],
	&"dark": [[RisoPrint.BLUE, 1.0], [RisoPrint.NIGHT, 0.35]],
}
## The coping along built stone's walkable tops: how much night over its stone.
const COPING_COVER: float = 0.45
## A building's back wall: how much of the rock's ink, how much night over it, and how much more
## night in the joints between its blocks (pixels wide: BACK_JOINT).
const BACK_STONE: float = 0.8
const BACK_SHADE: float = 0.38
const BACK_JOINT_COVER: float = 0.25
const BACK_JOINT: float = 4.0
static var masonry_look: StringName = &"sandstone"

var ink: InkCanvas


func _ready() -> void:
	z_index = -20
	z_as_relative = false
	add_to_group(&"riso_art")
	visible = RisoPrint.is_on()
	ink = InkCanvas.new()
	add_child(ink)
	var map: TileMap = Stage.tile_map()
	if map != null and map.get_used_cells(0).size() > 0:
		rebuild(map)


func rebuild(tile_map: TileMap, ledge_positions: Array[Vector2] = [], cracked_positions: Array[Vector2] = []) -> void:
	if tile_map == null:
		return
	var solid: Dictionary = {}
	for v: Vector2i in tile_map.get_used_cells(0):
		solid[v] = true
	# Cracked walls print as rock (their prop adds the cracks); breaking one reprints without it.
	for p: Vector2 in cracked_positions:
		solid[tile_map.local_to_map(tile_map.to_local(p))] = true
	# Floating platforms print with the rock: a thin bar across the top of their cell that joins
	# neighbouring platforms and rock, and shares the rock's cap strip.
	var ledges: Dictionary = {}
	for p: Vector2 in ledge_positions:
		ledges[tile_map.local_to_map(tile_map.to_local(p))] = true
	var info: MapInfo = MapInfo.instance
	var masonry: Dictionary = info.world.masonry if info != null and info.world != null else {}
	var interiors: Dictionary = info.world.interiors if info != null and info.world != null else {}
	var half: float = float(tile_map.tile_set.tile_size.x) * tile_map.global_scale.x * 0.5
	var radius: float = half * 0.32
	# Top corners stay nearly square: the floor's collision runs right to the cell edge, and a
	# rounded top made the wizard look like they stood on nothing at a ledge's end.
	var top_radius: float = 5.0
	var body: Array[PackedVector2Array] = []
	var built: Array[PackedVector2Array] = []
	var near: Array[PackedVector2Array] = []
	var far: Array[PackedVector2Array] = []
	var fillets: Array[PackedVector2Array] = []
	var near_pies: Array[PackedVector2Array] = []
	var far_pies: Array[PackedVector2Array] = []
	var empties: Dictionary = {}
	for v: Vector2i in solid:
		var c: Vector2 = tile_map.to_global(tile_map.map_to_local(v))
		var up: bool = solid.has(v + Vector2i.UP)
		var down: bool = solid.has(v + Vector2i.DOWN)
		var left: bool = solid.has(v + Vector2i.LEFT)
		var right: bool = solid.has(v + Vector2i.RIGHT)
		var ledge_l: bool = ledges.has(v + Vector2i.LEFT)
		var ledge_r: bool = ledges.has(v + Vector2i.RIGHT)
		if masonry.has(v):
			built.append(_cell(c, half, 0.0, false, false, false, false))
		else:
			body.append(_cell(c, half, radius, not up and not left and not ledge_l, not up and not right and not ledge_r, not down and not right, not down and not left, top_radius))
		for pair: Array in [[near, SHADE_NEAR], [far, SHADE_FAR]]:
			var d: float = float(pair[1])
			var inset: PackedVector2Array = _inset(c, half, d, radius, up, down, left, right)
			if inset.size() > 2:
				(pair[0] as Array[PackedVector2Array]).append(inset)
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if not solid.has(v + d):
				empties[v + d] = true
	for e: Vector2i in empties:
		var c: Vector2 = tile_map.to_global(tile_map.map_to_local(e))
		for sx: int in [-1, 1]:
			for sy: int in [-1, 1]:
				var round: Array[Vector2i] = [e + Vector2i(sx, 0), e + Vector2i(0, sy), e + Vector2i(sx, sy)]
				# Built stone meets things square: no fillet where any of it is built.
				if round.all(func(n: Vector2i) -> bool: return solid.has(n) and not masonry.has(n)):
					var corner: Vector2 = c + Vector2(sx, sy) * half
					fillets.append(_fillet(corner, Vector2(-sx, -sy), radius))
					near_pies.append(_pie(corner, Vector2(-sx, -sy), SHADE_NEAR + radius * 0.5))
					far_pies.append(_pie(corner, Vector2(-sx, -sy), SHADE_FAR))
	for v: Vector2i in ledges:
		if solid.has(v):
			continue
		var c: Vector2 = tile_map.to_global(tile_map.map_to_local(v))
		var joins_l: bool = solid.has(v + Vector2i.LEFT) or ledges.has(v + Vector2i.LEFT)
		var joins_r: bool = solid.has(v + Vector2i.RIGHT) or ledges.has(v + Vector2i.RIGHT)
		body.append(_box(Vector2(c.x, c.y - half + 17.0), half, 17.0, 12.0, false, false, not joins_r, not joins_l))
		# Square on top (it is walkable to its very end), rounded underneath at free ends.
	var caps: Array[PackedVector2Array] = []
	var copings: Array[PackedVector2Array] = []
	var tops: Array[Vector2i] = []
	for v: Vector2i in solid:
		if not solid.has(v + Vector2i.UP):
			tops.append(v)
	for v: Vector2i in ledges:
		if not solid.has(v) and not solid.has(v + Vector2i.UP):
			tops.append(v)
	tops.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var i: int = 0
	while i < tops.size():
		var j: int = i
		# A run of tops all bare rock or all built stone (each printed its own way).
		while j + 1 < tops.size() and tops[j + 1].y == tops[i].y and tops[j + 1].x == tops[j].x + 1 and masonry.has(tops[j + 1]) == masonry.has(tops[i]):
			j += 1
		var a: Vector2 = tile_map.to_global(tile_map.map_to_local(tops[i]))
		var b: Vector2 = tile_map.to_global(tile_map.map_to_local(tops[j]))
		var y0: float = a.y - half - 3.0
		# Ends against a rising wall stop short of the fillet with a rounded tip; open ends run
		# to the edge and are trimmed to the rock's (or ledge's) own corner curve.
		var wall_l: bool = solid.has(tops[i] + Vector2i.LEFT)
		var wall_r: bool = solid.has(tops[j] + Vector2i.RIGHT)
		var stop_l: bool = wall_l and solid.has(tops[i])
		var stop_r: bool = wall_r and solid.has(tops[j])
		var x0: float = a.x - half + (radius if stop_l else 0.0)
		var x1: float = b.x + half - (radius if stop_r else 0.0)
		var cap: PackedVector2Array = _box(Vector2((x0 + x1) * 0.5, y0 + 8.5), (x1 - x0) * 0.5, 8.5, 8.0, stop_l, stop_r, stop_r, stop_l)
		if not wall_l:
			cap = _trim(cap, _fillet(Vector2(x0, y0), Vector2(1, 1), top_radius))
		if not wall_r:
			cap = _trim(cap, _fillet(Vector2(x1, y0), Vector2(-1, 1), top_radius))
		if cap.size() > 2:
			if masonry.has(tops[i]):
				copings.append(_box(Vector2((a.x - half + b.x + half) * 0.5, y0 + 8.5), (b.x - a.x) * 0.5 + half, 8.5, 0.0, false, false, false, false))
			else:
				caps.append(cap)
		i = j + 1
	ink.begin()
	_back_wall(tile_map, solid, interiors, half)
	body.append_array(fillets)
	if info != null and info.here != null and info.here.open() and RisoPrint.instance != null:
		var style: StringName = RisoPrint.instance.sky_bottom_style
		if style == &"tapered":
			body.append_array(_tapers(tile_map, solid, half))
		elif style != &"roots":
			body.append_array(_cloud_bottoms(tile_map, solid, half, Rules.level_seed(info.coord.x, info.coord.y)))
	# Rock hides the sky behind it: no stars or moons printing through the ground.
	ink.knock([RisoPrint.PINK, RisoPrint.ACCENT], body)
	ink.ink(RisoPrint.BLUE, 1.0, body)
	var look: Array = MASONRY_LOOKS.get(masonry_look, MASONRY_LOOKS[&"sandstone"])
	if not built.is_empty():
		ink.knock([RisoPrint.PINK, RisoPrint.ACCENT], built)
		for k: int in range(look.size()):
			ink.ink(int(look[k][0]), float(look[k][1]), built, k == 0)
	# Deep band first, cleared around inside corners; then the near band, cleared tighter.
	ink.ink(RisoPrint.NIGHT, SHADE_COVER, far, false)
	ink.knock([RisoPrint.NIGHT], far_pies)
	ink.ink(RisoPrint.NIGHT, SHADE_COVER, near, false)
	ink.knock([RisoPrint.NIGHT], near_pies)
	ink.ink(RisoPrint.ACCENT, 1.0, caps)
	if not copings.is_empty():
		ink.knock([RisoPrint.ACCENT], copings)
		for k: int in range(look.size()):
			ink.ink(int(look[k][0]), float(look[k][1]), copings, k == 0)
		ink.ink(RisoPrint.NIGHT, COPING_COVER, copings, false)
	ink.finish()


## The back wall behind the air inside buildings (`interiors`; see the class description): it hides
## the sky as rock does.
func _back_wall(tile_map: TileMap, solid: Dictionary, interiors: Dictionary, half: float) -> void:
	var back: Array[PackedVector2Array] = []
	var joints: Array[PackedVector2Array] = []
	for v: Vector2i in interiors:
		if solid.has(v):
			continue
		var c: Vector2 = tile_map.to_global(tile_map.map_to_local(v))
		back.append(_cell(c, half, 0.0, false, false, false, false))
		for course: int in range(2):
			var y0: float = c.y - half + float(course) * half
			joints.append(RisoShapes.rrect(c.x - half, y0 - BACK_JOINT * 0.5, half * 2.0, BACK_JOINT, 0.0))
			var shift: float = half * 0.5 if (v.y * 2 + course) % 2 == 1 else 0.0
			for b: int in range(2):
				var x: float = c.x - half + shift + float(b) * half
				if x > c.x - half and x < c.x + half:
					joints.append(RisoShapes.rrect(x - BACK_JOINT * 0.5, y0, BACK_JOINT, half, 0.0))
	if back.is_empty():
		return
	ink.knock([RisoPrint.PINK, RisoPrint.ACCENT], back)
	ink.ink(RisoPrint.BLUE, BACK_STONE, back)
	ink.ink(RisoPrint.NIGHT, BACK_SHADE, back, false)
	ink.ink(RisoPrint.NIGHT, BACK_JOINT_COVER, joints, false)


## Floating islands' tapered undersides (SkyArchetype.taper_islands lays them as rock a row at a
## time): each step under an overhang filled on the diagonal, so the sides run smoothly in to the
## keel, and a point under the last cell of each keel. Printed with the ground; no tiles change
## (the wedges only fill the corner of a cell under rock and beside it, where nothing stands).
static func _tapers(tile_map: TileMap, solid: Dictionary, half: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var checked: Dictionary = {}
	for v: Vector2i in solid:
		if solid.has(v + Vector2i.DOWN):
			continue
		var c: Vector2 = tile_map.to_global(tile_map.map_to_local(v))
		# A keel's point: the last cell, with open air beside it and below.
		if solid.has(v + Vector2i.UP) and not solid.has(v + Vector2i.LEFT) and not solid.has(v + Vector2i.RIGHT):
			out.append(PackedVector2Array([Vector2(c.x - half * 0.75, c.y + half - 2.0), Vector2(c.x + half * 0.75, c.y + half - 2.0), Vector2(c.x, c.y + half * 1.8)]))
		# The steps beside it: an empty cell under rock with rock on one side gets the diagonal.
		for side: int in [-1, 1]:
			var e: Vector2i = v + Vector2i(side, 0)
			if checked.has(e) or solid.has(e) or not solid.has(e + Vector2i.UP) or solid.has(e + Vector2i.DOWN):
				continue
			checked[e] = true
			var ec: Vector2 = tile_map.to_global(tile_map.map_to_local(e))
			var near_x: float = ec.x - float(side) * half
			var far_x: float = ec.x + float(side) * half
			out.append(PackedVector2Array([Vector2(near_x, ec.y - half - 1.0), Vector2(far_x, ec.y - half - 1.0), Vector2(near_x, ec.y + half)]))
	return out


## Contiguous, seeded scallops along exposed bottom runs. Printed as part of the ground mass,
## so these are cloud-shaped island silhouettes rather than hanging props; no tiles change.
static func _cloud_bottoms(tile_map: TileMap, solid: Dictionary, half: float, seed_value: int) -> Array[PackedVector2Array]:
	var bottoms: Array[Vector2i] = []
	for v: Vector2i in solid:
		if not solid.has(v + Vector2i.DOWN):
			bottoms.append(v)
	bottoms.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var out: Array[PackedVector2Array] = []
	var i: int = 0
	while i < bottoms.size():
		var first: Vector2i = bottoms[i]
		var j: int = i
		while j + 1 < bottoms.size() and bottoms[j + 1].y == first.y and bottoms[j + 1].x == bottoms[j].x + 1:
			j += 1
		var a: Vector2 = tile_map.to_global(tile_map.map_to_local(first))
		var b: Vector2 = tile_map.to_global(tile_map.map_to_local(bottoms[j]))
		var x0: float = a.x - half
		var x1: float = b.x + half
		var y: float = a.y + half
		var lobes: Array[Vector3] = []
		var x: float = x0
		while x < x1 - 0.01:
			var k: int = lobes.size()
			var width: float = minf(x1 - x, half * (1.1 + RisoDecor.h(seed_value, first, 100 + k) * 1.2))
			# Distribute a very short remainder into the last puff rather than a tiny sliver.
			if x1 - x - width < half * 0.3:
				width = x1 - x
			var depth: float = minf(width * 0.42, half * (0.3 + RisoDecor.h(seed_value, first, 200 + k) * 0.3))
			lobes.append(Vector3(x + width * 0.5, width * 0.5, depth))
			x += width
		var poly: PackedVector2Array = PackedVector2Array([Vector2(x0, y - half * 0.35), Vector2(x1, y - half * 0.35)])
		for k: int in range(lobes.size() - 1, -1, -1):
			var lobe: Vector3 = lobes[k]
			for s: int in range(9):
				var angle: float = PI * float(s) / 8.0
				poly.append(Vector2(lobe.x + cos(angle) * lobe.y, y + sin(angle) * lobe.z))
		out.append(poly)
		i = j + 1
	return out


## `poly` with the `cut` region removed (largest remaining piece).
func _trim(poly: PackedVector2Array, cut: PackedVector2Array) -> PackedVector2Array:
	var best: PackedVector2Array = poly
	var best_area: float = -1.0
	for piece: PackedVector2Array in Geometry2D.clip_polygons(poly, cut):
		var area: float = absf(_area(piece))
		if area > best_area:
			best = piece
			best_area = area
	return best


func _area(poly: PackedVector2Array) -> float:
	var s: float = 0.0
	for k: int in range(poly.size()):
		var p: Vector2 = poly[k]
		var q: Vector2 = poly[(k + 1) % poly.size()]
		s += p.x * q.y - q.x * p.y
	return s * 0.5


## The part of a cell at least `d` from any exposed edge; corners facing open air are rounded.
func _inset(c: Vector2, h: float, d: float, r: float, up: bool, down: bool, left: bool, right: bool) -> PackedVector2Array:
	var x0: float = c.x - h + (0.0 if left else d)
	var x1: float = c.x + h - (0.0 if right else d)
	var y0: float = c.y - h + (0.0 if up else d)
	var y1: float = c.y + h - (0.0 if down else d)
	if x1 - x0 < 1.0 or y1 - y0 < 1.0:
		return PackedVector2Array()
	var hw: float = (x1 - x0) * 0.5
	var hh: float = (y1 - y0) * 0.5
	var rr: float = minf(r + d * 0.5, minf(hw, hh))
	return _box(Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5), hw, hh, rr, not up and not left, not up and not right, not down and not right, not down and not left)


## Three-quarter disc at an inside corner, leaving out the quadrant that faces open air.
func _pie(corner: Vector2, into_air: Vector2, r: float) -> PackedVector2Array:
	var a: float = into_air.angle() + PI * 0.25
	var out: PackedVector2Array = PackedVector2Array([corner])
	for s: int in range(13):
		var t: float = a + PI * 1.5 * float(s) / 12.0
		out.append(corner + Vector2(cos(t), sin(t)) * r)
	return out


func _box(c: Vector2, hw: float, hh: float, r: float, tl: bool, tr: bool, br: bool, bl: bool) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var corners: Array[Vector2] = [c + Vector2(-hw, -hh), c + Vector2(hw, -hh), c + Vector2(hw, hh), c + Vector2(-hw, hh)]
	var rounded: Array[bool] = [tl, tr, br, bl]
	var inward: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	var start: Array[float] = [PI, -PI * 0.5, 0.0, PI * 0.5]
	for k: int in range(4):
		if rounded[k] and r > 0.5:
			var q: Vector2 = corners[k] + inward[k] * r
			for s: int in range(5):
				var t: float = start[k] + (PI * 0.5) * float(s) / 4.0
				out.append(q + Vector2(cos(t), sin(t)) * r)
		else:
			out.append(corners[k])
	return out


## A cell square whose flagged corners (TL, TR, BR, BL) are rounded.
func _cell(c: Vector2, h: float, r: float, tl: bool, tr: bool, br: bool, bl: bool, r_top: float = -1.0) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var corners: Array[Vector2] = [c + Vector2(-h, -h), c + Vector2(h, -h), c + Vector2(h, h), c + Vector2(-h, h)]
	var rounded: Array[bool] = [tl, tr, br, bl]
	var inward: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	var start: Array[float] = [PI, -PI * 0.5, 0.0, PI * 0.5]
	for k: int in range(4):
		var rk: float = r_top if (k < 2 and r_top >= 0.0) else r
		if rounded[k] and rk > 0.5:
			var q: Vector2 = corners[k] + inward[k] * rk
			for s: int in range(5):
				var t: float = start[k] + (PI * 0.5) * float(s) / 4.0
				out.append(q + Vector2(cos(t), sin(t)) * rk)
		else:
			out.append(corners[k])
	return out


## Concave fillet in the corner `corner` of an empty cell; `into` points from the corner into the empty cell.
func _fillet(corner: Vector2, into: Vector2, r: float) -> PackedVector2Array:
	var q: Vector2 = corner + into * r
	var v1: Vector2 = Vector2(0, -into.y)
	var v2: Vector2 = Vector2(-into.x, 0)
	var out: PackedVector2Array = PackedVector2Array([corner])
	for s: int in range(5):
		out.append(q + v1.slerp(v2, float(s) / 4.0) * r)
	return out
