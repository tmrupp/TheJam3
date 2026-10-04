class_name Hyperspace
extends SideWorld
## Hyperspace: a side world (see SideWorld) one long level strung between a level and the one DROP
## below it (give or take a world sideways, see drift). Its door is rare: from depth 1, in CHANCE %
## of levels (every level in a debug run), and costs PRICE times the deeper exit. You come in at
## the left end (the way back, out of the door) and leave by its gate at the right end, which drops
## you at the far level's way back (and that way back leads here again).
##
## Its terrain is collapsed like any level's, but from its own, far more dangerous sample
## (SAMPLE: thorn-capped floors, thorn-bottomed pits, toothed ceilings, thorned islands) and laid
## out as a short strip, 64 cells across and 16 high (a quick crossing, packed with hazards), so the
## way on is always to the right. populate dresses what the collapse makes: both ends are laid flat
## and safe, the exits and lanterns (the start, a rest halfway and the gate) go in, gliding ledges
## and moons fill the big gaps and the tall walls, more are laid wherever a rough reach still can't
## get on (see _bridge), and watchers, wisps, moons and stars are scattered along it. Everything is
## a pure function of the level seed.

## Its door: dealt in CHANCE % of levels from depth 1; drops DROP levels; costs PRICE deeper exits.
const CHANCE: int = 18
const DROP: int = 4
const PRICE: float = 5.0

const WIDTH: int = 64
const HEIGHT: int = 16
## The flat ends: rock above row CEILING and from row FLOOR down, so a walker's cell is FLOOR - 1.
const CEILING: int = 3
const FLOOR: int = 12
## Cells laid flat at each end.
const ENDS: int = 8
const SAMPLE: String = "res://wfc_images/chasm_gauntlet.png"

const WATCHERS: int = 7
const WISPS: int = 5
const MOONS: int = 4
const STARS: int = 14
## Lasers set in the rock, firing across the way (see Laser.gd), and the cells a beam must cross.
const LASERS: int = 5
const LASER_MIN_REACH: int = 3
## Where the rest lantern stands, as a fraction of the way along.
const RESTS: Array[float] = [0.5]


func _init() -> void:
	name = "hyperspace"
	way = Vector2.RIGHT
	print_realm = &"hyperspace"
	plants = false
	price_factor = PRICE
	cells = Vector2i(WIDTH, HEIGHT)
	sample = SAMPLE


func deals(at: Vector2i) -> bool:
	return MapInfo.debug or (at.y >= 1 and MapInfo.level_seed(MapInfo.level_seed(at.x, at.y), 777) % 100 < CHANCE)


## How many worlds sideways (-1, 0 or +1) the one entered from level `from` comes out, dealt by
## that level's seed.
static func drift(from: Vector2i) -> int:
	return MapInfo.level_seed(MapInfo.level_seed(from.x, from.y), 991) % 3 - 1


func destination_for(from: Vector2i) -> Vector2i:
	return Vector2i(from.x + drift(from), from.y + DROP)


## Where two would land in the same level (one drifting onto the other's straight drop), the one
## straight above wins, then the one from the left.
func arriving(at: Vector2i) -> Variant:
	if at.y < DROP:
		return null
	for dx: int in [0, -1, 1]:
		var from: Vector2i = Vector2i(at.x - dx, at.y - DROP)
		if deals(from) and drift(from) == dx:
			return from
	return null


## The middle of the drop it spans.
func depth_for(from: Vector2i) -> int:
	@warning_ignore("integer_division")
	return from.y + DROP / 2


## An empty strip, in the generator's colours: what a collapse that never settles falls back to.
func fallback() -> Array:
	var out: Array = []
	for x: int in range(WIDTH):
		var column: Array = []
		for y: int in range(HEIGHT):
			column.append(Color.WHITE if y >= CEILING and y < FLOOR else Color.BLACK)
		out.append(column)
	return out


