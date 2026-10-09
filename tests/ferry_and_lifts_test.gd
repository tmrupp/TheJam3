extends TestKit
## The ferry spell (a raft that carries the wizard the way they aim, then fades) and lifts that wait
## for a switch (parked until it is thrown, then running for good).
## godot --headless --path . --script res://tests/ferry_and_lifts_test.gd


func run() -> void:
	print("lift switches in the layout")
	var paired: int = 0
	var good: bool = true
	for at: Vector2i in [Vector2i(7, 3), Vector2i(28, 6), Vector2i(1, 2), Vector2i(99, 1)]:
		var w: LevelGen = build(at)
		for lift: Vector2i in w.objects_of(LevelGen.Type.MOVING_PLATFORM):
			var info: Array = w.get_cell(lift).extra_info
			if info.size() <= 3:
				continue
			paired += 1
			var lever: Vector2i = info[3]
			good = good and w.get_cell(lever).type == LevelGen.Type.SWITCH and w.get_cell(lever).extra_info == lift
			good = good and LevelGen.dist(lever, lift) <= LevelGen.LIFT_SWITCH_NEAR
		check_eq(build(at).objects, w.objects, "%s: the same every visit" % at)
	check(paired > 0, "some lifts wait for a switch (%d)" % paired)
	check(good, "each such lift's switch is near it and names it back")

	await boot()
	player.end_invulnerable()

	print("a lift waiting for its switch")
	var lift: MovingPlatform = (load("res://prefabs/moving_platform.tscn") as PackedScene).instantiate() as MovingPlatform
	var home: Vector2i = info.cell_at(player.global_position) + Vector2i(2, -3)
	var lever_cell: Vector2i = home + Vector2i(-1, 0)
	lift.set_meta(&"cell", home)
	info.map_elements.add_child(lift)
	# Its switch off to begin with (some start on).
	info.set_switch(lever_cell, false)
	lift.setup(info, home, [1, Vector2i(1, 0), 3, lever_cell])
	await physics_frame
	var parked: Vector2 = lift.position
	for i: int in range(20):
		await physics_frame
	check(lift.waiting and lift.position == parked, "a lift with a switch waits, parked at the start of its track")
	var lever: Switch = (load("res://prefabs/switch.tscn") as PackedScene).instantiate() as Switch
	lever.set_meta(&"cell", lever_cell)
	info.map_elements.add_child(lever)
	lever.setup(info, lever_cell, home)
	lever.flip()
	check(not lift.waiting and info.switch_on(lever_cell), "turning its switch on starts it, and the record keeps it on")
	await physics_frame
	check(lift.position.distance_to(parked) < 4.0, "it sets off from where it was parked, without a jump")
	for i: int in range(40):
		await physics_frame
	check(lift.position.distance_to(parked) > 8.0, "and it runs")
	lever.flip()
	var stopped: Vector2 = lift.position
	for i: int in range(20):
		await physics_frame
	check(lift.waiting and not info.switch_on(lever_cell) and lift.position == stopped, "turned off, it stops where it is")
	lever.flip()
	for i: int in range(20):
		await physics_frame
	check(not lift.waiting and lift.position != stopped, "and on again, it runs on from there")
	var again: MovingPlatform = (load("res://prefabs/moving_platform.tscn") as PackedScene).instantiate() as MovingPlatform
	info.map_elements.add_child(again)
	again.setup(info, home, [1, Vector2i(1, 0), 3, lever_cell])
	check(not again.waiting, "built again (a revisit), it runs from the start")
	lift.queue_free()
	again.queue_free()
	lever.queue_free()

	print("the ferry")
	Abilities.set_tier(player, &"ferry", 1)
	check(Abilities.spell(player) == &"ferry", "the ferry takes the spell slot")
	# In open air with room to glide right: the wizard drops, and the raft catches and carries them.
	var spot: Vector2i = Vector2i(-1, -1)
	for v: Vector2i in info.world.empties:
		var room: bool = true
		for x: int in range(-1, 4):
			for y: int in range(-1, 1):
				var c: Vector2i = v + Vector2i(x, y)
				room = room and info.world.is_valid(c) and not info.solid_at(info.cell_position(c))
		if room and (spot.x < 0 or v < spot):
			spot = v
	check(spot.x >= 0, "a stretch of open air to glide through")
	player.global_position = info.cell_position(spot)
	player.velocity = Vector2.ZERO
	await physics_frame
	player.sprite.scale.x = absf(player.sprite.scale.x)
	var ferry: Ferry = player.get_node("Ferry") as Ferry
	Abilities.cast(player)
	check(ferry.rafts.size() == 1, "casting conjures a raft")
	var raft: FerryRaft = ferry.rafts[0]
	check(absf(raft.global_position.y - FerryRaft.HALF_THICK - player._feet_y()) < 2.0, "under the wizard's feet")
	check(raft.velocity.x > 0.0 and is_zero_approx(raft.velocity.y), "gliding the way they face, aiming nowhere")
	check(Abilities.running(player).x > 0.9, "the spell shows the raft's life running")
	var x0: float = player.global_position.x
	for i: int in range(40):
		await physics_frame
	check(player.global_position.x > x0 + 40.0, "it carries the wizard along (%d px)" % int(player.global_position.x - x0))
	Abilities.cast(player)
	check(ferry.rafts.size() == 1, "too soon to cast again")
	await until(func() -> bool: return ferry.readiness() >= 1.0, 2000)
	Abilities.cast(player)
	check(ferry.rafts.size() == 1 and ferry.rafts[0] != raft and (not is_instance_valid(raft) or raft.fading()), "ferry I keeps one raft: a new one sends the old one fading")
	check(await until(func() -> bool: return not is_instance_valid(raft), 2000), "and it is gone")
	Abilities.set_tier(player, &"ferry", 3)
	await until(func() -> bool: return ferry.readiness() >= 1.0, 2000)
	Abilities.cast(player)
	check(ferry.rafts.size() == 2 and is_equal_approx(ferry.speed, 230.0), "ferry III: two rafts at once, faster")
	var last: FerryRaft = ferry.rafts[-1]
	check(await within(func() -> bool: return not is_instance_valid(last), ferry.life + 2.0), "a raft fades when its life is out")
	finish()
