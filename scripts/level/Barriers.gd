class_name Barriers
extends RefCounted
## A barrier for each relic (docs/REVIEW_PLAN.md §3): a pocket carved into the rock off the level, as
## a secret room is, with a reward at its far end and in its mouth a barrier made for one relic move,
## a shape the player learns once and knows again in every level. Built from rock and thorns alone.
## - Wall climb, the one-wall shaft (SHAFT): a shaft going up, taller than a jump and a dash up, the
##   wall by the way in bare rock and the wall facing it thorned from bottom to top, so it cannot be
##   climbed by jumping from wall to wall. The reward waits at its head.
## - Double jump, the high sill (SILL): a ledge higher than a jump and a dash up reach, under the
##   pocket's roof, the face below it thorned, so nothing below it can be kicked off or climbed.
## - Levitate, the thorn throat (THROAT): a passage a row high with thorns along its floor and its
##   roof, longer than a dash or a blink carries, so a pogo or a jump only bounces into the roof.
## - Blink, the thorn curtain (CURTAIN): the mouth filled with thorns from floor to roof, a few cells
##   deep (thinner than a first-tier blink), with open room beyond.
## - Astral projection, the sealed cell (SEALED): a room closed in real rock on every side, the rock
##   thicker than a blink at its top tier carries; only a projection passes rock.
## Which move: the nearest level holding a relic within NEAR levels (Relics.at, by the rules alone,
## so the same in every run), else one dealt by the level seed. Laid in SHARE % of ordinary levels
## (by the level seed), none in a side world or a gate level, after everything else of the level's
## own (LevelGen._init), where solid rock fits the shape beside an open floor; where none fits, none
## is laid. It is never laid across a way on, a door, a shrine or a lantern: only into solid rock,
## and nothing already laid moves. What is laid is kept in LevelGen.barriers. Its mark (BarrierMark)
## stands on the floor at its mouth. Each one's measures are the consts below, to be set by playing
## each in the generation lab.

enum Kind { SHAFT, SILL, THROAT, CURTAIN, SEALED }

## The move each barrier is made for, by Kind.
const MOVE: Array[StringName] = [&"wall_climb", &"double_jump", &"levitate", &"blink", &"astral"]
## The share (%) of ordinary levels that try to take a barrier, dealt by the level seed (SHARE_DEAL;
## all of them for now: few levels have room for the shape their move asks, see _solid), and
## how far (levels, columns and rows added) a relic's level gives its move to the barriers round it.
const SHARE: int = 100
const SHARE_DEAL: int = 7300
const NEAR: int = 3
## Salt for the level seed dealing a move where no relic is near.
const MOVE_DEAL: int = 7301
## The shaft: its open width, and how many rows it rises above the way in's floor.
const SHAFT_WIDE: int = 2
const SHAFT_TALL: int = 5
## The sill: the pocket's open width (its far column below the sill thorned) and height, and how far
## above the floor the sill's top stands.
const SILL_WIDE: int = 2
const SILL_TALL: int = 5
const SILL_UP: int = 4
## The throat: its length, and the room at its far end.
const THROAT_LONG: int = 4
const END_ROOM: Vector2i = Vector2i(1, 2)
## The curtain: how many cells deep, and the room beyond.
const CURTAIN_DEEP: int = 2
const CURTAIN_ROOM: Vector2i = Vector2i(2, 2)
## The sealed cell: its room, and how many cells of rock all round it (thicker than a top-tier
## blink's 500 px, about four cells).
const SEALED_ROOM: Vector2i = Vector2i(2, 1)
const SEALED_WALL: int = 4


## Whether level `at` takes a barrier (SHARE of ordinary levels, by the level seed).
static func takes(at: Vector2i) -> bool:
	return Rules.level_seed(Rules.level_seed(at.x, at.y), SHARE_DEAL) % 100 < SHARE


