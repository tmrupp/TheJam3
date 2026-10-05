extends SceneTree
## Close-ups of the same wizard solid, astral, and solid again, with a timed levitate orb.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_astral.gd

func _initialize() -> void:
	call_deferred("capture")


func shot(player: Player, camera: Camera2D) -> Image:
	for i: int in range(6):
		camera.global_position = player.global_position + Vector2(0, -25)
		camera.reset_smoothing()
		await process_frame
	var at: Vector2 = root.get_final_transform() * player.get_global_transform_with_canvas().origin
	var crop: Image = root.get_texture().get_image().get_region(Rect2i(int(at.x) - 100, int(at.y) - 145, 200, 200))
	crop.resize(400, 400, Image.INTERPOLATE_NEAREST)
	return crop


func capture() -> void:
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://capture_astral.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	for i: int in range(40):
		await process_frame
	var player: Player = main.get_node("Player") as Player
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.end_invulnerable()
	player.get_node("CameraControl").set_process(false)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	Abilities.set_tier(player, &"astral", 2)
	var shots: Array[Image] = []
	shots.append(await shot(player, camera))
	var astral: AstralProjection = player.get_node("AstralProjection") as AstralProjection
	astral.project()
	# Compare the projection itself without the body's brief departure silhouette over it.
	(player.get_node("RisoWizard").get("ghosts") as Array).clear()
	shots.append(await shot(player, camera))
	astral.expire(astral.projection_timer)
	shots.append(await shot(player, camera))
	Abilities.set_tier(player, &"levitate", 1)
	var lev: Levitate = player.get_node("Levitate") as Levitate
	lev.set_physics_process(false)
	lev.start()
	lev.elapse(Levitate.FLOAT_TIME * 0.5)
	shots.append(await shot(player, camera))
	var out: Image = Image.create(400 * shots.size(), 400, false, shots[0].get_format())
	for i: int in range(shots.size()):
		out.blit_rect(shots[i], Rect2i(0, 0, 400, 400), Vector2i(i * 400, 0))
	out.save_png(ProjectSettings.globalize_path("res://../art-captures/riso-frames/astral_timing.png"))
	MapInfo.delete_save()
	print("CAPTURED astral and levitate")
	quit()
