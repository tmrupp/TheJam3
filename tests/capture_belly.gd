extends TestKit
## Stills of the whale's belly (Belly, Acid, Wreck): the whole of it from far out
## (belly_overview.png); its mouth as the wizard arrives (belly_mouth.png); its gullet
## (belly_gullet.png); its stomach drained, from afar and close on its pits and wreckage
## (belly_drained.png, belly_pits.png), warning (belly_warning.png) and flooded, the wizard in the
## acid (belly_flooded.png); and its heart's chamber (belly_heart.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_belly.gd

var camera: Camera2D


func run() -> void:
	window()
	await boot(28)
	camera = main.get_node("Camera2D") as Camera2D
	info.coord = Worlds.side_at(Worlds.kind_of(Belly), Vector2i(28, WhaleHunt.row()))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	# Let the place's title pass.
	await frames(200)
	save_still("belly_mouth.png")
	player.get_node("CameraControl").set_process(false)
	player.set_physics_process(false)
	await overview_still("belly_overview.png", 2)
	var acid: Acid = placed("acid.tscn")[0] as Acid
	acid.t = 0.0
	await _look(Vector2i(16, 10), "belly_gullet.png", 0.8)
	await _look(Vector2i(39, 24), "belly_drained.png", 0.7)
	await _look(Vector2i(39, 28), "belly_pits.png")
	acid.t = Acid.HOLD_LOW + Acid.WARN * 0.6
	await _look(Vector2i(39, 28), "belly_warning.png")
	acid.t = Acid.HOLD_LOW + Acid.WARN + Acid.RISE + 1.0
	player.global_position = info.cell_position(Vector2i(37, 26))
	await _look(Vector2i(39, 25), "belly_flooded.png")
	await _look(Vector2i(62, 18), "belly_heart.png", 0.8)
	RunState.delete_save()
	finish()


## The camera on cell `at` (zoomed by `zoom`) for a moment, then a still of the window as `file`.
func _look(at: Vector2i, file: String, zoom: float = 1.0) -> void:
	var was: Vector2 = camera.zoom
	camera.zoom = was * zoom
	var spot: Vector2 = info.cell_position(at)
	info.loader.wake_around(spot)
	for i: int in range(30):
		camera.global_position = spot
		camera.reset_smoothing()
		await process_frame
	save_still(file)
	camera.zoom = was
