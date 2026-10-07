extends SceneTree
## Walls: falling while pressed against a wall (holding toward it) slides down it no faster than
## Player.WALL_SLIDE_SPEED, and a jump in the air against a wall is a wall jump, before an air
## jump (which is kept for later). Repeated jumps from the same side keep pushing away without
## lifting the wizard or slowing their fall; alternating sides lifts them through a two-cell gap.
## godot --headless --path . --script res://tests/wall_test.gd

var main: Node
var info: MapInfo
var player: Player
var failed: bool = false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)


func settle(frames: int = 4) -> void:
	await process_frame
	var deadline: int = Time.get_ticks_msec() + 30000
	while (info.world == null or info.travelling) and Time.get_ticks_msec() < deadline:
		await process_frame
	for i: int in range(frames):
		await physics_frame
		await process_frame


## An open cell with a wall of rock to its right, and open air under it, for `tall` cells: the
## wizard can fall down the wall.
func wall_spot(tall: int) -> Variant:
	var w: LevelGen = info.world
	# Open air: nothing there, or only a star.
	var air: Callable = func(c: Vector2i) -> bool: return w.is_valid(c) and w.get_cell(c).type in [LevelGen.Type.EMPTY, LevelGen.Type.COIN]
	var spots: Array[Vector2i] = []
	for v: Vector2i in w.empties:
		spots.append(v)
	spots.sort()
	for v: Vector2i in spots:
		var ok: bool = true
		for dy: int in range(0, tall):
			var c: Vector2i = v + Vector2i(0, dy)
			if not air.call(c) or not w.is_ground(c + Vector2i.RIGHT):
				ok = false
				break
		if ok:
			return v
	return null


func hold(action: StringName, frames: int) -> void:
	Input.action_press(action)
	for i: int in range(frames):
		await physics_frame
	Input.action_release(action)


## A tall, empty wall or two-cell shaft, clear of the generated level's hazards.
func test_wall(at: Vector2, size: Vector2) -> void:
	var solid: StaticBody2D = StaticBody2D.new()
	solid.collision_layer = 4
	solid.collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	solid.add_child(shape)
	main.add_child(solid)
	solid.global_position = at


func jump_press() -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"Jump"
	event.pressed = true
	Input.parse_input_event(event)
	await physics_frame
	await process_frame
	await physics_frame


## Wait until the movement has reached the requested side of the shaft.
func reach_wall(side: float) -> bool:
	for i: int in range(90):
		await physics_frame
		await process_frame
		if player.is_on_wall() and signf(player.get_wall_normal().x) == side:
			return true
	return false