## Dress a World made from the collapsed terrain: ends, exits, lanterns, hazards, stars.
func populate(w: MapInfo.World) -> void:
	_lay_ends(w)
	w.connect_caves()
	var back: Vector2i = Vector2i(3, FLOOR - 1)
	var gate: Vector2i = Vector2i(WIDTH - 5, FLOOR - 1)
	var back_lantern: Vector2i = back + Vector2i(4, 0)
	var gate_lantern: Vector2i = gate - Vector2i(4, 0)
	_put(w, back, MapInfo.Type.EXIT, MapInfo.Exit.BACK)
	_put(w, back_lantern, MapInfo.Type.CHECKPOINT)
	_put(w, gate, MapInfo.Type.EXIT, MapInfo.Exit.DEEPER)
	_put(w, gate_lantern, MapInfo.Type.CHECKPOINT)
	w.exits = {MapInfo.Exit.BACK: back, MapInfo.Exit.DEEPER: gate}
	w.exit_lanterns = {MapInfo.Exit.BACK: back_lantern, MapInfo.Exit.DEEPER: gate_lantern}
	for fraction: float in RESTS:
		var at: Variant = _standing_near(w, int(fraction * WIDTH))
		if at != null:
			_put(w, at, MapInfo.Type.CHECKPOINT)
	_lifts(w)
	_lasers(w)
	_spread(w, WISPS, MapInfo.Type.ENEMY, 0.25)
	_spread(w, WATCHERS, MapInfo.Type.SHOOTER, 0.6)
	w.place_moons(MOONS)
	for i: int in range(STARS):
		w.set_cell(w.pop_if_random_empty(), MapInfo.Cell.new(MapInfo.Type.COIN))


static func _put(w: MapInfo.World, v: Vector2i, type: MapInfo.Type, extra: Variant = null) -> void:
	var cell: MapInfo.Cell = MapInfo.Cell.new(type)
	cell.extra_info = extra
	w.add_object_at(v)
	w.set_cell(v, cell)


## Rock above and below, open between, for ENDS cells at each end: a safe place to arrive and to leave.
static func _lay_ends(w: MapInfo.World) -> void:
	for x: int in range(WIDTH):
		if x >= ENDS and x < WIDTH - ENDS:
			continue
		for y: int in range(HEIGHT):
			var v: Vector2i = Vector2i(x, y)
			var rock: bool = y < CEILING or y >= FLOOR
			var is_rock: bool = w.get_cell(v).type == MapInfo.Type.GROUND
			if rock and not is_rock:
				w._to_rock(v)
			elif not rock and w.get_cell(v).type != MapInfo.Type.EMPTY:
				w._to_open(v)


## Standing places between the ends, in order: open floor with rock under it, clear of every
## exit, lantern and other thing placed (thorns aside).
static func _standing(w: MapInfo.World) -> Array[Vector2i]:
	var crowd: Dictionary = {}
	for o: Vector2i in w.objects:
		if w.get_cell(o).type == MapInfo.Type.SPIKES:
			continue
		for dx: int in range(-1, 2):
			for dy: int in range(-1, 2):
				crowd[o + Vector2i(dx, dy)] = true
	var spots: Array[Vector2i] = []
	for v: Vector2i in w.empties:
		if v.x >= ENDS and v.x < WIDTH - ENDS and w.ground_below(v) and not crowd.has(v):
			spots.append(v)
	spots.sort()
	return spots


static func _standing_near(w: MapInfo.World, x: int) -> Variant:
	var best: Variant = null
	for v: Vector2i in _standing(w):
		if best == null or absi(v.x - x) < absi((best as Vector2i).x - x):
			best = v
	return best


