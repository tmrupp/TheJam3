class_name Known
extends RefCounted
## What the map knows of a world, kept from run to run (docs/REVIEW_PLAN.md §4): knowledge is the
## progression between runs. Kept in a file of its own (path, one per band layout as the saves
## are), apart from the run's save and kept when that is deleted (a death with no lantern left, a
## win).
## - By place, as a level is the same in every run: the cells seen of it and whether it was inked
##   whole, the ways taken out of it, whether a relic was seen or taken there (it lies there again),
##   and a stamp of its layout (stamp): a kept place whose stamp no longer matches its layout is
##   dropped (seen_for), so a meant change to the layouts cannot leave a wrong map behind. Ordinary
##   levels only (not the tutorial, the side worlds or hyperspace).
## - By run seed, as these change with it: the column each garden or band boss was met in, and the
##   ways shrines told to it.
## A run notes what it knows here (note, from MapInfo as it saves, ends or is won; never a debug
## run), and a new run on a seed starts from it (teach): its relics and bosses' columns marked, and
## each level's map with the cells seen before as it is laid out again (MapInfo, seen_for). At most
## MOST places, the most lately visited. The start menu's settings can forget it all (forget).

## Where it is kept: tests point it elsewhere, as they do the save (TestKit.boot).
static var path: String = "user://known.save" if Bands.current == Bands.DEFAULT else "user://known_%s.save" % Bands.current
## The most places kept: those most lately visited.
const MOST: int = 300

static var _data: Dictionary = {}
static var _from: String = ""


## The kept knowledge ({"places": by place, "seeds": by run seed, "next": the visit count}), read
## from `path` the first time it is asked for.
static func kept() -> Dictionary:
	if _from != path:
		_from = path
		_data = {"places": {}, "seeds": {}, "next": 0}
		if FileAccess.file_exists(path):
			var file: FileAccess = FileAccess.open(path, FileAccess.READ)
			var read: Variant = file.get_var() if file != null else null
			if read is Dictionary and (read as Dictionary).has("places"):
				_data = read
	return _data


static func _write() -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_var(kept())


## Forget everything kept (the start menu's settings).
static func forget() -> void:
	_from = path
	_data = {"places": {}, "seeds": {}, "next": 0}
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Whether place `c` is known from a run before.
static func has(c: Vector2i) -> bool:
	return (kept()["places"] as Dictionary).has(c)


## Every place known.
static func places() -> Array:
	return (kept()["places"] as Dictionary).keys()


## A stamp of level `w`'s layout: its size and which cells are rock, hashed.
static func stamp(w: LevelGen) -> int:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(w.size.x * w.size.y)
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			bytes[y * w.size.x + x] = 1 if w.is_ground(Vector2i(x, y)) else 0
	return hash(bytes) ^ (w.size.x * 7919 + w.size.y)


## The cells seen of place `c` in runs before, laid out as `w` (a byte a cell, all seen if it was
## inked whole), or empty: nothing kept, or kept of a layout that is no longer its own, which is
## then dropped.
static func seen_for(c: Vector2i, w: LevelGen) -> PackedByteArray:
	var place: Dictionary = (kept()["places"] as Dictionary).get(c, {})
	if place.is_empty() or w == null:
		return PackedByteArray()
	if int(place.get("stamp", 0)) != stamp(w):
		(kept()["places"] as Dictionary).erase(c)
		_write()
		return PackedByteArray()
	var cells: int = w.size.x * w.size.y
	if bool(place.get("mapped", false)):
		var all: PackedByteArray = PackedByteArray()
		all.resize(cells)
		all.fill(1)
		return all
	var seen: PackedByteArray = place.get("seen", PackedByteArray())
	return seen if seen.size() == cells else PackedByteArray()


