extends SceneTree
## Generation budgets, gates and moon placement over both terrain families.

var failed: bool = false
var fixture: MapInfo.World

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func run() -> void:
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var wfc: Node = main.get_node("WaveFunctionCollapse")
	for seed_value: int in [1, 7, 28, 99, 512]:
		for depth: int in [0, 2, 5, 9]:
			var def: NextWorldDef = MapInfo.def_for(Vector2i(seed_value, depth))
			var w: MapInfo.World = MapInfo.World.new(wfc.call("generate_level", def), def)
			fixture = w
			var counts: Dictionary = {}
			for column: Array in w.cells:
				for cell: MapInfo.Cell in column:
					counts[cell.type] = int(counts.get(cell.type, 0)) + 1
			var label: String = "seed %d depth %d" % [seed_value, depth]
			# A vault's door and loot are its own (vaults_test); the rest keep to their budgets.
			counts[MapInfo.Type.DOOR] = int(counts.get(MapInfo.Type.DOOR, 0)) - w.vaults.size()
			for vault: Dictionary in w.vaults:
				for v: Vector2i in vault["room"]:
					var t: MapInfo.Type = w.get_cell(v).type
					if t != MapInfo.Type.EMPTY:
						counts[t] = int(counts.get(t, 0)) - 1
			print("%s %s: gates=%d moons=%d keys=%d lanterns=%d portals=%d" % [label, w.size, counts.get(MapInfo.Type.DOOR, 0), counts.get(MapInfo.Type.MOON, 0), counts.get(MapInfo.Type.KEY, 0), counts.get(MapInfo.Type.CHECKPOINT, 0), counts.get(MapInfo.Type.PORTAL, 0)])
			# A cemetery's open terraces have hardly any one-cell corridors to gate.
			check(def.chasmed() or int(counts.get(MapInfo.Type.DOOR, 0)) > 0, label + ": gates must be present")
			check(int(counts.get(MapInfo.Type.DOOR, 0)) <= w.per_area(MapInfo.DOORS_PER_K), label + ": gate budget")
			# A first level also has its start key (for the side door near the start).
			var start_key: int = 1 if w.start_side >= 0 else 0
			check(int(counts.get(MapInfo.Type.KEY, 0)) == w.key_count() + start_key and w.key_count() == maxi(MapInfo.KEYS_MIN, w.per_area(MapInfo.KEYS_PER_K)), label + ": keys scale with area (and the start key)")
			check(int(counts.get(MapInfo.Type.PORTAL, 0)) == 2 * w.per_area(MapInfo.PORTAL_PAIRS_PER_K), label + ": paired portals scale with area")
			if depth == 9:
				check(int(counts.get(MapInfo.Type.PORTAL, 0)) >= 4, label + ": the largest worlds have at least two generated pairs")
			check(int(counts.get(MapInfo.Type.MOON, 0)) > 0 and int(counts.get(MapInfo.Type.MOON, 0)) <= w.per_area(MapInfo.MOONS_PER_K), label + ": moon budget")
			for v: Vector2i in w.objects:
				if w.get_cell(v).type == MapInfo.Type.MOON:
					check(not w._ledge_below(v), label + ": moon above platform at " + str(v))
				elif w.get_cell(v).type == MapInfo.Type.PORTAL:
					var end: Vector2i = w.get_cell(v).extra_info
					check(w.get_cell(end).type == MapInfo.Type.PORTAL and w.get_cell(end).extra_info == v, label + ": reciprocal portal pair")
	moon_rules()
	print("FAILED" if failed else "PASS: spawn balance (20 levels) and moon rules")
	quit(1 if failed else 0)

func moon_rules() -> void:
	# A controlled open chamber makes support rejection and weighted choice measurable.
	var w: MapInfo.World = fixture
	w.objects.clear()
	w.grounds.clear()
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			w.set_cell(Vector2i(x, y), MapInfo.Cell.new(MapInfo.Type.EMPTY))
	var above: Vector2i = Vector2i(10, 4)
	var support: Vector2i = Vector2i(10, 12)
	w.set_cell(support, MapInfo.Cell.new(MapInfo.Type.PLATFORM))
	w.objects.append(support)
	check(w._ledge_below(above), "a platform more than three cells below rejects a moon")
	w.set_cell(Vector2i(10, 8), MapInfo.Cell.new(MapInfo.Type.GROUND))
	check(not w._ledge_below(above), "a platform hidden behind rock does not reject open air above it")
	w.set_cell(Vector2i(10, 8), MapInfo.Cell.new(MapInfo.Type.EMPTY))
	w.set_cell(support, MapInfo.Cell.new(MapInfo.Type.EMPTY))
	w.objects.clear()
	var moving: MapInfo.Cell = MapInfo.Cell.new(MapInfo.Type.MOVING_PLATFORM)
	moving.extra_info = [3, Vector2i.RIGHT, 8]
	w.set_cell(Vector2i(4, 12), moving)
	w.objects.append(Vector2i(4, 12))
	check(w._ledge_below(above), "the whole swept width of a moving platform rejects a moon")
	w.set_cell(Vector2i(4, 12), MapInfo.Cell.new(MapInfo.Type.EMPTY))
	w.objects.clear()
	var thorn_spot: Vector2i = Vector2i(10, 4)
	var plain_spot: Vector2i = Vector2i(30, 4)
	w.set_cell(thorn_spot + Vector2i(0, 4), MapInfo.Cell.new(MapInfo.Type.SPIKES))
	var over_spikes: int = 0
	for trial: int in range(400):
		w.objects.clear()
		w.empties.clear()
		w.empties.append_array([thorn_spot, plain_spot])
		w.set_cell(thorn_spot, MapInfo.Cell.new(MapInfo.Type.EMPTY))
		w.set_cell(plain_spot, MapInfo.Cell.new(MapInfo.Type.EMPTY))
		w.rng.seed = trial
		w.place_moons(1)
		if w.get_cell(thorn_spot).type == MapInfo.Type.MOON:
			over_spikes += 1
	print("moon weighting: %d/400 over spikes" % over_spikes)
	check(over_spikes > 260 and over_spikes < 340, "equal candidates favour spikes at approximately 3:1")
