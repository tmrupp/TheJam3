extends SceneTree
## Stills of the start menu, its settings page, the controls page (one row waiting for its key) and
## the credits page off it, the pause menu, a demo build's won card (the bosses past its garden
## faint beside the two won, the run in a line, its two lines, and the chevron once a press will
## take it), and the start menu once the game has been won (the trophies across its top), printed.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_menu.gd

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	TestKit.out_of_sight()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	RunState.save_path = "user://capture_menu.save"
	Tutorial.settings_path = "user://capture_menu.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Tutorial.settings_path))
	for i: int in range(40):
		await process_frame
	var output: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	root.get_texture().get_image().save_png(output.path_join("menu_start.png"))
	# Once won: the trophies across the top.
	Trophy.note_won(Bands.bosses())
	for i: int in range(10):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("menu_start_won.png"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Tutorial.settings_path))
	var menu: Menu = main.get_node("Menu") as Menu
	menu.open_settings()
	for i: int in range(10):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("menu_settings.png"))
	menu.open_controls()
	menu.listen(&"Spell")
	for i: int in range(10):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("menu_controls.png"))
	menu.close_controls()
	menu.open_credits()
	for i: int in range(10):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("menu_credits.png"))
	menu.close_credits()
	menu.close_settings()
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
	main.get_node("Menu").call("pause_resume_game")
	# A demo build's won card, shown without ending the run (win_run would go back to the menu).
	MapInfo.demo_build = true
	info.won = true
	info.run_ending = 1.0
	info.won_for = MapInfo.WIN_HOLD
	info.run.play_time = 1234.0
	for i: int in range(30):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("menu_won_demo.png"))
	MapInfo.demo_build = false
	RunState.delete_save()
	print("CAPTURED menus to ", output)
	quit()