## LASERS lasers spread along the way between the ends, each set in rock (a ceiling or a wall, or
## a floor) and firing out across at least LASER_MIN_REACH cells of open air, apart from each other.
static func _lasers(w: MapInfo.World) -> void:
	var spots: Array[Array] = []
	for v: Vector2i in w.empties:
		if v.x < ENDS + 1 or v.x >= WIDTH - ENDS - 1 or w.get_cell(v).type != MapInfo.Type.EMPTY:
			continue
		for d: Vector2i in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP]:
			if not w.is_ground(v - d):
				continue
			var reach: int = 0
			while _clear(w, v + d * (reach + 1)):
				reach += 1
			if reach >= LASER_MIN_REACH:
				spots.append([v, d])
	spots.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var span: float = float(WIDTH - ENDS * 2) / float(LASERS)
	var placed: Array[Vector2i] = []
	for k: int in range(LASERS):
		var target: float = ENDS + (float(k) + 0.5) * span
		var best: Array = []
		for s: Array in spots:
			var v: Vector2i = s[0]
			if placed.any(func(p: Vector2i) -> bool: return absi(p.x - v.x) + absi(p.y - v.y) < 5):
				continue
			if best.is_empty() or absf(v.x - target) < absf((best[0] as Vector2i).x - target):
				best = s
		if not best.is_empty():
			placed.append(best[0])
			_put(w, best[0], MapInfo.Type.LASER, best[1])


## `count` of something on the floor, aimed at `phase` of the way through each equal share of the
## way between the ends, on the free floor nearest that.
static func _spread(w: MapInfo.World, count: int, type: MapInfo.Type, phase: float) -> void:
	var span: float = float(WIDTH - ENDS * 2) / float(count)
	var spots: Array[Vector2i] = _standing(w)
	for k: int in range(count):
		var target: float = ENDS + (float(k) + phase) * span
		var best: Variant = null
		for v: Vector2i in spots:
			if best == null or absf(v.x - target) < absf((best as Vector2i).x - target):
				best = v
		if best != null:
			_put(w, best, type)
			var taken: Vector2i = best
			spots = spots.filter(func(v: Vector2i) -> bool: return absi(v.x - taken.x) > 1 or absi(v.y - taken.y) > 1)


# ------------------------------------------------------------------ ledges and moons for the gaps

## One hop, in cells: up to JUMP_UP up and JUMP_ACROSS across (the dash included), a cell further
## across for every two fallen; from a moon (caught with the jump still rising, and the dash given
## back) MOON_UP up. A rough reach, used to bridge whatever the strip leaves out of it.
const JUMP_UP: int = 2
const MOON_UP: int = 2
const JUMP_ACROSS: int = 4
## Up a tall wall, a lift every WALL_STEP cells.
const WALL_STEP: int = 3
const MOON_GAP: int = 4
## Bridges laid at most, so a hopeless strip gives up rather than filling with lifts.
const MAX_BRIDGES: int = 96
## A bridge starts from footholds this near where the reach stops, and aims this far on.
const BRIDGE_NEAR: int = 8
const BRIDGE_AHEAD: int = 12


## Cells of rock to stand on, in a gap's long fall, are what a wide gap lacks: lay gliding ledges
## across the big gaps (open stretches with nothing under them for several cells) and stacked up
## every tall wall, with moons beside them; then bridge every stretch the rough reach still can't
## cross (see _bridge), so the strip can be crossed by timing.
static func _lifts(w: MapInfo.World) -> void:
	var free: Dictionary = {}
	for v: Vector2i in w.empties:
		free[v] = true
	var placed: Array[Vector2i] = []
	var moons: Array[Vector2i] = []
	# Wide gaps: a gliding ledge every few cells along each stretch, row by row.
	for y: int in range(4, HEIGHT - 3):
		var x: int = ENDS
		while x < WIDTH - ENDS:
			if not _hangs(w, Vector2i(x, y)):
				x += 1
				continue
			var end: int = x
			while end + 1 < WIDTH - ENDS and _hangs(w, Vector2i(end + 1, y)):
				end += 1
			if end - x + 1 >= 4:
				for sx: int in range(x, end - 1, 4):
					var travel: int = clampi(end - sx - 1, 2, 4)
					if _glider(w, free, Vector2i(sx, y), Vector2i(1, 0), travel, placed):
						_moon(w, free, Vector2i(sx + 1, y - 3), moons)
			x = end + 1
	# Tall vertical walls: a close stack of gliding ledges that rise and fall, moons between.
	for x: int in range(ENDS, WIDTH - ENDS - 1):
		var y: int = 4
		while y < HEIGHT - 3:
			if not _walled(w, Vector2i(x, y)):
				y += 1
				continue
			var bottom: int = y
			while bottom + 1 < HEIGHT - 3 and _walled(w, Vector2i(x, bottom + 1)):
				bottom += 1
			if bottom - y + 1 >= 4:
				for sy: int in range(y, bottom - 1, WALL_STEP):
					if _glider(w, free, Vector2i(x, sy), Vector2i(0, 1), 2, placed):
						_moon(w, free, Vector2i(x, sy - 2), moons)
			y = bottom + 1
	_bridge(w, free, placed, moons)


