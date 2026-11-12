class_name Secrets
extends RefCounted
## A level's secret rooms: pockets of rock behind a false wall (the entrance) at floor height beside
## a floor. The room's cells and its entrance are cracked cells holding the secret's number; all of
## them look and map as plain rock (see MapInfo.open_secret), but the entrance can be walked and
## shot straight through. Stepping into it, a hex bolt striking the rock behind it, drifting in as
## an astral projection or warping in opens the whole room for good, and its rewards appear: the
## level's relic (see Relics) if it has one, and stars. Each is kept in LevelGen.secrets as
## {"room": cells, "entrance": cells, "rewards": [[cell, type, extra], ...]}; placed last of all
## (LevelGen.populate_level), so the rest of the level lands where it always has.

## How many rooms a level holds, per 1000 cells (LevelGen.per_area).
const PER_K: float = 0.6
## Room sizes (cells across and up) tried in turn, biggest first.
const SIZES: Array[Vector2i] = [Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2)]
## Stars in a room, besides the relic if it holds one.
const STARS: int = 3
## Left, then right.
const SIDES: Array[int] = [-1, 1]


## Lay `w`'s secret rooms (see the class description). `def` is the level's: its relic (unless a
## master carries it, LevelGen.relic_carrier, or it waits behind a bone gate, LevelGen.relic_gated)
## goes in the first room, and its skeleton key in place of one of the last room's stars.
static func place(w: LevelGen, def: NextWorldDef) -> void:
	# A relic a master carries (relic_carrier) is in no room.
	var relic: StringName = def.relic if w.relic_carrier.x < 0 else &""
	w.relic_gated = relic != &"" and Rules.relic_gated_at(def.coord)
	var want: int = w.per_area(PER_K)
	# Rooms wholly in rock first; then rooms that only need rock under them (a hidden room's
	# rock is real rock, so another side may face open air).
	for enclosed: bool in [true, false]:
		for room: Vector2i in SIZES:
			while w.secrets.size() < want:
				var found: Array = spots(w, room, enclosed)
				if found.is_empty():
					break
				var choice: Array = w.pick(found)
				_carve(w, choice[0], choice[1], relic if w.secrets.is_empty() and not w.relic_gated else &"")
	# A relic with no room for a secret stands on a floor in the open instead.
	if relic != &"" and w.secrets.is_empty() and not w.relic_gated:
		w.put_random(LevelGen.Type.RELIC, w.ground_below, true, relic)
	# A skeleton key takes the place of one of the last room's stars (the one nearest its door).
	if def.skeleton:
		var placed: bool = false
		if not w.secrets.is_empty():
			var rewards: Array = w.secrets[w.secrets.size() - 1]["rewards"]
			for i: int in range(rewards.size() - 1, -1, -1):
				if rewards[i][1] == LevelGen.Type.COIN:
					rewards[i] = [rewards[i][0], LevelGen.Type.KEY, Keys.SKELETON]
					placed = true
					break
		if not placed:
			w.put_random(LevelGen.Type.KEY, w.ground_below, true, Keys.SKELETON)


## Every place in `w` a `room` (cells across and up) fits: [its rect, its entrance]. The room's
## floor is level with a floor spot beside it, through one cell of rock (the entrance, with rock
## over it), and the room is solid rock with rock under it (the level's edge counts as rock); when
## `enclosed`, with a cell of rock all round it too. Vaults are found the same way (Vaults).
static func spots(w: LevelGen, room: Vector2i, enclosed: bool) -> Array:
	var floors: Array[Vector2i] = w.free_floors()
	# Rock a room may be cut into: rock not kept (LevelGen.kept, marked once); the level's edge counts.
	var held: PackedByteArray = w.kept_mask()
	var size: Vector2i = w.size
	var rock: Callable = func(v: Vector2i) -> bool:
		if v.x < 0 or v.y < 0 or v.x >= size.x or v.y >= size.y:
			return true
		var i: int = v.x * size.y + v.y
		return w.types[i] == LevelGen.Type.GROUND and held[i] == 0
	var out: Array = []
	for o: Vector2i in floors:
		for side: int in SIDES:
			var fit: Array = room_beside(o, side, room)
			var r: Rect2i = fit[0]
			var door: Vector2i = fit[1]
			if r.position.x < 0 or r.position.y < 0 or r.end.x > size.x or r.end.y > size.y:
				continue
			if not (rock.call(door) and rock.call(door + Vector2i.UP)):
				continue
			var around: Rect2i = r.grow(1) if enclosed else Rect2i(r.position, r.size + Vector2i(0, 1))
			var solid: bool = true
			for x: int in range(around.position.x, around.end.x):
				for y: int in range(around.position.y, around.end.y):
					if x >= 0 and y >= 0 and x < size.x and y < size.y and (w.types[x * size.y + y] != LevelGen.Type.GROUND or held[x * size.y + y] == 1):
						solid = false
						break
				if not solid:
					break
			if solid:
				out.append([r, door])
	return out


## A room `inside` (cells across and up) beside floor spot `o`, on its `side` (-1 left, 1 right):
## [its rect, its door]. The door is the cell next to `o`, and the room's floor is level with it,
## running on from the door away from `o`.
static func room_beside(o: Vector2i, side: int, inside: Vector2i) -> Array:
	var door: Vector2i = o + Vector2i(side, 0)
	var x0: int = door.x + 1 if side > 0 else door.x - inside.x
	return [Rect2i(x0, o.y - inside.y + 1, inside.x, inside.y), door]


## Cut a secret room `r` into `w`, entered through `door`, holding `relic` (if not &"") and stars.
static func _carve(w: LevelGen, r: Rect2i, door: Vector2i, relic: StringName) -> void:
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
		var o: Vector2i = door + d
		if w.is_valid(o) and not r.has_point(o) and w._open(o) and w.ground_below(o):
			w.secret_steps[o] = true
			w.secret_steps[o + Vector2i.DOWN] = true
	var id: int = w.secrets.size()
	var room: Array[Vector2i] = []
	for x: int in range(r.position.x, r.end.x):
		for y: int in range(r.position.y, r.end.y):
			room.append(Vector2i(x, y))
	var floor_cells: Array[Vector2i] = []
	for x: int in range(r.position.x, r.end.x):
		floor_cells.append(Vector2i(x, r.end.y - 1))
	# The far end of the floor first: the reward waits at the back of the room.
	if door.x < r.position.x:
		floor_cells.reverse()
	var rewards: Array = []
	if relic != &"":
		rewards.append([floor_cells[0], LevelGen.Type.RELIC, relic])
	for c: Vector2i in floor_cells:
		if rewards.size() >= STARS + (1 if relic != &"" else 0):
			break
		if rewards.all(func(rw: Array) -> bool: return rw[0] != c):
			rewards.append([c, LevelGen.Type.COIN, null])
	w.secrets.append({"room": room, "entrance": [door], "rewards": rewards})
	for c: Vector2i in room + [door]:
		w.grounds.erase(c)
		w.objects.append(c)
		var cell: LevelGen.Cell = LevelGen.Cell.new(LevelGen.Type.CRACKED)
		cell.extra_info = id
		w.set_cell(c, cell)
