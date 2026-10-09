extends SceneTree
## Stills of the sigils (Sigils) in play: in a garden level and a cemetery level, each switch
## beside what it works (a gate, a bell, a lift), each teleporter, a bell's prompt, a switch gate
## lifting, and the printed map of each.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_sigils.gd

const SIZE: int = 400
const COLUMNS: int = 4
const PLACES: Array[Vector2i] = [Vector2i(28, 3), Vector2i(28, 9)]

var camera: Camera2D


func _initialize() -> void:
	call_deferred("capture")


func shot(at: Vector2) -> Image:
	for i: int in range(40):
		camera.global_position = at + Vector2(0, -80)
		camera.reset_smoothing()
		await process_frame
	var sp: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * (at + Vector2(0, -80)))
	var x: int = clampi(int(sp.x) - SIZE / 2, 0, 1280 - SIZE)
	var y: int = clampi(int(sp.y) - SIZE / 2, 0, 720 - SIZE)
	return root.get_texture().get_image().get_region(Rect2i(x, y, SIZE, SIZE))


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	RunState.save_path = "user://capture_sigils.save"
	await process_frame
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	var player: Player = main.get_node("Player") as Player
	camera = main.get_node("Camera2D") as Camera2D
	var output: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	for place: Vector2i in PLACES:
		info.debug = true
		info.debug_travel(place)
		await process_frame
		while info.world == null or info.travelling or info.coord != place:
			await process_frame
		player.set_physics_process(false)
		player.get_node("CameraControl").set_process(false)
		player.global_position = Vector2(-9000, -9000)
		for i: int in range(90):
			await process_frame
		var shots: Array[Image] = []
		for n: Node in info.map_elements.get_children():
			var file: String = n.scene_file_path.get_file()
			if file == "switch.tscn":
				shots.append(await shot((n as Node2D).global_position))
				shots.append(await shot(info.cell_position((n as Switch).gate_cell)))
			elif file == "portal.tscn":
				shots.append(await shot((n as Node2D).global_position))
		var rows: int = (shots.size() + COLUMNS - 1) / COLUMNS
		var out: Image = Image.create(SIZE * COLUMNS, SIZE * rows, false, shots[0].get_format())
		for k: int in range(shots.size()):
			out.blit_rect(shots[k], Rect2i(0, 0, SIZE, SIZE), Vector2i((k % COLUMNS) * SIZE, (k / COLUMNS) * SIZE))
		out.save_png(output.path_join("sigils_%d_%d.png" % [place.x, place.y]))
		# Close by a bell chained to a switch: its prompt shows the switch emblem and the sigil.
		for n: Node in info.map_elements.get_children():
			if n is Bell and (n as Bell).lock == Bell.SWITCH_LOCK:
				player.global_position = (n as Node2D).global_position + Vector2(-20, 0)
				for i: int in range(30):
					await physics_frame
				var prompt: Image = await shot((n as Node2D).global_position)
				prompt.save_png(output.path_join("sigils_prompt_%d_%d.png" % [place.x, place.y]))
				player.global_position = Vector2(-9000, -9000)
				break
		# A switch gate lifting, its plate going up with it.
		for n: Node in info.map_elements.get_children():
			if n is SwitchGate:
				var at: Vector2 = (n as Node2D).global_position
				await shot(at)
				(n as SwitchGate).set_up(true)
				for i: int in range(18):
					await process_frame
				var opening: Image = root.get_texture().get_image()
				opening.save_png(output.path_join("sigils_gate_opening_%d_%d.png" % [place.x, place.y]))
				break
		info.ink_whole_map()
		var map: Node = main.get_node("RisoMap")
		map.call("toggle")
		for i: int in range(20):
			await process_frame
		root.get_texture().get_image().save_png(output.path_join("sigils_map_%d_%d.png" % [place.x, place.y]))
		map.call("toggle")
		for i: int in range(5):
			await process_frame
	print("CAPTURED sigil stills to ", output)
	quit()
