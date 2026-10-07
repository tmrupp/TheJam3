extends SceneTree
## The printed map opened over the level, with the wizard at a lantern (its prompt up): nothing in
## the level, nor the level's UI, may show over the map's sheet.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_map_over.gd

func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	RunState.save_path = "user://capture_map_over.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	for i: int in range(5):
		await process_frame
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	for i: int in range(30):
		await process_frame
	var player: Player = main.get_node("Player") as Player
	var lamp: Node2D = null
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "checkpoint.tscn":
			lamp = n as Node2D
			break
	player.global_position = lamp.global_position + Vector2(-30, 0)
	lamp.get_node("Interactable").set("touching", true)
	for i: int in range(20):
		await process_frame
	RisoPrint.instance.map_view.call("toggle")
	for i: int in range(30):
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../art-captures/riso-frames").path_join("map_over_level.png"))
	print("CAPTURED map")
	quit()
