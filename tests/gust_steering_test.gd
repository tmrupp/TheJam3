extends SceneTree
## Up/down steer within a vane's crosswind; leaving it restores falling, without stored drift.
## godot --headless --path . --script res://tests/gust_steering_test.gd

class TestGust extends Wind:
	var direction: float = 1.0
	func blowing() -> float:
		return direction

var player: Player
var gust: TestGust
var failed: bool = false
const STEP: float = 1.0 / 60.0
const HOME: Vector2 = Vector2(-10000, -10000)


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)


func tick(frames: int) -> void:
	for i: int in range(frames):
		await physics_frame
		player._physics_process(STEP)
		await process_frame


func reset_player() -> void:
	for action: StringName in [&"Up", &"Down", &"Left", &"Right"]:
		Input.action_release(action)
	player.global_position = HOME + Vector2(700, 128)
	player.velocity = Vector2.ZERO
	for timer: ActionTimer in player.timers:
		timer.end()
	player.move_and_slide()


func run() -> void:
	MapInfo.save_path = "user://gust_steering_test.save"
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	while MapInfo.instance.world == null or MapInfo.instance.travelling:
		await process_frame
	player = main.get_node("Player")
	player.set_physics_process(false)
	gust = TestGust.new()
	gust.rect = Rect2(HOME, Vector2(1536, 256))
	main.add_child(gust)
	for wind_direction: float in [1.0, -1.0]:
		gust.direction = wind_direction
		reset_player()
		var before: Vector2 = player.global_position
		await tick(15)
		check(absf(player.global_position.y - before.y) < 1.0, "neutral input still glides level")
		check(absf(player.global_position.x - before.x - wind_direction * Wind.CARRY * STEP * 15) < 1.0,
			"horizontal carry keeps its speed in either direction")
		Input.action_press(&"Up")
		before = player.global_position
		await tick(15)
		check(player.global_position.y < before.y - 40.0, "Up climbs within the gust")
		Input.action_release(&"Up")
		before = player.global_position
		await tick(10)
		check(absf(player.global_position.y - before.y) < 1.0, "releasing Up holds the new height")
		Input.action_press(&"Down")
		before = player.global_position
		await tick(15)
		check(player.global_position.y > before.y + 40.0, "Down descends within the gust")
		await tick(40)
		Input.action_release(&"Down")
		check(player.global_position.y > gust.rect.end.y and player.global_position.x > gust.rect.position.x and player.global_position.x < gust.rect.end.x,
			"Down leaves through the bottom before the far edge")
		check(Wind.push_at(self, player.global_position) == Vector2.ZERO and player.velocity.y > 0.0,
			"normal falling resumes outside the gust")
		before = player.global_position
		await tick(10)
		check(absf(player.global_position.x - before.x) < 1.0, "horizontal carry stops outside the gust")

	reset_player()
	gust.direction = 0.0
	Input.action_press(&"Up")
	await tick(15)
	check(player.velocity.y > 0.0, "an inactive gust does not grant vertical steering")
	Input.action_release(&"Up")
	reset_player()
	gust.up = 4
	await tick(10)
	check(player.velocity.y < -200.0, "updraft lift still works")
	MapInfo.delete_save()
	print("FAILED" if failed else "PASS: gust steering")
	quit(1 if failed else 0)