## The move a barrier in level `at` is made for: the nearest relic's within NEAR levels (by the
## rules alone; the nearer first, then the lower column and row), else one dealt by the level seed.
static func move_for(at: Vector2i) -> StringName:
	for d: int in range(0, NEAR + 1):
		for dy: int in range(-d, d + 1):
			var rest: int = d - absi(dy)
			for dx: int in ([-rest, rest] if rest > 0 else [0]):
				var c: Vector2i = at + Vector2i(dx, dy)
				if Worlds.is_side(c) or (c.y != 0 and signi(c.y) != signi(at.y) and at.y != 0):
					continue
				var move: StringName = Relics.at(c)
				if move != &"":
					return move
	return MOVE[posmod(Rules.level_seed(Rules.level_seed(at.x, at.y), MOVE_DEAL), MOVE.size())]


## Lay level `w`'s barrier, if it takes one (see the class description): the shape for its move,
## carved where solid rock fits it beside an open floor, picked with one draw of the world RNG.
static func lay(w: LevelGen, def: NextWorldDef) -> void:
	if Worlds.is_side(def.coord) or def.gate != &"" or def.coord.y == 0 or not takes(def.coord):
		return
	var move: StringName = move_for(def.coord)
	var kind: int = MOVE.find(move)
	if kind < 0:
		return
	var fits: Array = _fits(w, kind)
	if fits.is_empty():
		return
	var choice: Dictionary = w.pick(fits)
	_carve(w, choice)
	w.barriers.append(choice)


## Every place barrier `kind` fits in `w`: each {"kind", "move", "mouth" (the floor cell beside its
## way in, where its mark stands), "side" (the side of it the pocket lies to), "open" (the cells
## carved open), "thorns", "reward"}. All of it,
## and a cell of rock all round, solid rock now, and none of it a cell something else keeps.
static func _fits(w: LevelGen, kind: int) -> Array:
	var out: Array = []
	for o: Vector2i in _mouths(w):
		for side: int in [-1, 1]:
			var shape: Dictionary = _shape(o, side, kind)
			if _solid(w, shape):
				shape["kind"] = kind
				shape["move"] = MOVE[kind]
				shape["mouth"] = o
				shape["side"] = side
				out.append(shape)
	return out


## Every open cell on a floor (rock under it) that holds nothing but decor, sorted: where a barrier's
## mouth may be, its mark standing there.
static func _mouths(w: LevelGen) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			var v: Vector2i = Vector2i(x, y)
			if not w.is_ground(v) and w.ground_below(v) and w.get_cell(v).type == LevelGen.Type.EMPTY:
				out.append(v)
	return out


