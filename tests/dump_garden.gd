extends TestKit
## Lays out every garden row of a number of worlds and prints what each holds, one line a level,
## then the averages by row: its size and open cells, how long it took to lay out, its foes, its
## stars against the price of its way on, its keys and doors by colour (and the doors no key in
## the level opens), and its lanterns, portals, secrets and vaults. For looking over the garden's
## tuning at a glance, not a test.
## godot --headless --path . --script res://tests/dump_garden.gd -- worlds=20 first=1 [rows=4..8] [layout=garden]
## suite: full

const FOES: Array[LevelGen.Type] = [LevelGen.Type.ENEMY, LevelGen.Type.SHOOTER, LevelGen.Type.HOPPER, LevelGen.Type.BIRD]


func run() -> void:
	var opts: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=")
		if kv.size() == 2:
			opts[kv[0]] = kv[1]
	var count: int = int(opts.get("worlds", 20))
	var first: int = int(opts.get("first", 1))
	var rows: Array[int] = []
	if opts.has("rows"):
		var span: PackedStringArray = String(opts["rows"]).split("..")
		for row: int in range(int(span[0]), int(span[-1]) + 1):
			rows.append(row)
	else:
		for row: int in range(-Bands.garden_rows(), Bands.garden_rows() + 1):
			rows.append(row)
	var sums: Dictionary = {}
	print("row world   size  open   ms foes stars price keys doors locked lant port secr vault side walk gate")
	for row: int in rows:
		var tally: Dictionary = {}
		for i: int in range(count):
			var at: Vector2i = Vector2i(first + i, row)
			var started: int = Time.get_ticks_msec()
			var w: LevelGen = build(at)
			var ms: int = Time.get_ticks_msec() - started
			if w == null:
				print("%3d %5d  never settled" % [row, at.x])
				_add(tally, "unsettled", 1)
				continue
			var def: NextWorldDef = Rules.def_for(at)
			var foes: int = 0
			for t: LevelGen.Type in FOES:
				foes += count_of(w, t)
			var stars: int = count_of(w, LevelGen.Type.COIN) + Rules.cluster_value(def.depth) * count_of(w, LevelGen.Type.CLUSTER)
			for s: Dictionary in w.secrets:
				for r: Array in s["rewards"]:
					if r[1] == LevelGen.Type.COIN:
						stars += 1
			var keys: Dictionary = {}
			for v: Vector2i in w.objects_of(LevelGen.Type.KEY):
				keys[w.get_cell(v).extra_info] = true
			var locked: int = 0
			var doors: int = 0
			for v: Vector2i in w.objects_of(LevelGen.Type.DOOR):
				doors += 1
				if not keys.has(w.get_cell(v).extra_info):
					locked += 1
			var open: int = 0
			for x: int in range(w.size.x):
				for y: int in range(w.size.y):
					if not w.is_ground(Vector2i(x, y)):
						open += 1
			var walk: int = 0
			if w.exits.has(MapInfo.Exit.BACK) and w.exits.has(MapInfo.Exit.DEEPER):
				var start: Vector2i = w.exits[MapInfo.Exit.BACK]
				walk = 1 if Reach.tree(w, start).has(w.exits[MapInfo.Exit.DEEPER]) else 0
			var line: Dictionary = {"walk": walk, "ms": ms, "foes": foes, "stars": stars, "price": Rules.deeper_price(def.depth),
					"keys": count_of(w, LevelGen.Type.KEY), "doors": doors, "locked": locked,
					"lanterns": count_of(w, LevelGen.Type.CHECKPOINT), "portals": count_of(w, LevelGen.Type.PORTAL) / 2,
					"secrets": w.secrets.size(), "vaults": w.vaults.size(), "side": def.doors.size(), "open": open}
			for k: String in line:
				_add(tally, k, line[k])
			print("%3d %5d %3dx%-3d %5d %4d %4d %5d %5d %4d %5d %6d %4d %4d %4d %5d %4d %4d %s" % [row, at.x, w.size.x, w.size.y, open, ms,
					foes, stars, line["price"], line["keys"], doors, locked, line["lanterns"], line["portals"],
					line["secrets"], line["vaults"], line["side"], walk, def.gate])
		sums[row] = tally
	print("\naverages by row (of %d worlds)" % count)
	for row: int in rows:
		var tally: Dictionary = sums[row]
		var parts: Array[String] = []
		for k: String in ["open", "ms", "foes", "stars", "price", "keys", "doors", "locked", "lanterns", "portals", "secrets", "vaults", "side", "walk", "unsettled"]:
			parts.append("%s %.1f" % [k, float(tally.get(k, 0)) / float(count)])
		print("%3d  %s" % [row, ", ".join(parts)])
	finish()


func _add(tally: Dictionary, key: String, value: int) -> void:
	tally[key] = int(tally.get(key, 0)) + value
