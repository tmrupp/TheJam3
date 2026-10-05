extends SceneTree
## Deeper down, crossings are left to the relic moves: from MapInfo.RELIC_NEED_FROM a share of a
## cemetery's chasms and the sky's gaps have no bell or vane (and no planks, wind or switch), rising
## with depth; and hyperspace that drops deep may leave one stretch unbridged, which the rough reach
## cannot cross but a relic's longer reach can.
## godot --headless --path . --script res://tests/relics_needed_test.gd

var failed: bool = false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)


func run() -> void:
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var wfc: Node = main.get_node("WaveFunctionCollapse")

	print("the share rises with depth")
	check(MapInfo.relic_need(MapInfo.RELIC_NEED_FROM - 1) == 0 and MapInfo.relic_need(0) == 0, "none above depth %d" % MapInfo.RELIC_NEED_FROM)
	check(MapInfo.relic_need(MapInfo.RELIC_NEED_FROM) == MapInfo.RELIC_NEED_STEP and MapInfo.relic_need(MapInfo.RELIC_NEED_FROM + 2) == 3 * MapInfo.RELIC_NEED_STEP, "then %d%% a level" % MapInfo.RELIC_NEED_STEP)
	check(MapInfo.relic_need(40) == MapInfo.RELIC_NEED_MAX, "up to %d%%" % MapInfo.RELIC_NEED_MAX)

	print("chasms and gaps left to relics")
	var shallow: Array[int] = [0, 0]
	var deep: Array[int] = [0, 0]
	var clean: bool = true
	var c0: int = NextWorldDef.first_depth(&"cemetery")
	var s0: int = NextWorldDef.first_depth(&"sky")
	for at: Vector2i in [Vector2i(1, c0), Vector2i(7, c0), Vector2i(28, c0 + 1), Vector2i(99, c0 + 1),
			Vector2i(1, c0 + 5), Vector2i(7, c0 + 5), Vector2i(28, c0 + 4), Vector2i(99, c0 + 4),
			Vector2i(28, s0), Vector2i(7, s0 + 3)]:
		var def: NextWorldDef = MapInfo.def_for(at)
		var cells: Array = wfc.call("generate_level", def)
		var w: MapInfo.World = MapInfo.World.new(cells, def)
		var tally: Array[int] = shallow if at.y <= c0 + 1 else deep
		tally[0] += w.relic_chasms.size()
		tally[1] += w.chasms.size()
		for id: int in w.relic_chasms:
			for v: Vector2i in w.objects:
				var cell: MapInfo.Cell = w.get_cell(v)
				if cell.type in [MapInfo.Type.BELL, MapInfo.Type.VANE] and int((cell.extra_info as Array)[0]) == id:
					clean = false
				if cell.type == MapInfo.Type.BRIDGE and int(cell.extra_info) == id:
					clean = false
				if cell.type == MapInfo.Type.WIND and cell.extra_info is Dictionary and int((cell.extra_info as Dictionary).get("chasm", -1)) == id:
					clean = false
				if cell.type == MapInfo.Type.SWITCH and cell.extra_info is Vector2i and not w.get_cell(cell.extra_info).type in [MapInfo.Type.BELL, MapInfo.Type.VANE, MapInfo.Type.SWITCH_GATE]:
					clean = false
		var again: MapInfo.World = MapInfo.World.new(cells, def)
		check(again.objects == w.objects and again.relic_chasms == w.relic_chasms, "%s: the same every visit (%d of %d chasms left to relics)" % [at, w.relic_chasms.size(), w.chasms.size()])
	check(clean, "a chasm left to relics has no bell or vane, planks, wind or switch")
	check(deep[0] > 0, "some chasms are left to relics (%d of %d deep)" % [deep[0], deep[1]])
	check(deep[1] > 0 and shallow[1] > 0 and float(deep[0]) / float(deep[1]) > float(shallow[0]) / float(shallow[1]), "more of them deeper (%d of %d at the band's start, %d of %d at its end)" % [shallow[0], shallow[1], deep[0], deep[1]])
	var garden: NextWorldDef = MapInfo.def_for(Vector2i(28, 2))
	var gw: MapInfo.World = MapInfo.World.new(wfc.call("generate_level", garden), garden)
	check(gw.relic_chasms.is_empty(), "none in a shallow level")

	print("hyperspace")
	var kind: int = Worlds.kind_of(Hyperspace)
	var gaps: int = 0
	var shallow_gaps: int = 0
	var ok: bool = true
	for world_seed: int in range(1, 13):
		for from_depth: int in [1, 9]:
			var def: NextWorldDef = MapInfo.def_for(Worlds.side_at(kind, Vector2i(world_seed, from_depth)))
			var w: MapInfo.World = MapInfo.World.new(wfc.call("generate_level", def), def)
			if from_depth + Hyperspace.DROP < MapInfo.RELIC_NEED_FROM:
				shallow_gaps += w.relic_gaps.size()
				continue
			for gap: Rect2i in w.relic_gaps:
				gaps += 1
				if Hyperspace.crossable(w) or not Hyperspace.crossable(w, Hyperspace.RELIC_ACROSS):
					ok = false
				for v: Vector2i in w.objects:
					if gap.has_point(v) and w.get_cell(v).type in [MapInfo.Type.MOVING_PLATFORM, MapInfo.Type.PLATFORM, MapInfo.Type.MOON]:
						ok = false
	check(shallow_gaps == 0, "hyperspace dropping no deeper than depth %d is bridged all the way" % (MapInfo.RELIC_NEED_FROM - 1))
	check(gaps > 0, "deep hyperspace leaves stretches to the relics (%d of 12)" % gaps)
	check(ok, "such a stretch is cleared of lifts, ledges and moons, and only a relic's reach crosses it")

	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASSED")
		quit()
