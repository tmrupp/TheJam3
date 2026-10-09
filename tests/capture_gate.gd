extends SceneTree
## Stills of a gate (Bosses): the sealed way on at the head of the bramble's shaft, the stand-in
## boss in the necromancer's arena (whole, then struck, and the arena), the relic it leaves, and the
## necromancer's way on opened. The worm and the bramble, which are built, have capture_worm and
## capture_bramble.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_gate.gd

const SIZE: int = 420

var camera: Camera2D
var info: MapInfo


func _initialize() -> void:
	call_deferred("capture")


func shot(at: Vector2) -> Image:
	for i: int in range(30):
		camera.global_position = at + Vector2(0, -60)
		camera.reset_smoothing()
		await process_frame
	var sp: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * (at + Vector2(0, -60)))
	var x: int = clampi(int(sp.x) - SIZE / 2, 0, 1280 - SIZE)
	var y: int = clampi(int(sp.y) - SIZE / 2, 0, 720 - SIZE)
	return root.get_texture().get_image().get_region(Rect2i(x, y, SIZE, SIZE))


func go(at: Vector2i, player: Player) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await process_frame
	while info.world == null or info.travelling:
		await process_frame
	player.set_physics_process(false)
	player.global_position = Vector2(-9000, -9000)
	for i: int in range(30):
		await process_frame


func node(scene: String) -> Node2D:
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == scene:
			return n as Node2D
	return null


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	RunState.save_path = "user://capture_gate.save"
	await process_frame
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	var player: Player = main.get_node("Player") as Player
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	var shots: Array[Image] = []
	# The sealed way on, at the head of the bramble's shaft.
	await go(Vector2i(28, -NextWorldDef.GARDEN_ROWS), player)
	var on: Vector2 = info.cell_position(info.world.exits[MapInfo.Exit.DEEPER])
	shots.append(await shot(on))
	# The stand-in, in the necromancer's arena: whole, struck, and the relic it leaves.
	await go(Worlds.side_at(Worlds.kind_of(Arena), Vector2i(28, NextWorldDef.GARDEN_ROWS + NextWorldDef.BAND)), player)
	var boss: Boss = node("boss.tscn") as Boss
	boss.get_node("Mover").set_physics_process(false)
	shots.append(await shot(boss.global_position))
	var wound: Wound = boss.get_node("Wound") as Wound
	for i: int in range(4):
		wound.hit(1, Vector2.RIGHT)
	shots.append(await shot(boss.global_position))
	shots.append(await shot(boss.global_position + Vector2(-300, 0)))
	while is_instance_valid(boss) and not boss.is_queued_for_deletion():
		wound.hit(1, Vector2.RIGHT)
	await process_frame
	var relic: Node2D = null
	for n: Node in info.map_elements.get_children():
		if n.has_meta(&"boss"):
			relic = n as Node2D
	shots.append(await shot(relic.global_position))
	# Back out, the necromancer's way on open.
	await go(Vector2i(28, NextWorldDef.GARDEN_ROWS + NextWorldDef.BAND), player)
	shots.append(await shot(info.cell_position(info.world.exits[MapInfo.Exit.DEEPER])))
	var out: Image = Image.create(SIZE * 3, SIZE * 2, false, shots[0].get_format())
	for k: int in range(shots.size()):
		out.blit_rect(shots[k], Rect2i(0, 0, SIZE, SIZE), Vector2i((k % 3) * SIZE, (k / 3) * SIZE))
	var output: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	out.save_png(output.path_join("gate.png"))
	RunState.delete_save()
	print("CAPTURED gate stills to ", output)
	quit()