## Barrier `kind` beside floor `o`, on its `side`: {"open", "thorns", "reward", "rock"} (the cells to
## carve open, the open cells to lay thorns in, the reward's cell, and the cells that must be solid
## rock for it to fit: all of these and those round them, and for a sealed cell its thick walls).
static func _shape(o: Vector2i, side: int, kind: int) -> Dictionary:
	var open: Array[Vector2i] = []
	var thorns: Array[Vector2i] = []
	var reward: Vector2i = o
	var s: Vector2i = Vector2i(side, 0)
	var door: Vector2i = o + s
	var wall: int = 1
	match kind:
		Kind.SHAFT:
			# The way in at the foot; the shaft beyond it, SHAFT_WIDE open, the far column thorned.
			open.append(door)
			for k: int in range(1, SHAFT_WIDE + 2):
				for up: int in range(0, SHAFT_TALL):
					var c: Vector2i = door + s * k + Vector2i(0, -up)
					open.append(c)
					if k == SHAFT_WIDE + 1:
						thorns.append(c)
			reward = door + s * 1 + Vector2i(0, -(SHAFT_TALL - 1))
		Kind.SILL:
			open.append(door)
			for k: int in range(1, SILL_WIDE + 1):
				for up: int in range(0, SILL_TALL):
					var c: Vector2i = door + s * k + Vector2i(0, -up)
					# The sill: rock in the far column, SILL_UP above the floor.
					if k == SILL_WIDE and up == SILL_UP - 1:
						continue
					open.append(c)
					if k == SILL_WIDE and up < SILL_UP - 1:
						thorns.append(c)
			reward = door + s * SILL_WIDE + Vector2i(0, -SILL_UP)
		Kind.THROAT:
			# A row high, thorns under and over it, from the way in to the room at its far end.
			for k: int in range(0, THROAT_LONG + 1):
				var c: Vector2i = door + s * k
				open.append(c)
				if k >= 1:
					open.append(c + Vector2i.UP)
					open.append(c + Vector2i.DOWN)
					thorns.append(c + Vector2i.UP)
					thorns.append(c + Vector2i.DOWN)
			for k: int in range(1, END_ROOM.x + 1):
				for up: int in range(0, END_ROOM.y):
					open.append(door + s * (THROAT_LONG + k) + Vector2i(0, -up))
			reward = door + s * (THROAT_LONG + END_ROOM.x)
		Kind.CURTAIN:
			# The mouth two rows high, filled with thorns CURTAIN_DEEP deep; the room beyond.
			for k: int in range(0, CURTAIN_DEEP + CURTAIN_ROOM.x + 1):
				for up: int in range(0, 2 if k <= CURTAIN_DEEP else CURTAIN_ROOM.y):
					var c: Vector2i = door + s * k + Vector2i(0, -up)
					open.append(c)
					if k >= 1 and k <= CURTAIN_DEEP:
						thorns.append(c)
			reward = door + s * (CURTAIN_DEEP + CURTAIN_ROOM.x)
		Kind.SEALED:
			# No way in: a room SEALED_WALL cells of rock from the floor, walled as thick all round.
			wall = SEALED_WALL
			var start: Vector2i = o + s * (SEALED_WALL + 1)
			for k: int in range(0, SEALED_ROOM.x):
				for up: int in range(0, SEALED_ROOM.y):
					open.append(start + s * k + Vector2i(0, -up))
			reward = start + s * (SEALED_ROOM.x - 1)
	var rock: Dictionary = {}
	for c: Vector2i in open:
		for dx: int in range(-wall, wall + 1):
			for dy: int in range(-wall, wall + 1):
				var n: Vector2i = c + Vector2i(dx, dy)
				# The floor beside the way in, and the air over it, are the level's own.
				if (n - o).x * side <= 0:
					continue
				rock[n] = true
	return {"open": open, "thorns": thorns, "reward": reward, "rock": rock.keys()}


## Whether `shape` fits: every cell of it (its pocket and the rock round it) rock or air holding
## nothing (past the level's edge counts as rock, as for a secret room), none of them kept by
## something else (LevelGen.kept, secret rooms' steps) or a way out, and every cell it opens inside
## the level, off its border. The garden's rock is too thin for most shapes to be cut from solid rock
## alone (a block four or five cells across and seven high beside a floor is rare), so where its
## walls meet empty air they are built of rock there (_carve): nothing already laid moves.
static func _solid(w: LevelGen, shape: Dictionary) -> bool:
	for c: Vector2i in shape["open"]:
		if c.x <= 0 or c.y <= 0 or c.x >= w.size.x - 1 or c.y >= w.size.y - 1:
			return false
	for c: Vector2i in shape["rock"]:
		if not w.is_valid(c):
			continue
		if w.kept(c) or w.secret_steps.has(c) or w.exits.values().has(c):
			return false
		if not w.is_ground(c) and w.get_cell(c).type != LevelGen.Type.EMPTY:
			return false
	return true


## Carve `shape`: the rock round it made whole (empty air there built of rock), its cells opened,
## thorns laid, the reward (a star cluster) at its far end, and its mark at its mouth.
static func _carve(w: LevelGen, shape: Dictionary) -> void:
	var open: Array = shape["open"]
	for c: Vector2i in shape["rock"]:
		if w.is_valid(c) and not open.has(c) and not w.is_ground(c):
			w._to_rock(c)
	for c: Vector2i in open:
		w._to_open(c)
	for c: Vector2i in shape["thorns"]:
		w.put(c, LevelGen.Type.SPIKES)
	w.put(shape["reward"], LevelGen.Type.CLUSTER)
	w.put(shape["mouth"], LevelGen.Type.BARRIER_MARK, {"move": shape["move"], "side": shape["side"]})