## Whether the rough reach gets from the way back to the gate.
static func crossable(w: MapInfo.World) -> bool:
	var nodes: Dictionary = _footholds(w)
	var start: Vector2i = w.exits[MapInfo.Exit.BACK]
	var reach: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	_grow(w, nodes, reach, queue)
	return reach.has(w.exits[MapInfo.Exit.DEEPER])


## Lay lifts (or, where none fits, a floating ledge or a moon) along the way through the open air
## (see _air_path) until the rough reach gets from the way back to the gate: each time, where the
## reach stops along that way, the one that carries a rider furthest on along it.
static func _bridge(w: MapInfo.World, free: Dictionary, placed: Array[Vector2i], moons: Array[Vector2i]) -> void:
	var path: Array[Vector2i] = _air_path(w)
	if path.is_empty():
		return
	var along: Dictionary = {}
	for i: int in range(path.size()):
		along[path[i]] = i
		# Where the only way on runs through thorns, those thorns go.
		if w.get_cell(path[i]).type == MapInfo.Type.SPIKES:
			_unthorn(w, free, path[i])
	var nodes: Dictionary = _footholds(w)
	var gate: Vector2i = w.exits[MapInfo.Exit.DEEPER]
	var start: Vector2i = w.exits[MapInfo.Exit.BACK]
	var reach: Dictionary = {start: true}
	var far: Dictionary = {"i": 0}
	var first: Array[Vector2i] = [start]
	_grow(w, nodes, reach, first, along, far)
	var thinned: int = -1
	for i: int in range(MAX_BRIDGES):
		if reach.has(gate):
			return
		var at: int = far["i"]
		var here: Vector2i = path[at]
		var sources: Array[Vector2i] = []
		for v: Vector2i in reach:
			if absi(v.x - here.x) <= BRIDGE_NEAR and absi(v.y - here.y) <= BRIDGE_NEAR:
				sources.append(v)
		var ahead: int = mini(path.size() - 1, at + BRIDGE_AHEAD)
		var lo: Vector2i = here
		var hi: Vector2i = here
		for j: int in range(at, ahead + 1):
			lo = lo.min(path[j])
			hi = hi.max(path[j])
		var best: Array = []
		var best_score: int = at
		for x: int in range(maxi(0, lo.x - 3), mini(WIDTH, hi.x + 4)):
			for y: int in range(maxi(0, lo.y - 3), mini(HEIGHT, hi.y + 4)):
				var c: Vector2i = Vector2i(x, y)
				for width: int in [2, 1]:
					for axis: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
						for travel: int in range(2, 5):
							var swept: Array[Vector2i] = _track(w, free, c, axis, travel, width)
							if swept.is_empty():
								continue
							var lands: Array[Vector2i] = []
							for v: Vector2i in swept:
								var f: Vector2i = v + Vector2i.UP
								if _clear(w, f) and not reach.has(f) and not lands.has(f):
									lands.append(f)
							var score: int = _onward(w, path, lands, best_score, ahead, false)
							if score > best_score and _reached_from(w, sources, lands):
								best_score = score
								best = [c, axis, travel, swept, lands, width]
				# A ledge or a moon only where it carries a cell further than any lift.
				if free.has(c) and w.get_cell(c).type == MapInfo.Type.EMPTY:
					var alone: Array[Vector2i] = [c]
					var score: int = _onward(w, path, alone, best_score + 1, ahead, true)
					if score > best_score + 1 and _reached_from(w, sources, alone):
						best_score = score - 1
						best = [c]
					var step: Array[Vector2i] = [c + Vector2i.UP]
					if _clear(w, c + Vector2i.UP) and not reach.has(c + Vector2i.UP):
						score = _onward(w, path, step, best_score + 1, ahead, false)
						if score > best_score + 1 and _reached_from(w, sources, step):
							best_score = score - 1
							best = [c, step]
		if best.is_empty():
			# Stuck: the thorns right beside the way just ahead go, once per place, and it tries again.
			if at == thinned:
				return
			thinned = at
			for j: int in range(at, ahead + 1):
				for d: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
					var c: Vector2i = path[j] + d
					if w.is_valid(c) and w.get_cell(c).type == MapInfo.Type.SPIKES:
						_unthorn(w, free, c)
			nodes = _footholds(w)
			reach = {start: true}
			var again: Array[Vector2i] = [start]
			_grow(w, nodes, reach, again, along, far)
			continue
		var fresh: Array[Vector2i] = []
		if best.size() == 1:
			var m: Vector2i = best[0]
			free.erase(m)
			moons.append(m)
			_put(w, m, MapInfo.Type.MOON)
			nodes[m] = true
			fresh.append(m)
		elif best.size() == 2:
			var ledge: Vector2i = best[0]
			free.erase(ledge)
			_put(w, ledge, MapInfo.Type.PLATFORM)
			nodes[ledge + Vector2i.UP] = false
			fresh.append(ledge + Vector2i.UP)
		else:
			var lift: Vector2i = best[0]
			for v: Vector2i in best[3]:
				free.erase(v)
				w.empties.erase(v)
			placed.append(lift)
			_put(w, lift, MapInfo.Type.MOVING_PLATFORM, [best[5], best[1], best[2]])
			for f: Vector2i in best[4]:
				nodes[f] = false
				fresh.append(f)
			var beside: Vector2i = lift + Vector2i(0, -3)
			if _moon(w, free, beside, moons):
				nodes[beside] = true
		var queue: Array[Vector2i] = []
		for n: Vector2i in fresh:
			var alone: Array[Vector2i] = [n]
			if _reached_from(w, sources, alone):
				reach[n] = true
				queue.append(n)
		_grow(w, nodes, reach, queue, along, far)


