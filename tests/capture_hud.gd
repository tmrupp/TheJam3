extends SceneTree
## Windowed stills of the printed HUD in its states: a fresh run; then carrying a key with
## upgraded tiers, a ghost in another world and the vulnerable state; then a debug run.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_hud.gd

func _initialize() -> void:
	call_deferred("capture")


func shot(name: String, frames: int = 20) -> void:
	for i: int in range(frames):
		await process_frame
	var out: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	DirAccess.make_dir_recursive_absolute(out)
	var img: Image = root.get_texture().get_image()
	img.save_png(out.path_join(name))
	# The two top corners side by side, enlarged.
	var k: float = float(img.get_width()) / 320.0
	var left: Image = img.get_region(Rect2i(0, 0, int(150 * k), int(46 * k)))
	var right: Image = img.get_region(Rect2i(int(170 * k), 0, int(150 * k), int(46 * k)))
	var both: Image = Image.create(left.get_width() * 2 + 8, left.get_height(), false, img.get_format())
	both.fill(Color.WHITE)
	both.blit_rect(left, Rect2i(Vector2i.ZERO, left.get_size()), Vector2i.ZERO)
	both.blit_rect(right, Rect2i(Vector2i.ZERO, right.get_size()), Vector2i(left.get_width() + 8, 0))
	both.resize(both.get_width() * 2, both.get_height() * 2, Image.INTERPOLATE_NEAREST)
	both.save_png(out.path_join(name.replace(".png", "_corners.png")))


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
	var player: Player = main.get_node("Player") as Player
	await shot("hud_fresh.png", 30)
	player.collect(128)
	player.set_meta(&"carried_key", 1)
	Abilities.grant(player, &"double_jump")
	Abilities.grant(player, &"hex")
	Abilities.grant(player, &"vigor")
	player.health.health = 2
	player.health.display_health()
	player.die()
	while info.travelling:
		await process_frame
	info.travel(MapInfo.Exit.DEEPER)
	while info.travelling:
		await process_frame
	player.set_physics_process(false)
	(player.get_node("Hex") as Hex).charges = 1
	await shot("hud_busy.png")
	print("CAPTURED hud stills")
	quit()
