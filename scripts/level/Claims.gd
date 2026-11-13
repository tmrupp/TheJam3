class_name Claims
extends RefCounted
## The generator's one answer to "is this cell spoken for" (docs/CODE_REVIEW.md 2.3). What a cell
## holds is its type; what a cell is kept for is said in many places, each known to the pass that
## made it (the free list, a lift's track, a thing's room, a vault, a way out, a structure's cells,
## the start's way, a secret room's step, rock kept whole). The passes write what they keep in one
## map as they work (LevelGen.claim, LevelGen.spoken); this reads it, with what follows from the
## level as it stands (a thing's room, the ways out, air off the free list), so a pass that comes
## late asks here (LevelGen.claims: ask again after changing the level) and need not know them
## all. The barriers do (Barriers._solid); a new late pass should.
## - held(v): what holds cell `v` (ROOM, TRACK...), or &"" when nothing does.
## - is_free(v): open air nothing holds and nothing is laid in.
## - leant_on(v): a thing beside `v` may lean on its rock (a seed pod or vine grows from it, thorns
##   or a lantern stand on it): rock there is not to be opened.
## - faced(v): a thing that stays where it is laid is beside `v` and may face its air or be passed
##   through it (a seed pod spits into it, a door is walked through it, a cracked wall is broken
##   from it; of a ledge, only the air over it, where it is stood on): air there is not to be built
##   on. Floating pickups, thorns, star clusters and the nightmares free to move (LOOSE) aside.

## What may hold a cell, as held says it: a thing's room (Placeables.size), a lift's or rolling
## ladder's track and body (LevelGen.tracks), a vault's room, a way out, an archetype's structure
## (LevelGen.structures), the start's way (keep_clear), a secret room's
## step (secret_steps), rock kept whole (LevelGen.kept), and air that is no longer on the free list
## for a reason not written down (TAKEN: the second cell of a shrine, a crypt's or hall's insides).
const HELD_ROOM: StringName = &"room"
const HELD_TRACK: StringName = &"track"
const HELD_VAULT: StringName = &"vault"
const HELD_WAY_OUT: StringName = &"way out"
const HELD_STRUCTURE: StringName = &"structure"
const HELD_START_WAY: StringName = &"start's way"
const HELD_STEP: StringName = &"secret step"
const HELD_KEPT: StringName = &"kept whole"
const HELD_VAULT_WALL: StringName = &"vault wall"
const HELD_TAKEN: StringName = &"taken"

## The claims a pass writes as it works (LevelGen.claim), a bit each in LevelGen.spoken, and the
## name `held` gives each, the one that says most first.
const KEPT: int = 1
const START_WAY: int = 2
const STRUCTURE: int = 4
const STEP: int = 8
const VAULT_WALL: int = 16
const TRACK: int = 32
const VAULT: int = 64
const WRITTEN: Array = [[STEP, HELD_STEP], [START_WAY, HELD_START_WAY], [STRUCTURE, HELD_STRUCTURE], [VAULT, HELD_VAULT],
	[TRACK, HELD_TRACK], [KEPT, HELD_KEPT], [VAULT_WALL, HELD_VAULT_WALL]]

## The bits of `_beside`.
const LEANS: int = 1
const FACES: int = 2
## Things beside which air may be built on, besides the floating pickups: thorns and a star cluster
## face nothing, and a nightmare (Placeables' enemies) moves off its cell, all but those set in
## place (FIXED).
const LOOSE: Array[LevelGen.Type] = [LevelGen.Type.SPIKES, LevelGen.Type.CLUSTER]
const FIXED: Array[LevelGen.Type] = [LevelGen.Type.POD, LevelGen.Type.NEST, LevelGen.Type.CROSSBOW,
	LevelGen.Type.BREACH, LevelGen.Type.BOSS]

var _w: LevelGen
## The free cells (LevelGen.empties), a set.
var _free: Dictionary = {}
## Cell -> what holds it (see held).
var _held: Dictionary = {}
## Per cell (x * size.y + y): LEANS where a thing is beside it, and FACES too where that thing
## stays where it is laid.
var _beside: PackedByteArray = PackedByteArray()


func _init(w: LevelGen) -> void:
	_w = w
	_free = w.empty_set()
	# The later a holder is written here, the more it says: a way out over a thing's room.
	for v: Vector2i in w.objects:
		var room: Vector2i = Placeables.size(w.type_at(v))
		for dx: int in range(room.x):
			for dy: int in range(room.y):
				_held[v + Vector2i(dx, -dy)] = HELD_ROOM
	for e: Vector2i in w.exits.values():
		_held[e] = HELD_WAY_OUT
	_beside.resize(w.size.x * w.size.y)
	_beside.fill(0)
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			var t: LevelGen.Type = w.types[x * w.size.y + y] as LevelGen.Type
			if t == LevelGen.Type.EMPTY or t == LevelGen.Type.GROUND:
				continue
			var loose: bool = t in LOOSE or Placeables.has_flag(t, &"floats") or (Placeables.has_flag(t, &"enemy") and t not in FIXED)
			var bits: int = LEANS if loose or t == LevelGen.Type.PLATFORM else LEANS | FACES
			for d: Vector2i in w.neighbor_offsets:
				var n: Vector2i = Vector2i(x, y) + d
				if w.is_valid(n):
					_beside[n.x * w.size.y + n.y] |= bits | (FACES if t == LevelGen.Type.PLATFORM and d == Vector2i.UP else 0)


## What holds cell `v` (one of the names above), or &"" when nothing does: it is rock nothing
## keeps, a thing's own cell, or free air.
func held(v: Vector2i) -> StringName:
	if _held.has(v):
		return _held[v]
	var bits: int = _w.spoken.get(v, 0)
	if bits != 0:
		for claim: Array in WRITTEN:
			if bits & int(claim[0]) != 0:
				return claim[1]
	if not _w.is_valid(v):
		return &""
	# A shaft's and a keep's cells are kept whole by where they are, not written down (LevelGen.kept).
	if _w.kept(v):
		return HELD_KEPT
	if _w.type_at(v) == LevelGen.Type.EMPTY and not _free.has(v):
		return HELD_TAKEN
	return &""


## Whether `v` is open air that nothing holds and nothing is laid in.
func is_free(v: Vector2i) -> bool:
	return _w.is_valid(v) and _w.type_at(v) == LevelGen.Type.EMPTY and _free.has(v) and held(v) == &""


## Whether a thing beside `v` leans on it, so that its rock may not be opened.
func leant_on(v: Vector2i) -> bool:
	return _beside[v.x * _w.size.y + v.y] & LEANS != 0


## Whether a thing that stays where it is laid is beside `v`, so that its air may not be built on
## or laid in.
func faced(v: Vector2i) -> bool:
	return _beside[v.x * _w.size.y + v.y] & FACES != 0
