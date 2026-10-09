extends SceneTree
## A sheet of the portals, a row per style (TV static, ripples): a level's gate, the same
## gate with the wizard close by, and a linked rift; then a rift waiting for its partner (the
## same in every style).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_portals.gd

const SHOT: Vector2i = Vector2i(300, 360)


func _initialize() -> void:
	call_deferred("capture")


func shot(camera: Camera2D, at: Vector2) -> Image:
	for i: int in range(20):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	var sp: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * at)
	var x: int = clampi(int(sp.x) - SHOT.x / 2, 0, 1280 - SHOT.x)
	var y: int = clampi(int(sp.y) - SHOT.y / 2, 0, 720 - SHOT.y)
	return root.get_texture().get_image().get_region(Rect2i(Vector2i(x, y), SHOT))


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	RunState.save_path = "user://capture_portals.save"
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
	var art: PortalArt = portal.get_node("RisoArt") as PortalArt
	var gate_at: Vector2 = art.to_global(art.portal_center()) + Vector2(0, -10)
	player.set_physics_process(false)
	# A rift waiting for its partner, then linked (opened in mid air at tier II, beside the gate).
	Abilities.set_tier(player, &"rift", 2)
	var rift: Rift = player.get_node("Rift") as Rift
	player.global_position = portal.global_position + Vector2(-300, -40)
	var first: Node2D = rift.cast()
	player.global_position = portal.global_position + Vector2(-900, -400)
	var waiting: Image = await shot(camera, first.global_position)
	player.global_position = portal.global_position + Vector2(300, -40)
	rift.cast()
	var rows: Array[Array] = []
	for style: StringName in RisoPrint.PORTAL_STYLES:
		RisoPrint.instance.portal_style = style
		var row: Array[Image] = []
		player.global_position = portal.global_position + Vector2(-900, -400)
		row.append(await shot(camera, gate_at))
		player.global_position = portal.global_position + Vector2(-12, 0)
		row.append(await shot(camera, gate_at))
		player.global_position = portal.global_position + Vector2(-900, -400)
		row.append(await shot(camera, first.global_position))
		rows.append(row)
	RisoPrint.instance.portal_style = &"static"
	var out: Image = Image.create(SHOT.x * 4, SHOT.y * rows.size(), false, waiting.get_format())
	for r: int in range(rows.size()):
		for c: int in range(3):
			out.blit_rect(rows[r][c], Rect2i(Vector2i.ZERO, SHOT), Vector2i(c * SHOT.x, r * SHOT.y))
	out.blit_rect(waiting, Rect2i(Vector2i.ZERO, SHOT), Vector2i(3 * SHOT.x, 0))
	out.save_png(ProjectSettings.globalize_path("res://../art-captures/riso-frames").path_join("teleporters.png"))
	print("CAPTURED teleporters: rows static / ripples; gate, gate near, rift linked; rift waiting")
	quit()
