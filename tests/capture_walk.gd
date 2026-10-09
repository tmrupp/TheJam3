extends TestKit
## Film the default traveler under real physics (standing, starting a run, stopping, jumping and
## landing) as one contact sheet, to judge its walk and swinging parts frame by frame.
## Run windowed: godot --path . --windowed --resolution 1280x720 --script res://tests/capture_walk.gd.

## The sheet goes with the other art captures, outside the project.
const OUTPUT: String = "res://../art-captures/walk.png"
## One frame's crop around the figure, and frames per row.
const CELL: Vector2i = Vector2i(220, 240)
const COLS: int = 8
## Each step of the script: the action held (or none), for how many physics frames, filmed every n.
const PLAN: Array = [
	["", 6, 6], ["Right", 24, 2], ["", 36, 4], ["Jump", 8, 4], ["", 50, 5],
]


func run() -> void:
	window()
	await boot()
	player.end_invulnerable()
	info.run.vulnerable = false
	Abilities.set_tier(player, &"hex", 1)
	RisoPrint.instance.registration = &"locked"
	var camera: Camera2D = Stage.camera()
	player.get_node("CameraControl").set_process(false)
	camera.set_process(false)
	camera.set_physics_process(false)
	camera.position_smoothing_enabled = false
	camera.drag_horizontal_enabled = false
	camera.drag_vertical_enabled = false
	camera.zoom = Vector2.ONE * 0.36
	camera.limit_left = -100000
	camera.limit_top = -100000
	camera.limit_right = 100000
	camera.limit_bottom = 100000
	# Levels are cramped, so the run happens on a long bare platform far above the level.
	var ground: StaticBody2D = StaticBody2D.new()
	ground.collision_layer = player.collision_mask
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(6000, 40)
	shape.shape = rect
	ground.add_child(shape)
	ground.global_position = Vector2(0, -6000)
	main.add_child(ground)
	player.global_position = Vector2(-600, -6060)
	await frames(20)
	var shots: Array[Image] = []
	for step: Array in PLAN:
		var action: String = step[0]
		if action != "":
			Input.action_press(action)
		for f: int in range(int(step[1])):
			await physics_frame
			if f % int(step[2]) == 0:
				camera.global_position = player.global_position + Vector2(0, -30)
				await RenderingServer.frame_post_draw
				var full: Image = root.get_texture().get_image()
				var size: Vector2i = full.get_size()
				shots.append(full.get_region(Rect2i(size.x / 2 - CELL.x / 2, size.y / 2 - CELL.y / 2 + 20, CELL.x, CELL.y)))
		if action != "":
			Input.action_release(action)
	var rows: int = int(ceil(float(shots.size()) / COLS))
	var sheet: Image = Image.create(CELL.x * COLS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	for i: int in range(shots.size()):
		shots[i].convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shots[i], Rect2i(Vector2i.ZERO, CELL), Vector2i((i % COLS) * CELL.x, (i / COLS) * CELL.y))
	var path: String = ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	sheet.save_png(path)
	print("CAPTURED ", shots.size(), " frames: ", path)
	finish()
