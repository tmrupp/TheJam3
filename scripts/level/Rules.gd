class_name Rules
extends RefCounted
## The rules that hold across a run: every level's seed, what things cost and are worth by depth,
## how key colours are dealt by rarity, what a level holds by its seed (skeleton keys, bone vaults,
## gated relics, crossings left to relics), how big a level is, and which place is where. Plain
## static functions of a place or a depth, with no scene: the level generator calls them on its
## worker thread, and unit_test checks them on their own.

## Keys and doors come in this many colours; a key opens doors of its own colour.
const KEY_COLOR_COUNT: int = 4
## How common each key colour is, in order of rarity: sun (about 62 %), ember (24 %), moss (10 %),
## then plum (about one in 30). Keys, corridor doors, side-door locks and padlocks are all dealt by these
## weights (see rarity_color), so a common key opens a lot and a rare one seldom; vaults (see
## LevelGen.place_vaults) are the exception, and pay out by their lock's rarity.
const KEY_RARITY: Array[int] = [18, 7, 3, 1]
## Share (%) of levels from depth 1 whose secret room holds a skeleton key (see KeyRing).
const SKELETON_CHANCE: int = 30
## Bone gates, which only a skeleton key opens (LevelGen.place_bone_vault, deal_colors): the share (%)
## of levels from depth 1 with a bone vault holding rich loot (BONE_LOOT); the share of relic levels
## whose relic waits behind a bone gate instead of in a secret room; and from SKELETON_DOOR_DEPTH,
## the share of corridor doors on the way that are bone gates.
const BONE_VAULT_CHANCE: int = 25
## Deeper down, some crossings are left to the relic moves (double jump, blink, levitate, wall
## climb): from RELIC_NEED_FROM, relic_need(depth) % of a level's chasms and sky gaps have no bell
## or vane (Chasms.relax_crossings), and hyperspace that drops that deep may leave one stretch
## unbridged (Hyperspace._relic_gap). It rises RELIC_NEED_STEP a level, up to RELIC_NEED_MAX.
const RELIC_NEED_FROM: int = 6
const RELIC_NEED_STEP: int = 10
const RELIC_NEED_MAX: int = 60
const RELIC_GATE_CHANCE: int = 50
const SKELETON_DOOR_DEPTH: int = 6
const SKELETON_DOOR_CHANCE: int = 15


## Deterministic per-level seed from the run seed and depth (independent of engine hashing).
static func level_seed (run_seed: int, depth: int) -> int:
	var h: int = (run_seed * 73856093) ^ (depth * 19349663) ^ 0x5bd1e995
	h = (h ^ (h >> 15)) * 0x2c1b3c6d
	h = (h ^ (h >> 12)) * 0x297a2d39
	h = h ^ (h >> 15)
	return h & 0x7fffffff

## Stars to open a level's deeper exit.
static func deeper_price (depth: int) -> int:
	return roundi(16.0 * pow(1.4, depth))

## Stars to lift a toll gate (one shutting a gondola's station, CragsArchetype): TOLL_SHARE of the
## way on's price there.
const TOLL_SHARE: float = 0.3

static func toll_price (depth: int) -> int:
	return maxi(1, roundi(float(deeper_price(depth)) * TOLL_SHARE))

## Stars a level's star cluster is worth: about 10 at the surface, more deeper (stars per level
## grow too).
static func cluster_value (depth: int) -> int:
	return roundi(10.0 * pow(1.25, maxi(depth, 0)))

## Whether a secret room in the level at `at` holds a skeleton key: SKELETON_CHANCE % of levels
## from depth 1, dealt by the level seed.
static func skeleton_at (at: Vector2i) -> bool:
	if absi(at.y) < 1:
		return false
	return level_seed(level_seed(at.x, at.y), 4711) % 100 < SKELETON_CHANCE

## Minimum distance in cells between a level's way back and its deeper exit.
static func exit_distance (depth: int) -> int:
	return clampi(24 + 4 * depth, 24, 96)

## The share (%) of crossings left to the relic moves `depth` deep (see RELIC_NEED_FROM).
static func relic_need (depth: int) -> int:
	if depth < RELIC_NEED_FROM:
		return 0
	return mini(RELIC_NEED_STEP * (depth - RELIC_NEED_FROM + 1), RELIC_NEED_MAX)

## Whether level `at` has a bone vault of loot (BONE_VAULT_CHANCE % of levels from depth 1), and
## whether its relic, if it has one, waits behind a bone gate (RELIC_GATE_CHANCE %); both dealt by
## the level seed.
static func bone_vault_at (at: Vector2i) -> bool:
	return absi(at.y) >= 1 and level_seed(level_seed(at.x, at.y), 4811) % 100 < BONE_VAULT_CHANCE

static func relic_gated_at (at: Vector2i) -> bool:
	return level_seed(level_seed(at.x, at.y), 4911) % 100 < RELIC_GATE_CHANCE

## The key colour that locks a level's left or right exit, dealt by the level seed.
static func lateral_lock (at: Vector2i, which: int) -> int:
	return rarity_color(level_seed(level_seed(at.x, at.y), 500 + which))

## The key colour a draw of `roll` (any int) deals, by KEY_RARITY: common colours come up often,
## rare ones seldom.
static func rarity_color (roll: int) -> int:
	var total: int = 0
	for w: int in KEY_RARITY:
		total += w
	var r: int = posmod(roll, total)
	for c: int in range(KEY_RARITY.size()):
		r -= KEY_RARITY[c]
		if r < 0:
			return c
	return 0

## Cells across and down for a level: small near the surface, growing with depth.
static func level_size (depth: int) -> Vector2i:
	# Half the old growth (6 and 5 cells a depth, capped at 80 x 72): big levels were slow and long.
	return Vector2i(clampi(36 + 3 * depth, 36, 60), clampi(30 + (5 * depth) / 2, 30, 48))

## Stars to ink a level's whole map at its ink well.
static func map_price (depth: int) -> int:
	return roundi(8.0 * pow(1.3, depth))

## How a level is named on screen and when sharing it.
static func where (at: Vector2i) -> String:
	return def_for(at).title()

## A place as numbers, for printing without words (RisoMarks.place_marks): its world (the seed),
## its row (negative above the start, printed as a height with the depth mark turned up; a side
## world's is that of the level it hangs off) and its side world's kind (-1 for a level).
static func place_numbers (at: Vector2i) -> Vector3i:
	if Worlds.is_side(at):
		return Vector3i(at.x, Worlds.origin_of(at).y, Worlds.kind_at(at))
	return Vector3i(at.x, at.y, -1)

## The definition of the place at `at`: a level, or a side world (see Worlds).
static func def_for (at: Vector2i) -> NextWorldDef:
	return Worlds.def_for(at)
