extends SceneTree
## Draw order: the wizard stood on the floor in front of background decor and props (a garden
## fence; the cemetery's headstones, crosses, angels, railings, a bell, a lantern and a door), one
## close crop each, saved as a contact sheet (layers_sheet.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_layers.gd

var main: Node
var info: MapInfo
var player: Player
var camera: Camera2D
var crops: Array[Image] = []
var names: Array[String] = []
const CROP: Vector2i = Vector2i(320, 240)


func _initialize() -> void:
	call_deferred("capture")


## The wizard standing on the floor of `cell` (an open cell over rock), the camera on them.
func shot(cell: Vector2i, name: String, dx: float = 0.0) -> void:
	var floor_y: float = info.cell_position(cell).y + 64.0
	player.global_position = Vector2(info.cell_position(cell).x + dx, floor_y - 32.0)
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	for i: int in range(12):
		await physics_frame
	player.set_physics_process(false)
	for i: int in range(12):
		camera.global_position = player.global_position + Vector2(0, -20)
		camera.reset_smoothing()
		await process_frame
	var img: Image = root.get_texture().get_image()
	var c: Image = img.get_region(Rect2i(Vector2i(640, 380) - CROP / 2, CROP))
	c.resize(CROP.x * 2, CROP.y * 2, Image.INTERPOLATE_NEAREST)
	crops.append(c)
	names.append(name)


func decor_shots(kinds: Array[StringName], tag: String) -> void:
	var decor: RisoDecor = main.get_node("RisoDecor") as RisoDecor
	for kind: StringName in kinds:
		for item: Dictionary in decor.items:
			if item["kind"] == kind:
				var cells: Array = item.get("cells", [item["cell"]])
				await shot(cells[cells.size() / 2], "%s %s" % [tag, kind])
				break


func prop_shots(files: Array[String], tag: String) -> void:
	for file: String in files:
		for n: Node in info.map_elements.get_children():
			if is_instance_valid(n) and n is Node2D and n.scene_file_path.get_file() == file:
				await shot(info.cell_at((n as Node2D).global_position), "%s %s" % [tag, file.get_basename()], 20.0)
				break


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	RunState.save_path = "user://capture_layers.save"
	await process_frame
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	player = main.get_node("Player") as Player
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.invulnerable.enable()
	for i: int in range(30):
		await process_frame
	await decor_shots([&"fence_run", &"mushroom", &"stones"], "garden")
	await prop_shots(["door.tscn", "checkpoint.tscn", "level_exit.tscn"], "garden")
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"cemetery"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	while info.world == null or info.travelling:
		await process_frame
	player.invulnerable.enable()
	for i: int in range(30):
		await process_frame
	await decor_shots([&"headstone", &"cross", &"angel", &"obelisk", &"urn", &"dead_tree", &"fence_run"], "cemetery")
	await prop_shots(["bell.tscn", "checkpoint.tscn", "door.tscn", "switch.tscn"], "cemetery")
	var cols: int = 4
	var rows: int = ceili(float(crops.size()) / cols)
	var w: int = CROP.x * 2
	var h: int = CROP.y * 2
	var sheet: Image = Image.create(w * cols, h * rows, false, Image.FORMAT_RGBA8)
	for i: int in range(crops.size()):
		var c: Image = crops[i]
		c.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(c, Rect2i(Vector2i.ZERO, c.get_size()), Vector2i((i % cols) * w, (i / cols) * h))
	var out: String = ProjectSettings.globalize_path("res://../art-captures/riso-frames")
	sheet.save_png(out.path_join("layers_sheet.png"))
	print("ORDER ", names)
	RunState.delete_save()
	print("CAPTURED layers to ", out)
	quit()
