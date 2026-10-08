class_name RunState
extends RefCounted
## A run, apart from the scene: where it started and how deep it has been, every visited place's
## record (LevelRecord), the lantern the wizard comes back to, the ghost holding the stars of the
## last death, the relics found and pointed to, and the rift linking two levels. Saving and loading
## it (with the wizard's own state, see Player.to_save) lives here too. MapInfo keeps one (`run`)
## and does what happens in the scene.

## Where the run is saved. Tests point this elsewhere so they never touch a player's save.
static var save_path: String = "user://deeper_run.save"
const SAVE_VERSION: int = 3

## The seed this run started on (coord.x drifts as the player moves sideways), the furthest from
## the start it has been (in rows, either way), and the row where it got that far (negative above
## the start).
var run_seed: int = 0
var deepest: int = 0
var furthest_row: int = 0
## What changed in each visited place (coord -> LevelRecord).
var records: Dictionary = {}
## The last lantern lit, which may be in another level.
var respawn_coord: Vector2i = Vector2i.ZERO
var respawn_cell: Vector2i = Vector2i.ZERO
## Vulnerable means no lit lantern remains to absorb the next death. A lantern burns out after
## protecting one death; only lighting an unspent lantern restores protection.
var vulnerable: bool = false
## The ghost left where the wizard last died, holding the stars they carried.
var has_ghost: bool = false
var ghost_coord: Vector2i = Vector2i.ZERO
var ghost_pos: Vector2 = Vector2.ZERO
var ghost_stars: int = 0
## The run's cross-world rift link (Rift tier III): up to two ends, each [coord, position].
var rift_link: Array = []
## The levels whose relic has been taken, and the levels an ink well has pointed to (coord -> the
## move the relic holds), shown on the worlds map.
var relics_found: Dictionary = {}
var relic_hints: Dictionary = {}
## The bosses slain this run (name -> true; see Bosses), and the relics they left that wait still
## (name -> [the place, the position, the move]).
var bosses: Dictionary = {}
var boss_relics: Dictionary = {}


## A fresh run from depth 0 of `seed_value`: no records, no ghost, protected.
func start(seed_value: int) -> void:
	run_seed = seed_value
	deepest = 0
	furthest_row = 0
	records.clear()
	rift_link.clear()
	relics_found.clear()
	relic_hints.clear()
	bosses.clear()
	boss_relics.clear()
	vulnerable = false
	clear_ghost()


## The record of the place at `at`, made when first asked for.
func record(at: Vector2i) -> LevelRecord:
	if not records.has(at):
		records[at] = LevelRecord.new()
	return records[at]


## The record of `at` if it has been visited, else null (for looking without making one).
func visited(at: Vector2i) -> LevelRecord:
	return records.get(at)


## The furthest from the start reached, counting level `at` (side worlds count as the level they
## hang off).
func reached(at: Vector2i) -> void:
	var row: int = Worlds.origin_of(at).y if Worlds.is_side(at) else at.y
	if absi(row) > deepest:
		deepest = absi(row)
		furthest_row = row


## The lantern at `cell` in `at` burned out: it protects no more.
func spend_lantern(at: Vector2i, cell: Vector2i) -> void:
	record(at).spent_lanterns[cell] = true


## Death brings every slain enemy back.
func revive_slain() -> void:
	for c: Vector2i in records:
		(records[c] as LevelRecord).slain = {}


## The wizard died at `pos` in `at` carrying `stars`: they drop into the ghost there.
func leave_ghost(at: Vector2i, pos: Vector2, stars: int) -> void:
	has_ghost = true
	ghost_coord = at
	ghost_pos = pos
	ghost_stars = stars


func clear_ghost() -> void:
	has_ghost = false
	ghost_stars = 0


## A relic was taken in level `at`.
func relic_taken(at: Vector2i) -> void:
	relics_found[at] = true
	relic_hints.erase(at)


