class_name Vaults
extends RefCounted
## A level's vaults: small rooms sealed in the rock behind a locked corridor door, at floor height
## beside a floor (found as secret rooms are, Secrets.spots), their loot in plain sight through the
## bars. A vault's lock is dealt evenly among the key colours, unlike every other lock (see
## Rules.KEY_RARITY), and the rarer its colour the better what it holds (LOOT): a rare key seldom
## opens anything, but what it opens is worth having. PER_K per 1000 cells, as many as fit; placed
## last of all (LevelGen.populate_level), so the rest of the level lands where it always has. Each
## is kept in LevelGen.vaults as {"room": cells, "door": cell, "color": key colour}, the rock round
## them in LevelGen.vault_walls. Then the bone vault (place_bone).

## How many vaults a level holds, per 1000 cells (LevelGen.per_area).
const PER_K: float = 0.5
## Room sizes (cells across and up) tried in turn, biggest first.
## Low rooms (one cell high, like the corridors doors stand in) fit where tall ones don't.
const SIZES: Array[Vector2i] = [Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2), Vector2i(3, 1), Vector2i(2, 1)]
## What a vault holds, by its lock's colour in order of rarity, each thing as [type, extra info]:
## a half-sized star cluster (sun), a star cluster (ember), a cluster and a half (moss), a star
## cluster and a skeleton key (plum). A cluster's extra info is its share of a full cluster's
## worth (see LevelLoader.place_cell). Laid from the back of the room's floor, then along its upper
## row; two things at most, so it fits the smallest room.
const LOOT: Array = [
	[[LevelGen.Type.CLUSTER, 0.5]],
	[[LevelGen.Type.CLUSTER, 1.0]],
	[[LevelGen.Type.CLUSTER, 1.5]],
	[[LevelGen.Type.CLUSTER, 1.0], [LevelGen.Type.KEY, Keys.SKELETON]],
]
## An ember vault also holds a moss key (the next colour up) this share (%) of the time, dealt by
## the level seed and the vault's door, never the world RNG.
const KEY_CHANCE: int = 40
const KEY_DEAL: int = Salts.VAULTS_KEY * Salts.STRIDE
## A bone vault's loot, a step above a plum vault's: a hoard worth three star clusters.
const BONE_LOOT: Array = [[LevelGen.Type.CLUSTER, 3.0]]
## Room sizes for a bone vault: two high, so a relic stands in it.
const BONE_SIZES: Array[Vector2i] = [Vector2i(3, 2), Vector2i(2, 2)]
## A bone strongbox's inside, where no rock is thick enough (see _strongbox_spots).
const BONE_STRONGBOX: Vector2i = Vector2i(2, 2)
## A strongbox: a vault built out of open air, `inside` (cells across and up; STRONGBOX for a
## keyed vault) inside, its door beside a floor spot, walled, roofed and floored in rock (its floor
## may be rock already, or it hangs off the floor's edge, as a ledge does). Only where every cell
## it takes is free, STRONGBOX_HEADROOM rows of open air lie over it and a row under any floor it
## builds (so it never shuts a way, it is only gone round), and no chasm or gap is near.
const STRONGBOX: Vector2i = Vector2i(2, 1)
const STRONGBOX_HEADROOM: int = 2


## Lay `w`'s vaults (see the class description), then its bone vault. `def` is the level's.
static func place(w: LevelGen, def: NextWorldDef) -> void:
	var want: int = w.per_area(PER_K)
	for room: Vector2i in SIZES:
		while w.vaults.size() < want:
			var spots: Array = _spots(w, room)
			if spots.is_empty():
				break
			# The spot is drawn first, then the lock's colour.
			var choice: Array = w.pick(spots)
			_build(w, choice, w.rng.randi_range(0, Rules.KEY_COLOR_COUNT - 1))
	# No rock thick enough to carve one into (a sky level's islands are thin): build one, a
	# strongbox of rock on a floor.
	if w.vaults.is_empty():
		var choice: Array = _pick_strongbox(w, _strongbox_spots(w, STRONGBOX))
		if not choice.is_empty():
			_build(w, choice, w.rng.randi_range(0, Rules.KEY_COLOR_COUNT - 1))
	place_bone(w, def)


