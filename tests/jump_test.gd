extends SceneTree
## Ground jumps expire after coyote time; learned air jumps remain available.
## godot --headless --path . --script res://tests/jump_test.gd

var player: Player
var failed: bool = false
const HOME: Vector2 = Vector2(-10000, -10000)
const STEP: float = 1.0 / 60.0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)


func tick(frames: int = 1) -> void:
	for i: int in range(frames):
		await physics_frame
		player._physics_process(STEP)
		await process_frame


func jump_input() -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"Jump"
	event.pressed = true
	Input.parse_input_event(event)
	await tick()
	Input.action_release(&"Jump")


func stand(max_jumps: int = 1) -> void:
	Input.action_release(&"Jump")
	player.MAX_JUMPS = max_jumps
	player.jumps = max_jumps
	player.global_position = HOME + Vector2(0, -45)
	player.velocity = Vector2.ZERO
	player.jump_held = false
	player.jumping = false
	for timer: ActionTimer in player.timers:
		timer.end()
		timer.refresh()
	await tick(16)
	check(player.is_on_floor(), "standing on the test ledge")


func leave_ledge() -> void:
	player.global_position.x = HOME.x + 400
	player.velocity = Vector2.ZERO
	player.move_and_slide()
	check(not player.is_on_floor(), "walked off the ledge")


func run() -> void:
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	RunState.save_path = "user://jump_test.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo")
	while info.world == null or info.travelling:
		await process_frame
	player = main.get_node("Player")
	player.set_physics_process(false)
	var ledge: StaticBody2D = StaticBody2D.new()
	ledge.collision_layer = 4
	ledge.position = HOME
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(400, 20)
	collider.shape = shape
	ledge.add_child(collider)
	root.add_child(ledge)
	await physics_frame

	await stand()
	leave_ledge()
	await jump_input()
	check(player.velocity.y < -500 and player.jumps == 0, "jumping just after leaving a ledge uses coyote time")
	await tick(2)
	await jump_input()
	check(player.buffer_jump.is_acting() and player.jumps == 0, "a coyote jump is spent once")

	await stand()
	await jump_input()
	await tick(2)
	await jump_input()
	check(player.buffer_jump.is_acting() and player.jumps == 0, "a ground jump does not rearm coyote time for an extra jump")

	await stand()
	leave_ledge()
	await tick(15)
	await jump_input()
	check(player.velocity.y > 0 and player.jumps == 0, "an unused ground jump expires after coyote time")

	await stand(2)
	leave_ledge()
	await tick(15)
	await jump_input()
	check(player.velocity.y < -500 and player.jumps == 0, "walking off preserves exactly the learned air jump")
	await tick(2)
	await jump_input()
	check(player.buffer_jump.is_acting() and player.jumps == 0, "the learned air jump is spent once")

	await stand(2)
	await jump_input()
	await tick(12)
	await jump_input()
	check(player.velocity.y < -500 and player.jumps == 0, "a normal ground jump still allows the learned second jump")

	await stand()
	leave_ledge()
	await tick(15)
	await jump_input()
	check(player.buffer_jump.is_acting(), "late input buffers a landing jump")
	player.global_position = HOME + Vector2(0, -41.5)
	player.velocity = Vector2(0, 100)
	await tick(4)
	check(player.velocity.y < 0 and player.jumps == 0, "a buffered landing jump consumes the ground jump")
	var velocity_before: float = player.velocity.y
	await jump_input()
	check(player.buffer_jump.is_acting() and player.jumps == 0 and player.velocity.y >= velocity_before,
		"a buffered jump does not leave an extra jump available")

	RunState.delete_save()
	print("FAILED" if failed else "PASS: jump availability")
	quit(1 if failed else 0)
