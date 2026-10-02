extends SceneTree
## A strip of the portal trip: three departure frames at the near portal, three arrival frames at
## the far one. godot --path . --windowed --resolution 1280x720 --fixed-fps 30 --script res://tests/capture_portal_warp.gd

const SHOT_RECT: Rect2i = Rect2i(440, 160, 400, 400)
const DEPART_FRAMES: Array[int] = [1, 4, 8]
const ARRIVE_FRAMES: Array[int] = [3, 9, 18]


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
	player.get_node("CameraControl").set_process(false)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	camera.zoom *= 2.0
	var portal: Node2D = null
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "portal.tscn" and not n.has_meta(&"rift"):
			portal = n as Node2D
			break
	assert(portal != null, "A generated portal is required")
	player.global_position = portal.global_position
	for i: int in range(20):
		await physics_frame
	var art: RisoProp = portal.get_node("RisoArt") as RisoProp
	var from_center: Vector2 = art.to_global(art.portal_center())
	var to_center: Vector2 = from_center - portal.global_position + Vector2(portal.get("go_to_pos"))
	player.set_physics_process(false)
	portal.call("use_portal")
	var departs: Array[Image] = []
	var arrives: Array[Image] = []
	for frame: int in range(1, ARRIVE_FRAMES.back() + 1):
		var depart: bool = DEPART_FRAMES.has(frame)
		camera.global_position = from_center if depart else to_center
		camera.reset_smoothing()
		await process_frame
		await RenderingServer.frame_post_draw
		if depart:
			departs.append(root.get_texture().get_image().get_region(SHOT_RECT))
		elif ARRIVE_FRAMES.has(frame):
			arrives.append(root.get_texture().get_image().get_region(SHOT_RECT))
	var shots: Array[Image] = departs + arrives
	var out: Image = Image.create(400 * shots.size(), 400, false, shots[0].get_format())
	for k: int in range(shots.size()):
		out.blit_rect(shots[k], Rect2i(0, 0, 400, 400), Vector2i(k * 400, 0))
	var directory: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	DirAccess.make_dir_recursive_absolute(directory)
	out.save_png(directory.path_join("portal_warp.png"))
	print("CAPTURED portal warp: departure frames %s, arrival frames %s" % [DEPART_FRAMES, ARRIVE_FRAMES])
	quit()
