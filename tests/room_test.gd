extends SceneTree
## Big things get room: once any kind of place is laid out, rock and thorns in the box each thing
## takes (Placeables.size) are carved out, so a tall doorway, portal, shrine, lantern or ink well
## never prints into the rock over it. A secret room's rock and the rock sealing it, rock framing a
## door or gate, and rock a laser is set in are left alone.
## godot --headless --path . --script res://tests/room_test.gd

var failed: bool = false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)


## Cells in big things' boxes still holding rock or thorns (outside the cases left alone).
func cramped(w: LevelGen) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for v: Vector2i in w.objects:
		var size: Vector2i = Placeables.size(w.get_cell(v).type)
		for dx: int in range(size.x):
			for dy: int in range(size.y):
				var c: Vector2i = v + Vector2i(dx, -dy)
				if c == v or not w.is_valid(c):
					continue
				if w.get_cell(c).type in [LevelGen.Type.GROUND, LevelGen.Type.SPIKES] and not w._holds_up(c):
					out.append(c)
	return out


func run() -> void:
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var wfc: Node = main.get_node("WaveFunctionCollapse")
	var places: int = 0
	var carved: int = 0
	var all_clear: bool = true
	var same: bool = true
	var coords: Array[Vector2i] = []
	for s: int in range(1, 21):
		for depth: int in [0, 3]:
			coords.append(Vector2i(s, depth))
	for s: int in range(1, 5):
		coords.append(Worlds.side_at(Worlds.kind_of(Hyperspace), Vector2i(s, 1)))
	for at: Vector2i in coords:
		var def: NextWorldDef = Rules.def_for(at)
		var cells: Array = wfc.call("generate_level", def)
		var w: LevelGen = LevelGen.new(cells, def)
		places += 1
		carved += w.carved.size()
		var left: Array[Vector2i] = cramped(w)
		if not left.is_empty():
			all_clear = false
			print("  cramped at %s: %s" % [at, left])
		if at.x <= 3:
			var again: LevelGen = LevelGen.new(cells, Rules.def_for(at))
			same = same and again.carved == w.carved
	print("  %d places, %d cells carved" % [places, carved])
	check(carved > 0, "rock over big things is carved out")
	check(all_clear, "every big thing has its room, in levels and hyperspace alike")
	check(same, "the same place always carves the same cells")
	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASSED")
		quit()
