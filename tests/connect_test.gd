extends SceneTree
## Every generated level is one connected cave: all its open cells (and so every exit, the shrine,
## the ink well, keys, lanterns and moons) are joined through open space. Gates (doors, cracked
## walls, locked or unpaid exits) and abilities may still be needed; connectivity is not
## reachability. Checked over many worlds and depths.
## godot --headless --path . --script res://tests/connect_test.gd

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var wfc: Node = main.get_node("WaveFunctionCollapse")
	var failed: int = 0
	var checked: int = 0
	for world_seed: int in [1, 7, 28, 99, 512]:
		for depth: int in [0, 2, 5, 8]:
			var def: NextWorldDef = MapInfo.def_for(Vector2i(world_seed, depth))
			var cells: Array = wfc.call("generate_level", def)
			var w: MapInfo.World = MapInfo.World.new(cells, def)
			# Open = anything that is not rock (cracked walls are gates, so they count as open).
			var open: Callable = func(v: Vector2i) -> bool: return w.is_valid(v) and w.get_cell(v).type != MapInfo.Type.GROUND
			var start: Vector2i = w.exits[MapInfo.Exit.BACK]
			var seen: Dictionary = {start: true}
			var stack: Array[Vector2i] = [start]
			while not stack.is_empty():
				var v: Vector2i = stack.pop_back()
				for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					var n: Vector2i = v + d
					if not seen.has(n) and open.call(n):
						seen[n] = true
						stack.append(n)
			var missing: Array = []
			var total: int = 0
			for x: int in range(w.size.x):
				for y: int in range(w.size.y):
					var v: Vector2i = Vector2i(x, y)
					if open.call(v):
						total += 1
						if not seen.has(v):
							missing.append(v)
			var goals_ok: bool = true
			for v: Vector2i in w.objects:
				if w.get_cell(v).type in [MapInfo.Type.EXIT, MapInfo.Type.SHRINE, MapInfo.Type.INKWELL, MapInfo.Type.KEY, MapInfo.Type.CHECKPOINT, MapInfo.Type.MOON] and not seen.has(v):
					goals_ok = false
			checked += 1
			var shrine_ok: bool = w.shrine.x >= 0
			if not missing.is_empty() or not goals_ok or not shrine_ok:
				failed += 1
				push_error("FAIL world %d depth %d: %d of %d open cells cut off, goals %s, shrine %s" % [world_seed, depth, missing.size(), total, goals_ok, shrine_ok])
			else:
				print("  ok   world %d depth %d (%s): one cave of %d cells, shrine at %s" % [world_seed, depth, w.size, total, w.shrine])
	if failed > 0:
		print("FAILED %d of %d" % [failed, checked])
		quit(1)
	else:
		print("PASS: connected caves (%d levels)" % checked)
		quit()
