extends TestKit
## The sky's balloons (Balloon, SkyArchetype.place_balloon): one moored in every sky level of the
## band, on a floor with open air over it, kept clear, the same every build; how far one goes by the
## level's wind (a world for every Balloon.STEP vanes on its way, at most Balloon.MOST); in play,
## becalmed it shows nothing and goes nowhere, and with wind enough it shows the world it goes to (its
## number, no words), rises with the
## wizard and carries them along the row to that world, where they come down by its balloon.
## godot --headless --path . --script res://tests/balloon_test.gd


func run() -> void:
	if not needs([&"sky"]):
		finish()
		return
	print("laid out")
	var bad: Array[String] = []
	var levels: int = 0
	# The band's first, middle and last rows (not every row: a long band would take minutes).
	var last: int = Bands.rows_of(&"sky") - 1
	for world: int in [28, 29, 30]:
		for k: int in [0, last / 2, last]:
			var at: Vector2i = Vector2i(world, NextWorldDef.band_row(&"sky", k))
			var w: LevelGen = build(at)
			if w == null:
				continue
			levels += 1
			var v: Vector2i = w.balloon
			if not w.is_valid(v) or w.get_cell(v).type != LevelGen.Type.BALLOON or w.objects_of(LevelGen.Type.BALLOON).size() != 1:
				bad.append("%s: no balloon" % at)
				continue
			if not w.is_ground(v + Vector2i.DOWN):
				bad.append("%s: not on a floor" % at)
			for d: int in range(1, SkyArchetype.BALLOON_AIR + 1):
				var up: Vector2i = v - Vector2i(0, d)
				if w.is_ground(up) or w.get_cell(up).type != LevelGen.Type.EMPTY:
					bad.append("%s: no open air over it" % at)
					break
			if build(at).balloon != v:
				bad.append("%s: not the same every build" % at)
	check(levels > 0 and bad.is_empty(), "a balloon moored in each of %d sky levels, on a floor with open air over it, the same every build %s" % [levels, bad])
	check(Balloon.trip(0) == 0 and Balloon.trip(1) == 0 and Balloon.trip(2) == 1 and Balloon.trip(-4) == -2 and Balloon.trip(99) == Balloon.MOST, "a world for every %d vanes on its way, at most %d; less wind, nowhere" % [Balloon.STEP, Balloon.MOST])

	print("in play")
	var from: Vector2i = Vector2i(28, NextWorldDef.band_row(&"sky", 1))
	await boot(from.x)
	player.health.max_health = 99
	player.health.health = 99
	info.coord = from
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	var balloons: Array[Node] = placed("balloon.tscn")
	check(balloons.size() == 1, "the level's balloon is there")
	if balloons.is_empty():
		finish()
		return
	var balloon: Balloon = balloons[0] as Balloon
	# Standing by it (its chunk awake, as the wizard's always is).
	player.set_physics_process(false)
	player.global_position = balloon.global_position
	info.loader.wake_around(balloon.global_position)
	await frames(3)
	check(not balloon.interaction_hint().has("text") and balloon.destination() == null, "with no wind it is becalmed, and shows nothing")
	balloon.use()
	await frames(10)
	check(balloon.rising < 0.0 and info.coord == from, "and goes nowhere")
	info.record().vanes_on = {Vector2i(1, 1): -1, Vector2i(2, 1): -1, Vector2i(3, 1): -1}
	info.record().wind_way = -1
	check(info.level_wind() == -3 and balloon.destination() == from + Vector2i(-1, 0), "three vanes on to the left: one world to the left")
	check(str(balloon.interaction_hint().get("text", "")) == str(from.x - 1), "it shows the world's number before boarding")
	var start: float = player.global_position.y
	balloon.use()
	var rose: bool = await within(func() -> bool: return player.global_position.y < start - 100.0, Balloon.RISE_TIME + 1.0)
	check(rose, "boarded, it rises with the wizard")
	var there: bool = await until(func() -> bool: return info.coord == from + Vector2i(-1, 0) and not info.travelling, 15000)
	# Where they come down, as they arrive: left to play on, on a loaded machine a foe or a fall may
	# carry them off before the check.
	player.set_physics_process(false)
	await frames(2)
	check(there, "and carries them along the row to world %d" % (from.x - 1))
	var landed: Vector2i = info.world.balloon
	check(info.world.is_valid(landed) and player.global_position.distance_to(info.cell_position(landed)) < 140.0, "where they come down by its balloon (%s, %.0f px off)" % [info.coord, player.global_position.distance_to(info.cell_position(landed))])
	player.set_physics_process(true)
	await settle()
	RunState.delete_save()
	finish()
