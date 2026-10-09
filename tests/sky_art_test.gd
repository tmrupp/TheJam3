extends SceneTree
## suite: window
## Sparse, deterministic underside decor stays clear of obstacles; render the sky and check
## transition coverage at every screen edge, including small camera/print alignment shifts.
## Run with a renderer, --fixed-fps 60 --script res://tests/sky_art_test.gd.

var failed: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, what: String) -> void:
	print("  ok   " if ok else "FAIL  ", what)
	failed = failed or not ok

func run() -> void:
	var solid: Dictionary = {}
	for x: int in range(100):
		solid[Vector2i(x, 2)] = true
	solid[Vector2i(12, 5)] = true
	var occupied: Dictionary = {Vector2i(8, 3): true, Vector2i(24, 6): true}
	var bounds: Rect2i = Rect2i(0, 0, 100, 10)
	var plan: Array[Dictionary] = RisoDecor.plan_sky(solid, occupied, 28, bounds)
	var hangs: Array[Dictionary] = plan.filter(func(it: Dictionary) -> bool: return it.has("clearance"))
	check(hangs.size() >= 25 and hangs.size() <= 65, "%d scattered danglers along 100 underside cells" % hangs.size())
	var cloud_plan: Array[Dictionary] = RisoDecor.plan_sky(solid, occupied, 28, bounds, &"clouds")
	check(not cloud_plan.any(func(it: Dictionary) -> bool: return it.has("clearance")), "cloud-only undersides have no dangling roots or tendrils")
	var mixed: Array[Dictionary] = RisoDecor.plan_sky(solid, occupied, 28, bounds, &"clouds_roots")
	check(mixed.filter(func(it: Dictionary) -> bool: return it.has("clearance")).size() < hangs.size(), "clouds with roots use still fewer danglers")
	check(plan == RisoDecor.plan_sky(solid, occupied, 28, bounds), "undersides are deterministic")
	check(plan != RisoDecor.plan_sky(solid, occupied, 29, bounds), "another seed varies the curtains")
	var clear: bool = true
	for it: Dictionary in hangs:
		for d: int in range(it["clearance"]):
			var cell: Vector2i = it["cell"] + Vector2i(0, d)
			clear = clear and bounds.has_point(cell) and not solid.has(cell) and not occupied.has(cell)
	check(clear, "danglers stop before terrain, structures and the level edge")

	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var output: String = ProjectSettings.globalize_path("res://../art-captures/sky-art")
	DirAccess.make_dir_recursive_absolute(output)
	RunState.save_path = "user://sky_art_test.save"
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo")
	while info.world == null or info.travelling:
		await process_frame
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"sky"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	while info.travelling:
		await process_frame
	var player: Player = main.get_node("Player")
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	var cam: Camera2D = main.get_node("Camera2D")
	cam.limit_left = -100000
	cam.limit_right = 100000
	cam.limit_top = -100000
	cam.limit_bottom = 100000
	var decor: RisoDecor = main.get_node("RisoDecor")
	var curtain: Dictionary = {}
	var widest: int = 0
	for it: Dictionary in decor.items:
		if it["kind"] == &"sky_roots" and it["clearance"] == 4:
			var width: int = 0
			for dx: int in range(-3, 4):
				if info.world.is_ground(it["base"] + Vector2i(dx, 0)):
					width += 1
			if width > widest:
				widest = width
				curtain = it
	check(not curtain.is_empty(), "scattered root bundles in a generated sky world")
	if not curtain.is_empty():
		cam.zoom = Vector2.ONE * 0.24
		cam.global_position = info.cell_position(curtain["cell"]) + Vector2(0, 40)
		player.global_position = info.cell_position(curtain["base"]) + Vector2(0, -120)
		cam.reset_smoothing()
		for i: int in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("danglers.png"))
		var riso: RisoPrint = RisoPrint.instance
		var picker: OptionButton = riso._options[&"sky_bottoms"]
		var tiles: Array[Vector2i] = info.tile_map.get_used_cells(0)
		var previous_body: Array = riso.terrain.get("ink")._ops[0].polys.duplicate()
		for style: int in [1, 2, 3]:
			picker.select(style)
			picker.item_selected.emit(style)
			for i: int in range(6):
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("bottoms-%s.png" % RisoPrint.SKY_BOTTOM_STYLES[style]))
			check(info.tile_map.get_used_cells(0) == tiles, "switching sky bottoms leaves collision tiles unchanged")
		check(riso.terrain.get("ink")._ops[0].polys != previous_body, "cloud contours rebuild immediately from the F7 picker")
		picker.select(0)
		picker.item_selected.emit(0)
		check(riso.terrain.get("ink")._ops[0].polys == previous_body, "switching back restores the same seeded terrain contour")
	player.global_position = Vector2(-9000, -9000)
	cam.zoom = Vector2.ONE * 0.018
	cam.global_position = info.cell_position(info.world.size / 2)
	cam.reset_smoothing()
	for i: int in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("clusters.png"))

	# Flood the old scene with reward ink: none may remain when the sheet is fully over it.
	var sentinel: InkCanvas = InkCanvas.new()
	sentinel.z_as_relative = false
	sentinel.z_index = 57
	main.add_child(sentinel)
	sentinel.begin()
	sentinel.ink(RisoPrint.EYE, 1.0, [PackedVector2Array([Vector2(-100000, -100000), Vector2(100000, -100000), Vector2(100000, 100000), Vector2(-100000, 100000)])], false)
	sentinel.finish()
	var sheet: RisoTransition = RisoTransition.instance
	sheet.set_process(false)
	sheet.state = RisoTransition.State.COVERED
	sheet.lead = 1.0 + RisoTransition.EDGE
	sheet.trail = 0.0
	sheet.destination = Vector2i(28, 1)
	cam.zoom = Vector2.ONE * 0.25
	var clean: bool = true
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		for shift: Vector2 in [Vector2.ZERO, Vector2(-8, -8), Vector2(8, 8)]:
			cam.global_position += Vector2(1750, -1200)
			cam.reset_smoothing()
			cam.force_update_scroll()
			sheet.sweep = direction
			sheet._process(0)
			sheet.global_position += shift / cam.zoom
			for i: int in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			var plate: Image = RisoPrint.instance.plates[RisoPrint.EYE].get_texture().get_image()
			for y: int in range(0, plate.get_height(), 8):
				for x: int in [0, 1, plate.get_width() - 2, plate.get_width() - 1]:
					clean = clean and plate.get_pixel(x, y).a < 0.01
			for x: int in range(0, plate.get_width(), 8):
				for y: int in [0, 1, plate.get_height() - 2, plate.get_height() - 1]:
					clean = clean and plate.get_pixel(x, y).a < 0.01
	check(clean, "all four transition directions hide the previous world's edge ink")
	root.get_texture().get_image().save_png(output.path_join("transition-covered.png"))
	RunState.delete_save()
	print("FAILED" if failed else "PASS: sky art and transition edges")
	quit(1 if failed else 0)
