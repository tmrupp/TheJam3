extends TestKit
## Writes the institute timetable's rules, as the game has them, to a JSON file for the timetable model
## (tools/timetable_model.py) to check itself against and to run on: every outcome of the departments'
## climb (Timetable.climb, for every tier, every class attended and every set of departments
## meeting), each classroom's place in its cycle (Timetable.phase) and needs, the spells' top tiers, and the classrooms of some real
## institute levels with what each teaches over a few days, and each level as a graph for walking it:
## its regions (the open air joined without crossing a classroom: a classroom's doors, glyph seals,
## locked doors and gates count as walls, cracked walls as broken), the regions each classroom's
## doorways open on, where the wizard comes in, the regions holding a bell cord out of the
## classrooms (the great bell's, the library's), and which classroom holds the way on
## (Timetable.way_on_hall). Not a test: run it by hand.
## godot --headless --path . --script res://tests/dump_timetable.gd -- out=../timetable_rules.json

## The institute levels written: the first rows of its band (NextWorldDef.band_row) in each world.
const WORLDS: Array[int] = [28, 7, 99, 41, 5, 13, 64, 3, 11, 17]
const ROWS: int = 4
## How many rings of each classroom's schedule are written.
const RINGS: int = 36


func run() -> void:
	var out: String = "res://../timetable_rules.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	var depts: Array = Timetable.LADDERS.keys()
	var data: Dictionary = {"depts": depts, "ladders": {}, "in_session": Timetable.IN_SESSION, "holds": Timetable.HOLDS, "needs": Timetable.NEEDS, "top": Timetable.TOP,
		"periods": Timetable.PERIODS, "max_tier": {}, "relic_moves": Relics.MOVES, "climb": [], "levels": []}
	for d: StringName in depts:
		data["ladders"][d] = Timetable.LADDERS[d]
		for a: StringName in Timetable.LADDERS[d]:
			data["max_tier"][a] = Abilities.max_tier(a)
	# Every climb: tiers 1..TOP each, attended (or none), every set meeting.
	var attended: Array = [&""] + depts
	for code: int in range(int(pow(Timetable.TOP, depts.size()))):
		var tiers: Dictionary = {}
		var c: int = code
		for d: StringName in depts:
			tiers[d] = c % Timetable.TOP + 1
			@warning_ignore("integer_division")
			c = c / Timetable.TOP
		for a: StringName in attended:
			for m: int in range(1 << depts.size()):
				var meeting: Dictionary = {}
				for k: int in range(depts.size()):
					meeting[depts[k]] = (m >> k) & 1 == 1
				var after: Dictionary = Timetable.climb(tiers, a, meeting)
				data["climb"].append([depts.map(func(d: StringName) -> int: return int(tiers[d])), String(a), m, depts.map(func(d: StringName) -> int: return int(after[d]))])
	# Real levels' classrooms.
	for world: int in WORLDS:
		for k: int in range(ROWS):
			var at: Vector2i = Vector2i(world, NextWorldDef.band_row(&"institute", k))
			var w: LevelGen = build(at)
			if w == null:
				continue
			var region: Dictionary = _regions(w)
			var rooms: Array = []
			var way_on: int = -1
			for i: int in range(w.halls.size()):
				if w.halls[i]["kind"] != &"lecture":
					continue
				if i == Timetable.way_on_hall(w):
					way_on = rooms.size()
				var subjects: Array = []
				for r: int in range(RINGS):
					subjects.append(String(Timetable.subject(w, i, r)))
				var opens: Array = []
				for step: Vector2i in w.halls[i]["steps"]:
					if region.has(step) and not opens.has(region[step]):
						opens.append(region[step])
				var centre: Vector2i = (w.halls[i]["inside"] as Rect2i).get_center()
				rooms.append({"dept": String(w.halls[i]["dept"]), "subjects": subjects, "regions": opens, "at": [centre.x, centre.y], "phase": Timetable.phase(w, i)})
			var cords: Array = []
			for v: Vector2i in w.objects_of(LevelGen.Type.SCHOOL_BELL):
				if Institute.hall_at(w, v) < 0 or w.halls[Institute.hall_at(w, v)]["kind"] == &"library":
					if region.has(v) and not cords.has(region[v]):
						cords.append(region[v])
			# What joins regions besides classrooms: locked doors, gates and glyph seals (with the spell a seal asks for).
			var locks: Array = []
			for v: Vector2i in w.objects:
				var t: LevelGen.Type = w.get_cell(v).type
				if not t in [LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.LIGHT_GATE, LevelGen.Type.GLYPH_SEAL]:
					continue
				var sides: Array = []
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if region.has(v + d) and not sides.has(region[v + d]):
						sides.append(region[v + d])
				if sides.size() > 1:
					var what: String = String(w.get_cell(v).extra_info) if t == LevelGen.Type.GLYPH_SEAL else LevelGen.Type.keys()[t].to_lower()
					locks.append({"kind": what, "regions": sides})
			var start: Vector2i = w.exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
			data["levels"].append({"at": [at.x, at.y], "rooms": rooms, "start_region": region.get(start, -1), "start": [start.x, start.y], "cord_regions": cords, "locks": locks, "exit": way_on})
	var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	check(file != null, "writing %s" % out)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()
		print("  ok   wrote %d climbs and %d levels to %s" % [data["climb"].size(), data["levels"].size(), ProjectSettings.globalize_path(out)])
	finish()


## Each open cell of `w` out of the classrooms, by the region it lies in (see the class description).
func _regions(w: LevelGen) -> Dictionary:
	var out: Dictionary = {}
	var walls: Array[LevelGen.Type] = [LevelGen.Type.GROUND, LevelGen.Type.EXAM_DOOR, LevelGen.Type.GLYPH_SEAL, LevelGen.Type.DOOR,
		LevelGen.Type.SWITCH_GATE, LevelGen.Type.LIGHT_GATE]
	var open: Callable = func(v: Vector2i) -> bool:
		if not w.is_valid(v) or w.get_cell(v).type in walls:
			return false
		var hall: int = Institute.hall_at(w, v)
		return hall < 0 or w.halls[hall]["kind"] != &"lecture"
	var next: int = 0
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			var v: Vector2i = Vector2i(x, y)
			if out.has(v) or not open.call(v):
				continue
			var stack: Array[Vector2i] = [v]
			out[v] = next
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n: Vector2i = c + d
					if not out.has(n) and open.call(n):
						out[n] = next
						stack.append(n)
			next += 1
	return out
