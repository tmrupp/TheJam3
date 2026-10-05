extends "res://tests/interaction_hints_test.gd"
## F7 fog selection in a real cemetery, shared sleep behaviour and rendered comparisons.

func freeze_enemy(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is Area2D:
		(node as Area2D).collision_mask = 0
	for child: Node in node.get_children():
		freeze_enemy(child)

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	output = ProjectSettings.globalize_path("res://../art-captures/fog-shapes")
	DirAccess.make_dir_recursive_absolute(output)
	MapInfo.save_path = "user://fog_styles_test.save"
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	main.get_node("Menu").world_seed.text = "28"
	main.get_node("Menu").start_game()
	player = main.get_node("Player") as Player
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.invulnerable.enable()
	await loaded()
	info.coord = Vector2i(28, 3)
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await loaded()
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file().contains("enemy"):
			freeze_enemy(node)
	var fog: SleepFog = first("sleep_fog.tscn") as SleepFog
	assert(fog != null)
	fog.set_physics_process(false)
	fog.home = fog.global_position
	fog.phase = 0.0
	fog.t = 0.0
	player.global_position = fog.middle() + Vector2(-120, 40)
	camera.global_position = fog.middle()
	camera.zoom = Vector2.ONE * 0.25
	camera.reset_smoothing()
	await settle(60)
	var art: Node = fog.get_node("RisoArt")
	art.set_process(false)
	art.set("phase", 0.5)
	var riso: RisoPrint = RisoPrint.instance
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_F7
	key.pressed = true
	riso._unhandled_key_input(key)
	check(riso.panel.visible, "F7 opens the controls")
	var picker: OptionButton = (riso.get("_options") as Dictionary)[&"fog"] as OptionButton
	check(picker.item_count == 7, "five concepts, the blend and original mist are offered")
	check(picker.get_item_text(picker.selected) == "Torn ribbons", "ribbons are the default selection")
	check(is_equal_approx(riso.specks, 0.2) and (riso.get("_specks_label") as Label).text == "20%", "Specks defaults to 20% in the renderer and F7")
	var outside: Vector2 = fog.middle() + Vector2(310, 0)
	var inside: Vector2 = fog.middle()
	var outlines: Dictionary = {}
	for i: int in range(RisoPrint.FOG_STYLES.size()):
		picker.select(i)
		picker.item_selected.emit(i)
		check(riso.fog_style == RisoPrint.FOG_STYLES[i], "F7 selects " + picker.get_item_text(i))
		if riso.fog_style != &"original":
			var shapes: Array[PackedVector2Array] = RisoProp.FOG_ART.silhouette(2.0, 0.5, riso.fog_style)
			var fingerprint: int = hash(shapes)
			check(not outlines.has(fingerprint), "cloud has a distinct silhouette")
			outlines[fingerprint] = true
			check(shapes != RisoProp.FOG_ART.silhouette(5.0, 0.5, riso.fog_style), "cloud contour animates")
		check(fog.covers(inside) and not fog.covers(outside), "style keeps the same sleep boundary")
		fog._physics_process(0.0)
		check(player.is_drowsy(), "sleep effect remains active")
		riso._sync_panel()
		check(picker.selected == i, "panel selection stays in sync")
		riso.panel.visible = false
		for frame: int in range(3):
			art.set("t", 2.0 + float(frame) * 1.5)
			art.call("_redraw")
			await process_frame
			await shot("%s_%d" % [riso.fog_style, frame])
	# Show the new row in the scrolled F7 panel as well.
	riso.fog_style = &"shroud"
	riso._sync_panel()
	riso.panel.visible = true
	var scroll: ScrollContainer = riso.panel.get_child(0) as ScrollContainer
	await process_frame
	scroll.ensure_control_visible(picker)
	await process_frame
	await shot("f7_fog_selector")
	print("FAIL: fog styles" if failed else "PASS: fog styles")
	quit(1 if failed else 0)
