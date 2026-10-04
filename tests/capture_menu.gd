extends SceneTree
## Stills of the start menu and the pause menu, printed.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_menu.gd

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://capture_menu.save"
	for i: int in range(40):
		await process_frame
	var output: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	root.get_texture().get_image().save_png(output.path_join("menu_start.png"))
	main.get_node("Menu").start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	for i: int in range(30):
		await process_frame
	main.get_node("Menu").call("pause_resume_game")
	for i: int in range(20):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("menu_pause.png"))
	print("CAPTURED menus to ", output)
	quit()