func run() -> void:
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	RunState.save_path = "user://wall_test.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	await process_frame
	await process_frame
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	player = main.get_node("Player") as Player
	await settle()

	var spot: Variant = wall_spot(4)
	check(spot != null, "a wall to fall down")
	if spot == null:
		quit(1)
		return
	var top: Vector2 = info.cell_position(spot)

	print("sliding down a wall")
	player.global_position = top
	player.velocity = Vector2.ZERO
	Input.action_press(&"Right")
	var fastest: float = 0.0
	for i: int in range(40):
		await physics_frame
		if not player.is_on_floor():
			fastest = maxf(fastest, player.velocity.y)
	Input.action_release(&"Right")
	check(fastest > 0.0 and fastest <= Player.WALL_SLIDE_SPEED + 1.0, "holding toward the wall, the fall is slowed (%d)" % fastest)
	player.global_position = top + Vector2(-20, 0)
	player.velocity = Vector2.ZERO
	var free_fall: float = 0.0
	for i: int in range(40):
		await physics_frame
		if not player.is_on_floor():
			free_fall = maxf(free_fall, player.velocity.y)
	check(free_fall > Player.WALL_SLIDE_SPEED * 1.5, "not holding toward it, it falls as usual (%d)" % free_fall)

	print("wall jump before an air jump")
	Abilities.grant(player, &"double_jump")
	player.global_position = top
	player.velocity = Vector2.ZERO
	Input.action_press(&"Right")
	for i: int in range(6):
		await physics_frame
	player.jumps = 1
	check(not player.is_on_floor(), "in the air against the wall")
	# As a real event, so the jump reads as just pressed in the next physics frame.
	var press: InputEventAction = InputEventAction.new()
	press.action = &"Jump"
	press.pressed = true
	Input.parse_input_event(press)
	await physics_frame
	await physics_frame
	Input.action_release(&"Right")
	Input.action_release(&"Jump")
	check(player.velocity.x < 0.0 and player.wall_jump.is_acting(), "a jump against the wall springs off it (%s)" % player.velocity)
	check(player.jumps == 1, "and the air jump is kept for later")

	print("one wall cannot be climbed by repeated jumps")
	var origin: Vector2 = Vector2(-10000, -10000)
	test_wall(origin + Vector2(272, 0), Vector2(32, 3000))
	player.global_position = origin + Vector2(220, 0)
	player.velocity = Vector2.ZERO
	player.MAX_JUMPS = 1
	player.jumps = 0
	player.last_wall_jump_side = 0.0
	player.wall_jump.end()
	player.coyote.end()
	Input.action_press(&"Right")
	check(await reach_wall(-1.0), "touching the isolated right wall")
	await jump_press()
	check(player.wall_jump.is_acting() and player.velocity.x < -500.0, "the wall jump launches sideways at 600 px/s")
	Input.action_release(&"Jump")
	check(await reach_wall(-1.0), "steering back reaches the same wall")
	var repeat_y: float = player.global_position.y
	player.MAX_JUMPS = 2
	player.jumps = 1
	for i: int in range(3):
		var falling_speed: float = player.velocity.y
		await jump_press()
		check(player.wall_jump.is_acting() and player.velocity.x < -500.0, "same-wall jump %d still pushes away" % (i + 1))
		check(player.velocity.y >= clampf(falling_speed, 0.0, Player.WALL_SLIDE_SPEED), "same-wall jump %d adds no height or falling slowdown beyond the wall slide" % (i + 1))
		check(player.jumps == 1, "same-wall jump %d keeps the learned air jump" % (i + 1))
		Input.action_release(&"Jump")
		check(await reach_wall(-1.0), "return %d reaches the same wall" % (i + 1))
		check(player.global_position.y >= repeat_y, "repeat %d cannot climb the wall" % (i + 1))
	player.MAX_JUMPS = 1
	player.jumps = 0
	Input.action_release(&"Right")
	player.velocity.y = 200.0
	player.do_wall_jump(Vector2.LEFT)
	check(is_equal_approx(player.velocity.y, 200.0) and not player.jumping, "the sideways kick preserves falling speed and cannot cut it on release")
	player.velocity.y = -200.0
	player.do_wall_jump(Vector2.LEFT)
	check(player.velocity.y == 0.0, "another kick from the same wall cannot carry upward motion into a climb")

	print("alternating walls climbs a two-cell shaft")
	test_wall(origin + Vector2(-16, 0), Vector2(32, 3000))
	test_wall(origin + Vector2(128, 500), Vector2(256, 32))
	player.global_position = origin + Vector2(220, 0)
	player.velocity = Vector2.ZERO
	player.last_wall_jump_side = 0.0
	Input.action_press(&"Right")
	check(await reach_wall(-1.0), "at the right side of a 256 px gap")
	var start_y: float = player.global_position.y
	var side: float = -1.0
	for i: int in range(4):
		Input.action_release(&"Jump")
		await physics_frame
		await process_frame
		await jump_press()
		check(player.wall_jump.is_acting(), "alternating jump %d is allowed" % (i + 1))
		Input.action_release(&"Right" if side < 0.0 else &"Left")
		Input.action_press(&"Left" if side < 0.0 else &"Right")
		side = -side
		check(await reach_wall(side), "jump %d reaches the opposite wall" % (i + 1))
	check(player.global_position.y < start_y - 100.0, "four alternating jumps climb the shaft (%.1f px)" % (start_y - player.global_position.y))
	Input.action_release(&"Jump")
	Input.action_release(&"Left")
	Input.action_release(&"Right")
	player.global_position = origin + Vector2(128, 440)
	player.velocity = Vector2.ZERO
	for i: int in range(20):
		await physics_frame
		await process_frame
	check(player.is_on_floor() and player.last_wall_jump_side == 0.0, "landing permits jumps from either wall again")

	RunState.delete_save()
	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASS: wall slide and wall jump")
		quit()
