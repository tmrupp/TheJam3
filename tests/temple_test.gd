extends TestKit
## The sky's temples (Temple, SkyArchetype.build_temples): in some sky levels, not all, each a
## building of stone standing on an island (its floor carried down to the rock), roofed, its altar on
## its floor, its sequence of Temple.SPAN winds dealt with the
## level, the same every build; in play, shut while the winds along its row are not set its way
## (it refuses), then, with each level's vanes set as it asks, it opens for good and shows where the
## whale is (meeting it, if it was not).
## godot --headless --path . --script res://tests/temple_test.gd


func run() -> void:
	print("laid out")
	var found: Vector2i = Vector2i.ZERO
	var levels: int = 0
	var temples: int = 0
	var bad: Array[String] = []
	for world: int in range(28, 36):
		for k: int in range(NextWorldDef.BAND):
			var at: Vector2i = Vector2i(world, NextWorldDef.band_row(&"sky", k))
			var w: LevelGen = build(at)
			if w == null:
				continue
			levels += 1
			var held: Array[Vector2i] = w.objects_of(LevelGen.Type.TEMPLE)
			if held.is_empty():
				continue
			temples += 1
			var v: Vector2i = held[0]
			var winds: Array = w.get_cell(v).extra_info
			if held.size() != 1 or winds.size() != Temple.SPAN or not winds.all(func(x: Variant) -> bool: return absi(int(x)) == 1):
				bad.append("%s: its winds" % at)
			var box: Rect2i = w.temples[0]["box"] if w.temples.size() == 1 else Rect2i()
			if box.size == Vector2i.ZERO or w.temples[0]["altar"] != v or not w.is_ground(v + Vector2i.DOWN):
				bad.append("%s: its altar not on its floor in its building" % at)
			else:
				# Its stylobate stands on the island: every column of it carried down to rock.
				for x: int in range(box.position.x, box.end.x):
					var c: Vector2i = Vector2i(x, box.end.y - 1)
					while w.masonry.has(c):
						c += Vector2i.DOWN
					if not w.is_ground(c):
						bad.append("%s: not standing on the island" % at)
						break
				if not range(box.position.x, box.end.x).all(func(x: int) -> bool: return w.masonry.has(Vector2i(x, box.position.y)) and w.masonry.has(Vector2i(x, box.end.y - 1))):
					bad.append("%s: no roof and floor of stone" % at)
			if str(build(at).get_cell(v).extra_info) != str(winds):
				bad.append("%s: not the same every build" % at)
			if found == Vector2i.ZERO:
				found = at
	check(temples > 0 and temples < levels and bad.is_empty(), "temples in %d of %d sky levels, each standing on an island, its %d winds dealt, the same every build %s" % [temples, levels, Temple.SPAN, bad])
	if found == Vector2i.ZERO:
		finish()
		return

	print("in play")
	await boot(found.x)
	info.coord = found
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	var temple: Temple = placed("temple.tscn")[0] as Temple
	check(not temple.opened() and not temple.all_lit() and str(temple.interaction_hint().get("text", "")) != "", "shut while the winds are not set, and it says so")
	# Every level of its sequence set its way but the middle one, set the other way.
	for i: int in range(Temple.SPAN):
		var rec: LevelRecord = info.run.record(temple.place_of(i))
		var way: int = temple.winds[i] if i != 1 else -temple.winds[i]
		rec.vanes_on = {Vector2i(1, 1): way}
		rec.wind_way = way
	check(temple.lit(0) and not temple.lit(1) and temple.lit(Temple.SPAN - 1), "each level's wind lit on its door as it is set its way")
	temple.use()
	check(not temple.opened(), "one level wrong: it refuses")
	var middle: LevelRecord = info.record()
	middle.vanes_on = {Vector2i(1, 1): temple.winds[1]}
	middle.wind_way = temple.winds[1]
	check(temple.all_lit(), "all set its way: all lit")
	temple.use()
	check(temple.opened() and info.record().temple_open, "it opens, kept in the level record")
	check(info.run.whale_x != WhaleHunt.NONE and str(temple.interaction_hint().get("text", "")) == "the whale: world %d" % info.run.whale_x, "and shows where the whale is (world %d)" % info.run.whale_x)
	RunState.delete_save()
	finish()
