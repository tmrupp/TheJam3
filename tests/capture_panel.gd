extends SceneTree
## Stills of the F7 panel in a debug run: as it opens (travel and print open, the rest folded), and
## with the abilities section opened.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_panel.gd

func _initialize() -> void:
	call_deferred("capture")


func frames(n: int) -> void:
	for i: int in range(n):
		await process_frame


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	MapInfo.save_path = "user://capture_panel.save"
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	var menu: Node = main.get_node("Menu")
	menu.set_debug(true)
	menu.world_seed.text = "28"
	menu.start_game()
	while MapInfo.instance == null or MapInfo.instance.world == null or MapInfo.instance.travelling:
		await process_frame
	await frames(10)
	var output: String = ProjectSettings.globalize_path("res://../art-captures/panel")
	DirAccess.make_dir_recursive_absolute(output)
	var riso: RisoPrint = RisoPrint.instance
	riso.set_pad_panel(true)
	await frames(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("panel_folded.png"))
	riso.set_section("Print", false)
	riso.set_section("Abilities", true)
	await frames(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("panel_abilities.png"))
	riso.set_section("Print", true)
	riso.set_section("Abilities", false)
	riso.set_pad_panel(false)
	print("CAPTURED panel stills to ", output)
	quit()