## `a` and `b` (bytes a cell) together: a cell seen in either; the other alone if one is empty or
## they are of different levels' sizes.
static func merged(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	if a.is_empty():
		return b.duplicate()
	if b.is_empty() or b.size() != a.size():
		return a.duplicate()
	var out: PackedByteArray = a.duplicate()
	for i: int in range(out.size()):
		if b[i] != 0:
			out[i] = 1
	return out


## Note what the run in `info` knows (not a debug run): each ordinary level it has been in (its
## stamp from its layout where that is in hand), the most lately visited last; and its seed's
## bosses' columns met and the ways shrines told. Kept to the MOST most lately visited places.
static func note(info: MapInfo) -> void:
	if MapInfo.debug or info == null or info.run == null:
		return
	var run: RunState = info.run
	var data: Dictionary = kept()
	var places: Dictionary = data["places"]
	var order: Array = run.records.keys()
	# The place being played last, as the most lately visited.
	order.erase(info.coord)
	order.append(info.coord)
	for c: Vector2i in order:
		if Worlds.is_side(c) or not run.records.has(c):
			continue
		var rec: LevelRecord = run.records[c]
		var old: Dictionary = places.get(c, {})
		# Its layout's stamp from the layout in hand (never laid out afresh for it): the level being
		# played, or one the loader keeps; else the stamp kept.
		var stamped: int = int(old.get("stamp", 0))
		if c == info.coord or stamped == 0:
			var w: LevelGen = info.world if c == info.coord else (info.loader.laid_out(c) if info.loader != null else null)
			if w != null:
				stamped = Known.stamp(w)
		var place: Dictionary = {
			"seen": Known.merged(rec.seen, old.get("seen", PackedByteArray())),
			"mapped": rec.mapped or bool(old.get("mapped", false)),
			"ways": _union(old.get("ways", {}), rec.ways_taken),
			"relic": bool(old.get("relic", false)) or run.relics_found.has(c) or run.relic_hints.has(c),
			"stamp": stamped,
			"t": int(data["next"]),
		}
		data["next"] = int(data["next"]) + 1
		places[c] = place
	if places.size() > MOST:
		var by_age: Array = places.keys()
		by_age.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return int(places[a]["t"]) < int(places[b]["t"]))
		for i: int in range(places.size() - MOST):
			places.erase(by_age[i])
	var seeds: Dictionary = data["seeds"]
	var mine: Dictionary = seeds.get(run.run_seed, {})
	for boss: StringName in Bands.bosses():
		var row: int = Bosses.row_of(boss)
		var col: int = Bosses.column(boss, run.run_seed)
		var old: Dictionary = mine.get(boss, {})
		var hints: Array = (old.get("hints", []) as Array).duplicate()
		for hint: Array in run.boss_hints.get(boss, []):
			if not hints.has(hint):
				hints.append(hint)
		var met: bool = bool(old.get("met", false)) or (boss != &"whale" and (run.records.has(Vector2i(col, row)) or run.bosses.has(boss)))
		if met or not hints.is_empty():
			mine[boss] = {"met": met, "hints": hints}
	seeds[run.run_seed] = mine
	_write()


static func _union(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = a.duplicate()
	for k: Variant in b:
		out[k] = true
	return out


## Start `run` (begun on its seed, nothing else known) from what was kept: the relics seen or taken
## before marked where they lie (RunState.relic_hints, for those not yet found this run), and its
## seed's bosses' columns met marked (a hint of this column, [column, 0]) and the ways told.
static func teach(run: RunState) -> void:
	if MapInfo.debug:
		return
	var places: Dictionary = kept()["places"]
	for c: Vector2i in places:
		if bool((places[c] as Dictionary).get("relic", false)) and not run.relics_found.has(c):
			var move: StringName = Relics.at(c)
			if move != &"":
				run.relic_hints[c] = move
	var mine: Dictionary = (kept()["seeds"] as Dictionary).get(run.run_seed, {})
	for boss: Variant in mine:
		var name: StringName = StringName(boss)
		if run.bosses.has(name):
			continue
		var hints: Array = []
		var entry: Dictionary = mine[boss]
		for hint: Array in entry.get("hints", []):
			hints.append(hint.duplicate())
		var here: Array = [Bosses.column(name, run.run_seed), 0]
		if bool(entry.get("met", false)) and not hints.has(here):
			hints.append(here)
		if not hints.is_empty():
			run.boss_hints[name] = hints
