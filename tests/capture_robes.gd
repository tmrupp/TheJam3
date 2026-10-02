extends SceneTree
## The wizard's robe in each spell's ink, then in plain blue for comparison.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_robes.gd

const LOOKS: Array[StringName] = [&"hex", &"astral", &"parry", &"levitate", &"awareness", &"rift", &""]


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://test_run.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	for i: int in range(5):
		await process_frame
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	for i: int in range(40):
		await process_frame
	var player: Player = main.get_node("Player") as Player
	player.get_node("CameraControl").set_process(false)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	camera.zoom *= 3.0
	var riso: RisoPrint = RisoPrint.instance
	var shots: Array[Image] = []
	for look: int in range(LOOKS.size() + 1):
		for a: StringName in Abilities.SPELLS:
			player.tiers[a] = 0
		if look < LOOKS.size() and LOOKS[look] != &"":
			player.tiers[LOOKS[look]] = 1
		riso.robe_by_spell = look < LOOKS.size()
		riso.robe_color = Color(-1, -1, -1)
		for i: int in range(6):
			camera.global_position = player.global_position + Vector2(0, -30)
			camera.reset_smoothing()
			await process_frame
		await RenderingServer.frame_post_draw
		shots.append(root.get_texture().get_image().get_region(Rect2i(540, 210, 200, 260)))
	var strip: Image = Image.create(200 * shots.size(), 260, false, shots[0].get_format())
	for k: int in range(shots.size()):
		strip.blit_rect(shots[k], Rect2i(0, 0, 200, 260), Vector2i(k * 200, 0))
	var out: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	strip.save_png(out.path_join("robes.png"))
	print("CAPTURED robes: %s, then blue" % [LOOKS])
	quit()
