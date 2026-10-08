extends TestKit
## A dormant worm wakes at its full activation distance, even when its burrow is outside the
## camera's awake chunks. World 42 has an open floor at that boundary above its original burrow.
## godot --headless --path . --script res://tests/worm_wake_test.gd


func run() -> void:
	MapInfo.debug = false
	await boot(42)
	info.coord = Vector2i(42, NextWorldDef.GARDEN_ROWS)
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	var worms: Array[Node] = placed("worm.tscn")
	check(worms.size() == 1, "the gate level places its worm")
	if worms.is_empty():
		finish()
		return
	var worm: Worm = worms[0] as Worm
	var spot: Vector2i = Vector2i(-1, -1)
	for floor_cell: Vector2i in info.world.free_floors():
		if LevelGen.dist(floor_cell, worm.home) != Worm.WAKE_RANGE:
			continue
		player.global_position = info.cell_position(floor_cell)
		info.loader.wake_around(player.global_position)
		if not info.loader.is_awake(worm):
			spot = floor_cell
			break
	check(spot != Vector2i(-1, -1) and not worm.awake, "a floor at the activation boundary lies outside the burrow's awake chunks")
	if spot == Vector2i(-1, -1):
		finish()
		return
	check(worm.process_mode == Node.PROCESS_MODE_INHERIT and worm.visible, "the dormant boss can process its wake-up there")
	check(await until(func() -> bool: return worm.awake, 2000), "the player at the boundary wakes it without moving closer")
	check(await until(func() -> bool: return worm.pieces[0].segments[0].live, 6000), "it warns and emerges normally")
	var far: Variant = LevelGen.best_of(info.world.free_floors(), func(v: Vector2i) -> int: return -LevelGen.dist(v, worm.home))
	player.global_position = info.cell_position(far as Vector2i)
	info.loader.wake_around(player.global_position)
	check(worm.process_mode == Node.PROCESS_MODE_INHERIT and worm.visible, "once awakened it keeps pursuing when the player leaves the activation range")
	RunState.delete_save()
	finish()
