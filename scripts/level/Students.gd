class_name Students
extends RefCounted
## The institute's students' days (Scholar): in each passing time every student walks the halls to
## the class it goes to next, and in class time it stays wherever it got to. Each period a student
## goes to one of the classrooms in session then or the library (`next_seat`), in an order dealt by
## the level seed and where the student was laid, taking the first it can walk to from where it is.
## A student that can walk to none of them (the levels climb further than it can) blinks to the
## first instead (Scholar._jump_to), as the scholars warp; it stays where it is only when there is
## nowhere else to go. In a classroom it takes a place on the floor
## at the back, away from the lectern; in the library, on its ground floor (`seats`).
##
## Students walk as a scholar does (Scholar._step): along floors and ledges, off an edge to whatever
## is under it, and with a jump up onto a floor or ledge as much as JUMP_UP cells over them, beside
## them or straight above (through a ledge, from under it); they go through classroom doors, which
## open for them (ExamDoor), but not locked doors or gates, and never onto thorns (`route`). A
## classroom's gallery is out of their reach, so once they have left it they sit on floors.
##
## Where a student is is worked out from its first place and the level's periods alone
## (`seat_at`), so a level comes back with its students where their days have taken them. Nothing
## here draws from the world RNG: it is hashed from the level seed.

## Salt for the level seed: the order a student tries the period's classes in, and its place in one.
const SHUFFLE_DEAL: int = 6480
const SEAT_DEAL: int = 6490
## The furthest a student drops off an edge, and the most it jumps up (cells).
const FALL_MOST: int = 12
const JUMP_UP: int = 2

## The cells reached from each cell walked from (`reach`), for the one level last asked about.
static var _reach_cache: Dictionary = {}
static var _cache_of: int = 0


## Whether a student walks into or through cell `c`: open air or a classroom's doorway, not rock, a
## locked door or a gate.
static func passable(w: LevelGen, c: Vector2i) -> bool:
	if not w.is_valid(c) or w.is_ground(c):
		return false
	return not w.get_cell(c).type in [LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.LIGHT_GATE, LevelGen.Type.CRACKED]


## Whether a student can stand in cell `c`: passable, not thorns, with rock or a ledge under it.
static func standing(w: LevelGen, c: Vector2i) -> bool:
	if not passable(w, c) or w.get_cell(c).type == LevelGen.Type.SPIKES:
		return false
	var under: Vector2i = c + Vector2i.DOWN
	return w.is_valid(under) and (w.is_ground(under) or w.get_cell(under).type == LevelGen.Type.PLATFORM)


## The cells a student standing in `c` walks to next: along the floor either way, off an edge to
## where it lands, or a jump up (JUMP_UP) to a floor beside it or over it, with room over its head.
static func steps_from(w: LevelGen, c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: int in [-1, 1]:
		var n: Vector2i = c + Vector2i(d, 0)
		if not passable(w, n):
			continue
		if standing(w, n):
			out.append(n)
			continue
		for k: int in range(1, FALL_MOST + 1):
			var f: Vector2i = n + Vector2i(0, k)
			if not passable(w, f) or w.get_cell(f).type == LevelGen.Type.SPIKES:
				break
			if standing(w, f):
				out.append(f)
				break
	for k: int in range(1, JUMP_UP + 1):
		if not passable(w, c + Vector2i(0, -k)):
			break
		for d: int in [-1, 0, 1]:
			var up: Vector2i = c + Vector2i(d, -k)
			if standing(w, up) and not out.has(up):
				out.append(up)
	return out


## Every cell a student walks to from `from`, each with the cell it is walked to from (`from` holds
## itself), searched in order so the same level always gives the same routes.
static func reach(w: LevelGen, from: Vector2i) -> Dictionary:
	if _cache_of != w.get_instance_id():
		_reach_cache.clear()
		_cache_of = w.get_instance_id()
	if _reach_cache.has(from):
		return _reach_cache[from]
	var came: Dictionary = {from: from}
	var queue: Array[Vector2i] = [from]
	var i: int = 0
	while i < queue.size():
		var c: Vector2i = queue[i]
		i += 1
		for n: Vector2i in steps_from(w, c):
			if not came.has(n):
				came[n] = c
				queue.append(n)
	_reach_cache[from] = came
	return came


## The cells a student walks through from `from` to `to`, `to` last (`from` left out); empty when it
## is there already or cannot get there.
static func route(w: LevelGen, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var came: Dictionary = reach(w, from)
	var out: Array[Vector2i] = []
	if from == to or not came.has(to):
		return out
	var c: Vector2i = to
	while c != from:
		out.push_front(c)
		c = came[c]
	return out


## Where students sit in hall `hall`: the standing cells of its lowest floor, in a classroom only
## those in the half away from its lectern, from the left.
static func seats(w: LevelGen, hall: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var floors: Array = w.halls[hall]["floors"]
	var bottom: int = -1
	for v: Vector2i in floors:
		bottom = maxi(bottom, v.y)
	var inside: Rect2i = w.halls[hall]["inside"]
	var front: int = int(w.halls[hall].get("front", 0))
	@warning_ignore("integer_division")
	var middle: int = inside.position.x + inside.size.x / 2
	for v: Vector2i in floors:
		if v.y != bottom or not standing(w, v):
			continue
		if front > 0 and v.x < middle or front < 0 and v.x >= middle:
			continue
		out.append(v)
	out.sort()
	return out


## Where the student first laid at `origin` goes in period `rings` from cell `from`: a seat in the
## first, in its dealt order, of the classrooms in session then and the library (but the one it is
## in) that it can walk to; if it can walk to none, a seat in the first of them, which it blinks to;
## `from` itself, staying put, if none has a seat.
static func next_seat(w: LevelGen, origin: Vector2i, rings: int, from: Vector2i) -> Vector2i:
	var halls: Array[int] = []
	for i: int in range(w.halls.size()):
		var kind: StringName = w.halls[i]["kind"]
		if kind == &"library" or (kind == &"lecture" and Timetable.in_session(w, i, rings)):
			halls.append(i)
	var key: Callable = func(i: int) -> int: return posmod(Rules.level_seed(w.seed_for_colors, SHUFFLE_DEAL + rings * 131 + i * 17 + origin.x * 977 + origin.y), 1 << 24)
	var here: int = Timetable.hall_inside(w, from)
	halls.erase(here)
	halls.sort_custom(func(a: int, b: int) -> bool: return key.call(a) < key.call(b))
	var came: Dictionary = reach(w, from)
	var pick: int = posmod(Rules.level_seed(w.seed_for_colors, SEAT_DEAL + rings * 131 + origin.x * 977 + origin.y), 1 << 20)
	var blink: Vector2i = Vector2i(-1, -1)
	for i: int in halls:
		var all: Array[Vector2i] = seats(w, i)
		if all.is_empty():
			continue
		var places: Array[Vector2i] = all.filter(func(v: Vector2i) -> bool: return came.has(v))
		if not places.is_empty():
			return places[pick % places.size()]
		if blink.x < 0:
			blink = all[pick % all.size()]
	return blink if blink.x >= 0 else from


## Where the student first laid at `origin` sits in class time of period `rings` (and so where it
## sets out from in the passing time after): its day walked through from the first period.
static func seat_at(w: LevelGen, origin: Vector2i, rings: int) -> Vector2i:
	var at: Vector2i = origin
	for r: int in range(rings + 1):
		at = next_seat(w, origin, r, at)
	return at
