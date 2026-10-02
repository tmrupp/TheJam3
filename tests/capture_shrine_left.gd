extends SceneTree
## A spent shrine holding the spell a swap left behind: away (the mark in its niche) and at it
## (the take-back pop-up).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_shrine_left.gd

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
	for i: int in range(30):
		await process_frame
	var player: Player = main.get_node("Player") as Player
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	var shrine: Node2D = null
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "shrine.tscn":
			shrine = n as Node2D
	for a: StringName in Abilities.ORDER:
		player.tiers[a] = 0 if a in Abilities.SPELLS else int(Abilities.MAX[a])
	player.tiers[&"hex"] = 2
	Abilities.apply(player)
	player.collect(500)
	var k: int = 0 if bool(shrine.call("swap", 0)) else 1
	shrine.call("buy_boon", k)
	var out: Image = null
	var shots: Array[Image] = []
	for spot: int in range(2):
		var niche: Node2D = shrine.get_node("Boon" if k == 0 else "Boon2") as Node2D
		player.global_position = niche.global_position + (Vector2(-300, 0) if spot == 0 else Vector2.ZERO)
		for i: int in range(30):
			camera.global_position = shrine.global_position + Vector2(64, -80)
			camera.reset_smoothing()
			await process_frame
		shots.append(root.get_texture().get_image().get_region(Rect2i(340, 60, 600, 500)))
	out = Image.create(1200, 500, false, shots[0].get_format())
	for i: int in range(2):
		out.blit_rect(shots[i], Rect2i(0, 0, 600, 500), Vector2i(i * 600, 0))
	out.save_png(ProjectSettings.globalize_path("res://../art-captures/riso-frames").path_join("shrine_left_spell.png"))
	print("CAPTURED left spell")
	quit()
