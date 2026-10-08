extends TestKit
## Stills of light and darkness by line of sight (RisoLight): the garden by the start (sight on,
## then off on the F7 panel to compare), the garden by its deeper exit, and the catacombs' deep
## dark, protected and unprotected. Written whole (sight_*.png) and as one sheet (sight.png). Prints
## how long the light takes a frame.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_sight.gd

const SHOT: Vector2i = Vector2i(640, 400)


func run() -> void:
	window()
	await boot(28)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	var light: RisoLight = main.get_node("RisoLight") as RisoLight
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	var shots: Array[Image] = []
	shots.append(await _shot(camera, "sight_start.png"))
	RisoLight.by_sight = false
	shots.append(await _shot(camera, "sight_start_off.png"))
	RisoLight.by_sight = true
	player.global_position = info.cell_position(info.world.exits[MapInfo.Exit.DEEPER]) + Vector2(-140, 20)
	shots.append(await _shot(camera, "sight_exit.png"))
	_time(light)
	info.coord = Vector2i(28, NextWorldDef.band_row(&"catacombs", 0))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	for vulnerable: bool in [false, true]:
		info.run.vulnerable = vulnerable
		shots.append(await _shot(camera, "sight_catacombs_%s.png" % ("unlit" if vulnerable else "lit")))
	_time(light)
	var sheet: Image = Image.create(SHOT.x * 2, SHOT.y * 3, false, shots[0].get_format())
	for k: int in range(shots.size()):
		sheet.blit_rect(shots[k], Rect2i(Vector2i.ZERO, SHOT), Vector2i((k % 2) * SHOT.x, (k / 2) * SHOT.y))
	save_still("sight.png", sheet)
	RunState.delete_save()
	finish()


## The view round the wizard, saved whole as `file`; returns its middle.
func _shot(camera: Camera2D, file: String) -> Image:
	for i: int in range(30):
		camera.global_position = player.global_position
		camera.reset_smoothing()
		await process_frame
	save_still(file)
	var img: Image = root.get_texture().get_image()
	return img.get_region(Rect2i((img.get_width() - SHOT.x) / 2, (img.get_height() - SHOT.y) / 2, SHOT.x, SHOT.y))


## How long the light takes a frame, on average over a few.
func _time(light: RisoLight) -> void:
	var start: int = Time.get_ticks_usec()
	for i: int in range(20):
		light._process(0.016)
	print("light: %.2f ms a frame" % (float(Time.get_ticks_usec() - start) / 20000.0))
