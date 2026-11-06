extends TestKit
## Stills of the keys, one of each colour and a skeleton key, laid out in a row in the open air of
## a level of each band (world 28), close up and at play size (legibility_<band>.png,
## legibility_<band>_wide.png): to see that they read as clearly over every band's backdrop.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_legibility.gd

## The bands to look in, and the row of each.
const BANDS: Array[StringName] = [&"garden", &"cemetery", &"institute", &"crags", &"sky"]

var camera: Camera2D


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	for band: StringName in BANDS:
		info.coord = Vector2i(28, 1 if band == &"garden" else NextWorldDef.band_row(band, 1))
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		await settle()
		player.set_physics_process(false)
		player.get_node("CameraControl").set_process(false)
		var spot: Vector2 = _open_row(6)
		player.global_position = spot + Vector2(-900, 0)
		var keys: Array[Node2D] = []
		for i: int in range(Rules.KEY_COLOR_COUNT + 1):
			var key: Node2D = load("res://prefabs/key.tscn").instantiate()
			key.set_meta(&"key_color", KeyRing.SKELETON if i == Rules.KEY_COLOR_COUNT else i)
			key.position = spot + Vector2((float(i) - 2.0) * 90.0, 0)
			info.map_elements.add_child(key)
			keys.append(key)
		await _look(spot, "legibility_%s.png" % band, 2.0)
		await _look(spot, "legibility_%s_wide.png" % band, 1.0)
		for key: Node2D in keys:
			key.queue_free()
	RunState.delete_save()
	finish()


## The middle of the first run of `long` open cells, with open cells over and under them too.
func _open_row(long: int) -> Vector2:
	var w: LevelGen = info.world
	for y: int in range(2, w.size.y - 2):
		for x: int in range(2, w.size.x - long - 2):
			var ok: bool = true
			for k: int in range(long):
				for dy: int in range(-1, 2):
					if w.is_ground(Vector2i(x + k, y + dy)):
						ok = false
			if ok:
				return (info.cell_position(Vector2i(x, y)) + info.cell_position(Vector2i(x + long - 1, y))) * 0.5
	return info.cell_position(w.size / 2)


## Hold the camera on `at` at `zoom` for a while, then save the still.
func _look(at: Vector2, file: String, zoom: float = 1.0) -> void:
	var was: Vector2 = camera.zoom
	for i: int in range(40):
		camera.global_position = at
		camera.zoom = was * zoom
		camera.reset_smoothing()
		await process_frame
	save_still(file)
	camera.zoom = was
