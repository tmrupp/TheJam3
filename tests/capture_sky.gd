extends SceneTree
## Stills of a sky level (world 28, depth 6): where you arrive, a jump pad, a cloud that gives way
## (whole, then worn), a chasm before and after its vane is turned, an updraft, a shielded enemy, a
## watcher whose shots rebound, and the level from afar.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_sky.gd

var main: Node
var info: MapInfo
var player: Player
var camera: Camera2D
var output: String


func _initialize() -> void:
	call_deferred("capture")


func look(at: Vector2, name: String, frames: int = 30) -> void:
	for i: int in range(frames):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	root.get_texture().get_image().save_png(output.path_join(name))


func first(file: String, test: Callable = func(_n: Node) -> bool: return true) -> Node2D:
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == file and not n.is_queued_for_deletion() and test.call(n):
			return n as Node2D
	return null


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://capture_sky.save"
	await process_frame
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	player = main.get_node("Player") as Player
	camera = main.get_node("Camera2D") as Camera2D
	output = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"sky"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	while info.world == null or info.travelling:
		await process_frame
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	player.invulnerable.enable()
	for i: int in range(60):
		await process_frame
	await look(player.global_position + Vector2(0, -80), "sky_arrival.png")
	var pad: Node2D = first("pad.tscn")
	if pad != null:
		player.global_position = pad.global_position + Vector2(-150, 0)
		await look(pad.global_position + Vector2(0, -120), "sky_pad.png")
	var puff: Node2D = first("puff.tscn")
	if puff != null:
		player.global_position = puff.global_position + Vector2(0, -100)
		player.set_physics_process(true)
		for i: int in range(25):
			await physics_frame
		await look(puff.global_position + Vector2(0, -60), "sky_puff.png", 2)
		for i: int in range(18):
			await physics_frame
		await look(puff.global_position + Vector2(0, -60), "sky_puff_worn.png", 2)
		player.set_physics_process(false)
	var vane: Node2D = first("vane.tscn")
	if vane != null:
		var id: int = int(vane.get("chasm"))
		var wind: Node2D = first("wind.tscn", func(n: Node) -> bool: return int(n.get("chasm")) == id)
		player.global_position = vane.global_position + Vector2(-90, 0)
		var span: Vector2 = vane.global_position.lerp(wind.global_position, 0.5) if wind != null else vane.global_position
		await look(span + Vector2(0, -60), "sky_chasm.png")
		info.free_bell(vane.get_meta(&"cell"))
		vane.call("ring")
		await create_timer(0.8).timeout
		await look(span + Vector2(0, -60), "sky_wind.png", 5)
	var draft: Node2D = first("wind.tscn", func(n: Node) -> bool: return int(n.get("up")) > 0)
	if draft != null:
		player.global_position = draft.global_position + Vector2(-200, 0)
		await look(draft.global_position, "sky_updraft.png")
	var foe: Node2D = null
	for n: Node in info.map_elements.get_children():
		if Shield.of(n) != null:
			foe = n as Node2D
			break
	if foe != null:
		player.global_position = foe.global_position + Vector2(-300, 0)
		await look(foe.global_position + Vector2(0, -40), "sky_shield.png")
		Shield.of(foe).absorb(false, Vector2.RIGHT)
		Shield.of(foe).absorb(false, Vector2.RIGHT)
		await look(foe.global_position + Vector2(0, -40), "sky_shield_cracked.png", 5)
	var bird: Node2D = first("bird_enemy.tscn")
	if bird != null:
		await look(bird.global_position + Vector2(0, 60), "sky_bird.png")
		var b: Node = bird.get_node("Bird")
		b.set("since_swoop", 99.0)
		player.global_position = bird.global_position + Vector2(80, 320)
		for i: int in range(40):
			camera.global_position = bird.global_position
			camera.reset_smoothing()
			await physics_frame
		await look(bird.global_position, "sky_bird_swoop.png", 2)
		player.global_position = bird.global_position + Vector2(0, -2000)
	var decor: RisoDecor = main.get_node("RisoDecor") as RisoDecor
	for kind: StringName in [&"fence_run", &"menhir", &"cairn"]:
		for item: Dictionary in decor.items:
			if item["kind"] == kind:
				player.global_position = info.cell_position(item["cell"]) + Vector2(-260, -2000)
				await look(info.cell_position(item["cell"]) + Vector2(140 if kind == &"fence_run" else 0, -40), "sky_decor_%s.png" % kind)
				break
	var watcher: Node2D = first("shooter_enemy.tscn", func(n: Node) -> bool: return int(n.get_meta(&"bounces", 0)) > 0)
	if watcher != null:
		player.global_position = watcher.global_position + Vector2(-260, 0)
		var shot: Node2D = (load("res://prefabs/bullet.tscn") as PackedScene).instantiate()
		info.map_elements.add_child(shot)
		shot.global_position = watcher.global_position + Vector2(-80, -30)
		shot.call("setup", Vector2(-120, 0), [watcher], watcher)
		shot.set("bounces", 2)
		await look(watcher.global_position + Vector2(-60, -40), "sky_watcher.png")
	# The level from afar (the camera let past its limits).
	camera.limit_left = -100000
	camera.limit_top = -100000
	camera.limit_right = 100000
	camera.limit_bottom = 100000
	camera.zoom = Vector2(0.18, 0.18)
	await look(info.cell_position(info.world.size / 2), "sky_overview.png")
	camera.zoom = Vector2.ONE
	camera.zoom = Vector2.ONE
	# The level's printed map: the clusters and the gaps between.
	info.ink_whole_map()
	main.get_node("RisoMap").call("toggle")
	for i: int in range(20):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("sky_map.png"))
	MapInfo.delete_save()
	print("CAPTURED sky stills to ", output)
	quit()
