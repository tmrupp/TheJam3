extends TestKit
## Stills of a master's health pips whirling round it like motes (ScholarArt._pips), close up: a
## whole master at three moments a little apart, then one with half its health lost.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_master_pips.gd

var camera: Camera2D


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"institute"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	var at: Vector2i = info.world.free_floors()[0]
	for v: Vector2i in info.world.free_floors():
		if not info.world.is_ground(v + Vector2i.UP) and not info.world.is_ground(v + Vector2i(0, -2)) and not info.world.is_ground(v + Vector2i(-1, 0)) and not info.world.is_ground(v + Vector2i(1, 0)):
			at = v
			break
	for n: Node in get_nodes_in_group(&"scholar"):
		if (n as Node2D).global_position.distance_to(info.cell_position(at)) < 600.0:
			n.queue_free()
	var master: Scholar = (load("res://prefabs/master.tscn") as PackedScene).instantiate() as Scholar
	LevelLoader.arm(master, info.here.depth)
	info.map_elements.add_child(master)
	master.global_position = info.cell_position(at)
	master.setup(info, at, {"ability": &"hex", "hall": -1})
	await physics_frame
	master.set_physics_process(false)
	master.facing = 1.0
	player.global_position = info.cell_position(at) + Vector2(-900, 0)
	var middle: Vector2 = info.cell_position(at) + Vector2(0, -40)
	for k: int in range(3):
		await _look(middle, "master_pips_%d.png" % k, 2.6, 12 if k > 0 else 40)
	(master.get_node("Wound") as Wound).hp -= 3
	await _look(middle, "master_pips_hurt.png", 2.6, 20)
	RunState.delete_save()
	finish()


## Hold the camera on `at` at `zoom` for `hold` frames, then save the still.
func _look(at: Vector2, file: String, zoom: float, hold: int) -> void:
	var was: Vector2 = camera.zoom
	for i: int in range(hold):
		camera.global_position = at
		camera.zoom = was * zoom
		camera.reset_smoothing()
		await process_frame
	save_still(file)
	camera.zoom = was
