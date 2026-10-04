extends SceneTree
## Windowed stills of the printed transition between levels: sweeping in, covering the view with
## the destination named, and sweeping away.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_transition.gd

func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://capture_transition.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	for i: int in range(5):
		await process_frame
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	for i: int in range(20):
		await process_frame
	var out: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	var sheet: RisoTransition = RisoTransition.instance
	info.travel(MapInfo.Exit.DEEPER)
	var shots: Dictionary = {"transition_in.png": false, "transition_covered.png": false, "transition_out.png": false}
	for i: int in range(240):
		await process_frame
		var name: String = ""
		if sheet.state == RisoTransition.State.COVERING and sheet.lead > 0.5 and not shots["transition_in.png"]:
			name = "transition_in.png"
		elif sheet.state == RisoTransition.State.COVERED and not shots["transition_covered.png"]:
			name = "transition_covered.png"
		elif sheet.state == RisoTransition.State.REVEALING and sheet.trail > 0.45 and not shots["transition_out.png"]:
			name = "transition_out.png"
		if name != "":
			shots[name] = true
			root.get_texture().get_image().save_png(out.path_join(name))
	print("CAPTURED ", shots)
	quit()
