extends SceneTree
## A sheet of a portal trip: five frames going in at the near portal (top row), then five coming
## out of the
## far one after the cut (bottom row), blown up.
## godot --path . --windowed --resolution 1280x720 --fixed-fps 30 --script res://tests/capture_portal_warp.gd

const SHOT: Vector2i = Vector2i(180, 240)
## Each frame is blown up this much, to read the details.
const ZOOM: int = 2
## Frames after using the portal (30 a second): the cut is at 0.3 s (frame 9).
const IN_FRAMES: Array[int] = [1, 3, 5, 7, 9]
const OUT_FRAMES: Array[int] = [10, 12, 14, 17, 22]


func _initialize() -> void:
	call_deferred("capture")


func grab(at: Vector2) -> Image:
	var sp: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * at)
	var x: int = clampi(int(sp.x) - SHOT.x / 2, 0, 1280 - SHOT.x)
	var y: int = clampi(int(sp.y) - SHOT.y / 2, 0, 720 - SHOT.y)
	var img: Image = root.get_texture().get_image().get_region(Rect2i(Vector2i(x, y), SHOT))
	img.resize(SHOT.x * ZOOM, SHOT.y * ZOOM, Image.INTERPOLATE_NEAREST)
	return img


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
	var portal: Node2D = null
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "portal.tscn" and not n.has_meta(&"rift"):
			portal = n as Node2D
			break
	player.global_position = portal.global_position
	for i: int in range(20):
		await physics_frame
	var art: RisoProp = portal.get_node("RisoArt") as RisoProp
	var from_center: Vector2 = art.to_global(art.portal_center())
	var to_center: Vector2 = from_center - portal.global_position + Vector2(portal.get("go_to_pos"))
	camera.global_position = from_center
	camera.reset_smoothing()
	await process_frame
	portal.call("use_portal")
	var shots: Array[Image] = []
	for frame: int in range(1, OUT_FRAMES.back() + 1):
		var going: bool = frame <= IN_FRAMES.back()
		camera.global_position = from_center if going else to_center
		camera.reset_smoothing()
		await process_frame
		await RenderingServer.frame_post_draw
		if IN_FRAMES.has(frame) or OUT_FRAMES.has(frame):
			shots.append(grab(from_center if going else to_center))
	var out: Image = Image.create(SHOT.x * ZOOM * 5, SHOT.y * ZOOM * 2, false, shots[0].get_format())
	for k: int in range(shots.size()):
		out.blit_rect(shots[k], Rect2i(Vector2i.ZERO, SHOT * ZOOM), Vector2i((k % 5) * SHOT.x * ZOOM, (k / 5) * SHOT.y * ZOOM))
	out.save_png(ProjectSettings.globalize_path("res://../art-captures/riso-frames").path_join("portal_warp.png"))
	print("CAPTURED portal warp: in %s, out %s" % [IN_FRAMES, OUT_FRAMES])
	quit()
