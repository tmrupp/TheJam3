extends SceneTree
## Close-ups of the parry guard's gleam sweeping across the wizard, at a few points of its window
## (the game slowed so the window can be caught).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_parry_guard.gd

const SIZE: int = 220
const FRAMES: int = 5


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	RunState.save_path = "user://capture_parry_guard.save"
	await process_frame
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	var player: Player = main.get_node("Player") as Player
	for i: int in range(60):
		await process_frame
	Abilities.set_tier(player, &"parry", 1)
	var guard: Parry = player.get_node("Parry") as Parry
	var shots: Array[Image] = []
	Engine.time_scale = 0.05
	player.parry.emit()
	var last: float = 2.0
	while guard.guard_left() >= 0.0 and shots.size() < FRAMES:
		await process_frame
		var left: float = guard.guard_left()
		if left >= 0.0 and last - left >= 1.0 / float(FRAMES + 1):
			last = left
			var sp: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * (player.global_position + Vector2(0, -30)))
			var x: int = clampi(int(sp.x) - SIZE / 2, 0, 1280 - SIZE)
			var y: int = clampi(int(sp.y) - SIZE / 2, 0, 720 - SIZE)
			shots.append(root.get_texture().get_image().get_region(Rect2i(x, y, SIZE, SIZE)))
	Engine.time_scale = 1.0
	var out: Image = Image.create(SIZE * shots.size(), SIZE, false, shots[0].get_format())
	for k: int in range(shots.size()):
		out.blit_rect(shots[k], Rect2i(0, 0, SIZE, SIZE), Vector2i(k * SIZE, 0))
	var output: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	out.save_png(output.path_join("parry_guard.png"))
	print("CAPTURED parry guard to ", output)
	quit()
