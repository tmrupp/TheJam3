extends TestKit
## Writes the institute timetable's rules, as the game has them, to a JSON file for the timetable model
## (tools/timetable_model.py) to check itself against and to run on: every outcome of the departments'
## climb (Timetable.climb, for every tier, every class attended, every set of departments meeting, and
## botany's class taught or not),
## each department's rhythm and needs, the spells' top tiers, and the classrooms of some real
## institute levels with what each teaches over a few days. Not a test: run it by hand.
## godot --headless --path . --script res://tests/dump_timetable.gd -- out=../timetable_rules.json

## The institute levels whose classrooms are written: rows into its band, by world.
const LEVELS: Array[Vector2i] = [Vector2i(28, 0), Vector2i(28, 1), Vector2i(28, 2), Vector2i(7, 0), Vector2i(7, 3), Vector2i(99, 1),
	Vector2i(99, 4), Vector2i(41, 2), Vector2i(41, 5), Vector2i(5, 0), Vector2i(13, 2), Vector2i(64, 3)]
## How many rings of each classroom's schedule are written.
const RINGS: int = 36


func run() -> void:
	var out: String = "res://../timetable_rules.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.substr(4)
	var depts: Array = Timetable.LADDERS.keys()
	var data: Dictionary = {"depts": depts, "ladders": {}, "meets": {}, "holds": Timetable.HOLDS, "needs": Timetable.NEEDS, "top": Timetable.TOP,
		"periods": Timetable.PERIODS, "max_tier": {}, "relic_moves": Relics.MOVES, "climb": [], "levels": []}
	for d: StringName in depts:
		data["ladders"][d] = Timetable.LADDERS[d]
		data["meets"][d] = range(Timetable.PERIODS).filter(func(p: int) -> bool: return Timetable.meets(d, p))
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
				for untaught: bool in [false, true]:
					var after: Dictionary = Timetable.climb(tiers, a, meeting, untaught)
					data["climb"].append([depts.map(func(d: StringName) -> int: return int(tiers[d])), String(a), m, untaught, depts.map(func(d: StringName) -> int: return int(after[d]))])
	# Real levels' classrooms.
	for place: Vector2i in LEVELS:
		var at: Vector2i = Vector2i(place.x, NextWorldDef.band_row(&"institute", place.y))
		var w: LevelGen = build(at)
		if w == null:
			continue
		var rooms: Array = []
		for i: int in range(w.halls.size()):
			if w.halls[i]["kind"] != &"lecture":
				continue
			var subjects: Array = []
			for r: int in range(RINGS):
				subjects.append(String(Timetable.subject(w, i, r)))
			rooms.append({"dept": String(w.halls[i]["dept"]), "subjects": subjects})
		data["levels"].append({"at": [at.x, at.y], "rooms": rooms})
	var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	check(file != null, "writing %s" % out)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()
		print("  ok   wrote %d climbs and %d levels to %s" % [data["climb"].size(), data["levels"].size(), ProjectSettings.globalize_path(out)])
	finish()