## Everything the vault of `w` behind `door`, locked in `color`, holds (see LOOT; a bone vault's,
## locked by a skeleton key, BONE_LOOT or the relic, LevelGen.bone_relic).
static func loot(w: LevelGen, color: int, door: Vector2i) -> Array:
	if color == Keys.SKELETON:
		return [[LevelGen.Type.RELIC, w.bone_relic]] if w.bone_relic != &"" else BONE_LOOT.duplicate()
	var out: Array = (LOOT[color] as Array).duplicate()
	if color == 1 and Rules.level_seed(w.seed_for_colors, KEY_DEAL + door.x * 1000 + door.y) % 100 < KEY_CHANCE:
		out.append([LevelGen.Type.KEY, 2])
	return out


## A bone vault: a vault behind a bone gate, which only a skeleton key opens. In BONE_VAULT_CHANCE
## % of levels from depth 1 (Rules.bone_vault_at) it holds BONE_LOOT; in a level whose relic is
## gated (LevelGen.relic_gated) it holds the relic instead. Placed after the other vaults. A gated
## relic with no room for a bone vault goes back to the level's first secret room (in place of a
## star), or, with no secret room either, stands on a floor in the open.
static func place_bone(w: LevelGen, def: NextWorldDef) -> void:
	if not w.relic_gated and not Rules.bone_vault_at(def.coord):
		return
	w.bone_relic = def.relic if w.relic_gated else &""
	for room: Vector2i in BONE_SIZES:
		var spots: Array = _spots(w, room)
		if not spots.is_empty():
			_build(w, w.pick(spots), Keys.SKELETON)
			return
	# No rock to carve one into (a cemetery's terraces, the sky's islands): build a strongbox,
	# two high so a relic stands in it.
	var built: Array = _pick_strongbox(w, _strongbox_spots(w, BONE_STRONGBOX))
	if not built.is_empty():
		_build(w, built, Keys.SKELETON)
		return
	if not w.relic_gated:
		return
	if not w.secrets.is_empty():
		var rewards: Array = w.secrets[0]["rewards"]
		rewards[0] = [rewards[0][0], LevelGen.Type.RELIC, def.relic]
	else:
		w.put_random(LevelGen.Type.RELIC, w.ground_below, true, def.relic)
	w.relic_gated = false


## Every place in `w` a vault `room` (cells across and up) fits, found as secret rooms are
## (enclosed), but walled in the level's own rock, never its edge, and clear of where the secret
## rooms are walked into (LevelGen.secret_steps): [its rect, its door].
static func _spots(w: LevelGen, room: Vector2i) -> Array:
	return Secrets.spots(w, room, true).filter(func(spot: Array) -> bool: return Rect2i(Vector2i.ZERO, w.size).encloses((spot[0] as Rect2i).grow(1)) \
			and not w.secret_steps.keys().any(func(c: Vector2i) -> bool: return (spot[0] as Rect2i).grow(1).has_point(c)))


## Build the vault `choice` ([its rect, its door] and, for a strongbox, the cells to turn to rock)
## into `w`, locked in `color`.
static func _build(w: LevelGen, choice: Array, color: int) -> void:
	if choice.size() > 2:
		for c: Vector2i in choice[2]:
			w._to_rock(c)
	_carve(w, choice[0], choice[1], color)


## Every place in `w` a strongbox with `inside` (cells across and up) inside could be built (see
## STRONGBOX): [its room, its door, the cells to turn to rock].
static func _strongbox_spots(w: LevelGen, inside: Vector2i) -> Array:
	var free: Dictionary = w.empty_set()
	var floors: Array[Vector2i] = w.free_floors()
	var out: Array = []
	for o: Vector2i in floors:
		for side: int in Secrets.SIDES:
			var fit: Array = Secrets.room_beside(o, side, inside)
			var r: Rect2i = fit[0]
			var door: Vector2i = fit[1]
			# The room with a wall either side (the door is one of them) and a roof.
			var box: Rect2i = r.grow_individual(1, 1, 1, 0)
			if not Rect2i(Vector2i(1, 1), w.size - Vector2i(2, 2)).encloses(box.grow_individual(0, STRONGBOX_HEADROOM, 0, 2)):
				continue
			var ok: bool = true
			var walls: Array[Vector2i] = []
			for x: int in range(box.position.x, box.end.x):
				# Rock to stand on under all of it (built where there is none, with air under it);
				# open air over it.
				var under: Vector2i = Vector2i(x, box.end.y)
				if not w.is_ground(under):
					ok = ok and _buildable(w, under, free) and not w.keep_clear.has(under) and not Chasms.near(w, under) \
							and w._open(under + Vector2i.DOWN) and not w.keep_clear.has(under + Vector2i.DOWN)
					walls.append(under)
				for h: int in range(1, STRONGBOX_HEADROOM + 1):
					ok = ok and w._open(Vector2i(x, box.position.y - h)) and not w.keep_clear.has(Vector2i(x, box.position.y - h))
				for y: int in range(box.position.y, box.end.y):
					var c: Vector2i = Vector2i(x, y)
					ok = ok and _buildable(w, c, free) and not w.keep_clear.has(c) and not Chasms.near(w, c)
					if c != door and not r.has_point(c):
						walls.append(c)
				if not ok:
					break
			if ok:
				out.append([r, door, walls])
	return out


