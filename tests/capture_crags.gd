extends TestKit
## Stills of a crag level (world 28, the band's second row): where you arrive, the whole cliff
## zoomed out, the castle's decor (battlements, an arrow slit, a banner, a broken column, rubble), a
## door, and a gondola waiting, mid-ride (shut, its wraiths about) and at the top.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_crags.gd

var camera: Camera2D


func run() -> void:
	window()
	await boot(28)
	info.coord = Vector2i(28, NextWorldDef.band_row(&"crags", 1))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.health.max_health = 99
	player.health.health = 99
	await frames(30)
	await look(player.global_position + Vector2(0, -120), "crags_arrival.png")
	# The whole cliff, zoomed out.
	var zoom: Vector2 = camera.zoom
	camera.zoom = zoom * 0.25
	await look(info.cell_position(info.world.size / 2), "crags_whole.png")
	camera.zoom = zoom
	var decor: RisoDecor = main.get_node("RisoDecor") as RisoDecor
	for want: StringName in [&"battlement", &"slit", &"banner", &"column", &"rubble"]:
		for item: Dictionary in decor.items:
			if item["kind"] == want or item.has(String(want)):
				await look(info.cell_position(item["cell"]) + Vector2(0, -60), "crags_%s.png" % want)
				break
	var doors: Array[Node] = placed("door.tscn")
	if not doors.is_empty():
		await look((doors[0] as Node2D).global_position, "crags_door.png")
	# A gondola waiting, then ridden: shut, its wraiths called up on the way, and at the top.
	var gondolas: Array[Node] = placed("gondola.tscn")
	if not gondolas.is_empty():
		var g: Gondola = gondolas[0] as Gondola
		await look(g.center(), "crags_gondola.png")
		player.global_position = g.global_position + Vector2(0, -60)
		player.velocity = Vector2.ZERO
		await until(func() -> bool: return g.state == Gondola.State.RIDING and g.progress > 0.55)
		await look(g.center(), "crags_gondola_ride.png", false)
		await until(func() -> bool: return g.state != Gondola.State.RIDING)
		await look(g.center() + Vector2(0, 80), "crags_gondola_top.png", false)
	RunState.delete_save()
	finish()


## The camera on `at` for a moment (or at once, if not `wait`), then a still of the window as `file`.
func look(at: Vector2, file: String, wait: bool = true) -> void:
	for i: int in range(20 if wait else 3):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	save_still(file)
