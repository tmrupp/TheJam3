extends TestKit
## The institute's rolling ladders (RollingLadder), laid where other bands lay lifts and in the
## libraries: in the layout (none of its lifts left, each ladder's track running right, its foot on
## solid ground all along it, the garden's lifts as they were), and in play: its step as wide as the
## ladder, standing still until ridden; up on one takes hold, held it stays put until the wizard
## presses a way, then rolls that way with them while they climb, climbed to the top they stand on
## its step, down from the step climbs back down under it, and a jump lets go.
## godot --headless --path . --script res://tests/ladder_test.gd


func run() -> void:
	_layout()
	await boot()
	await _climb()
	finish()


func _layout() -> void:
	print("ladders in the layout")
	var ladders: int = 0
	var lifts: int = 0
	var right: bool = true
	var grounded: bool = true
	for world: int in [28, 7, 99]:
		for k: int in range(2):
			var at: Vector2i = Vector2i(world, NextWorldDef.band_row(&"institute", k))
			var w: LevelGen = build(at)
			lifts += w.objects_of(LevelGen.Type.MOVING_PLATFORM).size()
			for v: Vector2i in w.objects_of(LevelGen.Type.ROLLING_LADDER):
				ladders += 1
				var extra: Array = w.get_cell(v).extra_info
				right = right and extra[1] == Vector2i(1, 0)
				# Its foot on rock in every column along its track.
				var foot: int = v.y + RollingLadder.hang(w, v, int(extra[0]), int(extra[2]))
				for x: int in range(v.x, v.x + int(extra[2]) + 1):
					grounded = grounded and w.is_ground(Vector2i(x, foot))
			check_eq(build(at).objects, w.objects, "%s: the same every visit" % at)
	check(ladders > 0 and lifts == 0, "the institute has rolling ladders (%d) and no lifts" % ladders)
	check(right, "each ladder rolls along a track running right")
	check(grounded, "each ladder's foot stands on solid ground all along its track")
	var garden: LevelGen = build(Vector2i(28, 1))
	check(garden.objects_of(LevelGen.Type.ROLLING_LADDER).is_empty(), "the garden keeps its lifts, no ladders")


func _climb() -> void:
	print("climbing a ladder")
	var ladder: RollingLadder = null
	for world: int in [28, 7, 99, 3]:
		for k: int in range(3):
			await _go(Vector2i(world, NextWorldDef.band_row(&"institute", k)))
			for node: Node in placed("rolling_ladder.tscn"):
				var found: RollingLadder = node as RollingLadder
				if found.rungs >= 3 and found.travel > 0.0:
					ladder = found
					break
			if ladder != null:
				break
		if ladder != null:
			break
	check(ladder != null, "a ladder three cells long or more")
	if ladder == null:
		return
	# Nothing to fight while climbing.
	for node: Node in info.map_elements.get_children():
		if node is Scholar or node is Abomination:
			node.queue_free()
	await physics_frame
	player.end_invulnerable()
	var shape: RectangleShape2D = (ladder.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	check_eq(shape.size.x, RollingLadder.WIDTH, "its step is as wide as the ladder")
	var parked: float = ladder.global_position.x
	await frames(30)
	check_eq(ladder.global_position.x, parked, "left alone, it stands still")
	# Halfway down it, in the air: up takes hold.
	var lift: float = player._feet_y() - player.global_position.y
	player.global_position = Vector2(ladder.ladder_x(), (ladder.top_y() + ladder.foot_y()) * 0.5 - lift)
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	Input.action_press(&"Up")
	await until(func() -> bool: return player.ladder == ladder, 3000)
	check(player.ladder == ladder, "up on the ladder takes hold of it")
	Input.action_release(&"Up")
	await physics_frame
	var from: float = ladder.global_position.x
	await frames(10)
	check(player.ladder == ladder and ladder.global_position.x == from, "held with no way pressed, it stays put")
	# Pressing a way rolls it that way (towards the more room on its track), the wizard with it,
	# climbing all the while.
	var way: StringName = &"Right" if ladder.along < ladder.travel * 0.5 else &"Left"
	Input.action_press(way)
	Input.action_press(&"Up")
	await physics_frame
	var held: bool = true
	var rose: bool = false
	var feet: float = player._feet_y()
	for i: int in range(20):
		await physics_frame
		if player.ladder != ladder:
			break
		held = held and absf(player.global_position.x - ladder.ladder_x()) < 8.0
		rose = rose or player._feet_y() < feet - 20.0
	var rolled: float = (ladder.global_position.x - from) * (1.0 if way == &"Right" else -1.0)
	check(held and rolled > 4.0, "pressing a way rolls it that way, the wizard with it (%.0f px)" % rolled)
	check(rose, "climbing as it rolls")
	Input.action_release(way)
	await within(func() -> bool: return player.ladder == null and player.is_on_floor(), 6.0)
	check(player.ladder == null and player.is_on_floor() and absf(player._feet_y() - ladder.top_y()) < 6.0, "climbed to the top, they stand on its step")
	Input.action_release(&"Up")
	await physics_frame
	await within(func() -> bool: return player.ladder_rest <= 0.0, 1.0)
	# Down from the step climbs back down under it.
	Input.action_press(&"Down")
	await until(func() -> bool: return player.ladder == ladder, 3000)
	await frames(10)
	check(player.ladder == ladder and player._feet_y() > ladder.top_y() + 30.0, "down from the step climbs down the ladder")
	Input.action_release(&"Down")
	await physics_frame
	Input.action_press(&"Jump")
	await physics_frame
	await physics_frame
	check(player.ladder == null and player.velocity.y < 0.0, "a jump lets go")
	Input.action_release(&"Jump")
	player.set_physics_process(false)


func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