## The relic a shrine in `at` would point to: the nearest one neither found nor already marked, or
## null.
func next_relic(at: Vector2i) -> Variant:
	return Relics.nearest(at, relics_found.merged(relic_hints))


## A shrine's hint from `at`: mark that relic on the worlds map. Returns its level, or null.
func hint_relic(at: Vector2i) -> Variant:
	var found: Variant = next_relic(at)
	if found != null:
		relic_hints[found] = Relics.at(found)
	return found


# ------------------------------------------------------------------ saving

## Everything saved: the run's own state, `coord` (the place being played) and the wizard's
## (`player`, see Player.to_save).
func to_save(coord: Vector2i, player: Dictionary) -> Dictionary:
	var recs: Dictionary = {}
	for c: Vector2i in records:
		recs[c] = (records[c] as LevelRecord).to_dict()
	var data: Dictionary = {
		"version": SAVE_VERSION, "run_seed": run_seed, "deepest": deepest, "furthest_row": furthest_row, "coord": coord, "records": recs,
		"respawn_coord": respawn_coord, "respawn_cell": respawn_cell,
		"vulnerable": vulnerable,
		"has_ghost": has_ghost, "ghost_coord": ghost_coord, "ghost_pos": ghost_pos, "ghost_stars": ghost_stars,
		"debug": MapInfo.debug, "rift_link": rift_link,
		"relics_found": relics_found, "relic_hints": relic_hints,
		"bosses": bosses, "boss_relics": boss_relics,
	}
	data.merge(player)
	return data


## Take up the run saved in `data` (see read_save).
func from_save(data: Dictionary) -> void:
	MapInfo.debug = bool(data.get("debug", false))
	run_seed = int(data["run_seed"])
	deepest = int(data["deepest"])
	furthest_row = int(data.get("furthest_row", deepest))
	records = {}
	var recs: Dictionary = data["records"]
	for c: Vector2i in recs:
		records[c] = LevelRecord.from_dict(recs[c])
	rift_link = data.get("rift_link", [])
	relics_found = data.get("relics_found", {})
	relic_hints = data.get("relic_hints", {})
	bosses = data.get("bosses", {})
	boss_relics = data.get("boss_relics", {})
	respawn_coord = data["respawn_coord"]
	respawn_cell = data["respawn_cell"]
	vulnerable = bool(data["vulnerable"])
	# Version-1 saves from the old recovery system remain usable: an unprotected save's last
	# lantern is spent, so resuming cannot turn it into another free life.
	if vulnerable:
		spend_lantern(respawn_coord, respawn_cell)
	has_ghost = bool(data["has_ghost"])
	ghost_coord = data["ghost_coord"]
	ghost_pos = data["ghost_pos"]
	ghost_stars = int(data["ghost_stars"])


static func write_save(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_var(data)


## The saved run, or {} when there is none (or it is from a version too old to read). A version-2
## save is brought up to date (from_v2).
static func read_save() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = file.get_var()
	if not (data is Dictionary):
		return {}
	var version: int = int((data as Dictionary).get("version", 0))
	if version == 2:
		return from_v2(data)
	if version != SAVE_VERSION:
		return {}
	return data


## A version-2 save brought up to version 3: side worlds moved to make room for the rows above the
## start (Worlds.from_v2), so every place it names (the records, where the wizard is, the lantern,
## the ghost, the rift's ends) moves with them. Levels keep their places.
static func from_v2(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	var recs: Dictionary = {}
	var old: Dictionary = data["records"]
	for c: Vector2i in old:
		recs[Worlds.from_v2(c)] = old[c]
	out["records"] = recs
	for key: String in ["coord", "respawn_coord", "ghost_coord"]:
		if out.has(key):
			out[key] = Worlds.from_v2(out[key])
	var link: Array = []
	for end: Array in (data.get("rift_link", []) as Array):
		link.append([Worlds.from_v2(end[0]), end[1]])
	out["rift_link"] = link
	out["furthest_row"] = int(data.get("deepest", 0))
	out["version"] = SAVE_VERSION
	return out


static func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
