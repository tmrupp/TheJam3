extends SceneTree
## A strip of the wizard through a jump, every few frames from take-off to settling after the
## landing (the body bows; nothing squashes), then a warp's way in and out (the silhouette whirls).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_motion.gd

func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	RunState.save_path = "user://capture_motion.save"
	await process_frame
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	var player: Player = main.get_node("Player") as Player
	# A floor with headroom, three cells of open air over it and to each side.
	var w: LevelGen = info.world
	for v: Vector2i in w.empties:
		var open: bool = w.ground_below(v)
		for dx: int in range(-1, 2):
			for dy: int in range(0, 4):
				open = open and w.is_valid(v + Vector2i(dx, -dy)) and not w.is_ground(v + Vector2i(dx, -dy))
			open = open and w.is_ground(v + Vector2i(dx, 1))
		if open:
			player.global_position = info.cell_position(v)
			break
	for i: int in range(60):
		await physics_frame
	var output: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	var frames: Array[Image] = []
	var grab: Callable = func() -> Image:
		var sp: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * (player.global_position + Vector2(0, -60)))
		var x: int = clampi(int(sp.x) - 110, 0, 1280 - 220)
		var y: int = clampi(int(sp.y) - 150, 0, 720 - 260)
		return root.get_texture().get_image().get_region(Rect2i(x, y, 220, 260))
	frames.append(grab.call())
	var jump: InputEventAction = InputEventAction.new()
	jump.action = &"Jump"
	jump.pressed = true
	Input.parse_input_event(jump)
	var landed_at: int = -1
	for i: int in range(90):
		await physics_frame
		await process_frame
		if i == 2 or i == 8 or i == 16 or i == 26:
			frames.append(grab.call())
		if i > 4 and landed_at < 0 and player.is_on_floor():
			landed_at = i
		if landed_at >= 0 and (i == landed_at + 2 or i == landed_at + 5 or i == landed_at + 10 or i == landed_at + 20):
			frames.append(grab.call())
	Input.action_release(&"Jump")
	var strip: Image = Image.create(220 * frames.size(), 260, false, frames[0].get_format())
	for k: int in range(frames.size()):
		strip.blit_rect(frames[k], Rect2i(0, 0, 220, 260), Vector2i(k * 220, 0))
	strip.save_png(output.path_join("motion_jump.png"))
	# A warp: its way in and out.
	Abilities.set_tier(player, &"warp", 1)
	player.collect(20)
	var shots: Array[Image] = []
	Abilities.cast(player)
	for i: int in range(40):
		await process_frame
		if i == 6 or i == 12 or i == 17:
			shots.append(root.get_texture().get_image().get_region(Rect2i(440, 160, 400, 400)))
		if i == 24 or i == 30:
			shots.append(root.get_texture().get_image().get_region(Rect2i(440, 160, 400, 400)))
	var warp_strip: Image = Image.create(400 * shots.size(), 400, false, shots[0].get_format())
	for k: int in range(shots.size()):
		warp_strip.blit_rect(shots[k], Rect2i(0, 0, 400, 400), Vector2i(k * 400, 0))
	warp_strip.save_png(output.path_join("motion_warp.png"))
	RunState.delete_save()
	print("CAPTURED motion strips to ", output)
	quit()