## Clear the thorn at `v` to free open air.
static func _unthorn(w: MapInfo.World, free: Dictionary, v: Vector2i) -> void:
	w.cells[v.x][v.y] = MapInfo.Cell.new(MapInfo.Type.EMPTY)
	w.objects.erase(v)
	w.empties.append(v)
	free[v] = true


## How far along `path` (past `past`, up to `ahead`) one hop from any of `lands` gets.
static func _onward(w: MapInfo.World, path: Array[Vector2i], lands: Array[Vector2i], past: int, ahead: int, from_moon: bool) -> int:
	for j: int in range(ahead, past, -1):
		for f: Vector2i in lands:
			if f == path[j] or _hop(w, f, path[j], from_moon):
				return j
	return past


## The cheapest way through the open air from the way back to the gate: a cell with something to
## stand on costs 1, a cell of air 3, a thorn 40, so it keeps to the floors and crosses the air
## only where it has to.
static func _air_path(w: MapInfo.World) -> Array[Vector2i]:
	var start: Vector2i = w.exits[MapInfo.Exit.BACK]
	var gate: Vector2i = w.exits[MapInfo.Exit.DEEPER]
	var dist: Dictionary = {start: 0}
	var from: Dictionary = {}
	var buckets: Array = [[start]]
	var d: int = 0
	while d < buckets.size() and not from.has(gate):
		for c: Vector2i in buckets[d]:
			if int(dist[c]) != d:
				continue
			for step: Vector2i in [Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT]:
				var n: Vector2i = c + step
				if not w.is_valid(n) or w.get_cell(n).type in [MapInfo.Type.GROUND, MapInfo.Type.CRACKED]:
					continue
				var cost: int = 3
				if w.get_cell(n).type == MapInfo.Type.SPIKES:
					cost = 40
				elif _underfoot(w, n):
					cost = 1
				var nd: int = d + cost
				if nd < int(dist.get(n, 1000000)):
					dist[n] = nd
					from[n] = c
					while buckets.size() <= nd:
						buckets.append([])
					(buckets[nd] as Array).append(n)
		d += 1
	if not from.has(gate):
		return []
	var path: Array[Vector2i] = [gate]
	while path[-1] != start:
		path.append(from[path[-1]])
	path.reverse()
	return path