## One of the strongbox `spots`, drawn, that shuts no open air in (see _shuts_in), or [] if none
## does. Another is drawn only when the one drawn would, so a level where it never would is laid
## out as before.
static func _pick_strongbox(w: LevelGen, spots: Array) -> Array:
	var left: Array = spots.duplicate()
	while not left.is_empty():
		var choice: Array = w.pick(left)
		if not _shuts_in(w, choice[2]):
			return choice
		left.erase(choice)
	return []


## Whether turning `walls` to rock would cut open air off from the rest: the open cells beside
## them (the air under a floor it builds can be a pocket whose only way out was through it) must
## all still reach one another, with every switch gate shut (a switch must stay reachable with its
## gate shut, see LevelGen.place_switch_gates).
static func _shuts_in(w: LevelGen, walls: Array) -> bool:
	var wall: Dictionary = {}
	for c: Vector2i in walls:
		wall[c] = true
	var open: Callable = func(v: Vector2i) -> bool: return w._open(v) and w.type_at(v) != LevelGen.Type.SWITCH_GATE and not wall.has(v)
	var beside: Dictionary = {}
	for c: Vector2i in walls:
		for d: Vector2i in w.neighbor_offsets:
			if open.call(c + d):
				beside[c + d] = true
	if beside.is_empty():
		return false
	var first: Vector2i = beside.keys()[0]
	var seen: Dictionary = {first: true}
	var stack: Array[Vector2i] = [first]
	var found: int = 1
	while not stack.is_empty() and found < beside.size():
		var v: Vector2i = stack.pop_back()
		for d: Vector2i in w.neighbor_offsets:
			var n: Vector2i = v + d
			if not seen.has(n) and open.call(n):
				seen[n] = true
				stack.append(n)
				if beside.has(n):
					found += 1
	return found < beside.size()


## Whether a strongbox may take cell `c` of `w`: open air with nothing in it, or only a star or a
## piece of a ledge that stays put (which it takes the place of). `free` holds the open cells.
static func _buildable(w: LevelGen, c: Vector2i, free: Dictionary) -> bool:
	if w.kept(c) or w.secret_steps.has(c):
		return false
	return (free.has(c) and w.type_at(c) == LevelGen.Type.EMPTY) or w.type_at(c) in [LevelGen.Type.COIN, LevelGen.Type.PLATFORM]


## Cut vault `r` into `w`, behind a door at `door` locked in `color`, its loot in it.
static func _carve(w: LevelGen, r: Rect2i, door: Vector2i, color: int) -> void:
	for x: int in range(r.position.x - 1, r.end.x + 1):
		for y: int in range(r.position.y - 1, r.end.y + 1):
			if w.is_ground(Vector2i(x, y)):
				w.vault_walls[Vector2i(x, y)] = true
	w.vault_walls.erase(door)
	var room: Array[Vector2i] = []
	for x: int in range(r.position.x, r.end.x):
		for y: int in range(r.position.y, r.end.y):
			room.append(Vector2i(x, y))
			w._to_open(Vector2i(x, y))
	# A strongbox's door may stand where a star was: it is listed once.
	w.objects.erase(door)
	w.put(door, LevelGen.Type.DOOR, color)
	# The back of the floor first, then the row over it: the loot waits at the back of the room.
	var slots: Array[Vector2i] = []
	for y: int in range(r.end.y - 1, r.position.y - 1, -1):
		var row: Array[Vector2i] = []
		for x: int in range(r.position.x, r.end.x):
			row.append(Vector2i(x, y))
		if door.x < r.position.x:
			row.reverse()
		slots.append_array(row)
	var held: Array = loot(w, color, door)
	for i: int in range(mini(held.size(), slots.size())):
		var at: Vector2i = slots[i]
		w.put(at, held[i][0], held[i][1])
	w.vaults.append({"room": room, "door": door, "color": color})
