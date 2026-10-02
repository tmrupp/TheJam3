extends SceneTree
## Matched close-ups and eight-second frame sequences of generated, unlinked and linked portals.
## godot --path . --windowed --resolution 1280x720 --fixed-fps 30 --script res://tests/capture_portals.gd

const SHOT_RECT: Rect2i = Rect2i(480, 200, 320, 320)
const FRAME_COUNT: int = 240
const REVIEW_PATH: String = "res://../art-captures/portal-comparison"

func _initialize() -> void:
	call_deferred("compose" if OS.get_cmdline_user_args().has("--compose-only") else "capture")


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
	camera.zoom *= 3.0
	var shots: Array[Image] = []
	var portal: Node2D = null
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "portal.tscn" and not n.has_meta(&"rift"):
			portal = n as Node2D
			break
	assert(portal != null, "A generated portal is required for the comparison")
	player.global_position = portal.global_position + Vector2(-200, 0)
	Abilities.grant(player, &"rift")
	for i: int in range(40):
		await physics_frame
	var rift: Rift = player.get_node("Rift") as Rift
	var first: Node2D = rift.cast()
	assert(first != null, "The player must be able to open the first rift")
	player.set_physics_process(false)
	player.hide()
	player.global_position = portal.global_position + Vector2(-1024, 0)
	for i: int in range(5):
		await process_frame
	shots.append(await _capture_portal(camera, portal, "generated"))
	shots.append(await _capture_portal(camera, first, "player_unlinked"))
	player.global_position = portal.global_position + Vector2(256, 0)
	var partner: Node2D = rift.cast()
	assert(partner != null and bool(first.get("linked")), "The player rift must be linked for the final comparison")
	player.global_position = portal.global_position + Vector2(-1024, 0)
	shots.append(await _capture_portal(camera, first, "player_linked"))
	var out: Image = Image.create(960, 320, false, shots[0].get_format())
	for k: int in range(shots.size()):
		out.blit_rect(shots[k], Rect2i(0, 0, 320, 320), Vector2i(k * 320, 0))
	out.save_png(ProjectSettings.globalize_path("res://../art-captures/riso-frames").path_join("teleporters.png"))
	print("CAPTURED teleporters: generated / player unlinked / player linked; 240 frames per state")
	quit()


func _capture_portal(camera: Camera2D, portal: Node2D, state: String) -> Image:
	var art: RisoProp = portal.get_node("RisoArt") as RisoProp
	art.set_process(false)
	art.phase = 0.0
	var center: Vector2 = Vector2(0, -6) if portal.has_meta(&"rift") else Vector2(0, art._ground() - RisoProp.PORTAL_RADIUS)
	var directory: String = ProjectSettings.globalize_path(REVIEW_PATH).path_join(state)
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK, "Cannot create the portal capture directory")
	var still: Image = null
	for frame_index: int in range(FRAME_COUNT):
		art.t = float(frame_index) / 30.0
		art.call("_redraw")
		camera.global_position = art.to_global(center)
		camera.reset_smoothing()
		await process_frame
		await RenderingServer.frame_post_draw
		var shot: Image = root.get_texture().get_image().get_region(SHOT_RECT)
		assert(shot.save_png(directory.path_join("frame_%04d.png" % frame_index)) == OK, "Cannot save a portal frame")
		if frame_index == FRAME_COUNT / 2:
			still = shot
	return still


func compose() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 384)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var background: ColorRect = ColorRect.new()
	background.color = Color("#e4dfe8")
	background.size = Vector2(960, 384)
	root.add_child(background)
	var states: Array[String] = ["generated", "player_unlinked", "player_linked"]
	var titles: Array[String] = ["Generated", "Player / Unlinked", "Player / Linked"]
	var captions: Array[String] = ["Blue centre | outward ripple", "Violet centre | ripple paused", "Violet centre | inward ripple"]
	var panels: Array[TextureRect] = []
	for panel_index: int in range(states.size()):
		var panel: TextureRect = TextureRect.new()
		panel.position = Vector2(panel_index * 320, 0)
		panel.size = Vector2(320, 320)
		panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		root.add_child(panel)
		panels.append(panel)
		for line_index: int in range(2):
			var label: Label = Label.new()
			label.text = titles[panel_index] if line_index == 0 else captions[panel_index]
			label.position = Vector2(panel_index * 320, 326 if line_index == 0 else 358)
			label.size = Vector2(320, 28 if line_index == 0 else 20)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_override("font", RisoTheme.serif())
			label.add_theme_font_size_override("font_size", 20 if line_index == 0 else 14)
			label.add_theme_color_override("font_color", Color("#161b3a"))
			root.add_child(label)
	var directory: String = ProjectSettings.globalize_path(REVIEW_PATH)
	for frame_index: int in range(FRAME_COUNT):
		for panel_index: int in range(states.size()):
			var image: Image = Image.load_from_file(directory.path_join(states[panel_index]).path_join("frame_%04d.png" % frame_index))
			assert(image != null and image.get_size() == Vector2i(320, 320), "Missing or invalid portal comparison frame")
			if panels[panel_index].texture == null:
				panels[panel_index].texture = ImageTexture.create_from_image(image)
			else:
				(panels[panel_index].texture as ImageTexture).update(image)
		await process_frame
		await RenderingServer.frame_post_draw
		if frame_index == FRAME_COUNT / 2:
			assert(root.get_texture().get_image().save_png(directory.path_join("comparison.png")) == OK, "Cannot save the labeled portal comparison")
	print("COMPOSED portal comparison: generated / player unlinked / player linked")
	quit()
