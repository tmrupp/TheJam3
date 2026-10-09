extends TestKit
## Stills of the crags' towers (CragsArchetype.build_towers): for a few crag levels, the camera on
## each tower, zoomed out to take it all in, and on its top room close up.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_towers.gd

var camera: Camera2D


func run() -> void:
	window()
	await boot(28)
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.health.max_health = 99
	player.health.health = 99
	var zoom: Vector2 = camera.zoom
	for k: int in [0, 4]:
		info.coord = Vector2i(28, NextWorldDef.band_row(&"crags", k))
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		await settle()
		player.set_physics_process(false)
		var n: int = 0
		for tower: Dictionary in info.world.towers:
			var box: Rect2i = tower["box"]
			var mid: Vector2 = (info.cell_position(box.position) + info.cell_position(box.end - Vector2i.ONE)) * 0.5
			player.global_position = info.cell_position(Vector2i(box.position.x - 1, box.end.y - 2))
			camera.zoom = zoom * 0.42
			await look_at(mid, "tower_%d_%d.png" % [k, n])
			camera.zoom = zoom
			await look_at(info.cell_position(box.position + Vector2i(box.size.x / 2, 2)), "tower_%d_%d_top.png" % [k, n])
			n += 1
		camera.zoom = zoom
	RunState.delete_save()
	finish()


## The camera on `at` for a moment, then a still of the window as `file`.
func look_at(at: Vector2, file: String) -> void:
	for i: int in range(20):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	save_still(file)