## Where the wizard can stand (open, not thorns, on rock or a ledge, or riding a lift anywhere on
## its track) as false, and the moons as true.
static func _footholds(w: MapInfo.World) -> Dictionary:
	var nodes: Dictionary = {}
	for x: int in range(WIDTH):
		for y: int in range(HEIGHT):
			var v: Vector2i = Vector2i(x, y)
			if _clear(w, v) and _underfoot(w, v):
				nodes[v] = false
	for v: Vector2i in w.objects:
		var cell: MapInfo.Cell = w.get_cell(v)
		if cell.type == MapInfo.Type.MOON:
			nodes[v] = true
		elif cell.type == MapInfo.Type.MOVING_PLATFORM:
			var motion: Array = cell.extra_info
			for step: int in range(int(motion[2]) + 1):
				for dx: int in range(int(motion[0])):
					var f: Vector2i = v + Vector2i(dx, -1) + (motion[1] as Vector2i) * step
					if _clear(w, f):
						nodes[f] = false
	return nodes


## Spread the reach from `queue` hop by hop over every foothold and moon; `far["i"]` keeps the
## furthest cell of `along` (a way through: cell to index) the wizard gets to.
static func _grow(w: MapInfo.World, nodes: Dictionary, reach: Dictionary, queue: Array[Vector2i], along: Dictionary = {}, far: Dictionary = {}) -> void:
	var track: bool = not along.is_empty()
	while not queue.is_empty():
		var a: Vector2i = queue.pop_back()
		var moon: bool = nodes.get(a, false)
		if track and int(along.get(a, -1)) > int(far["i"]):
			far["i"] = along[a]
		for y: int in range(maxi(0, a.y - (MOON_UP if moon else JUMP_UP)), HEIGHT):
			var across: int = JUMP_ACROSS + maxi(0, y - a.y) / 2
			for x: int in range(maxi(0, a.x - across), mini(WIDTH, a.x + across + 1)):
				var b: Vector2i = Vector2i(x, y)
				var node: bool = nodes.has(b) and not reach.has(b)
				var onward: bool = track and int(along.get(b, -1)) > int(far["i"])
				if (node or onward) and _hop(w, a, b, moon):
					if node:
						reach[b] = true
						queue.append(b)
					if onward:
						far["i"] = along[b]


static func _reached_from(w: MapInfo.World, sources: Array[Vector2i], targets: Array[Vector2i]) -> bool:
	for b: Vector2i in targets:
		for a: Vector2i in sources:
			if _hop(w, a, b, w.get_cell(a).type == MapInfo.Type.MOON):
				return true
	return false


## One hop from `a` to `b`: in reach, and over clear air (up from `a`, across, down to `b`, either
## clearing a cell over the higher end or, in a low passage, level with it).
static func _hop(w: MapInfo.World, a: Vector2i, b: Vector2i, from_moon: bool) -> bool:
	var rise: int = a.y - b.y
	if rise > (MOON_UP if from_moon else JUMP_UP):
		return false
	if absi(b.x - a.x) > JUMP_ACROSS + maxi(0, -rise) / 2:
		return false
	var top: int = mini(a.y, b.y)
	return (top > 0 and _arc_clear(w, a, b, top - 1)) or _arc_clear(w, a, b, top)


