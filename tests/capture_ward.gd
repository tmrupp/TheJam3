extends SceneTree
## Close-ups of the plated guards (RisoWard): an enemy's shield whole and after a bolt, and the
## wizard's ward (tier III, two charges) whole, just broken, and half grown back.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_ward.gd

const SIZE: int = 260

var camera: Camera2D


func _initialize() -> void:
	call_deferred("capture")


func shot(at: Vector2, settle: int = 20) -> Image:
	for i: int in range(settle):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	var sp: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * at)
	var x: int = clampi(int(sp.x) - SIZE / 2, 0, 1280 - SIZE)
	var y: int = clampi(int(sp.y) - SIZE / 2, 0, 720 - SIZE)
	return root.get_texture().get_image().get_region(Rect2i(x, y, SIZE, SIZE))


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	RunState.save_path = "user://capture_ward.save"
	await process_frame
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	var player: Player = main.get_node("Player") as Player
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	for i: int in range(60):
		await process_frame
	var shots: Array[Image] = []
	# An enemy's shield.
	var foe: Node2D = null
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "mover_enemy.tscn":
			foe = n as Node2D
			break
	var shield: Shield = Shield.new()
	shield.name = "Shield"
	foe.add_child(shield)
	foe.set_physics_process(false)
	shots.append(await shot(foe.global_position))
	shield.absorb(false, Vector2.RIGHT)
	for i: int in range(4):
		await process_frame
	shots.append(await shot(foe.global_position, 2))
	shots.append(await shot(foe.global_position, 30))
	# The wizard's ward.
	player.set_physics_process(false)
	Abilities.set_tier(player, &"ward", 3)
	var ward: Ward = player.get_node("Ward") as Ward
	var at: Vector2 = player.global_position + Ward.CENTER
	shots.append(await shot(at))
	ward.take(Vector2.RIGHT)
	shots.append(await shot(at, 4))
	ward.regrowing = ward.recharge * 0.5
	shots.append(await shot(at, 30))
	var out: Image = Image.create(SIZE * shots.size(), SIZE, false, shots[0].get_format())
	for k: int in range(shots.size()):
		out.blit_rect(shots[k], Rect2i(0, 0, SIZE, SIZE), Vector2i(k * SIZE, 0))
	var output: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	out.save_png(output.path_join("ward.png"))
	print("CAPTURED ward stills to ", output)
	quit()
