extends SceneTree
## Walls: falling while pressed against a wall (holding toward it) slides down it no faster than
## Player.WALL_SLIDE_SPEED, and a jump in the air against a wall is a wall jump, before an air
## jump (which is kept for later).
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
	var w: MapInfo.World = info.world
	# Open air: nothing there, or only a star.
	var air: Callable = func(c: Vector2i) -> bool: return w.is_valid(c) and w.get_cell(c).type in [MapInfo.Type.EMPTY, MapInfo.Type.COIN]
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


func run() -> void:
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://wall_test.save"
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

	MapInfo.delete_save()
	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASS: wall slide and wall jump")
		quit()