static func _arc_clear(w: MapInfo.World, a: Vector2i, b: Vector2i, top: int) -> bool:
	for y: int in range(top, a.y + 1):
		if not _clear(w, Vector2i(a.x, y)):
			return false
	for y: int in range(top, b.y + 1):
		if not _clear(w, Vector2i(b.x, y)):
			return false
	var step: int = signi(b.x - a.x)
	if step != 0:
		for x: int in range(a.x, b.x + step, step):
			if not _clear(w, Vector2i(x, top)):
				return false
	return true


## Air the wizard can pass through: not rock and not thorns.
static func _clear(w: MapInfo.World, v: Vector2i) -> bool:
	return w.is_valid(v) and not w.get_cell(v).type in [MapInfo.Type.GROUND, MapInfo.Type.CRACKED, MapInfo.Type.SPIKES]


## Something to stand on under `v`: rock, a ledge, or the border rock round the strip.
static func _underfoot(w: MapInfo.World, v: Vector2i) -> bool:
	var below: Vector2i = v + Vector2i.DOWN
	return not w.is_valid(below) or w.get_cell(below).type in [MapInfo.Type.GROUND, MapInfo.Type.CRACKED, MapInfo.Type.PLATFORM]


## The cells a lift `width` cells wide at `at` sweeps along `axis` over `travel` cells, or none if
## any of them is not free open air.
static func _track(w: MapInfo.World, free: Dictionary, at: Vector2i, axis: Vector2i, travel: int, width: int = 2) -> Array[Vector2i]:
	var swept: Array[Vector2i] = []
	for step: int in range(travel + 1):
		for dx: int in range(width):
			var v: Vector2i = at + Vector2i(dx, 0) + axis * step
			if not free.has(v) or w.get_cell(v).type != MapInfo.Type.EMPTY:
				return []
			if not swept.has(v):
				swept.append(v)
	return swept


## Open air with nothing to land on for the next four cells down.
static func _hangs(w: MapInfo.World, v: Vector2i) -> bool:
	if w.get_cell(v).type != MapInfo.Type.EMPTY:
		return false
	for k: int in range(1, 5):
		if not w.is_valid(v + Vector2i(0, k)) or w.get_cell(v + Vector2i(0, k)).type == MapInfo.Type.GROUND:
			return false
	return true


## Open air in a tall shaft, with rock close beside it on at least one side.
static func _walled(w: MapInfo.World, v: Vector2i) -> bool:
	if w.get_cell(v).type != MapInfo.Type.EMPTY or not w.is_valid(v + Vector2i.RIGHT):
		return false
	return w.is_ground(v + Vector2i.LEFT) or w.is_ground(v + Vector2i(2, 0))


## A gliding ledge two cells wide from `at`, sweeping `travel` cells along `axis`, if all it sweeps
## is free open air, and no other ledge is close.
static func _glider(w: MapInfo.World, free: Dictionary, at: Vector2i, axis: Vector2i, travel: int, placed: Array[Vector2i]) -> bool:
	for p: Vector2i in placed:
		if absi(p.x - at.x) < 5 and absi(p.y - at.y) < 3:
			return false
	var swept: Array[Vector2i] = _track(w, free, at, axis, travel)
	if swept.is_empty():
		return false
	for v: Vector2i in swept:
		free.erase(v)
		w.empties.erase(v)
	placed.append(at)
	_put(w, at, MapInfo.Type.MOVING_PLATFORM, [2, axis, travel])
	return true


## A moon at `v` if it is free open air with nothing to stand on under it, and no other moon is
## within MOON_GAP cells.
static func _moon(w: MapInfo.World, free: Dictionary, v: Vector2i, moons: Array[Vector2i]) -> bool:
	if not free.has(v) or w.get_cell(v).type != MapInfo.Type.EMPTY or _underfoot(w, v):
		return false
	for m: Vector2i in moons:
		if absi(m.x - v.x) + absi(m.y - v.y) < MOON_GAP:
			return false
	free.erase(v)
	moons.append(v)
	_put(w, v, MapInfo.Type.MOON)
	return true
