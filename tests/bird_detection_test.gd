extends SceneTree
## Swoops require a nearby wizard and a visible bird; camera lag cannot produce a blind dive.

var failed: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, what: String) -> void:
	print("  ok   " if ok else "FAIL  ", what)
	failed = failed or not ok

func run() -> void:
	RunState.save_path = "user://bird_detection_test.save"
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	while MapInfo.instance.world == null or MapInfo.instance.travelling:
		await process_frame
	var player: Player = main.get_node("Player")
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	# Test sensing in an empty arena, independently of the collapsed terrain's arc clearance.
	MapInfo.instance.world = null
	var camera: Camera2D = main.get_node("Camera2D")
	camera.limit_left = -100000
	camera.limit_right = 100000
	camera.limit_top = -100000
	camera.limit_bottom = 100000
	camera.zoom = Vector2.ONE * 0.25
	var body: Node2D = load("res://prefabs/bird_enemy.tscn").instantiate()
	main.add_child(body)
	var bird: Bird = body.get_node("Bird")
	bird.set_physics_process(false)
	body.global_position = Vector2(4000, 4000)
	bird.height = 4000
	bird.span = Vector2(3500, 4500)
	bird.since_swoop = 99
	camera.global_position = body.global_position + Vector2(0, 100)
	camera.reset_smoothing()
	camera.force_update_scroll()
	player.global_position = body.global_position + Vector2(0, 600)
	bird._look()
	check(not bird.swooping(), "a wizard far below does not trigger a swoop")
	player.global_position = body.global_position + Vector2(400, 200)
	bird._look()
	check(not bird.swooping(), "a wizard far across does not trigger a swoop")
	player.global_position = body.global_position + Vector2(60, 200)
	camera.global_position = body.global_position + Vector2(0, 700)
	camera.reset_smoothing()
	camera.force_update_scroll()
	bird._look()
	check(not bird.swooping(), "a nearby bird outside a lagging camera waits")
	camera.global_position = player.global_position
	camera.reset_smoothing()
	camera.force_update_scroll()
	bird._look()
	check(bird.swooping(), "a visible bird starts a dive when the wizard is close below")
	check(bird.arc.size() == 3 and bird.arc[1].y > player.global_position.y, "the dive still passes through the wizard's height")
	RunState.delete_save()
	print("FAILED" if failed else "PASS: bird detection")
	quit(1 if failed else 0)
