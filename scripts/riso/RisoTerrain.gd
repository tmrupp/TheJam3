extends Node2D
## Terrain printed from the TileMap's ground layer as one contiguous mass: rounded outer
## corners, concave fillets where walls meet floors, one rounded cap strip per walkable run,
## and two screened bands of night ink inset from every exposed edge, so the shading follows
## the rock's outline instead of stepping cell by cell.

const SHADE_NEAR: float = 22.0
const SHADE_FAR: float = 58.0
const SHADE_COVER: float = 0.16

var ink: InkCanvas


func _ready() -> void:
	z_index = -20
	z_as_relative = false
	add_to_group(&"riso_art")
	visible = RisoPrint.is_on()
	ink = InkCanvas.new()
	add_child(ink)
	var map: TileMap = get_node_or_null("/root/Main/TileMap") as TileMap
	if map != null and map.get_used_cells(0).size() > 0:
		rebuild(map)


func rebuild(tile_map: TileMap) -> void:
	if tile_map == null:
		return
	var solid: Dictionary = {}
	for v: Vector2i in tile_map.get_used_cells(0):
		solid[v] = true
	var half: float = float(tile_map.tile_set.tile_size.x) * tile_map.global_scale.x * 0.5
	var radius: float = half * 0.32
	var body: Array[PackedVector2Array] = []
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
		body.append(_cell(c, half, radius, not up and not left, not up and not right, not down and not right, not down and not left))
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
				if solid.has(e + Vector2i(sx, 0)) and solid.has(e + Vector2i(0, sy)) and solid.has(e + Vector2i(sx, sy)):
					var corner: Vector2 = c + Vector2(sx, sy) * half
					fillets.append(_fillet(corner, Vector2(-sx, -sy), radius))
					near_pies.append(_pie(corner, Vector2(-sx, -sy), SHADE_NEAR + radius * 0.5))
					far_pies.append(_pie(corner, Vector2(-sx, -sy), SHADE_FAR))
	var caps: Array[PackedVector2Array] = []
	var tops: Array[Vector2i] = []
	for v: Vector2i in solid:
		if not solid.has(v + Vector2i.UP):
			tops.append(v)
	tops.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var i: int = 0
	while i < tops.size():
		var j: int = i
		while j + 1 < tops.size() and tops[j + 1].y == tops[i].y and tops[j + 1].x == tops[j].x + 1:
			j += 1
		var a: Vector2 = tile_map.to_global(tile_map.map_to_local(tops[i]))
		var b: Vector2 = tile_map.to_global(tile_map.map_to_local(tops[j]))
		var x0: float = a.x - half + 2.0
		var x1: float = b.x + half - 2.0
		caps.append(RisoShapes.rrect(x0, a.y - half - 3.0, x1 - x0, 17.0, 8.0, 3))
		i = j + 1
	ink.begin()
	body.append_array(fillets)
	# Rock hides the sky behind it: no stars or moons printing through the ground.
	ink.knock([RisoPrint.PINK, RisoPrint.ACCENT], body)
	ink.ink(RisoPrint.BLUE, 1.0, body)
	# Deep band first, cleared around inside corners; then the near band, cleared tighter.
	ink.ink(RisoPrint.NIGHT, SHADE_COVER, far, false)
	ink.knock([RisoPrint.NIGHT], far_pies)
	ink.ink(RisoPrint.NIGHT, SHADE_COVER, near, false)
	ink.knock([RisoPrint.NIGHT], near_pies)
	ink.ink(RisoPrint.ACCENT, 1.0, caps)
	ink.finish()


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
func _cell(c: Vector2, h: float, r: float, tl: bool, tr: bool, br: bool, bl: bool) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var corners: Array[Vector2] = [c + Vector2(-h, -h), c + Vector2(h, -h), c + Vector2(h, h), c + Vector2(-h, h)]
	var rounded: Array[bool] = [tl, tr, br, bl]
	var inward: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	var start: Array[float] = [PI, -PI * 0.5, 0.0, PI * 0.5]
	for k: int in range(4):
		if rounded[k]:
			var q: Vector2 = corners[k] + inward[k] * r
			for s: int in range(5):
				var t: float = start[k] + (PI * 0.5) * float(s) / 4.0
				out.append(q + Vector2(cos(t), sin(t)) * r)
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
