extends SceneTree
## Stills of a cemetery level (world 28, depth 3): where you arrive, a wraith, moths round the lit
## lantern, a bank of sleep fog with the wizard drowsy in it, a chasm before and after its bell is
## rung, and the level's printed map; first, the garden level the run starts in, with its
## background fences.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_cemetery.gd

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


func first(file: String) -> Node2D:
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == file and not n.is_queued_for_deletion():
			return n as Node2D
	return null


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://capture_cemetery.save"
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
	# First, the garden level the run starts in, for its background fences: the wizard beside one,
	# the camera following as in play.
	for i: int in range(30):
		await process_frame
	var decor: RisoDecor = main.get_node("RisoDecor") as RisoDecor
	for item: Dictionary in decor.items:
		if item["kind"] == &"fence_run":
			player.global_position = info.cell_position(item["cell"])
			break
	for i: int in range(90):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("garden_fences.png"))
	# A gate in the garden, padlocked in its key's colour.
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "door.tscn":
			player.global_position = (n as Node2D).global_position + Vector2(-150, 0)
			break
	for i: int in range(90):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("garden_gate.png"))
	info.coord = Vector2i(28, 3)
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	while info.world == null or info.travelling:
		await process_frame
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	print("archetype ", info.here.archetype, " realm ", RisoPrint.instance.realm)
	for i: int in range(60):
		await process_frame
	await look(player.global_position + Vector2(0, -80), "cemetery_arrival.png")
	var wraith: Node2D = first("wraith_enemy.tscn")
	if wraith != null:
		await look(wraith.global_position, "cemetery_wraith.png")
		# Chasing: its eyes light up pink.
		player.global_position = wraith.global_position + Vector2(380, 0)
		player.invulnerable.enable()
		for i: int in range(20):
			await physics_frame
		await look(wraith.global_position, "cemetery_wraith_chasing.png", 5)
	# Light the lantern by the way in: the moths come to it.
	var lantern: Node2D = null
	for n: Node in info.map_elements.get_children():
		if n is Checkpoint and not info.is_lantern_spent(n):
			lantern = n as Node2D
			break
	if lantern != null:
		info.light_lantern(lantern)
		player.global_position = lantern.global_position + Vector2(-200, 0)
		for i: int in range(600):
			await physics_frame
		await look(lantern.global_position + Vector2(0, -60), "cemetery_moths.png", 10)
		# Scattered by a hex: faint, a pink point where they will gather.
		for n: Node in info.map_elements.get_children():
			if n is MothSwarm and (n as MothSwarm).drawn_to == &"lantern":
				(n as MothSwarm).scatter(Vector2.RIGHT)
		await create_timer(0.6).timeout
		await look(lantern.global_position + Vector2(0, -60), "cemetery_moths_scattered.png", 5)
	var fog: Node2D = first("sleep_fog.tscn")
	if fog != null:
		Abilities.grant(player, &"hex")
		player.global_position = fog.global_position + Vector2(0, -10)
		player.set_physics_process(true)
		for i: int in range(30):
			await physics_frame
		player.set_physics_process(false)
		print("drowsy in fog: ", player.is_drowsy())
		await look(fog.global_position + Vector2(0, -60), "cemetery_fog.png", 10)
	# A chasm and its bell, before and after the bell is rung.
	var bell: Node2D = first("bell.tscn")
	if bell != null:
		player.global_position = bell.global_position + Vector2(-60, 0)
		var span: Vector2 = bell.global_position
		for n: Node in info.map_elements.get_children():
			if n.scene_file_path.get_file() == "bridge.tscn" and int(n.get("chasm")) == int(bell.get("chasm")):
				span = span.lerp((n as Node2D).global_position, 0.5)
		await look(span + Vector2(0, -60), "cemetery_chasm.png")
		await look(bell.global_position + Vector2(40, -80), "cemetery_bell.png", 10)
		bell.call("open")
		bell.call("ring")
		await create_timer(0.35).timeout
		root.get_texture().get_image().save_png(output.path_join("cemetery_bridge_laying.png"))
		await create_timer(1.2).timeout
		await look(span + Vector2(0, -60), "cemetery_bridge.png", 5)
	# The whole level from afar.
	camera.zoom = Vector2(0.25, 0.25)
	await look(info.cell_position(info.world.size / 2), "cemetery_overview.png")
	camera.zoom = Vector2.ONE
	info.ink_whole_map()
	var map: Node = main.get_node("RisoMap")
	map.call("toggle")
	for i: int in range(20):
		await process_frame
	root.get_texture().get_image().save_png(output.path_join("cemetery_map.png"))
	MapInfo.delete_save()
	print("CAPTURED cemetery stills to ", output)
	quit()
