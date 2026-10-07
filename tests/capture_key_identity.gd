extends "res://tests/interaction_hints_test.gd"
## Review colour and monochrome key identities, matching locks, and a chasing wraith.

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	output = ProjectSettings.globalize_path("res://../art-captures/key-identity")
	DirAccess.make_dir_recursive_absolute(output)
	RunState.save_path = "user://capture_key_identity.save"
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	main.get_node("Menu").world_seed.text = "28"
	main.get_node("Menu").start_game()
	player = main.get_node("Player") as Player
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	await loaded()
	var base: Vector2 = Vector2(-2000, -2000)
	player.global_position = base + Vector2(-600, 0)
	camera.global_position = base
	camera.zoom = Vector2.ONE * 0.35
	camera.reset_smoothing()
	info.run.has_ghost = true
	info.run.ghost_coord = Vector2i(29, 3)
	info.run.ghost_stars = 12
	var gallery: InkCanvas = InkCanvas.new()
	main.add_child(gallery)
	gallery.position = base
	gallery.begin()
	for color: int in range(MapInfo.KEY_COLOR_COUNT):
		var at: Vector2 = Vector2((float(color) - 1.5) * 135.0, -100)
		var key: Node2D = load("res://prefabs/key.tscn").instantiate()
		key.set_meta(&"key_color", color)
		key.position = base + at
		info.map_elements.add_child(key)
		RisoMarks.padlock(gallery, at + Vector2(0, 65), color, 1.6, 1.0)
		gallery.ink(RisoPrint.EYE, 0.8, [RisoShapes.rrect(at.x - 40, at.y + 125, 80, 54, 12)])
		gallery.ink(RisoPrint.NIGHT, 1.0, RisoMarks.key_shape(at + Vector2(0, 151), 1.0, color), false)
	gallery.finish()
	await settle(50)
	await shot("keys_and_locks")
	gallery.queue_free()
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"cemetery"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await loaded()
	var wraith: Node2D = first("wraith_enemy.tscn")
	assert(wraith != null)
	wraith.global_position = base
	var chase: Node = wraith.get_node("Wraith")
	chase.set_physics_process(false)
	chase.set("awake", true)
	chase.set("stunned", false)
	chase.set("velocity", Vector2(95, 0))
	player.global_position = base + Vector2(140, 0)
	info.run.has_ghost = true
	info.run.ghost_coord = Vector2i(29, 4)
	info.run.ghost_stars = 12
	camera.global_position = base + Vector2(0, -40)
	camera.zoom = Vector2.ONE * 0.35
	camera.reset_smoothing()
	await settle(30)
	await shot("wraith_chasing")
	print("CAPTURED key identities and chasing wraith")
	quit()
