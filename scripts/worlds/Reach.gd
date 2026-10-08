class_name Reach
extends RefCounted
## A rough reach for the wizard over a World's cells, used to make sure a place can be got
## through: where the wizard can stand (footholds), and which of them one hop gets to. One hop,
## in cells, is up to UP up and ACROSS across (the dash included), a cell further across for every
## two fallen; from a moon (caught with the jump still rising, and the dash given back) MOON_UP up.
## Hyperspace bridges its strip with it; levels use it to keep the start escapable.

const UP: int = 2
const MOON_UP: int = 2
const ACROSS: int = 4


## Where the wizard can stand (open, not thorns, on rock or a ledge, or riding a lift anywhere on
## its track or a gondola anywhere on its circuit) as false, and the moons as true.
static func footholds(w: LevelGen) -> Dictionary:
	var nodes: Dictionary = {}
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			var v: Vector2i = Vector2i(x, y)
			if clear(w, v) and underfoot(w, v):
				nodes[v] = false
	for v: Vector2i in w.objects:
		var cell: LevelGen.Cell = w.get_cell(v)
		if cell.type == LevelGen.Type.MOON:
			nodes[v] = true
		elif cell.type == LevelGen.Type.MOVING_PLATFORM:
			var motion: Array = cell.extra_info
			for step: int in range(int(motion[2]) + 1):
				for dx: int in range(int(motion[0])):
					var f: Vector2i = v + Vector2i(dx, -1) + (motion[1] as Vector2i) * step
					if clear(w, f):
						nodes[f] = false
		elif cell.type == LevelGen.Type.GONDOLA:
			for f: Vector2i in CragsArchetype.loop_cells((cell.extra_info as Dictionary)["loop"]):
				if clear(w, f):
					nodes[f] = false
	return nodes


## Spread the reach from `queue` hop by hop over every foothold and moon; `far["i"]` keeps the
## furthest cell of `along` (a way through: cell to index) the wizard gets to. Hops climb up to
## `up` rows (UP for the wizard's own; more for a relic's, see Climb) and fall any way down, or at
## most `down` rows when that is not negative (a climb has little use for long falls, and they are
## the slow part in a big open level).
static func grow(w: LevelGen, nodes: Dictionary, reach: Dictionary, queue: Array[Vector2i], along: Dictionary = {}, far: Dictionary = {}, across: int = ACROSS, up: int = UP, down: int = -1) -> void:
	var track: bool = not along.is_empty()
	while not queue.is_empty():
		var a: Vector2i = queue.pop_back()
		var moon: bool = nodes.get(a, false)
		if track and int(along.get(a, -1)) > int(far["i"]):
			far["i"] = along[a]
		var bottom: int = w.size.y if down < 0 else mini(w.size.y, a.y + down + 1)
		for y: int in range(maxi(0, a.y - maxi(MOON_UP if moon else 0, up)), bottom):
			@warning_ignore("integer_division")
			var span: int = across + maxi(0, y - a.y) / 2
			for x: int in range(maxi(0, a.x - span), mini(w.size.x, a.x + span + 1)):
				var b: Vector2i = Vector2i(x, y)
				var node: bool = nodes.has(b) and not reach.has(b)
				var onward: bool = track and int(along.get(b, -1)) > int(far["i"])
				if (node or onward) and hop(w, a, b, moon, across, up):
					if node:
						reach[b] = true
						queue.append(b)
					if onward:
						far["i"] = along[b]


## Every foothold reached from `start`, hop by hop with hops `across` wide, nearest first: each
## mapped to the foothold it was reached from (`start` to itself), so the way to it can be
## followed back.
static func tree(w: LevelGen, start: Vector2i, across: int = ACROSS) -> Dictionary:
	var nodes: Dictionary = footholds(w)
	var parent: Dictionary = {start: start}
	var queue: Array[Vector2i] = [start]
	var i: int = 0
	while i < queue.size():
		var a: Vector2i = queue[i]
		i += 1
		var moon: bool = nodes.get(a, false)
		for y: int in range(maxi(0, a.y - (MOON_UP if moon else UP)), w.size.y):
			@warning_ignore("integer_division")
			var span: int = across + maxi(0, y - a.y) / 2
			for x: int in range(maxi(0, a.x - span), mini(w.size.x, a.x + span + 1)):
				var b: Vector2i = Vector2i(x, y)
				if nodes.has(b) and not parent.has(b) and hop(w, a, b, moon, across):
					parent[b] = a
					queue.append(b)
	return parent


## The footholds on the way from the root of `parent` (see tree) to `to`, root first.
static func way(parent: Dictionary, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [to]
	while parent.has(out[-1]) and parent[out[-1]] != out[-1]:
		out.append(parent[out[-1]])
	out.reverse()
	return out


static func reached_from(w: LevelGen, sources: Array[Vector2i], targets: Array[Vector2i]) -> bool:
	for b: Vector2i in targets:
		for a: Vector2i in sources:
			if hop(w, a, b, w.get_cell(a).type == LevelGen.Type.MOON):
				return true
	return false


## One hop from `a` to `b`: in reach (up to `up` rows up, or MOON_UP from a moon), and over clear
## air (up from `a`, across, down to `b`, either clearing a cell over the higher end or, in a low
## passage, level with it).
static func hop(w: LevelGen, a: Vector2i, b: Vector2i, from_moon: bool, across: int = ACROSS, up: int = UP) -> bool:
	var rise: int = a.y - b.y
	if rise > maxi(MOON_UP if from_moon else 0, up):
		return false
	@warning_ignore("integer_division")
	if absi(b.x - a.x) > across + maxi(0, -rise) / 2:
		return false
	var top: int = mini(a.y, b.y)
	return (top > 0 and arc_clear(w, a, b, top - 1)) or arc_clear(w, a, b, top)


## Whether the arc of a hop from `a` to `b` over row `top` is clear air all the way.
static func arc_clear(w: LevelGen, a: Vector2i, b: Vector2i, top: int) -> bool:
	for y: int in range(top, a.y + 1):
		if not clear(w, Vector2i(a.x, y)):
			return false
	for y: int in range(top, b.y + 1):
		if not clear(w, Vector2i(b.x, y)):
			return false
	var step: int = signi(b.x - a.x)
	if step != 0:
		for x: int in range(a.x, b.x + step, step):
			if not clear(w, Vector2i(x, top)):
				return false
	return true


## The cells a hop from `a` to `b` passes through (the box between them and a cell over it).
static func arc_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x: int in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
		for y: int in range(mini(a.y, b.y) - 1, maxi(a.y, b.y) + 1):
			out.append(Vector2i(x, y))
	return out


## Air the wizard can pass through: not rock and not thorns.
static func clear(w: LevelGen, v: Vector2i) -> bool:
	return w.is_valid(v) and not w.get_cell(v).type in [LevelGen.Type.GROUND, LevelGen.Type.CRACKED, LevelGen.Type.SPIKES]


## Something to stand on under `v`: rock, a ledge, or the border rock round the world.
static func underfoot(w: LevelGen, v: Vector2i) -> bool:
	var below: Vector2i = v + Vector2i.DOWN
	return not w.is_valid(below) or w.get_cell(below).type in [LevelGen.Type.GROUND, LevelGen.Type.CRACKED, LevelGen.Type.PLATFORM]
